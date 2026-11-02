import SwiftUI

enum AppTheme {
    /// Deep red accent, close to the forum's flag-inspired branding.
    static let accent = Color(red: 0.78, green: 0.17, blue: 0.14)
    static let navy = Color(red: 0.13, green: 0.19, blue: 0.26)

    /// Metadata grey that still clears 4.5:1 on grouped backgrounds.
    static var secondaryText: Color { Color.primary.opacity(0.58) }

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.20, green: 0.09, blue: 0.10), Color(red: 0.09, green: 0.13, blue: 0.19)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var markGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.88, green: 0.24, blue: 0.20), Color(red: 0.55, green: 0.10, blue: 0.12)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct AppMark: View {
    var size: CGFloat = 72

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(AppTheme.markGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: size * 0.14, y: size * 0.06)

            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

struct RootView: View {
    @Environment(Session.self) private var session

    var body: some View {
        ZStack {
            switch session.phase {
            case .restoring:
                LaunchView().transition(.opacity)
            case .signedOut:
                LoginView().transition(.opacity)
            case .signedIn:
                MainTabs().transition(.opacity)
            }
        }
        .task { await session.bootstrap() }
        .animation(.easeInOut(duration: 0.22), value: session.phase)
    }
}

struct LaunchView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            AppTheme.heroGradient.ignoresSafeArea()
            VStack(spacing: 18) {
                AppMark(size: 88)
                VStack(spacing: 4) {
                    Text("China Defence Forum")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("Forum reader")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                }
                ProgressView()
                    .tint(.white.opacity(0.8))
                    .padding(.top, 8)
                    .opacity(pulse ? 1 : 0.45)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
