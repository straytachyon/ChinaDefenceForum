import Foundation
import Observation

/// Loads and paginates a topic list (either all unread topics or one board).
@MainActor
@Observable
final class TopicListModel {
    enum Mode: Hashable {
        case unread
        case board(BoardTarget)

        var board: BoardTarget? {
            if case .board(let board) = self { return board }
            return nil
        }

        var title: String {
            switch self {
            case .unread: return "Unread"
            case .board(let board): return board.name
            }
        }
    }

    private(set) var topics: [ForumTopic] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMore = false
    private(set) var boardSummary: String?
    private(set) var totalTopics: Int?
    private(set) var markAllReadURL: URL?
    var errorMessage: String?

    private let client = SMFClient.shared
    private var mode: Mode?
    private var nextStart: Int?
    private var didLoad = false

    func loadIfNeeded(mode: Mode, session: Session) async {
        if didLoad, self.mode == mode { return }
        self.mode = mode
        await fetch(mode: mode, start: 0, session: session, appending: false)
    }

    func refresh(session: Session) async {
        guard let mode else { return }
        await fetch(mode: mode, start: 0, session: session, appending: false)
    }

    func loadMore(session: Session) async {
        guard let mode, let start = nextStart, !isLoading, !isLoadingMore else { return }
        await fetch(mode: mode, start: start, session: session, appending: true)
    }

    /// Drops a topic that the user just read, without waiting for the server list.
    func removeTopic(id: Int) {
        topics.removeAll { $0.id == id }
    }

    private func fetch(mode: Mode, start: Int, session: Session, appending: Bool) async {
        if appending { isLoadingMore = true } else { isLoading = true }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        #if DEBUG
        if DemoMode.isEnabled {
            apply(DemoMode.topicList(mode: mode, start: start), mode: mode, appending: appending, session: session)
            return
        }
        #endif

        do {
            let page: TopicListPage
            switch mode {
            case .unread:
                page = try await client.fetchUnread(start: start)
            case .board(let board):
                page = try await client.fetchBoard(id: board.id, start: start)
            }
            apply(page, mode: mode, appending: appending, session: session)
        } catch SMFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ page: TopicListPage, mode: Mode, appending: Bool, session: Session) {
        if appending {
            let existing = Set(topics.map(\.id))
            topics += page.topics.filter { !existing.contains($0.id) }
        } else {
            topics = page.topics
            boardSummary = page.boardSummary
            totalTopics = page.totalTopics
            markAllReadURL = page.markAllReadURL
        }

        nextStart = page.nextStart
        hasMore = page.hasNextPage
        errorMessage = nil
        didLoad = true

        if case .unread = mode, !appending {
            session.reportUnreadCount(topics.count)
        }
    }
}

/// Loads a topic and its posts. When a topic is unread it opens at the newest
/// message (SMF's `.msgNNN` jump) and can page backwards as well as forwards.
@MainActor
@Observable
final class TopicModel {
    let topicID: Int
    /// Message the view should scroll to after the first page lands.
    private(set) var targetMessageID: Int?

    private(set) var title: String
    private(set) var posts: [ForumPost] = []
    private(set) var boardName: String?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMore = false
    private(set) var hasPrevious = false
    private(set) var isLocked = false
    private(set) var currentPage = 1
    private(set) var pageCount = 1
    /// Bumped when the user jumps to another page, so the view can scroll to the top.
    private(set) var paginationToken = 0
    private(set) var jumpTarget: Int?
    private(set) var jumpToken = 0
    var errorMessage: String?

    private enum FetchMode {
        case initial
        case page
        case append
        case prepend
    }

    private let client = SMFClient.shared
    private let jumpToNew: Bool
    private let queryMessageID: Int?
    private var nextStart: Int?
    private var previousStart: Int?
    private var earliestStart = 0
    private var latestStart = 0
    private var pageSize = 20
    private var didLoad = false

    init(topic: ForumTopic) {
        topicID = topic.id
        title = topic.title

        if topic.isUnread, let firstUnread = topic.firstUnreadMessageID {
            // The unread row names the exact first unread post; requesting it
            // directly makes SMF return the page holding that message.
            targetMessageID = firstUnread
            queryMessageID = firstUnread
            jumpToNew = false
        } else if topic.isUnread {
            targetMessageID = topic.lastMessageID
            queryMessageID = nil
            jumpToNew = true
        } else {
            // Fully read: open at the newest post instead of page one.
            targetMessageID = topic.lastMessageID
            queryMessageID = topic.lastMessageID
            jumpToNew = false
        }
    }

    func loadIfNeeded(session: Session) async {
        guard !didLoad else { return }
        await fetch(session: session, start: nil, mode: .initial)
    }

    func refresh(session: Session) async {
        await fetch(session: session, start: 0, mode: .initial)
    }

    func loadMore(session: Session) async {
        guard let start = nextStart, !isLoading, !isLoadingMore else { return }
        await fetch(session: session, start: start, mode: .append)
    }

    func loadPrevious(session: Session) async {
        guard let start = previousStart, !isLoading, !isLoadingMore else { return }
        await fetch(session: session, start: start, mode: .prepend)
    }

    /// After posting, show the page containing the new message.
    func reloadAfterPost(messageID: Int?, session: Session) async {
        if let messageID {
            await fetch(session: session, start: nil, mode: .page, messageIDOverride: messageID)
            jumpTarget = messageID
        } else {
            await fetch(session: session, start: nil, mode: .page, forceNew: true)
            jumpTarget = posts.last?.id
        }
        jumpToken += 1
    }

    /// Jumps to a specific page (1-based), replacing the loaded posts.
    func go(to page: Int, session: Session) async {
        let target = min(max(page, 1), pageCount)
        guard target != currentPage, !isLoading, !isLoadingMore else { return }
        await fetch(session: session, start: (target - 1) * pageSize, mode: .page)
    }

    private func fetch(session: Session, start: Int?, mode: FetchMode, messageIDOverride: Int? = nil, forceNew: Bool = false) async {
        if mode == .initial {
            isLoading = true
        } else {
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        #if DEBUG
        if DemoMode.isEnabled {
            apply(DemoMode.topic(id: topicID, title: title, start: start), mode: mode)
            return
        }
        #endif

        do {
            let page = try await client.fetchTopic(
                id: topicID,
                start: start,
                messageID: start == nil ? (forceNew ? nil : (messageIDOverride ?? queryMessageID)) : nil,
                jumpToNew: start == nil && (forceNew || jumpToNew)
            )
            apply(page, mode: mode)
        } catch SMFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ page: TopicPage, mode: FetchMode) {
        pageSize = page.perPage

        switch mode {
        case .initial, .page:
            posts = page.posts
            if mode == .initial {
                // Prefer SMF's redirect target, otherwise keep the exact unread
                // message from the list when it is on this page.
                if let redirected = page.targetMessageID {
                    targetMessageID = redirected
                }
                if let target = targetMessageID,
                   !page.posts.contains(where: { $0.id == target }) {
                    if let next = page.posts.first(where: { $0.id >= target }) {
                        targetMessageID = next.id
                    } else if jumpToNew, let first = page.posts.first {
                        targetMessageID = first.id
                    }
                }
            }
            earliestStart = page.currentStart
            latestStart = page.currentStart
            nextStart = page.nextStart
            hasMore = page.hasNextPage
            if mode == .page { paginationToken += 1 }

        case .append:
            let existing = Set(posts.map(\.id))
            posts += page.posts.filter { !existing.contains($0.id) }
            latestStart = page.currentStart
            nextStart = page.nextStart
            hasMore = page.hasNextPage

        case .prepend:
            let existing = Set(posts.map(\.id))
            posts = page.posts.filter { !existing.contains($0.id) } + posts
            earliestStart = page.currentStart
        }

        previousStart = earliestStart > 0 ? max(0, earliestStart - page.perPage) : nil
        hasPrevious = previousStart != nil
        pageCount = max(1, page.maxStart / page.perPage + 1)
        currentPage = min(pageCount, latestStart / page.perPage + 1)

        if !page.title.isEmpty { title = page.title }
        boardName = page.boardName
        isLocked = page.isLocked
        errorMessage = nil
        didLoad = true
    }
}
