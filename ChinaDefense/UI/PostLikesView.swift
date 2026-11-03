import SwiftUI

struct PostLikesView: View {
    let post: ForumPost

    @Environment(\.dismiss) private var dismiss
    @State private var likers: [PostLiker] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var link: WebLink?

    private var title: String {
        post.likeCount == 1 ? "1 Like" : "\(post.likeCount) Likes"
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && likers.isEmpty {
                    ProgressView("Loading likes…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let errorMessage, likers.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn’t Load Likes", systemImage: "heart.slash")
                    } description: {
                        Text(errorMessage)
                    }
                } else if likers.isEmpty {
                    ContentUnavailableView {
                        Label("No Likes Yet", systemImage: "heart")
                    } description: {
                        Text("Nobody has liked this post yet.")
                    }
                } else {
                    List(likers) { liker in
                        Button {
                            if let profileURL = liker.profileURL {
                                link = WebLink(url: profileURL)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                avatar(for: liker)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(liker.name)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    if !liker.group.isEmpty {
                                        Text(liker.group)
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.secondaryText)
                                    }
                                }
                                Spacer(minLength: 4)
                                if !liker.time.isEmpty {
                                    Text(liker.time)
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
            .sheet(item: $link) { webLink in
                WebSheet(url: webLink.url)
            }
        }
    }

    @ViewBuilder
    private func avatar(for liker: PostLiker) -> some View {
        if let url = liker.avatarURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Circle().fill(Color(.tertiarySystemFill))
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(Circle())
        } else {
            Circle()
                .fill(Color(.tertiarySystemFill))
                .frame(width: 34, height: 34)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func load() async {
        guard let url = post.likesViewURL else {
            isLoading = false
            return
        }
        do {
            likers = try await SMFClient.shared.fetchPostLikers(url: url)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
