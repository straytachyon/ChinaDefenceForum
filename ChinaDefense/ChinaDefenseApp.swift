import SwiftUI

@main
struct ChinaDefenseApp: App {
    @State private var session = Session()
    @AppStorage(AppAppearance.defaultsKey) private var appearanceRaw = AppAppearance.system.rawValue
    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup
        {
            RootView()
                .environment(session)
                .tint(AppTheme.accent)
                .environment(settings)
                .preferredColorScheme(AppAppearance(rawValue: appearanceRaw)?.colorScheme)
        }
    }
}
