import Foundation
import Observation

@MainActor
@Observable
final class AlertsStore {
    private(set) var unreadCount = 0
    private(set) var items: [ForumAlert] = []
    private(set) var markAllReadURL: URL?
    private(set) var isLoading = false
    var errorMessage: String?

    private let client = SMFClient.shared

    func refresh(session: Session) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await client.fetchAlerts()
            unreadCount = snapshot.unread
            items = snapshot.items
            markAllReadURL = snapshot.markAllReadURL
            errorMessage = nil
        } catch SMFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markRead(_ alert: ForumAlert, session: Session) async {
        guard alert.isUnread, let url = alert.markReadURL else { return }
        do {
            try await client.markAlertRead(url)
            if let index = items.firstIndex(where: { $0.id == alert.id }) {
                items[index].isUnread = false
            }
            unreadCount = max(0, unreadCount - 1)
        } catch SMFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllRead(session: Session) async {
        guard unreadCount > 0, let url = markAllReadURL else { return }
        do {
            try await client.markAllRead(url)
            for index in items.indices { items[index].isUnread = false }
            unreadCount = 0
        } catch SMFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
