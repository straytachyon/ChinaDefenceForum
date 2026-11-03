import Foundation

enum SMFError: LocalizedError, Equatable {
    case notLoggedIn
    case loginFailed(String)
    case http(Int)
    case parsing(String)
    case network(String)
    case postFailed(String)

    var errorDescription: String? {
        switch self {
        case .notLoggedIn:
            return "Your session has ended. Please sign in again."
        case .loginFailed(let message):
            return message
        case .http(403):
            return "The forum refused the request (403). It may require a different network or block automated clients."
        case .http(503):
            return "The forum is temporarily unavailable (503). Try again shortly."
        case .http(let code):
            return "The forum returned an unexpected response (HTTP \(code))."
        case .parsing(let message):
            return "Unexpected page from the forum: \(message)"
        case .network(let message):
            return "Network error: \(message)"
        case .postFailed(let message):
            return message
        }
    }
}

/// Talks to the forum. All requests share a cookie jar so the SMF session created by the
/// scraped login form is reused for every later page.
actor SMFClient {
    /// One client for the whole app keeps a single cookie jar and session.
    static let shared = SMFClient()

    private let baseURL: URL
    private let session: URLSession
    private let redirectDelegate = SMFRedirectDelegate()

    init(baseURL: URL = AppConfig.baseURL) {
        self.baseURL = baseURL

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.httpShouldSetCookies = true
        configuration.httpCookieStorage = .shared
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpAdditionalHeaders = [
            "User-Agent": AppConfig.userAgent,
            "Accept-Language": "en-US,en;q=0.9",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        ]
        self.session = URLSession(
            configuration: configuration,
            delegate: redirectDelegate,
            delegateQueue: nil
        )
    }

    // MARK: - Public API

    func fetchCurrentUser() async throws -> SMFUser {
        let (html, _) = try await get(url("") )
        let member = SMFParser.parseMember(in: html)
        guard member.id > 0 else { throw SMFError.notLoggedIn }
        return SMFUser(id: member.id, name: member.name ?? "Member")
    }

    func login(username: String, password: String) async throws -> SMFUser {
        let (loginHTML, loginURL) = try await get(url("action=login"))
        let document = HTMLParser.parse(loginHTML)

        guard let form = document.all(where: { $0.tag == "form" })
            .first(where: { $0.attr("id") == "frmLogin" || $0.attr("name") == "frmLogin" }),
            let action = form.attr("action"),
            let actionURL = AppConfig.resolve(action, relativeTo: loginURL) else {
            throw SMFError.parsing("the login form could not be found")
        }

        // SMF protects the login POST with per-session hidden fields; forward all of them.
        var fields: [String: String] = [:]
        for input in form.allTags("input") {
            guard let name = input.attr("name") else { continue }
            let type = (input.attr("type") ?? "text").lowercased()
            if type == "submit" || type == "button" || type == "image" || type == "checkbox" { continue }
            fields[name] = input.attr("value") ?? ""
        }
        fields["user"] = username
        fields["passwrd"] = password
        fields["hash_passwrd"] = ""
        // 3153600 is the forum's own "Forever" choice for "Time to stay logged in".
        fields["cookielength"] = "3153600"

        var request = URLRequest(url: actionURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue(loginURL.absoluteString, forHTTPHeaderField: "Referer")
        request.httpBody = Self.formEncode(fields).data(using: .utf8)

        let (data, response) = try await perform(request)
        let html = Self.decode(data, response: response)
        let resultDocument = HTMLParser.parse(html)

        if let message = Self.loginErrorMessage(in: resultDocument) {
            throw SMFError.loginFailed(message)
        }

        let member = SMFParser.parseMember(in: html)
        guard member.id > 0 else {
            throw SMFError.loginFailed("The forum did not accept that username and password.")
        }
        return SMFUser(id: member.id, name: member.name ?? username)
    }

    func fetchBoardIndex() async throws -> BoardIndexResult {
        let (html, _) = try await get(url(""))
        try ensureLoggedIn(html)
        let result = SMFParser.parseBoardIndex(html)
        guard !result.categories.isEmpty else {
            throw SMFError.parsing("no boards were found on the index page")
        }
        return result
    }

    func fetchUnread(start: Int = 0) async throws -> TopicListPage {
        let (html, _) = try await get(url("action=unread;all;start=\(start)"))
        try ensureLoggedIn(html)
        return SMFParser.parseTopicList(html, start: start)
    }

    func fetchBoard(id: Int, start: Int = 0) async throws -> TopicListPage {
        let (html, _) = try await get(url("board=\(id).\(start)"))
        try ensureLoggedIn(html)
        return SMFParser.parseTopicList(html, start: start)
    }

    func fetchTopic(id: Int, start: Int?, messageID: Int? = nil, jumpToNew: Bool) async throws -> TopicPage {
        let query: String
        if let start {
            query = "topic=\(id).\(start)"
        } else if let messageID {
            query = "topic=\(id).msg\(messageID)"
        } else if jumpToNew {
            query = "topic=\(id).new"
        } else {
            query = "topic=\(id).0"
        }

        let (html, finalURL) = try await get(url(query))
        try ensureLoggedIn(html)

        var page = SMFParser.parseTopic(html, topicID: id, start: start ?? 0)
        if let requested = messageID,
           let finalTopic = Self.number(after: "topic=", in: finalURL.absoluteString),
           finalTopic != id {
            // The stored unread message belonged to another topic; fall back to
            // SMF's own ".new" jump for the requested topic.
            let (fallbackHTML, fallbackURL) = try await get(url("topic=\(id).new"))
            try ensureLoggedIn(fallbackHTML)
            page = SMFParser.parseTopic(fallbackHTML, topicID: id, start: 0)
            if let target = Self.number(after: "msg", in: fallbackURL.absoluteString) {
                page.targetMessageID = target
            }
            _ = requested
        }
        if jumpToNew, let target = Self.number(after: "msg", in: finalURL.absoluteString) {
            // SMF resolves ".new" to topic=ID.msgNNN#new; that NNN is the true target.
            page.targetMessageID = target
        }
        if page.posts.isEmpty, messageID != nil || jumpToNew {
            // ".new" can resolve to an odd page (or none) when the topic has been read.
            let (fallbackHTML, fallbackURL) = try await get(url("topic=\(id).0"))
            try ensureLoggedIn(fallbackHTML)
            page = SMFParser.parseTopic(fallbackHTML, topicID: id, start: 0)
            if jumpToNew, let target = Self.number(after: "msg", in: fallbackURL.absoluteString) {
                page.targetMessageID = target
            }
        }
        guard !page.posts.isEmpty else {
            throw SMFError.parsing("the topic had no readable posts")
        }
        return page
    }

    func resolveTopic(from url: URL) async throws -> ResolvedTopic {
        let (html, finalURL) = try await get(url)
        try ensureLoggedIn(html)
        let text = finalURL.absoluteString + " " + url.absoluteString
        guard let topicID = Self.number(after: "topic=", in: text) else {
            throw SMFError.parsing("the notification did not point to a topic")
        }
        let page = SMFParser.parseTopic(html, topicID: topicID, start: 0)
        let target = Self.number(after: "msg", in: text)
            ?? SMFParser.messageID(fromHTML: html)
        let first = page.posts.first
        let last = page.posts.last
        let topic = ForumTopic(
            id: topicID,
            title: page.title.isEmpty ? "Thread" : page.title,
            author: first?.author ?? "",
            replies: 0,
            views: 0,
            lastPostText: last?.dateText ?? "",
            isUnread: false,
            isSticky: false,
            isLocked: false,
            pageCount: max(1, page.maxStart / max(page.perPage, 1) + 1),
            boardID: page.boardID,
            lastMessageID: target ?? last?.id,
            firstUnreadMessageID: nil
        )
        return ResolvedTopic(topic: topic, targetMessageID: target)
    }

    func fetchPostForm(topicID: Int? = nil, boardID: Int? = nil, quoteMessageID: Int? = nil) async throws -> PostFormInfo {
        let query: String
        if let topicID {
            if let quoteMessageID {
                query = "action=post;topic=\(topicID).0;quote=\(quoteMessageID)"
            } else {
                query = "action=post;topic=\(topicID).0"
            }
        } else if let boardID {
            query = "action=post;board=\(boardID).0"
        } else {
            throw SMFError.parsing("no board or topic for the post form")
        }

        let (html, _) = try await get(url(query))
        try ensureLoggedIn(html)
        guard let form = SMFParser.parsePostForm(html) else {
            throw SMFError.parsing("the post form could not be found")
        }
        return form
    }

    /// Sends the editor contents. `preview` uses SMF's own preview endpoint, which
    /// renders the BBCode without creating a post.
    func submitPost(form: PostFormInfo, subject: String, message: String, preview: Bool,
                    attachments: [AttachmentUpload] = []) async throws -> PostOutcome {
        var fields = form.fields
        fields["subject"] = subject
        fields["message"] = message
        fields["message_mode"] = "0"
        fields["goback"] = "1"
        if preview {
            fields["preview"] = "Preview"
        } else {
            fields["post"] = "Post"
        }

        var request = URLRequest(url: form.action)
        request.httpMethod = "POST"
        let files = preview ? [] : attachments
        if files.isEmpty {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.formEncode(fields).data(using: .utf8)
        } else {
            let boundary = "ChinaDefense-\(UUID().uuidString)"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.multipartBody(fields: fields, files: files, boundary: boundary)
        }
        let referer = form.topicID.map { url("action=post;topic=\($0).0") }
            ?? url("action=post;board=\(form.boardID ?? 0).0")
        request.setValue(referer.absoluteString, forHTTPHeaderField: "Referer")

        let (data, response) = try await perform(request)
        let html = Self.decode(data, response: response)

        if let error = SMFParser.postError(html) {
            throw SMFError.postFailed(error)
        }

        if preview {
            guard let rendered = SMFParser.parsePreview(html) else {
                throw SMFError.parsing("the preview could not be read")
            }
            let refreshed = SMFParser.parsePostForm(html) ?? form
            return .preview(subject: rendered.subject, content: rendered.content, form: refreshed)
        }

        // A successful post redirects to the topic (which also contains a
        // postmodify quick-reply form, so the presence of that form proves nothing).
        let finalURL = response.url?.absoluteString ?? ""
        guard finalURL.contains("topic=") else {
            throw SMFError.postFailed("The forum did not accept the post. Your draft is still here.")
        }

        let topicID = Self.number(after: "topic=", in: finalURL) ?? form.topicID
        let messageID = Self.number(after: "msg", in: finalURL)
        return .posted(topicID: topicID, messageID: messageID)
    }

    static func multipartBody(fields: [String: String],
                                      files: [AttachmentUpload],
                                      boundary: String) -> Data {
        var body = Data()
        func append(_ string: String) {
            body.append(Data(string.utf8))
        }
        for (name, value) in fields {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
            append("\(value)\r\n")
        }
        for file in files {
            let safeName = file.fileName.replacingOccurrences(of: "\"", with: "_")
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"attachment[]\"; filename=\"\(safeName)\"\r\n")
            append("Content-Type: \(file.mimeType)\r\n\r\n")
            body.append(file.data)
            append("\r\n")
        }
        append("--\(boundary)--\r\n")
        return body
    }

    private static func number(after marker: String, in string: String) -> Int? {
        guard let range = string.range(of: marker) else { return nil }
        var digits = ""
        for character in string[range.upperBound...] {
            if character.isNumber { digits.append(character) } else { break }
        }
        return Int(digits)
    }

    func fetchPostLikers(url: URL) async throws -> [PostLiker] {
        let (html, _) = try await get(url)
        try ensureLoggedIn(html)
        return SMFParser.parsePostLikers(html)
    }

    func fetchAlerts() async throws -> AlertsSnapshot {
        let (popup, _) = try await get(url("action=profile;area=alerts_popup"))
        try ensureLoggedIn(popup)
        let count = SMFParser.parseAlertPopupCount(popup)

        let (list, _) = try await get(url("action=profile;area=showalerts"))
        try ensureLoggedIn(list)
        return AlertsSnapshot(
            unread: count,
            items: SMFParser.parseAlerts(list),
            markAllReadURL: SMFParser.parseAlertMarkAllURL(popup)
        )
    }

    func toggleLike(url: URL) async throws {
        let (html, _) = try await get(url)
        try ensureLoggedIn(html)
    }

    func markAllRead(_ url: URL) async throws {
        let (html, _) = try await get(url)
        try ensureLoggedIn(html)
    }

    func markAlertRead(_ url: URL) async throws {
        let (html, _) = try await get(url)
        try ensureLoggedIn(html)
    }

    func signOut() async {
        let storage = HTTPCookieStorage.shared
        for cookie in (storage.cookies ?? []) where cookie.domain.contains("china-defense.com") {
            storage.deleteCookie(cookie)
        }
        URLCache.shared.removeAllCachedResponses()
    }

    // MARK: - HTTP

    private func url(_ query: String) -> URL {
        query.isEmpty ? baseURL.appendingPathComponent("index.php") : AppConfig.url(query)
    }

    private func get(_ url: URL) async throws -> (String, URL) {
        var request = URLRequest(url: url)
        request.setValue(baseURL.absoluteString, forHTTPHeaderField: "Referer")
        let (data, response) = try await perform(request)
        return (Self.decode(data, response: response), response.url ?? url)
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        while true {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw SMFError.network("no HTTP response")
                }
                guard (200..<400).contains(http.statusCode) else {
                    if http.statusCode == 429 {
                        throw SMFError.http(429)
                    }
                    throw SMFError.http(http.statusCode)
                }
                return (data, http)
            } catch let error as SMFError {
                throw error
            } catch let error as URLError {
                if error.code == .cancelled { throw SMFError.network("cancelled") }
                attempt += 1
                guard attempt < 2 else { throw SMFError.network(error.localizedDescription) }
                try? await Task.sleep(for: .milliseconds(600))
            } catch {
                throw SMFError.network(error.localizedDescription)
            }
        }
    }

    private static func decode(_ data: Data, response: HTTPURLResponse) -> String {
        let contentType = response.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if contentType.contains("iso-8859-1") || contentType.contains("latin1") {
            return String(data: data, encoding: .isoLatin1) ?? ""
        }
        return String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
    }

    private static func formEncode(_ fields: [String: String]) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        return fields
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
            .sorted()
            .joined(separator: "&")
    }

    private func ensureLoggedIn(_ html: String) throws {
        if html.contains("id=\"frmLogin\"") || html.contains("name=\"frmLogin\"") {
            throw SMFError.notLoggedIn
        }
    }

    /// Only real error boxes count. Scanning the whole document is unsafe: SMF puts
    /// "Sorry Guest, you are banned…" in a JavaScript variable on every single page.
    static func loginErrorMessage(in document: HTMLNode) -> String? {
        let boxes = document.all(where: { $0.hasClass("error") || $0.hasClass("errorbox") })
        for box in boxes {
            let text = box.textContent
            if !text.isEmpty { return text }
        }
        return nil
    }
}


/// SMF sometimes redirects an alert's "view" link to an absolute `http://`
/// URL. ATS blocks that before the app can follow it, so upgrade China Defense
/// Forum redirects to HTTPS.
private final class SMFRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard let url = request.url,
              url.scheme == "http",
              url.host?.contains("china-defense.com") == true,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            completionHandler(request)
            return
        }
        components.scheme = "https"
        var upgraded = request
        upgraded.url = components.url
        completionHandler(upgraded)
    }
}
