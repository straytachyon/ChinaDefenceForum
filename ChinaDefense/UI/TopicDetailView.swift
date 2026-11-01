import SwiftUI

struct TopicDetailView: View {
    let topic: ForumTopic

    @Environment(Session.self) private var session
    @State private var model: TopicModel
    @State private var safari: WebLink?
    @State private var didScrollToTarget = false
    @State private var showReply = false
    @State private var quotingPost: ForumPost?
    @State private var isLandscape = false

    /// Phones go edge-to-edge in both orientations; iPad keeps a readable column
    /// until it is turned to landscape.
    private let isPhone = UIDevice.current.userInterfaceIdiom == .phone
    private var usesFullWidth: Bool { isPhone || isLandscape }

    init(topic: ForumTopic) {
        self.topic = topic
        _model = State(initialValue: TopicModel(topic: topic))
    }

    private var topicURL: URL {
        AppConfig.url("topic=\(topic.id).0")
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // A page holds ~20 posts; a plain VStack guarantees every
                // scroll target exists (LazyVStack may not materialise off-screen rows).
                VStack(alignment: .leading, spacing: 12) {
                    header

                    if model.hasPrevious {
                        Button {
                            Task { await model.loadPrevious(session: session) }
                        } label: {
                            Label("Load Earlier Posts", systemImage: "arrow.up.circle")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(Capsule().fill(Color(.tertiarySystemFill)))
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                    }

                    if model.isLoading && model.posts.isEmpty {
                        ProgressView("Loading posts…")
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    } else if let error = model.errorMessage, model.posts.isEmpty {
                        ContentUnavailableView {
                            Label("Couldn’t Load Topic", systemImage: "exclamationmark.bubble")
                        } description: {
                            Text(error)
                        } actions: {
                            Button("Try Again") {
                                Task { await model.refresh(session: session) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 40)
                    } else {
                        ForEach(model.posts) { post in
                            PostCard(
                                post: post,
                                topicTitle: model.title,
                                leadingInset: landscapeInsets.left,
                                trailingInset: landscapeInsets.right
                            ) { quoted in
                                quotingPost = quoted
                            }
                            .id(post.id)
                        }

                        if model.isLoadingMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        } else if model.hasMore {
                            Button {
                                Task { await model.loadMore(session: session) }
                            } label: {
                                Label("Load More Posts", systemImage: "arrow.down.circle")
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
                                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, usesFullWidth ? 0 : 14)
                .padding(.vertical, isPhone ? 0 : 10)
                .frame(maxWidth: usesFullWidth ? .infinity : 820)
                .frame(maxWidth: .infinity)
            }
            .onGeometryChange(for: Bool.self) { proxy in
                proxy.size.width > proxy.size.height
            } action: { newValue in
                isLandscape = newValue
            }
            // Cards run to the physical edges; the top safe area still keeps the
            // first post below the island/notch.
            .ignoresSafeArea(.container, edges: isPhone ? .horizontal : [])
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .task(id: model.posts.count) {
                guard !didScrollToTarget,
                      let target = model.targetMessageID,
                      model.posts.contains(where: { $0.id == target }) else { return }
                didScrollToTarget = true
                // Lazy rows are not always laid out on the first pass; retry.
                for delay in [80, 250, 600] {
                    try? await Task.sleep(for: .milliseconds(delay))
                    proxy.scrollTo(target, anchor: .top)
                }
            }
            .onChange(of: model.paginationToken) { _, _ in
                guard let first = model.posts.first else { return }
                proxy.scrollTo(first.id, anchor: .top)
            }
            .onChange(of: model.jumpToken) { _, _ in
                if let target = model.jumpTarget {
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.pageCount > 1 {
                paginationBar
            }
        }
        .navigationTitle(model.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            NotificationCenter.default.post(name: .topicDidClose, object: topic.id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showReply = true
                } label: {
                    Image(systemName: "arrowshape.turn.up.left")
                }
                .accessibilityLabel("Reply")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if model.hasPrevious {
                        Button("Load Earlier Posts", systemImage: "arrow.up.circle") {
                            Task { await model.loadPrevious(session: session) }
                        }
                    }
                    if model.hasMore {
                        Button("Load More Posts", systemImage: "arrow.down.circle") {
                            Task { await model.loadMore(session: session) }
                        }
                    }
                    Divider()
                    Button("Open in Browser", systemImage: "safari") {
                        safari = WebLink(url: topicURL)
                    }
                    ShareLink(item: topicURL)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { await model.loadIfNeeded(session: session) }
        .refreshable { await model.refresh(session: session) }
        .environment(\.openURL, OpenURLAction { url in
            guard url.scheme == "http" || url.scheme == "https" else { return .systemAction }
            safari = WebLink(url: url)
            return .handled
        })
        .sheet(item: $safari) { link in
            WebSheet(url: link.url)
        }
        .sheet(isPresented: $showReply) {
            ComposeView(mode: .reply(topic, quoteMessageID: nil)) { outcome in
                if case .posted(_, let messageID) = outcome {
                    Task { await model.reloadAfterPost(messageID: messageID, session: session) }
                }
            }
        }
        .sheet(item: $quotingPost) { quoted in
            ComposeView(mode: .reply(topic, quoteMessageID: quoted.id)) { outcome in
                if case .posted(_, let messageID) = outcome {
                    Task { await model.reloadAfterPost(messageID: messageID, session: session) }
                }
            }
        }
    }

    private var paginationBar: some View {
        HStack(spacing: 22) {
            Button {
                jump(to: 1)
            } label: {
                Image(systemName: "chevron.backward.2")
            }
            .disabled(model.currentPage <= 1 || model.isLoading)

            Button {
                jump(to: model.currentPage - 1)
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(model.currentPage <= 1 || model.isLoading)

            Spacer(minLength: 4)

            Menu {
                ForEach(1...model.pageCount, id: \.self) { page in
                    Button(page == model.currentPage ? "Page \(page) ✓" : "Page \(page)") {
                        jump(to: page)
                    }
                }
            } label: {
                Text("Page \(model.currentPage) of \(model.pageCount)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
            }
            .disabled(model.pageCount <= 1)

            Spacer(minLength: 4)

            Button {
                jump(to: model.currentPage + 1)
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(model.currentPage >= model.pageCount || model.isLoading)

            Button {
                jump(to: model.pageCount)
            } label: {
                Image(systemName: "chevron.forward.2")
            }
            .disabled(model.currentPage >= model.pageCount || model.isLoading)
        }
        .font(.body.weight(.semibold))
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Page navigation")
    }

    private func jump(to page: Int) {
        Task { await model.go(to: page, session: session) }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let board = model.boardName, !board.isEmpty {
                Text(board)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(.tertiarySystemFill)))
            }

            Text("\(max(topic.replies, 0)) replies")
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)

            if model.isLocked {
                Label("Locked", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.leading, landscapeInsets.left)
        .padding(.trailing, landscapeInsets.right)
        .padding(.bottom, 2)
    }

    /// In landscape the strip is full-bleed; nudge content past the island/notch.
    private var landscapeInsets: (left: CGFloat, right: CGFloat) {
        guard isPhone, isLandscape,
              let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.keyWindow else { return (0, 0) }
        return (window.safeAreaInsets.left, window.safeAreaInsets.right)
    }
}
