import SwiftUI
import SwiftData
import UIKit

/// The two apps that live in this one: Isle (planner) and PRIME (gym).
enum AppSide: String {
    case isle, prime
}

/// Decides which side is showing and runs the load animation between them.
@MainActor
@Observable
final class SideSwitcher {
    static let shared = SideSwitcher()

    private static let key = "hub.side"

    /// The side that is mounted underneath.
    private(set) var side: AppSide
    /// The side being loaded while its animation plays; nil when nothing is happening.
    private(set) var loading: AppSide?

    private init() {
        side = AppSide(rawValue: UserDefaults.standard.string(forKey: Self.key) ?? "") ?? .isle
    }

    /// Called once at launch so the system bars match the side that opens.
    func prepareLaunch() {
        if side == .prime { _ = PrimeRuntime.shared; Appearance.configure() } else { Appearance.reset() }
    }

    func switchTo(_ target: AppSide) {
        guard loading == nil, target != side else { return }
        if target == .prime { _ = PrimeRuntime.shared }
        loading = target
        Task { @MainActor in
            // Let the cover fill the screen before swapping what's underneath.
            try? await Task.sleep(for: .milliseconds(560))
            if target == .prime { Appearance.configure() } else { Appearance.reset() }
            side = target
            UserDefaults.standard.set(target.rawValue, forKey: Self.key)
            // Let the logo finish, then lift the cover.
            try? await Task.sleep(for: .milliseconds(950))
            withAnimation(.easeOut(duration: 0.38)) { loading = nil }
        }
    }

    /// Switches without the show, used when a notification opens the other side.
    func jump(to target: AppSide) {
        guard loading == nil, target != side else { return }
        if target == .prime { Appearance.configure() } else { Appearance.reset() }
        side = target
        UserDefaults.standard.set(target.rawValue, forKey: Self.key)
    }
}

/// The top of the app: one side mounted, with the load cover over it while switching.
struct SideHost: View {
    let isleContainer: ModelContainer
    @Environment(AppModel.self) private var app
    private var switcher: SideSwitcher { SideSwitcher.shared }

    var body: some View {
        ZStack {
            switch switcher.side {
            case .isle:
                IsleRootView()
                    .environment(app)
                    .modelContainer(isleContainer)
            case .prime:
                PrimeShell()
            }

            if let target = switcher.loading {
                Group {
                    switch target {
                    case .prime: PrimeLoadCover()
                    case .isle: IsleLoadCover(pip: pipLook())
                    }
                }
                .transition(.asymmetric(insertion: .identity,
                                        removal: .opacity.combined(with: .scale(scale: 1.06))))
                .zIndex(10)
            }
        }
    }

    private func pipLook() -> (color: Int, outfit: String) {
        let state = try? isleContainer.mainContext.fetch(FetchDescriptor<IsleState>()).first
        return (state?.bodyColorIndex ?? 0, state?.outfit ?? "none")
    }
}

// MARK: - Loading PRIME

/// Dark cover that floods in, draws the PRIME mark, then lands with a thud.
struct PrimeLoadCover: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flood: CGFloat = 0
    @State private var drawn: CGFloat = 0
    @State private var glow = false
    @State private var wordUp = false
    @State private var line: CGFloat = 0
    @State private var rays = false

    var body: some View {
        GeometryReader { geo in
            let reach = hypot(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(Color(hex: 0x05070B))
                    .frame(width: reach * 1.15, height: reach * 1.15)
                    .scaleEffect(flood)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.62)

                RadialGradient(colors: [Theme.accent.opacity(glow ? 0.32 : 0), .clear],
                               center: .center, startRadius: 4, endRadius: 260)
                    .opacity(flood)

                ForEach(0..<12, id: \.self) { i in
                    Capsule()
                        .fill(Theme.accent.opacity(0.5))
                        .frame(width: 2, height: rays ? 26 : 4)
                        .offset(y: rays ? -118 : -60)
                        .rotationEffect(.degrees(Double(i) * 30))
                        .opacity(rays ? 0 : 0.9)
                }
                .opacity(drawn > 0 ? 1 : 0)

                VStack(spacing: 22) {
                    ZStack {
                        PrimeMark().fill(Theme.accent.opacity(0.14 * drawn))
                        PrimeMark()
                            .trim(from: 0, to: drawn)
                            .stroke(Theme.accentGradient,
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    }
                    .frame(width: 78, height: 78)
                    .shadow(color: Theme.accent.opacity(glow ? 0.75 : 0), radius: glow ? 22 : 0)
                    .scaleEffect(glow ? 1 : 0.86)

                    VStack(spacing: 10) {
                        Text("PRIME")
                            .font(.system(size: 34, weight: .heavy).width(.expanded))
                            .tracking(wordUp ? 6 : 18)
                            .foregroundStyle(Color(hex: 0xF5F7FA))
                        Capsule()
                            .fill(Theme.accentGradient)
                            .frame(width: 130 * line, height: 3)
                    }
                    .opacity(wordUp ? 1 : 0)
                    .offset(y: wordUp ? 0 : 16)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(true)
        .onAppear(perform: run)
        .accessibilityLabel("Loading PRIME")
    }

    private func run() {
        Feedback.play(.whoosh)
        if reduceMotion {
            flood = 1; drawn = 1; glow = true; wordUp = true; line = 1
            return
        }
        withAnimation(.easeIn(duration: 0.5)) { flood = 1 }
        withAnimation(.easeInOut(duration: 0.6).delay(0.38)) { drawn = 1 }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.62).delay(0.92)) { glow = true }
        withAnimation(.easeOut(duration: 0.5).delay(0.92)) { rays = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.7)) { wordUp = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.95)) { line = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(940))
            Haptics.heavy()
        }
    }
}

// MARK: - Loading Isle

/// Warm cover that bubbles up, a wave rolls in and Pip pops out to say hello.
struct IsleLoadCover: View {
    let pip: (color: Int, outfit: String)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bubble: CGFloat = 0
    @State private var tide: CGFloat = 0
    @State private var pipIn = false
    @State private var letters = 0
    @State private var bob = false

    private let word = Array("Isle")

    var body: some View {
        GeometryReader { geo in
            let reach = hypot(geo.size.width, geo.size.height)
            ZStack {
                Circle()
                    .fill(T.cream)
                    .frame(width: reach * 1.15, height: reach * 1.15)
                    .scaleEffect(bubble)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.62)

                // The sea rolling in along the bottom.
                LoadWave(phase: bob ? 1 : 0)
                    .fill(Color(hex: 0x8FD3F0))
                    .frame(height: geo.size.height * 0.34)
                    .offset(y: geo.size.height * 0.33 + (1 - tide) * geo.size.height * 0.4)
                LoadWave(phase: bob ? 0 : 1)
                    .fill(Color(hex: 0x6EC1E6).opacity(0.7))
                    .frame(height: geo.size.height * 0.3)
                    .offset(y: geo.size.height * 0.37 + (1 - tide) * geo.size.height * 0.4)

                VStack(spacing: 18) {
                    ZStack(alignment: .bottom) {
                        Ellipse()
                            .fill(Color(hex: 0xF2D9A0))
                            .frame(width: 150, height: 34)
                            .offset(y: 14)
                            .scaleEffect(x: pipIn ? 1 : 0.2, y: 1)
                        PipView(mood: .cheer, size: 118, colorIndex: pip.color, outfit: pip.outfit, animated: true)
                            .scaleEffect(pipIn ? 1 : 0.2, anchor: .bottom)
                            .offset(y: pipIn ? 0 : 60)
                            .opacity(pipIn ? 1 : 0)
                    }
                    HStack(spacing: 2) {
                        ForEach(word.indices, id: \.self) { i in
                            Text(String(word[i]))
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .foregroundStyle(Color(hex: 0x2B2848))
                                .scaleEffect(i < letters ? 1 : 0.3)
                                .offset(y: i < letters ? 0 : 18)
                                .opacity(i < letters ? 1 : 0)
                        }
                    }
                }
                .offset(y: -40)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(true)
        .onAppear(perform: run)
        .accessibilityLabel("Loading Isle")
    }

    private func run() {
        Feedback.play(.slide)
        if reduceMotion {
            bubble = 1; tide = 1; pipIn = true; letters = word.count
            return
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) { bubble = 1 }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.75).delay(0.2)) { tide = 1 }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { bob = true }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.55).delay(0.55)) { pipIn = true }
        Feedback.play(.chirp, after: 0.62)
        for i in 0..<word.count {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.6).delay(0.8 + Double(i) * 0.08)) {
                letters = i + 1
            }
        }
    }
}

/// A soft sine wave for the Isle cover.
struct LoadWave: Shape {
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let amp: CGFloat = 10
        let len = rect.width / 1.3
        p.move(to: CGPoint(x: 0, y: amp))
        var x: CGFloat = 0
        while x <= rect.width {
            let y = amp + sin((x / len + phase) * .pi * 2) * amp
            p.addLine(to: CGPoint(x: x, y: y))
            x += 4
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

// MARK: - Switch buttons

/// The button in Isle that opens PRIME.
struct SwitchToPrimeButton: View {
    var body: some View {
        Button { SideSwitcher.shared.switchTo(.prime) } label: {
            ZStack {
                Circle().fill(Color(hex: 0x05070B))
                PrimeMark()
                    .fill(LinearGradient(colors: [Color(hex: 0x5B8CFF), Color(hex: 0x2E5BFF)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 18, height: 18)
            }
            .frame(width: 40, height: 40)
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel("Switch to PRIME")
    }
}

/// The button in PRIME that goes back to Isle.
struct SwitchToIsleButton: View {
    var body: some View {
        Button { SideSwitcher.shared.switchTo(.isle) } label: {
            ZStack {
                Circle().fill(Color(hex: 0xFFD45C))
                PipView(mood: .happy, size: 30, animated: false)
                    .offset(y: 2)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Switch to Isle")
    }
}
