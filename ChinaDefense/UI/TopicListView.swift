import SwiftUI

/// A tab's root: its own navigation stack plus topic-list destinations.
struct TopicListTab: View {
    let mode: TopicListModel.Mode
    var onShowSettings: () -> Void

    var body: some View {
        NavigationStack {
            TopicListContent(mode: mode, onShowSettings: onShowSettings)
                .navigationTitle(mode.title)
                .navigationBarTitleDisplayMode(.inline)
                .navigationDestination(for: ForumTopic.self) { topic in
                    TopicDetailView(topic: topic)
                }
                .navigationDestination(for: BoardTarget.self) { target in
                    TopicListContent(mode: .board(target), onShowSettings: onShowSettings)
                        .navigationTitle(target.name)
                        .navigationBarTitleDisplayMode(.inline)
                }
        }
    }
}

/// Topic list for a board or for all unread topics.
struct TopicListContent: View {
    let mode: TopicListModel.Mode
    var onShowSettings: () -> Void

    @Environment(Session.self) private var session
    @Environment(AlertsStore.self) private var alerts
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var model = TopicListModel()
    @State private var showTabOrder = false
    @State private var showCompose = false
    @State private var hasAppeared = false
    @State private var showAlerts = false

    var body: some View {
        Group {
            if model.isLoading && model.topics.isEmpty {
                loadingView
            } else if model.topics.isEmpty, let error = model.errorMessage {
                errorView(error)
            } else if model.topics.isEmpty {
                emptyView
            } else {
                topicList
            }
        }
        .background(Color(.systemGroupedBackground))
        .background(MoreBackButtonHider())
        .toolbar {
            if let board = mode.board {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New topic")
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showAlerts = true
                } label: {
                    Image(systemName: "bell")
                        .overlay(alignment: .topTrailing) {
                            if alerts.unreadCount > 0 {
                                Text(alerts.unreadCount > 99 ? "99+" : "\(alerts.unreadCount)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(.red))
                                    .offset(x: 7, y: -5)
                            }
                        }
                }
                .accessibilityLabel("Notifications")

                Button(action: onShowSettings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showAlerts) {
            AlertsView()
        }
        .sheet(isPresented: $showTabOrder) {
            NavigationStack {
                TabOrderEditor()
            }
        }
        .sheet(isPresented: $showCompose) {
            if let board = mode.board {
                ComposeView(mode: .newTopic(board)) { _ in
                    Task { await model.refresh(session: session) }
                }
            }
        }
        .task(id: mode) {
            await model.loadIfNeeded(mode: mode, session: session)
            guard case .unread = mode else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                await model.refresh(session: session)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, case .unread = mode else { return }
            Task { await model.refresh(session: session) }
        }
        .onAppear {
            guard hasAppeared else {
                hasAppeared = true
                return
            }
            // Returning to the tab: re-fetch so read topics drop out.
            if case .unread = mode {
                Task { await model.refresh(session: session) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .topicDidClose)) { notification in
            guard case .unread = mode else { return }
            if let id = notification.object as? Int {
                model.removeTopic(id: id)
                session.reportUnreadCount(model.topics.count)
            }
        }
    }

    private var topicList: some View {
        List {
            if sizeClass == .regular {
                Section {
                    if let board = mode.board {
                        boardHeader(board)
                    } else {
                        unreadHeader
                    }
                }
            } else if let board = mode.board, !board.summary.isEmpty || !board.childBoards.isEmpty {
                Section {
                    boardHeader(board)
                }
            }

            Section {
                ForEach(model.topics) { topic in
                    NavigationLink(value: topic) {
                        TopicRow(topic: topic)
                    }
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .onAppear {
                        guard topic.id == model.topics.last?.id else { return }
                        Task { await model.loadMore(session: session) }
                    }
                }

                if model.isLoadingMore {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading more topics…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                } else if model.hasMore {
                    Button {
                        Task { await model.loadMore(session: session) }
                    } label: {
                        Text("Load more topics")
                            .font(.footnote.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }

            if let error = model.errorMessage, !model.topics.isEmpty {
                Section {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
            await model.refresh(session: session)
        }
    }

    private func boardHeader(_ board: BoardTarget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if sizeClass == .regular {
                Text(board.name)
                    .font(.largeTitle.bold())
            }
            if !board.summary.isEmpty {
                Text(board.summary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !board.childBoards.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(board.childBoards) { child in
                            NavigationLink(value: BoardTarget(ref: child)) {
                                Label(child.name, systemImage: "arrow.turn.down.right")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 7)
                                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
    }

    private var unreadHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Unread")
                .font(.largeTitle.bold())
            Text(unreadSubtitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(.vertical, 4)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
    }

    private var unreadSubtitle: String {
        if model.isLoading && model.topics.isEmpty { return "Checking for new posts…" }
        if model.topics.isEmpty { return "All caught up" }
        let count = model.topics.count
        return count == 1 ? "1 unread topic" : "\(count) unread topics"
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(mode == .unread ? "Checking for unread posts…" : "Loading topics…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label(
                mode == .unread ? "All caught up" : "No topics yet",
                systemImage: mode == .unread ? "checkmark.circle" : "bubble.left.and.bubble.right"
            )
        } description: {
            Text(
                mode == .unread
                    ? "You have no unread posts on the forum."
                    : "This board does not have any topics yet."
            )
        } actions: {
            Button("Refresh") {
                Task { await model.refresh(session: session) }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Couldn’t Load Topics", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await model.refresh(session: session) }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

struct TopicRow: View {
    let topic: ForumTopic

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(topic.isUnread ? AppTheme.accent : Color.clear)
                .frame(width: 3)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    if topic.isSticky {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                    if topic.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(topic.title)
                        .font(.subheadline.weight(topic.isUnread ? .semibold : .regular))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }

                HStack(spacing: 5) {
                    if !topic.author.isEmpty {
                        Text(topic.author).lineLimit(1)
                        Text("·")
                    }
                    Text(topic.lastPostText).lineLimit(1)
                }
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 6)

            HStack(spacing: 4) {
                Image(systemName: "bubble.left")
                    .font(.caption2)
                Text("\(topic.replies)")
                    .font(.caption.weight(.semibold).monospacedDigit())
            }
            .foregroundStyle(AppTheme.secondaryText)
            .accessibilityLabel("\(topic.replies) replies")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .contentShape(Rectangle())
    }
}


extension Notification.Name {
    static let topicDidClose = Notification.Name("ChinaDefense.topicDidClose")
}


/// The iPhone tab bar moves extra tabs into UIKit's "More" controller, which
/// pushes each tab inside its own navigation stack and shows a back button to
/// the More list. That extra button sits above a thread's own back button, so
/// hide it on the More controller's current item.
private struct MoreBackButtonHider: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {}

    final class Controller: UIViewController {
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            hideMoreBackButton()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            hideMoreBackButton()
        }

        private func hideMoreBackButton() {
            var current: UIViewController? = self
            while let controller = current {
                if let navigation = controller as? UINavigationController,
                   let tabBar = navigation.tabBarController,
                   tabBar.moreNavigationController === navigation {
                    navigation.topViewController?.navigationItem.hidesBackButton = true
                }
                current = controller.parent
            }
        }
    }
}
