import Foundation
import Observation

@MainActor
@Observable
final class AlertsStore {
    private(set) var unreadCount = 0
    private(set) var items: [ForumAlert] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let client = SMFClient.shared

    func refresh(session: Session) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await client.fetchAlerts()
            unreadCount = snapshot.unread
            items = snapshot.items
            errorMessage = nil
        } catch SMFError.notLoggedIn {
            session.sessionExpired()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
