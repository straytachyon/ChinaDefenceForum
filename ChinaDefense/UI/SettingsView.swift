import SwiftUI

struct SettingsView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppAppearance.defaultsKey) private var appearanceRaw = AppAppearance.system.rawValue
    @Environment(AppSettings.self) private var settings
    @State private var isReloading = false
    @State private var confirmSignOut = false
    @State private var showWebsite = false

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Picker("Appearance", selection: $appearanceRaw) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper(value: $settings.postTextScale, in: 0.8...1.5, step: 0.1) {
                        HStack {
                            Text("Post text size")
                            Spacer()
                            Text("\(Int((settings.postTextScale * 100).rounded()))%")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }

                    Text("Post text preview — Aa")
                        .font(.system(size: 16 * settings.postTextScale))
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Display")
                } footer: {
                    Text("System follows your device's light or dark setting. Post text size applies to post bodies in threads.")
                }

                Section {
                    if let user = session.user {
                        LabeledContent("Signed in as", value: user.name)
                    }
                    if let username = session.savedUsername {
                        LabeledContent("Saved account", value: username)
                    }
                    Button("Sign Out", role: .destructive) {
                        confirmSignOut = true
                    }
                } header: {
                    Text("Account")
                }

                Section {
                    NavigationLink {
                        TabOrderEditor()
                    } label: {
                        Label("Arrange Board Tabs", systemImage: "arrow.up.arrow.down")
                    }
                } header: {
                    Text("Tabs")
                } footer: {
                    Text("Reorder the board tabs shown at the bottom of the screen. “Unread” always stays first.")
                }

                Section {
                    Button {
                        reload()
                    } label: {
                        HStack {
                            Text("Reload Forum Structure")
                            Spacer()
                            if isReloading { ProgressView() }
                        }
                    }
                    .disabled(isReloading)

                    LabeledContent("Boards", value: "\(session.boards.count)")
                    if let badge = session.unreadBadge {
                        LabeledContent("Unread Topics", value: "\(badge)")
                    }
                    Button("Open Forum Website") {
                        showWebsite = true
                    }
                    if let error = session.boardsError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Forum")
                } footer: {
                    Text("Tabs follow the top-level boards on the forum index. Reload after the forum structure changes.")
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.shortVersion)
                    Text("Unofficial reader for China Defence Forum. Not affiliated with the forum or its operators.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("About")
                }

                Section {
                    Button("Clear Cached Boards", role: .destructive) {
                        session.clearCache()
                    }
                } header: {
                    Text("Storage")
                } footer: {
                    Text("The cached board list rebuilds the tab bar instantly on launch. It is refreshed every time you sign in.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showWebsite) {
                WebSheet(url: AppConfig.forumDisplayURL)
            }
            .confirmationDialog(
                "Sign out of China Defence Forum?",
                isPresented: $confirmSignOut,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task {
                        await session.signOut()
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    private func reload() {
        Task {
            isReloading = true
            await session.refreshBoards()
            isReloading = false
        }
    }
}

extension Bundle {
    var shortVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
