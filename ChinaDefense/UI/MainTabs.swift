import SwiftUI

enum TabID: Hashable {
    case unread
    case board(Int)
}

/// One tab per top-level board, plus a leading Unread tab.
///
/// On iPad the tab bar adapts into a sidebar (grouped by forum category) so all boards
/// stay reachable; on iPhone the system tab bar handles overflow with "More".
struct MainTabs: View {
    @Environment(Session.self) private var session

    @State private var selection: TabID = .unread
    @State private var showSettings = false
    @AppStorage(TabOrder.defaultsKey) private var tabOrder = ""

    var body: some View {
        tabs
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onChange(of: session.categories) { _, _ in
                validateSelection()
            }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            Tab("Unread", systemImage: "dot.radiowaves.left.and.right", value: TabID.unread) {
                TopicListTab(mode: .unread, onShowSettings: { showSettings = true })
            }
            .badge(session.unreadBadge ?? 0)

            // One tab per top-level board, in the order the user arranged.
            ForEach(TabOrder.ordered(session.tabCategories.flatMap(\.boards), saved: tabOrder)) { board in
                Tab(board.tabTitle, systemImage: board.iconName, value: TabID.board(board.id)) {
                    TopicListTab(
                        mode: .board(BoardTarget(board: board)),
                        onShowSettings: { showSettings = true }
                    )
                }
            }
        }
        .modifier(SidebarTabStyle())
    }

    private func validateSelection() {
        if case .board(let id) = selection, !session.boards.contains(where: { $0.id == id }) {
            selection = .unread
        }
    }
}

/// iPadOS 18+ collapses the tab bar into a sidebar, which is a much better fit for a
/// forum with a dozen boards.
private struct SidebarTabStyle: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            content.tabViewStyle(.sidebarAdaptable)
        } else {
            // Plain tab bar: the adaptive style adds its own navigation bar on
            // top of a thread's NavigationStack on iPhone.
            content.tabViewStyle(.tabBarOnly)
        }
    }
}
