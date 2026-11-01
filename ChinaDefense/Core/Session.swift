import Foundation
import Observation

/// Owns the signed-in state, the forum structure and the shared network client.
@MainActor
@Observable
final class Session {
    enum Phase: Equatable {
        case restoring
        case signedOut
        case signedIn
    }

    private(set) var phase: Phase = .restoring
    private(set) var user: SMFUser?
    private(set) var categories: [ForumCategory] = []
    private(set) var unreadBadge: Int?
    private(set) var isRefreshingBoards = false

    /// Message shown on the login screen (expired session, sign-out, …).
    var notice: String?
    /// Last failure while refreshing the board structure, shown in settings.
    var boardsError: String?

    private let client = SMFClient.shared
    private let keychain = KeychainStore()
    private var didBootstrap = false

    var boards: [ForumBoard] { categories.flatMap(\.boards) }
    var savedUsername: String? { keychain.load()?.username }

    /// Categories used for the tab bar. Redirect boards are links to other sites and
    /// cannot show topics, so they are left out; empty groups would break `TabSection`.
    var tabCategories: [ForumCategory] {
        categories.compactMap { category in
            let boards = category.boards.filter { !$0.isRedirect }
            guard !boards.isEmpty else { return nil }
            return ForumCategory(id: category.id, name: category.name, boards: boards)
        }
    }

    // MARK: - Lifecycle

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        if let cached = CacheStore.loadBoards() {
            categories = cached
        }

        #if DEBUG
        if DemoMode.isEnabled {
            let result = DemoMode.boardIndex()
            categories = result.categories
            unreadBadge = result.unreadCount
            user = SMFUser(id: 42, name: "observer")
            phase = .signedIn
            return
        }
        #endif

        do {
            let current = try await client.fetchCurrentUser()
            user = current
            phase = .signedIn
            await refreshBoards()
        } catch {
            // The stored cookie may have expired: retry with the saved credentials.
            if let credentials = keychain.load(),
               let current = try? await client.login(username: credentials.username, password: credentials.password) {
                user = current
                phase = .signedIn
                await refreshBoards()
            } else {
                phase = .signedOut
            }
        }
    }

    func signIn(username: String, password: String, remember: Bool) async throws {
        let current = try await client.login(username: username, password: password)
        if remember {
            keychain.save(Credentials(username: username, password: password))
        } else {
            keychain.delete()
        }
        user = current
        notice = nil
        boardsError = nil
        phase = .signedIn
        await refreshBoards()
    }

    func signOut() async {
        await client.signOut()
        keychain.delete()
        user = nil
        unreadBadge = nil
        boardsError = nil
        notice = "You have been signed out."
        phase = .signedOut
    }

    // MARK: - Forum structure

    func refreshBoards() async {
        guard phase == .signedIn else { return }
        #if DEBUG
        if DemoMode.isEnabled { return }
        #endif
        isRefreshingBoards = true
        defer { isRefreshingBoards = false }

        do {
            let result = try await client.fetchBoardIndex()
            categories = result.categories
            unreadBadge = result.unreadCount
            boardsError = nil
            CacheStore.save(result.categories)
        } catch SMFError.notLoggedIn {
            sessionExpired()
        } catch {
            boardsError = error.localizedDescription
        }
    }

    func clearCache() {
        CacheStore.clear()
        categories = []
    }

    // MARK: - Badge / session

    func reportUnreadCount(_ count: Int) {
        unreadBadge = count
    }

    func sessionExpired() {
        phase = .signedOut
        notice = "Your forum session expired. Please sign in again."
    }
}
