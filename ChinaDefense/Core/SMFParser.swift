import Foundation

/// Parses the server-rendered pages of SMF 2.1.x into app models.
///
/// Selectors follow the stock `Themes/default` templates (BoardIndex, MessageIndex,
/// Recent, Display) which this forum runs, but every lookup is defensive: if a marker
/// is missing the parser falls back to a looser structural query instead of failing.
enum SMFParser {

    // MARK: - Account

    static func parseMember(in html: String) -> (id: Int, name: String?) {
        let document = HTMLParser.parse(html)
        var memberID = 0
        if let match = capture("var smf_member_id = (\\d+)", in: html), let value = Int(match[1]) {
            memberID = value
        }

        var name: String?
        let header = document.element(id: "top_info") ?? document.element(id: "top_section")
        if let header {
            let anchors = header.all(where: { $0.tag == "a" && ($0.href?.contains("action=profile") ?? false) })
            if let anchor = anchors.first(where: { !$0.textContent.isEmpty }) {
                // The anchor wraps the username plus an "amt" badge (unread PMs).
                name = anchor.children.first(where: { $0.isText })?.text ?? anchor.textContent
            }
        }
        if name == nil || name?.isEmpty == true {
            name = document.all(where: { $0.tag == "a" && ($0.href?.contains("action=profile;u=") ?? false) })
                .first(where: { !$0.textContent.isEmpty })?.textContent
        }
        return (memberID, name?.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    // MARK: - Board index

    static func parseBoardIndex(_ html: String) -> BoardIndexResult {
        let document = HTMLParser.parse(html)
        let markURL = document.all(where: { $0.tag == "a" && ($0.href?.contains("action=markasread") ?? false) })
            .first.flatMap { $0.href.flatMap { AppConfig.resolve($0) } }

        var categories: [ForumCategory] = []
        var seen = Set<Int>()

        // Stock 2.1 markup: div.cat_bar#category_N followed by #category_N_boards.
        let categoryBars = document.all(where: { $0.tag == "div" && $0.hasClass("cat_bar") })
        for bar in categoryBars {
            guard let idValue = bar.id, idValue.hasPrefix("category_"),
                  let categoryID = Int(idValue.dropFirst("category_".count)) else { continue }
            let categoryName = bar.firstTag("h3")?.textContent ?? bar.textContent
            guard !categoryName.isEmpty else { continue }

            guard let container = document.element(id: "category_\(categoryID)_boards") else { continue }
            var boards: [ForumBoard] = []
            for child in container.children {
                guard child.tag == "div", child.id?.hasPrefix("board_") == true else { continue }
                guard let board = parseBoardNode(child, categoryID: categoryID, categoryName: categoryName) else { continue }
                if seen.insert(board.id).inserted { boards.append(board) }
            }
            if !boards.isEmpty {
                categories.append(ForumCategory(id: categoryID, name: categoryName, boards: boards))
            }
        }

        // Fallback for themes that don't use category wrappers.
        if categories.isEmpty {
            var boards: [ForumBoard] = []
            for node in document.all(where: { isBoardElement($0) }) {
                guard node.ancestor(where: { isBoardElement($0) }) == nil else { continue }
                guard let board = parseBoardNode(node, categoryID: 0, categoryName: "Forums") else { continue }
                if seen.insert(board.id).inserted { boards.append(board) }
            }
            if !boards.isEmpty {
                categories = [ForumCategory(id: 0, name: "Forums", boards: boards)]
            }
        }

        return BoardIndexResult(
            categories: categories,
            markAllReadURL: markURL,
            unreadCount: parseUnreadCount(in: document)
        )
    }

    private static func parseBoardNode(_ node: HTMLNode, categoryID: Int, categoryName: String) -> ForumBoard? {
        guard let idValue = node.id,
              let boardElementID = Int(idValue.dropFirst("board_".count)) else { return nil }

        let subjectAnchor = node.all(where: { $0.tag == "a" })
            .first { $0.id == "b\(boardElementID)" || $0.hasClass("subject") }
        guard let subjectAnchor else { return nil }
        let name = subjectAnchor.textContent
        guard !name.isEmpty else { return nil }

        let summary = node.firstClass("board_description")?.textContent ?? ""
        let statsNode = node.firstClass("board_stats")
        let statsText = statsNode?.textContent ?? ""
        let isRedirect = node.all(where: { $0.hasClass("board_redirect") }).isEmpty == false
            || (subjectAnchor.href?.contains("action=redirect") ?? false)

        var children: [BoardRef] = []
        if let childContainer = node.element(id: "board_\(boardElementID)_children") {
            for anchor in childContainer.allTags("a") {
                guard let href = anchor.href, let childID = boardID(fromHref: href) else { continue }
                let childName = anchor.textContent
                guard !childName.isEmpty, childID != boardElementID,
                      !children.contains(where: { $0.id == childID }) else { continue }
                children.append(BoardRef(id: childID, name: childName))
            }
        }

        // Stock SMF writes "Topics: 12 / Posts: 345", but this theme uses
        // <span class="board_stats_post_txt">Posts</span><br><span class="board_stats_post_numbers"> 628</span>
        // and puts Posts before Topics. Read the spans when present.
        var topicCount = 0
        var postCount = 0
        if let statsNode {
            let labels = statsNode.allClasses("board_stats_post_txt").map { $0.textContent.lowercased() }
            let values = statsNode.allClasses("board_stats_post_numbers").map { $0.textContent }
            for (label, value) in zip(labels, values) {
                let count = Int(value.filter(\.isNumber)) ?? 0
                if label.contains("topic") {
                    topicCount = count
                } else if label.contains("post") || label.contains("message") {
                    postCount = count
                }
            }
        }
        if topicCount == 0 && postCount == 0 {
            topicCount = number(in: statsText, labels: ["topics", "topic"]) ?? 0
            postCount = number(in: statsText, labels: ["posts", "post", "messages", "message"]) ?? 0
        }

        return ForumBoard(
            id: boardElementID,
            name: name,
            summary: summary,
            categoryID: categoryID,
            categoryName: categoryName,
            childBoards: children,
            topicCount: topicCount,
            postCount: postCount,
            isRedirect: isRedirect
        )
    }

    // MARK: - Topic lists (board index / unread)

    static func parseTopicList(_ html: String, start: Int) -> TopicListPage {
        let document = HTMLParser.parse(html)
        let container = document.element(id: "topic_container")
            ?? document.element(id: "unread")
            ?? document

        var rows = container.children.filter(isTopicRow)
        if rows.isEmpty {
            rows = container.descendants.filter(isTopicRow)
        }

        var topics: [ForumTopic] = []
        var seen = Set<Int>()
        for row in rows {
            guard let topic = parseTopicRow(row), seen.insert(topic.id).inserted else { continue }
            topics.append(topic)
        }

        let displayHead = document.element(id: "display_head")
        let boardName = displayHead?.firstClass("display_title")?.textContent
        let summary: String? = {
            guard let head = displayHead else { return nil }
            return head.allTags("p")
                .map(\.textContent)
                .first { !$0.isEmpty && !$0.hasPrefix("Started by") }
        }()

        let pagination = paginate(document, currentStart: start, defaultPerPage: 20)
        let totalTopics = number(
            in: document.allClasses("pagesection").map(\.textContent).joined(separator: " "),
            labels: ["topics", "topic"]
        )

        return TopicListPage(
            topics: topics,
            boardID: nil,
            boardName: boardName,
            boardSummary: summary,
            currentStart: pagination.current,
            perPage: pagination.perPage,
            maxStart: pagination.maxStart,
            totalTopics: totalTopics,
            markAllReadURL: document.all(where: { $0.tag == "a" && ($0.href?.contains("action=markasread") ?? false) })
                .first.flatMap { $0.href.flatMap { AppConfig.resolve($0) } }
        )
    }

    private static func isTopicRow(_ node: HTMLNode) -> Bool {
        guard node.tag == "div", !node.isText else { return false }
        guard node.firstClass("board_icon") != nil || node.firstClass("info") != nil else { return false }
        return topicAnchor(in: node) != nil
    }

    private static func topicAnchor(in node: HTMLNode) -> HTMLNode? {
        let anchors = node.all(where: { $0.tag == "a" && ($0.href?.contains("topic=") ?? false) })
            .filter { anchor in
                guard let href = anchor.href else { return false }
                if anchor.hasClass("new_posts") || anchor.hasClass("navPages") { return false }
                if anchor.ancestor(where: { $0.hasClass("topic_pages") || $0.hasClass("pagelinks") }) != nil { return false }
                if href.contains(";start=") || href.contains(".msg") { return false }
                return !anchor.textContent.isEmpty
            }
        return anchors.first(where: { $0.hasClass("subject") }) ?? anchors.first
    }

    private static func parseTopicRow(_ row: HTMLNode) -> ForumTopic? {
        guard let anchor = topicAnchor(in: row),
              let href = anchor.href,
              let match = capture("topic=(\\d+)", in: href),
              let topicID = Int(match[1]) else { return nil }

        let statsText = row.firstClass("board_stats")?.textContent ?? ""
        let lastPost = row.firstClass("lastpost")?.textContent ?? ""
        let pagesText = row.firstClass("topic_pages")?.textContent ?? ""
        let pageCount = pagesText
            .split(whereSeparator: { !$0.isNumber })
            .compactMap { Int($0) }
            .max() ?? 1

        let firstUnreadMessageID = row
            .all(where: { $0.hasClass("new_posts") })
            .compactMap { anchor -> Int? in
                guard let href = anchor.href,
                      let match = capture("msg(\\d+)", in: href) else { return nil }
                return Int(match[1])
            }
            .first

        let lastMessageID = row.firstClass("lastpost")?
            .allTags("a")
            .compactMap { anchor -> Int? in
                guard let href = anchor.href,
                      href.contains("topic="),
                      let match = capture("msg(\\d+)", in: href) else { return nil }
                return Int(match[1])
            }
            .first

        return ForumTopic(
            id: topicID,
            title: anchor.textContent,
            author: startedBy(in: row),
            replies: number(in: statsText, labels: ["replies", "reply", "repl"]) ?? 0,
            views: number(in: statsText, labels: ["views", "view"]) ?? 0,
            lastPostText: cleanLastPost(lastPost),
            isUnread: row.all(where: { $0.hasClass("new_posts") }).isEmpty == false || href.contains(".new"),
            isSticky: row.all(where: { $0.hasClass("sticky") }).isEmpty == false,
            isLocked: row.all(where: { $0.hasClass("lock") }).isEmpty == false,
            pageCount: pageCount,
            boardID: row.all(where: { $0.tag == "a" && ($0.href?.contains("board=") ?? false) })
                .first.flatMap { $0.href.flatMap { boardID(fromHref: $0) } },
            lastMessageID: lastMessageID,
            firstUnreadMessageID: firstUnreadMessageID
        )
    }

    /// Trims SMF's last-post strings down to the date, which is what the row needs.
    /// Examples: "Last post by tester on Today at 09:15:00 AM" -> "Today at 09:15 AM",
    /// "Today at 07:00:00 AM by reporter" -> "Today at 07:00 AM".
    private static func cleanLastPost(_ text: String) -> String {
        var value = clean(text)
        if let range = value.range(of: " on ") {
            value = String(value[range.upperBound...])
        } else if let range = value.range(of: " by ") {
            value = String(value[..<range.lowerBound])
        }
        value = value.replacingOccurrences(of: "Last post by", with: "", options: .caseInsensitive)
        return cleanDate(value)
    }

    /// Drops seconds so list rows and post headers stay compact ("09:15 AM").
    private static func cleanDate(_ text: String) -> String {
        clean(text).replacingOccurrences(
            of: #"(\d{1,2}:\d{2}):\d{2}"#,
            with: "$1",
            options: .regularExpression
        )
    }

    private static func startedBy(in row: HTMLNode) -> String {
        let info = row.firstClass("info") ?? row
        let paragraphNode = info.allTags("p").first {
            $0.textContent.localizedCaseInsensitiveContains("started by")
        }

        // "Started by <strong>sandyj</strong> in <em><a>Board</a></em>" (all-board lists).
        if let name = paragraphNode?.firstTag("strong")?.textContent, !name.isEmpty {
            return name
        }
        if let anchor = info.all(where: { $0.tag == "a" && ($0.href?.contains("action=profile") ?? false) })
            .first(where: { !$0.textContent.isEmpty }) {
            return anchor.textContent
        }
        if let paragraph = paragraphNode?.textContent {
            var stripped = paragraph.replacingOccurrences(of: "Started by", with: "", options: .caseInsensitive)
            // Drop the trailing "in Board" context from the unread listing.
            if let range = stripped.range(of: " in ", options: .backwards) {
                stripped = String(stripped[..<range.lowerBound])
            }
            return stripped.trimmingCharacters(in: .whitespaces)
        }
        return ""
    }

    // MARK: - Topic

    static func parseTopic(_ html: String, topicID: Int, start: Int) -> TopicPage {
        let document = HTMLParser.parse(html)

        let title = document.element(id: "top_subject")?.textContent
            ?? document.firstClass("display_title")?.textContent
            ?? document.firstTag("title")?.textContent
            ?? ""

        let boardAnchor = document.all(where: { $0.tag == "a" && ($0.href?.contains("board=") ?? false) })
            .first { !$0.textContent.isEmpty }

        var wrappers = document.allClasses("post_wrapper")
        if wrappers.isEmpty {
            wrappers = document.all(where: { $0.tag == "div" && $0.hasClass("post") && $0.firstClass("inner") != nil })
        }

        var posts: [ForumPost] = []
        var seen = Set<Int>()
        for wrapper in wrappers {
            guard let post = parsePost(wrapper), seen.insert(post.id).inserted else { continue }
            posts.append(post)
        }

        let pagination = paginate(document, currentStart: start, defaultPerPage: 15)
        let displayHead = document.element(id: "display_head")

        return TopicPage(
            topicID: topicID,
            title: title,
            boardName: boardAnchor?.textContent,
            boardID: boardAnchor?.href.flatMap { boardID(fromHref: $0) },
            posts: posts,
            currentStart: pagination.current,
            perPage: pagination.perPage,
            maxStart: pagination.maxStart,
            isLocked: displayHead.map { !$0.all(where: { $0.hasClass("lock") }).isEmpty } ?? false,
            isSticky: displayHead.map { !$0.all(where: { $0.hasClass("sticky") }).isEmpty } ?? false
        )
    }

    private static func parsePost(_ wrapper: HTMLNode) -> ForumPost? {
        let inner = wrapper.allClasses("inner").first { $0.attributes["data-msgid"] != nil }
            ?? wrapper.firstClass("inner")

        guard let inner else { return nil }
        let idValue = inner.attributes["data-msgid"]
            ?? inner.id?.replacingOccurrences(of: "msg_", with: "")
        guard let idValue, let postID = Int(idValue) else { return nil }

        let poster = wrapper.firstClass("poster")
        let authorAnchor = poster?.all(where: { $0.tag == "a" && ($0.href?.contains("action=profile") ?? false) })
            .first { !$0.textContent.isEmpty }
        let author = authorAnchor?.textContent
            ?? poster?.firstTag("h4")?.textContent
            ?? "Guest"
        let authorID = authorAnchor?.href.flatMap { href -> Int? in
            guard let match = capture("u=(\\d+)", in: href) else { return nil }
            return Int(match[1])
        }

        let avatar = poster?.allTags("img").first { $0.hasClass("avatar") }
            ?? poster?.allTags("img").first { ($0.src ?? "").lowercased().contains("avatar") }
        let avatarURL = avatar?.src.flatMap { AppConfig.resolve($0) }

        let subject = wrapper.firstClass("subject_title")?.textContent
            ?? wrapper.all(where: { $0.id?.hasPrefix("subject_") ?? false }).first?.textContent
            ?? ""

        let dateText = wrapper.firstClass("postinfo")?.allTags("a").first?.textContent
            ?? wrapper.firstClass("keyinfo")?.all(where: { $0.hasClass("smalltext") }).first?.textContent
            ?? ""
        let date = SMFDate.parse(dateText)

        let postNumber = Int(
            (wrapper.firstClass("page_number")?.textContent ?? "").filter { $0.isNumber }
        )

        // SMF renders attachments in a sibling .attachments block, outside .inner.
        // Keep the wrapper element so the renderer can skip the filename/size chrome.
        let attachmentsHTML = wrapper
            .all(where: { $0.hasClass("attachments") })
            .filter { node in node.ancestor(where: { $0 === inner }) == nil }
            .map { $0.serialized() }
            .joined()
        let rawHTML = inner.innerHTML + attachmentsHTML

        let likeAnchor = wrapper.all(where: { $0.tag == "a" && $0.hasClass("msg_like") }).first
        let canLike = likeAnchor != nil
        let youLike = likeAnchor?.textContent.lowercased().contains("unlike") ?? false
        let likeURL = likeAnchor?.href.flatMap { AppConfig.resolve($0) }
        let likeCountNode = wrapper.all(where: { $0.hasClass("like_count") }).first
        let likeCountText = likeCountNode?.textContent ?? ""
        var likeCount = 0
        if let match = capture("(\\d[\\d,]*)", in: likeCountText) {
            likeCount = Int(match[1].replacingOccurrences(of: ",", with: "")) ?? 0
        }
        if likeCount == 0 && youLike { likeCount = 1 }
        let likesViewURL = likeCountNode?.firstTag("a")?.href.flatMap { AppConfig.resolve($0) }

        return ForumPost(
            id: postID,
            author: author,
            authorID: authorID,
            avatarURL: avatarURL,
            subject: subject,
            dateText: cleanDate(dateText),
            date: date,
            postNumber: postNumber,
            content: PostRenderer.render(html: rawHTML),
            rawHTML: rawHTML,
            likeCount: likeCount,
            canLike: canLike,
            youLike: youLike,
            likeURL: likeURL,
            likesViewURL: likesViewURL
        )
    }

    // MARK: - Likers

    static func parsePostLikers(_ html: String) -> [PostLiker] {
        let document = HTMLParser.parse(html)
        let items = document.all(where: { $0.hasClass("like_profile") }).isEmpty
            ? document.all(where: { $0.id == "likes" || $0.firstClass("like_profile") != nil })
            : document.all(where: { $0.hasClass("like_profile") })

        var likers: [PostLiker] = []
        for node in items {
            let profile = node.hasClass("like_profile") ? node : node.firstClass("like_profile") ?? node
            let link = profile.firstTag("a")
            let name = link?.textContent ?? ""
            guard !name.isEmpty else { continue }
            let id = link?.href.flatMap { href -> String? in
                guard let match = capture("u=(\\d+)", in: href) else { return nil }
                return match[1]
            } ?? name
            let row = profile.parent ?? node.parent ?? node
            let avatar = row.allTags("img").first { $0.hasClass("avatar") }?.src
            likers.append(PostLiker(
                id: id,
                name: name,
                group: profile.firstClass("description")?.textContent ?? "",
                time: row.firstClass("like_time")?.textContent
                    ?? row.all(where: { $0.hasClass("like_time") }).first?.textContent ?? "",
                avatarURL: avatar.flatMap { AppConfig.resolve($0) },
                profileURL: link?.href.flatMap { AppConfig.resolve($0) }
            ))
        }
        return likers
    }

    // MARK: - Alerts

    static func parseAlertPopupCount(_ html: String) -> Int {
        let document = HTMLParser.parse(html)
        if document.firstClass("no_unread") != nil { return 0 }
        return document.all(where: { $0.hasClass("unread_notify") }).count
    }

    static func parseAlerts(_ html: String) -> [ForumAlert] {
        let document = HTMLParser.parse(html)
        let table = document.all(where: { $0.tag == "table" && $0.id == "alerts" }).first
        let rows = (table ?? document).all(where: { $0.hasClass("windowbg") })
        return rows.enumerated().compactMap { index, row in
            guard let textNode = row.firstClass("alert_text") else { return nil }
            let text = textNode.firstTag("div")?.textContent ?? textNode.textContent
            guard !text.isEmpty else { return nil }
            let time = row.firstClass("alert_time")?.textContent
                ?? row.firstClass("alert_inline_time")?.textContent
                ?? ""

            let markLink = row.allTags("a").first(where: {
                let href = $0.href ?? ""
                return href.contains("area=showalerts")
                    && (href.contains("do=read") || href.contains("do=unread"))
            })
            let markHref = markLink?.href ?? ""
            let isUnread = markHref.contains("do=read")
            let alertID = capture("[;&]aid=(\\d+)", in: markHref)?.dropFirst().first
                ?? "\(index)"
            let viewLink = row.allTags("a").first(where: {
                let href = $0.href ?? ""
                return href.contains("area=showalerts") && href.contains("alert=")
            })
            let topicLink = row.allTags("a").first(where: {
                let href = $0.href ?? ""
                return href.contains("topic=") || href.contains("msg=")
            })
            let url = (viewLink ?? topicLink)?.href.flatMap { AppConfig.resolve($0) }

            return ForumAlert(
                id: alertID,
                text: text,
                time: time,
                url: url,
                isUnread: isUnread,
                markReadURL: markLink?.href.flatMap { AppConfig.resolve($0) }
            )
        }
    }

    static func messageID(fromHTML html: String) -> Int? {
        capture("msg=(\\d+)", in: html).flatMap { Int($0[1]) }
    }

    static func parseAlertMarkAllURL(_ html: String) -> URL? {
        let document = HTMLParser.parse(html)
        return document.all(where: {
            $0.tag == "a" && ($0.href?.contains("area=notification") ?? false)
                && ($0.href?.contains("sa=markread") ?? false)
        }).first?.href.flatMap { AppConfig.resolve($0) }
    }

    // MARK: - Pagination

    private struct Pagination {
        var current: Int
        var perPage: Int
        var maxStart: Int
    }

    private static func paginate(_ document: HTMLNode, currentStart: Int, defaultPerPage: Int) -> Pagination {
        var starts = Set<Int>()
        var numberedLinks: [(start: Int, page: Int)] = []

        let containers = document.allClasses("pagelinks") + document.allClasses("pagesection")
        for container in containers {
            for anchor in container.allTags("a") {
                guard let href = anchor.href else { continue }
                let start: Int?
                if let match = capture("[;?&]start=(\\d+)", in: href) {
                    start = Int(match[1])
                } else if let match = capture("(?:board|topic)=\\d+\\.(\\d+)", in: href) {
                    start = Int(match[1])
                } else {
                    start = nil
                }
                guard let start else { continue }
                starts.insert(start)

                // A link reading "3" pointing at start=40 proves the page size is 20.
                if let page = Int(anchor.textContent), page > 1 {
                    numberedLinks.append((start, page))
                }
            }
        }

        var perPage = defaultPerPage
        let derived = numberedLinks.compactMap { link -> Int? in
            guard link.start > 0, link.page > 1 else { return nil }
            let denominator = link.page - 1
            guard link.start % denominator == 0 else { return nil }
            let size = link.start / denominator
            return size >= 5 ? size : nil
        }
        if let mostCommon = derived.mostCommon() {
            perPage = mostCommon
        } else {
            // Sparse pagination (only "next" arrows): use the smallest gap.
            let sorted = starts.sorted()
            let gaps = zip(sorted, sorted.dropFirst()).map { $1 - $0 }.filter { $0 >= 5 }
            if let smallest = gaps.min() {
                perPage = smallest
            }
        }

        var current = currentStart
        if let active = document.first(where: { $0.hasClass("current_page") }),
           let page = Int(active.textContent), page > 0 {
            current = (page - 1) * perPage
        }

        let maxStart = max(starts.max() ?? current, current)
        return Pagination(current: current, perPage: perPage, maxStart: maxStart)
    }

    // MARK: - Small helpers

    private static func boardID(fromHref href: String) -> Int? {
        capture("board=(\\d+)", in: href).flatMap { Int($0[1]) }
    }

    private static func isBoardElement(_ node: HTMLNode) -> Bool {
        guard node.tag == "div", let id = node.id, id.hasPrefix("board_") else { return false }
        return Int(id.dropFirst("board_".count)) != nil
    }

    /// Reads a labelled count from strings such as "Replies: 3 / Views: 45",
    /// "3 Replies", "Topics: 12" or "12 topics".
    private static func number(in text: String, labels: [String]) -> Int? {
        guard !text.isEmpty else { return nil }
        for label in labels {
            if let match = capture("\(label)\\s*:\\s*(\\d[\\d,]*)", in: text), let value = intValue(match[1]) {
                return value
            }
            if let match = capture("(\\d[\\d,]*)\\s*\(label)", in: text), let value = intValue(match[1]) {
                return value
            }
        }
        return nil
    }

    private static func intValue(_ string: String) -> Int? {
        Int(string.replacingOccurrences(of: ",", with: ""))
    }

    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: "«", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func capture(_ pattern: String, in string: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(string.startIndex..., in: string)
        guard let match = regex.firstMatch(in: string, range: range) else { return nil }
        return (0..<match.numberOfRanges).map { index in
            guard let range = Range(match.range(at: index), in: string) else { return "" }
            return String(string[range])
        }
    }

    private static func parseUnreadCount(in document: HTMLNode) -> Int? {
        let candidates = document.all(where: { node in
            guard node.tag == "a", let href = node.href else { return false }
            return href.contains("action=unread")
        })
        for candidate in candidates {
            let text = candidate.textContent
            if let match = capture("\\((\\d+)\\)", in: text), let value = Int(match[1]) {
                return value
            }
            if let amount = candidate.allClasses("amt").first.flatMap({ Int($0.textContent) }) {
                return amount
            }
        }
        return nil
    }
}

// MARK: - Date parsing

enum SMFDate {
    private static let months: [String: Int] = [
        "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
        "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
    ]

    /// Parses SMF's relative ("Today at 01:23:45 PM") and absolute
    /// ("October 30, 2026, 09:12:04 PM") timestamp formats.
    static func parse(_ text: String) -> Date? {
        let cleaned = text
            .replacingOccurrences(of: "«", with: "")
            .replacingOccurrences(of: "»", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let calendar = Calendar.current
        let lower = cleaned.lowercased()

        if lower.hasPrefix("today") || lower.hasPrefix("yesterday") {
            let dayOffset = lower.hasPrefix("yesterday") ? -1 : 0
            guard let time = timeComponents(from: lower) else { return nil }
            let base = calendar.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date()
            return calendar.date(
                bySettingHour: time.hour, minute: time.minute, second: time.second, of: base
            )
        }

        // "October 30, 2026, 09:12:04 PM"
        let parts = cleaned
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        guard parts.count >= 3 else { return nil }
        guard let month = months[parts[0].lowercased()],
              let day = Int(parts[1]),
              let year = Int(parts[2]) else { return nil }
        guard let time = timeComponents(from: lower) else { return nil }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = time.hour
        components.minute = time.minute
        components.second = time.second
        return calendar.date(from: components)
    }

    private static func timeComponents(from text: String) -> (hour: Int, minute: Int, second: Int)? {
        if let range = text.range(of: "at ") {
            return matchTime(in: String(text[range.upperBound...]))
        }
        if let range = text.range(of: ",") {
            return matchTime(in: String(text[range.upperBound...]))
        }
        return matchTime(in: text)
    }

    private static func matchTime(in text: String) -> (hour: Int, minute: Int, second: Int)? {
        guard let regex = try? NSRegularExpression(pattern: "(\\d{1,2}):(\\d{2})(?::(\\d{2}))?\\s*([ap]m)?", options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              let hourRange = Range(match.range(at: 1), in: text),
              let minuteRange = Range(match.range(at: 2), in: text),
              let hour = Int(text[hourRange]),
              let minute = Int(text[minuteRange]) else { return nil }

        var second = 0
        if match.range(at: 3).location != NSNotFound, let range = Range(match.range(at: 3), in: text) {
            second = Int(text[range]) ?? 0
        }

        var hour24 = hour
        if match.range(at: 4).location != NSNotFound, let range = Range(match.range(at: 4), in: text) {
            let meridiem = text[range].lowercased()
            if meridiem == "pm", hour < 12 { hour24 += 12 }
            if meridiem == "am", hour == 12 { hour24 = 0 }
        }
        return (hour24, minute, second)
    }
}


private extension Array where Element == Int {
    /// Returns the most frequent value, preferring the smallest on a tie.
    func mostCommon() -> Int? {
        guard !isEmpty else { return nil }
        var counts: [Int: Int] = [:]
        for value in self { counts[value, default: 0] += 1 }
        return counts.max { lhs, rhs in
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        }?.key
    }
}

// MARK: - Posting form

struct PostFormInfo: Sendable {
    var action: URL
    var fields: [String: String]
    var subject: String
    var message: String
    var boardID: Int?
    var topicID: Int?
}

extension SMFParser {
    /// Reads SMF's post/new-topic form: its action, every hidden field (session
    /// tokens and seqnum included), the default subject and any quoted text.
    static func parsePostForm(_ html: String, base: URL = AppConfig.baseURL) -> PostFormInfo? {
        let document = HTMLParser.parse(html)
        guard let form = document.all(where: { $0.tag == "form" }).first(where: {
            $0.attr("id") == "postmodify" || $0.attr("name") == "postmodify"
        }) else { return nil }

        guard let action = form.attr("action"), let actionURL = AppConfig.resolve(action, relativeTo: base) else {
            return nil
        }

        var fields: [String: String] = [:]
        for input in form.allTags("input") {
            guard let name = input.attr("name") else { continue }
            let type = (input.attr("type") ?? "text").lowercased()
            if type == "submit" || type == "button" || type == "file" || type == "image" { continue }
            if type == "checkbox" && input.attr("checked") == nil { continue }
            fields[name] = input.attr("value") ?? ""
        }

        // SMF's editor can be in WYSIWYG mode; force the BBCode textarea.
        fields["message_mode"] = "0"

        let subject = form.element(id: "subject")?.attr("value") ?? ""
        let message = form.element(id: "message")?.rawText ?? ""

        let query = actionURL.query ?? ""
        let boardID = captureGroup("board=(\\d+)", in: query).flatMap(Int.init)
        let topicID = fields["topic"].flatMap(Int.init).flatMap { $0 > 0 ? $0 : nil }

        return PostFormInfo(
            action: actionURL,
            fields: fields,
            subject: subject,
            message: message,
            boardID: boardID,
            topicID: topicID
        )
    }

    /// The rendered preview body SMF returns for `preview=Preview`.
    static func parsePreview(_ html: String) -> (subject: String, content: PostContent)? {
        let document = HTMLParser.parse(html)
        guard let body = document.element(id: "preview_body") else { return nil }
        let subject = document.element(id: "preview_subject")?.textContent ?? ""
        return (subject, PostRenderer.render(html: body.innerHTML))
    }

    /// Server-side error shown after a failed post attempt.
    static func postError(_ html: String) -> String? {
        let document = HTMLParser.parse(html)
        if let node = document.element(id: "post_error") {
            let text = node.textContent
            if !text.isEmpty { return text }
        }
        // Only real error boxes: class "error" also appears in the theme's JS
        // templates, which would produce false failures on a successful post.
        for box in document.all(where: { $0.hasClass("errorbox") }) {
            let text = box.textContent
            if !text.isEmpty { return text }
        }
        return nil
    }

    private static func captureGroup(_ pattern: String, in string: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: string) else { return nil }
        return String(string[range])
    }
}
