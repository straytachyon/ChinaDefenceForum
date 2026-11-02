import SwiftUI

struct AlertsView: View {
    @Environment(AlertsStore.self) private var alerts
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var link: WebLink?

    var body: some View {
        NavigationStack {
            Group {
                if alerts.isLoading && alerts.items.isEmpty {
                    ProgressView("Loading notifications…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if alerts.items.isEmpty {
                    ContentUnavailableView {
                        Label("No Notifications", systemImage: "bell")
                    } description: {
                        VStack(spacing: 6) {
                            Text("Quotes, mentions and likes will appear here.")
                            if let error = alerts.errorMessage {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                } else {
                    List(alerts.items) { alert in
                        Button {
                            if let url = alert.url { link = WebLink(url: url) }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(alert.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                if !alert.time.isEmpty {
                                    Text(alert.time)
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(alerts.unreadCount > 0 ? "Notifications (\(alerts.unreadCount))" : "Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("View All") {
                        link = WebLink(url: AppConfig.url("action=profile;area=showalerts"))
                    }
                }
            }
            .refreshable { await alerts.refresh(session: session) }
            .task {
                if alerts.items.isEmpty { await alerts.refresh(session: session) }
            }
            .sheet(item: $link) { webLink in
                WebSheet(url: webLink.url)
            }
        }
    }
}
