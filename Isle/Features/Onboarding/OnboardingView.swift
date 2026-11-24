import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var step = 0           // 0 egg, 1 name + seeds, 2 permissions
    @State private var taps = 0
    @State private var wobble: Double = 0
    @State private var hatched = false
    @State private var shellsFly = false
    @State private var name = "Pip"
    @State private var picked: [Int] = []
    @State private var permStep = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    struct Seed {
        let name: String
        let color: Int
        let target: Int
        let time: Int?
        let minutes: Int
    }

    private let seeds: [Seed] = [
        Seed(name: "Gym", color: 0, target: 3, time: 7 * 60, minutes: 45),
        Seed(name: "Read 10 pages", color: 1, target: 7, time: 21 * 60, minutes: 15),
        Seed(name: "Walk outside", color: 2, target: 3, time: nil, minutes: 30),
        Seed(name: "Drink water", color: 6, target: 7, time: 12 * 60 + 30, minutes: 1),
        Seed(name: "In bed by 11", color: 3, target: 5, time: 22 * 60 + 30, minutes: 30),
        Seed(name: "Journal", color: 4, target: 3, time: 21 * 60 + 30, minutes: 5),
        Seed(name: "Stretch", color: 5, target: 3, time: nil, minutes: 10),
        Seed(name: "Meditate", color: 7, target: 3, time: nil, minutes: 10)
    ]

    var body: some View {
        ZStack {
            T.sky.ignoresSafeArea()
            switch step {
            case 0, 1: hatchStage
            default: PermissionsStage(onDone: finish)
            }
        }
    }

    // MARK: egg → name → seeds

    private var hatchStage: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i <= step ? T.ink : T.ink.opacity(0.2)).frame(width: 24, height: 6)
                }
            }
            .padding(.top, 12)
            VStack(spacing: 6) {
                Text(hatched ? "Hello, \(name.isEmpty ? "Pip" : name)!" : "Someone's waiting for you")
                    .font(.isle(.largeTitle, .heavy)).foregroundStyle(T.ink).multilineTextAlignment(.center)
                Text(hatched ? "Your companion grows when you look after yourself." : "Tap the egg to help it hatch.")
                    .font(.isle(.subheadline, .semibold)).foregroundStyle(T.muted).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20).padding(.top, 14)
            .animation(.easeOut(duration: 0.25), value: hatched)

            ZStack(alignment: .bottom) {
                Ellipse().fill(T.grass).frame(width: 520, height: 300)
                    .overlay(Ellipse().strokeBorder(T.outline, lineWidth: 2.5))
                    .offset(y: hatched ? 160 : 190)
                if hatched {
                    PipView(mood: .cheer, size: 160)
                        .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
                        .offset(y: -40)
                    EggHalf(left: true).offset(x: shellsFly ? -110 : -30, y: shellsFly ? 30 : -40)
                        .rotationEffect(.degrees(shellsFly ? -70 : 0))
                        .opacity(shellsFly ? 0 : 1)
                    EggHalf(left: false).offset(x: shellsFly ? 110 : 30, y: shellsFly ? 40 : -40)
                        .rotationEffect(.degrees(shellsFly ? 80 : 0))
                        .opacity(shellsFly ? 0 : 1)
                } else {
                    Button(action: tapEgg) {
                        EggView(cracks: taps).frame(width: 150, height: 186)
                    }
                    .buttonStyle(.plain)
                    .rotationEffect(.degrees(wobble), anchor: .bottom)
                    .offset(y: -40)
                    .accessibilityLabel("Tap the egg, \(taps) of 3")
                }
            }
            .frame(height: 300)
            .clipped()

            if hatched {
                namingCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Text(["Tap tap tap!", "Something's moving…", "One more!"][min(taps, 2)])
                    .font(.isle(.headline)).foregroundStyle(Color(hex: 0x2E5E2A))
                    .padding(.top, 8)
                Spacer()
            }
        }
        .onAppear { idleWobble() }
    }

    private var namingCard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name your companion").font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink)
                    TextField("Pip", text: $name)
                        .font(.isle(.title2, .heavy))
                        .padding(.horizontal, 12).frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 14).fill(T.bg))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(T.outline, lineWidth: 2))
                }
                VStack(alignment: .leading, spacing: 6) {
                    (Text("Pick up to 3 starter seeds ").font(.isle(.subheadline, .heavy)) + Text("· \(picked.count)/3").font(.isle(.subheadline, .heavy)).foregroundColor(T.muted))
                        .foregroundStyle(T.ink)
                    IsleFlowLayout(spacing: 6) {
                        ForEach(0..<seeds.count, id: \.self) { i in
                            let on = picked.contains(i)
                            Button { toggleSeed(i) } label: {
                                HStack(spacing: 6) {
                                    Circle().fill(T.habit(seeds[i].color)).overlay(Circle().strokeBorder(T.outline, lineWidth: 2)).frame(width: 14, height: 14)
                                    Text(seeds[i].name).font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink)
                                }
                                .padding(.horizontal, 12).frame(minHeight: 40)
                                .background(Capsule().fill(on ? T.primarySoft : T.surface))
                                .overlay(Capsule().strokeBorder(on ? T.outline : T.line, lineWidth: 2))
                                .opacity(!on && picked.count >= 3 ? 0.45 : 1)
                                .scaleEffect(on ? 1.04 : 1)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                }
                Button(picked.isEmpty ? "Pick a seed to start" : "Next") {
                    guard !picked.isEmpty else { Feedback.play(.hmm); return }
                    plantSeeds()
                    Feedback.play(.slide)
                    withAnimation(.easeInOut(duration: 0.35)) { step = 2 }
                }
                .buttonStyle(ChunkyButtonStyle(fill: picked.isEmpty ? T.line : T.primary, shadow: !picked.isEmpty))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 24).fill(T.surface))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(T.outline, lineWidth: 2.5))
            .padding(16)
        }
    }

    private func idleWobble() {
        guard !reduceMotion else { return }
        Task { @MainActor in
            while !hatched {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if hatched || taps > 0 { continue }
                withAnimation(.easeInOut(duration: 0.12)) { wobble = -5 }
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.easeInOut(duration: 0.12)) { wobble = 5 }
                try? await Task.sleep(nanoseconds: 120_000_000)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) { wobble = 0 }
            }
        }
    }

    private func tapEgg() {
        taps += 1
        Feedback.play(.knock)
        if taps >= 2 { Feedback.play(.crack) }
        let dir: Double = taps % 2 == 0 ? 1 : -1
        withAnimation(.easeOut(duration: 0.1)) { wobble = 12 * dir }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 110_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.3)) { wobble = 0 }
        }
        if taps >= 3 {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                Feedback.play(.hatch)
                withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) { hatched = true }
                withAnimation(.easeIn(duration: 0.7).delay(0.05)) { shellsFly = true }
                withAnimation(.easeOut(duration: 0.3)) { step = 1 }
            }
        }
    }

    private func toggleSeed(_ i: Int) {
        if let idx = picked.firstIndex(of: i) {
            picked.remove(at: idx)
            Feedback.play(.undo)
        } else if picked.count < 3 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { picked.append(i) }
            Feedback.play(.chip(picked.count * 2))
        } else {
            Feedback.play(.hmm)
        }
    }

    private func plantSeeds() {
        let store = Store(context: context)
        let isle = store.isle()
        isle.pipName = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Pip" : name.trimmingCharacters(in: .whitespaces)
        var owned = isle.owned
        owned.insert("beanie")
        isle.owned = owned
        let existing = Set(store.allHabits().map { $0.name })
        for i in picked {
            let s = seeds[i]
            guard !existing.contains(s.name) else { continue }
            let mask = s.name == "In bed by 11" ? 0b0011111 : 127
            store.addHabit(name: s.name, colorIndex: s.color, target: s.target, daysMask: mask, time: s.time, minutes: s.minutes)
        }
        store.save()
    }

    private func finish() {
        let store = Store(context: context)
        store.settings().onboarded = true
        store.earn(20)
        store.save()
        Feedback.play(.celebrate)
    }
}

struct EggView: View {
    var cracks: Int

    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 160
            var c = ctx
            c.scaleBy(x: s, y: s)
            let ink = T.pipInk
            var nest = Path()
            nest.addEllipse(in: CGRect(x: 16, y: 174, width: 128, height: 24))
            c.fill(nest, with: .color(Color(hex: 0x8A5A3B)))
            c.stroke(nest, with: .color(ink), lineWidth: 2.5)
            var egg = Path()
            egg.move(to: CGPoint(x: 80, y: 12))
            egg.addCurve(to: CGPoint(x: 146, y: 120), control1: CGPoint(x: 122, y: 12), control2: CGPoint(x: 146, y: 80))
            egg.addCurve(to: CGPoint(x: 80, y: 184), control1: CGPoint(x: 146, y: 160), control2: CGPoint(x: 118, y: 184))
            egg.addCurve(to: CGPoint(x: 14, y: 120), control1: CGPoint(x: 42, y: 184), control2: CGPoint(x: 14, y: 160))
            egg.addCurve(to: CGPoint(x: 80, y: 12), control1: CGPoint(x: 14, y: 80), control2: CGPoint(x: 38, y: 12))
            c.fill(egg, with: .color(Color(hex: 0xFFF6E4)))
            c.stroke(egg, with: .color(ink), lineWidth: 3.5)
            for (x, y, r, col) in [(56.0, 70.0, 7.0, UInt32(0xFFB4A2)), (104, 100, 9, 0xB8A4F5), (64, 140, 6, 0x8FD0F0), (108, 150, 5, 0x7CCB6B)] {
                c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: col)))
            }
            let crack = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            if cracks >= 1 {
                var p = Path()
                p.move(to: CGPoint(x: 50, y: 96)); p.addLine(to: CGPoint(x: 64, y: 108))
                p.addLine(to: CGPoint(x: 74, y: 94)); p.addLine(to: CGPoint(x: 86, y: 110))
                c.stroke(p, with: .color(ink), style: crack)
            }
            if cracks >= 2 {
                var p = Path()
                p.move(to: CGPoint(x: 86, y: 110)); p.addLine(to: CGPoint(x: 98, y: 98))
                p.addLine(to: CGPoint(x: 112, y: 112)); p.addLine(to: CGPoint(x: 124, y: 100))
                p.move(to: CGPoint(x: 74, y: 94)); p.addLine(to: CGPoint(x: 70, y: 80))
                p.move(to: CGPoint(x: 98, y: 98)); p.addLine(to: CGPoint(x: 102, y: 84))
                c.stroke(p, with: .color(ink), style: crack)
            }
        }
    }
}

struct EggHalf: View {
    var left: Bool
    var body: some View {
        Canvas { ctx, size in
            var p = Path()
            if left {
                p.move(to: CGPoint(x: 70, y: 10))
                p.addCurve(to: CGPoint(x: 10, y: 90), control1: CGPoint(x: 30, y: 10), control2: CGPoint(x: 10, y: 60))
                p.addLine(to: CGPoint(x: 40, y: 70)); p.addLine(to: CGPoint(x: 55, y: 84)); p.addLine(to: CGPoint(x: 70, y: 66))
            } else {
                p.move(to: CGPoint(x: 10, y: 10))
                p.addCurve(to: CGPoint(x: 70, y: 90), control1: CGPoint(x: 50, y: 10), control2: CGPoint(x: 70, y: 60))
                p.addLine(to: CGPoint(x: 44, y: 72)); p.addLine(to: CGPoint(x: 30, y: 86)); p.addLine(to: CGPoint(x: 10, y: 68))
            }
            p.closeSubpath()
            ctx.fill(p, with: .color(Color(hex: 0xFFF6E4)))
            ctx.stroke(p, with: .color(T.pipInk), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        }
        .frame(width: 80, height: 100)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Calendar, then notifications. Each gets Isle's own explainer before the iOS prompt.
struct PermissionsStage: View {
    var onDone: () -> Void
    @Environment(\.modelContext) private var context
    @State private var page = 0
    @State private var style = "gentle"

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 10)
            if page == 0 {
                PipView(mood: .happy, size: 130)
                Text("Show your calendar in Isle?").font(.isle(.title, .heavy)).foregroundStyle(T.ink).multilineTextAlignment(.center)
                Text("Pip plans around your real day, so it never fills a slot you're already busy in.")
                    .font(.isle(.subheadline, .semibold)).foregroundStyle(T.muted).multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 8) {
                    point("Only reads events, never changes them")
                    point("Stays on your phone")
                    point("Turn it off any time in Settings")
                }
                .card()
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                PipView(mood: .normal, size: 130)
                Text("How chatty should Pip be?").font(.isle(.title, .heavy)).foregroundStyle(T.ink).multilineTextAlignment(.center)
                Text("Pip never nags or guilt-trips. You can change this any time.")
                    .font(.isle(.subheadline, .semibold)).foregroundStyle(T.muted).multilineTextAlignment(.center)
                VStack(spacing: 8) {
                    styleRow("gentle", "Gentle", "Up to 3 a day. Only things with a time.")
                    styleRow("normal", "Normal", "Timed things, plus a nudge for habits.")
                    styleRow("essentials", "Only the essentials", "Tasks with a start time and Focus.")
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            Spacer()
            Button(page == 0 ? "Connect my calendar" : "Turn on notifications") { primary() }
                .buttonStyle(ChunkyButtonStyle())
            Button("Not now") { skip() }
                .font(.isle(.subheadline)).foregroundStyle(T.muted)
                .frame(minHeight: 44)
        }
        .padding(20)
    }

    private func point(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark").font(.system(size: 14, weight: .black)).foregroundStyle(T.good)
            Text(text).font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink)
            Spacer(minLength: 0)
        }
    }

    private func styleRow(_ id: String, _ name: String, _ desc: String) -> some View {
        let on = style == id
        return Button {
            Feedback.play(.tap)
            style = id
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.isle(.headline)).foregroundStyle(T.ink)
                Text(desc).font(.isle(.caption, .semibold)).foregroundStyle(T.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(on ? T.surface : T.surface.opacity(0.5)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(on ? T.outline : T.line, lineWidth: on ? 2.5 : 2))
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func primary() {
        Feedback.play(.tap)
        Task { @MainActor in
            let store = Store(context: context)
            if page == 0 {
                let ok = await CalendarService.shared.requestAccess()
                store.settings().calendarOn = ok
                store.save()
                Feedback.play(ok ? .tick : .undo)
                withAnimation(.easeInOut(duration: 0.35)) { page = 1 }
            } else {
                let ok = await IsleNotifications.requestAuthorization()
                let s = store.settings()
                s.notificationsOn = ok
                s.notifStyle = style
                store.save()
                onDone()
            }
        }
    }

    private func skip() {
        Feedback.play(.tap)
        if page == 0 {
            withAnimation(.easeInOut(duration: 0.35)) { page = 1 }
        } else {
            onDone()
        }
    }
}
