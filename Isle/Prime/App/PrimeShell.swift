import SwiftData
import SwiftUI
import UIKit

/// PRIME lives inside Isle. Its state and database are made once and kept for the
/// whole run, so switching away and back doesn't lose a workout in progress.
@MainActor
final class PrimeRuntime {
    static let shared = PrimeRuntime()
    let appState = AppState()
    let store = TrainingStore()
    let container: Result<ModelContainer, Error>

    private init() {
        container = Result(catching: { try PrimeStore.makeContainer() })
        // So the load screen already wears the accent the user picked.
        if case .success(let c) = container,
           let profile = try? c.mainContext.fetch(FetchDescriptor<UserProfile>()).first {
            Theme.accentChoice = AccentChoice(rawValue: profile.accentRaw) ?? .electric
            Haptics.enabled = profile.hapticsEnabled
        }
    }
}

/// What used to be PRIME's whole app, now one side of Isle.
struct PrimeShell: View {
    private var runtime: PrimeRuntime { PrimeRuntime.shared }

    var body: some View {
        Group {
            switch runtime.container {
            case .success(let container):
                RootView()
                    .environment(runtime.appState)
                    .environment(runtime.store)
                    .modelContainer(container)
            case .failure(let error):
                StoreErrorView(message: error.localizedDescription)
            }
        }
        .preferredColorScheme(.dark)
    }
}

enum Appearance {
    /// Puts the system bars back the way Isle expects them.
    static func reset() {
        let plain = UINavigationBarAppearance()
        plain.configureWithDefaultBackground()
        UINavigationBar.appearance().standardAppearance = plain
        UINavigationBar.appearance().compactAppearance = nil
        UINavigationBar.appearance().scrollEdgeAppearance = nil
        UISegmentedControl.appearance().selectedSegmentTintColor = nil
        UISegmentedControl.appearance().setTitleTextAttributes(nil, for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes(nil, for: .normal)
        UISegmentedControl.appearance().backgroundColor = nil
    }

    static func configure() {
        let titleColor = UIColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1)
        let navy = UIColor(red: 0.02, green: 0.03, blue: 0.045, alpha: 0.82)

        let transparent = UINavigationBarAppearance()
        transparent.configureWithTransparentBackground()
        transparent.largeTitleTextAttributes = [.foregroundColor: titleColor, .font: UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: .systemFont(ofSize: 32, weight: .bold))]
        transparent.titleTextAttributes = [.foregroundColor: titleColor, .font: UIFont.systemFont(ofSize: 17, weight: .semibold)]

        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.backgroundEffect = UIBlurEffect(style: .systemChromeMaterialDark)
        scrolled.backgroundColor = navy
        scrolled.shadowColor = UIColor(red: 0.11, green: 0.17, blue: 0.26, alpha: 1)
        scrolled.largeTitleTextAttributes = transparent.largeTitleTextAttributes
        scrolled.titleTextAttributes = transparent.titleTextAttributes

        UINavigationBar.appearance().standardAppearance = scrolled
        UINavigationBar.appearance().compactAppearance = scrolled
        UINavigationBar.appearance().scrollEdgeAppearance = transparent

        UISegmentedControl.appearance().selectedSegmentTintColor = UIColor(red: 0.22, green: 0.48, blue: 1, alpha: 1)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)], for: .selected)
        UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.white.withAlphaComponent(0.75)], for: .normal)
        UISegmentedControl.appearance().backgroundColor = UIColor(red: 0.063, green: 0.102, blue: 0.176, alpha: 1)
    }
}

/// Shown only if the database can't be opened. Nothing is deleted automatically.
struct StoreErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 44))
                .foregroundStyle(Theme.warning)
            Text("PRIME couldn't open your data")
                .font(.primeTitle)
                .foregroundStyle(Theme.textPrimary)
            Text("Your workouts haven't been deleted. Close PRIME completely and open it again. If this keeps happening, free up some storage on your iPhone.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textSecondary)
            Text(message)
                .font(.caption.monospaced())
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
    }
}
