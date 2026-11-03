import Foundation

// MARK: - Account

struct SMFUser: Codable, Equatable, Sendable {
    let id: Int
    var name: String
}

// MARK: - Boards

struct BoardRef: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    let name: String
}

struct ForumBoard: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    var name: String
    var summary: String
    var categoryID: Int
    var categoryName: String
    var childBoards: [BoardRef]
    var topicCount: Int
    var postCount: Int
    var isRedirect: Bool

    var iconName: String { BoardIcon.symbol(for: name) }

    /// Short label for the tab bar. iOS lays out four long titles poorly on a phone,
    /// so tabs use a compact name while navigation keeps the full board name.
    var tabTitle: String {
        if let known = BoardShortName.map[name] { return known }
        var candidate = name
        for separator in [",", " & ", " and "] {
            if let range = candidate.range(of: separator) {
                candidate = String(candidate[..<range.lowerBound])
            }
        }
        if candidate.count > 14 {
            candidate = String(candidate.prefix(14)).trimmingCharacters(in: .whitespaces)
        }
        return candidate.isEmpty ? name : candidate
    }
}

enum BoardShortName {
    static let map: [String: String] = [
        "Welcome to CDF!": "Welcome",
        "General Military Discussion": "General",
        "Drones, UAV, and AI": "Drones",
        "Ground Forces": "Ground Forces",
        "Naval Forces": "Naval Forces",
        "Air Forces": "Air Forces",
        "Strategic Forces and Space": "Strategic",
        "Politics & Media": "Politics",
        "Economics & Business": "Economics",
        "Science & Technology": "Science & Tech",
        "Culture & Society": "Culture",
        "Everything Else": "Everything",
        "Before 1911": "Before 1911",
        "After 1911": "After 1911",
    ]
}

struct ForumCategory: Identifiable, Hashable, Codable, Sendable {
    let id: Int
    var name: String
    var boards: [ForumBoard]
}

/// A board that can be opened as a topic list. Top-level boards become tabs; child
/// boards are pushed onto the navigation stack from within a tab.
struct BoardTarget: Hashable, Sendable {
    let id: Int
    let name: String
    var summary: String = ""
    var childBoards: [BoardRef] = []

    init(board: ForumBoard) {
        id = board.id
        name = board.name
        summary = board.summary
        childBoards = board.childBoards
    }

    init(ref: BoardRef, summary: String = "", childBoards: [BoardRef] = []) {
        id = ref.id
        name = ref.name
        self.summary = summary
        self.childBoards = childBoards
    }
}

struct BoardIndexResult: Sendable {
    var categories: [ForumCategory]
    var markAllReadURL: URL?
    var unreadCount: Int?

    var boards: [ForumBoard] { categories.flatMap(\.boards) }
}

// MARK: - Topics

struct ForumTopic: Identifiable, Hashable, Sendable {
    let id: Int
    var title: String
    var author: String
    var replies: Int
    var views: Int
    var lastPostText: String
    var isUnread: Bool
    var isSticky: Bool
    var isLocked: Bool
    var pageCount: Int
    /// Present when the topic was discovered through a board listing.
    var boardID: Int?
    /// Newest message in the topic, used when the thread is fully read.
    var lastMessageID: Int? = nil
    /// First unread message, from SMF's "new" marker.
    var firstUnreadMessageID: Int? = nil
}

struct ResolvedTopic: Sendable {
    var topic: ForumTopic
    var targetMessageID: Int?
}

struct TopicListPage: Sendable {
    var topics: [ForumTopic]
    var boardID: Int?
    var boardName: String?
    var boardSummary: String?
    var currentStart: Int
    var perPage: Int
    var maxStart: Int
    var totalTopics: Int?
    var markAllReadURL: URL?

    var nextStart: Int? {
        let next = currentStart + max(perPage, 1)
        return next <= maxStart ? next : nil
    }

    var hasNextPage: Bool { nextStart != nil }
}

// MARK: - Posts

enum PostBlock: Hashable, Sendable {
    case text(AttributedString)
    case quote(AttributedString)
    case code(String)
    case image(URL)
    case video(String)
}

struct YouTubeVideo: Identifiable, Hashable, Sendable {
    let id: String
    let watchURL: URL
}

struct PostContent: Hashable, Sendable {
    /// Flattened text used for search, tests and emptiness checks.
    var text: AttributedString
    /// Ordered content; code blocks are rendered as real cards, not inline text.
    var blocks: [PostBlock]
    /// Attachments, rendered after the post body (as SMF does on the web).
    var images: [URL]

    var isEmpty: Bool { text.characters.isEmpty && blocks.isEmpty && images.isEmpty }
}

struct ForumPost: Identifiable, Sendable {
    let id: Int
    var author: String
    var authorID: Int?
    var avatarURL: URL?
    var subject: String
    var dateText: String
    var date: Date?
    var postNumber: Int?
    var content: PostContent
    var rawHTML: String
    var likeCount: Int = 0
    var canLike: Bool = false
    var youLike: Bool = false
    var likeURL: URL? = nil
    var likesViewURL: URL? = nil
    var editURL: URL? = nil

    var profileURL: URL? {
        guard let authorID, authorID > 0 else { return nil }
        return AppConfig.url("action=profile;u=\(authorID)")
    }
}

struct TopicPage: Sendable {
    var topicID: Int
    var title: String
    var boardName: String?
    var boardID: Int?
    var posts: [ForumPost]
    var currentStart: Int
    var perPage: Int
    var maxStart: Int
    var isLocked: Bool
    var isSticky: Bool
    /// Set when SMF's `.new` redirect points at a specific first-unread message.
    var targetMessageID: Int? = nil

    var nextStart: Int? {
        let next = currentStart + max(perPage, 1)
        return next <= maxStart ? next : nil
    }

    var hasNextPage: Bool { nextStart != nil }
}


struct PostLiker: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let group: String
    let time: String
    let avatarURL: URL?
    let profileURL: URL?
}

struct ForumAlert: Identifiable, Hashable, Sendable {
    let id: String
    var text: String
    var time: String
    var url: URL?
    var isUnread: Bool
    var markReadURL: URL?
}

struct AlertsSnapshot: Sendable {
    let unread: Int
    let items: [ForumAlert]
    let markAllReadURL: URL?
}
