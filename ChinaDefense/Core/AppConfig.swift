import Foundation

enum AppConfig {
    /// Production forum. Debug builds can point at a test server with the launch
    /// argument `-baseURL http://rpi4b.realm/smf/`.
    static let productionBaseURL = URL(string: "https://www.china-defense.com/smf/")!

    static var baseURL: URL {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "-baseURL"), index + 1 < args.count,
           let url = URL(string: args[index + 1]) {
            return url
        }
        #endif
        return productionBaseURL
    }

    static let forumName = "China Defense Forum"
    static var forumHost: String { baseURL.host ?? "www.china-defense.com" }
    static var forumDisplayURL: URL { baseURL.appendingPathComponent("index.php") }

    static let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1 ChinaDefenseReader/1.0"

    /// Builds an `index.php?…` URL. SMF query strings use `;` as a separator and
    /// `URLComponents` would leave them intact, but plain string building is simpler here.
    static func url(_ query: String) -> URL {
        guard let url = URL(string: baseURL.absoluteString + "index.php?" + query) else {
            return baseURL
        }
        return url
    }

    /// Resolves a link found in a forum page against the forum's base URL.
    static func resolve(_ href: String, relativeTo base: URL = baseURL) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("#") { return nil }
        if trimmed.lowercased().hasPrefix("javascript:") { return nil }
        guard let absolute = URL(string: trimmed, relativeTo: base)?.absoluteURL else { return nil }
        // parts of the forum still emit http:// media; the host supports https.
        if absolute.scheme == "http", (absolute.host ?? "").hasSuffix("china-defense.com"),
           var components = URLComponents(url: absolute, resolvingAgainstBaseURL: false) {
            components.scheme = "https"
            return components.url ?? absolute
        }
        return absolute
    }
}

enum BoardIcon {
    /// Picks a sensible SF Symbol for a board based on its name.
    static func symbol(for name: String) -> String {
        let n = name.lowercased()
        func matches(_ needles: [String]) -> Bool { needles.contains { n.contains($0) } }

        if matches(["unread", "new post"]) { return "dot.radiowaves.left.and.right" }
        if matches(["navy", "naval", "ship", "vessel", "fleet", "submarine"]) { return "sailboat" }
        if matches(["air", "aviation", "flight", "drone", "uav"]) { return "airplane" }
        if matches(["army", "land", "ground", "infantry", "tank", "armor", "artillery"]) { return "shield.lefthalf.filled" }
        if matches(["space", "rocket", "missile", "strategic"]) { return "paperplane" }
        if matches(["nuclear", "energy"]) { return "atom" }
        if matches(["cyber", "tech", "science", "research", "electronic"]) { return "cpu" }
        if matches(["econom", "trade", "industry", "business"]) { return "chart.line.uptrend.xyaxis" }
        if matches(["politic", "government", "law", "policy"]) { return "building.columns" }
        if matches(["history", "archive"]) { return "book.closed" }
        if matches(["news", "announce", "headline"]) { return "newspaper" }
        if matches(["off topic", "general", "lounge", "chat", "member"]) { return "bubble.left.and.bubble.right" }
        if matches(["feedback", "support", "help", "site"]) { return "questionmark.circle" }
        if matches(["war", "conflict", "combat"]) { return "flame" }
        return "bubble.left.and.text.bubble.right"
    }
}
