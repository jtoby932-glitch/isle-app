import SwiftUI
import SwiftData

struct FocusView: View {
    var task: TaskItem?
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var isles: [IsleState]

    @State private var total: TimeInterval = 25 * 60
    @State private var endAt: Date? = nil
    @State private var pausedLeft: TimeInterval? = nil
    @State private var finished = false
    @State private var sound = "rain"
    @State private var started = false
    @State private var glow = false

    private let sounds: [(String, String)] = [("rain", "Rain"), ("waves", "Waves"), ("cafe", "Café"), ("off", "Off")]
    private static let builds = ["bench", "lantern", "hammock", "lighthouse"]

    private func left(at now: Date) -> TimeInterval {
        if finished { return 0 }
        if let p = pausedLeft { return p }
        guard let e = endAt else { return total }
        return max(0, e.timeIntervalSince(now))
    }

    private var running: Bool { started && pausedLeft == nil && !finished }
    private var buildName: String {
        let owned = isles.first?.owned ?? []
        return FocusView.builds.first { !owned.contains($0) } ?? "flowerbed"
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let l = left(at: tl.date)
            let frac = total > 0 ? 1 - l / total : 1
            ZStack {
                T.night.ignoresSafeArea()
                StarField()
                VStack(spacing: 18) {
                    HStack(spacing: 10) {
                        Button { leave() } label: { Image(systemName: "xmark").foregroundStyle(T.cream) }
                            .buttonStyle(IconButtonStyle(fill: Color.white.opacity(0.08)))
                            .accessibilityLabel("Leave focus")
                        VStack(alignment: .leading, spacing: 0) {
                            Text("FOCUSING ON").font(.isle(.caption, .heavy)).foregroundStyle(Color(hex: 0xBDB6E6))
                            Text(task?.title ?? "Free focus").font(.isle(.title3, .heavy)).foregroundStyle(T.cream).lineLimit(1)
                        }
                        Spacer()
                    }

                    ZStack {
                        Circle().fill(Color(hex: 0xB8A4F5).opacity(glow ? 0.35 : 0.18)).blur(radius: 40).padding(30)
                        Circle().stroke(Color(hex: 0x3A3470), lineWidth: 18)
                        Circle()
                            .trim(from: 0, to: frac)
                            .stroke(T.primary, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: frac)
                        VStack(spacing: 0) {
                            PipView(mood: finished ? .cheer : (running ? .sleepy : .normal), size: 96,
                                    colorIndex: isles.first?.bodyColorIndex ?? 0, outfit: isles.first?.outfit ?? "none")
                            Text(clock(l)).font(.system(size: 50, weight: .semibold, design: .rounded)).monospacedDigit()
                                .foregroundStyle(T.cream)
                            Text(finished ? "done" : (running ? "left" : (started ? "paused" : "ready")))
                                .font(.isle(.subheadline, .heavy)).foregroundStyle(Color(hex: 0xBDB6E6))
                        }
                    }
                    .frame(width: 290, height: 290)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(Int(l) / 60) minutes \(Int(l) % 60) seconds left")

                    if finished {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(buildDisplay) built! +\(Rewards.focus) shells").font(.isle(.title3, .heavy))
                            Text("Take five. \(isles.first?.pipName ?? "Pip")'s stretching too.").font(.isle(.subheadline, .heavy))
                        }
                        .foregroundStyle(T.primaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(fill: T.good)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "hammer.fill").font(.system(size: 20))
                                .foregroundStyle(T.primary)
                                .rotationEffect(.degrees(running && glow ? -28 : 0), anchor: .bottomTrailing)
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(isles.first?.pipName ?? "Pip") is building a \(buildDisplay.lowercased()) for your isle")
                                    .font(.isle(.subheadline, .heavy)).foregroundStyle(T.cream)
                                IsleProgressBar(value: frac, color: T.good, track: Color(hex: 0x24204A))
                            }
                            Text("\(Int(frac * 100))%").font(.isle(.subheadline, .heavy)).foregroundStyle(T.cream).monospacedDigit()
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 18).fill(Color(hex: 0x322D66)))
                        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color(hex: 0x4A4488), lineWidth: 2))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text(started ? "SOUND" : "SOUND · TAP ONE TO HEAR IT").font(.isle(.caption, .heavy)).foregroundStyle(Color(hex: 0xBDB6E6))
                        HStack(spacing: 6) {
                            ForEach(0..<sounds.count, id: \.self) { i in
                                let s = sounds[i]
                                let on = sound == s.0
                                Button {
                                    Feedback.play(.tap)
                                    sound = s.0
                                    if running { SoundEngine.shared.startAmbient(s.0) }
                                    else if !finished { previewAmbient(s.0) }
                                } label: {
                                    Text(s.1).font(.isle(.subheadline, .heavy))
                                        .foregroundStyle(on ? T.primaryInk : T.cream)
                                        .frame(maxWidth: .infinity, minHeight: 40)
                                        .background(Capsule().fill(on ? T.cream : Color.clear))
                                        .overlay(Capsule().strokeBorder(on ? T.cream : Color(hex: 0x5A5498), lineWidth: 2))
                                }
                                .buttonStyle(PressStyle())
                                .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }

                    HStack(spacing: 18) {
                        roundButton("−5") { adjust(-300) }
                        Button { toggle() } label: {
                            Image(systemName: finished ? "arrow.counterclockwise" : (running ? "pause.fill" : "play.fill"))
                                .font(.system(size: 30, weight: .black))
                                .foregroundStyle(T.primaryInk)
                                .frame(width: 84, height: 84)
                                .background(Circle().fill(T.primary))
                                .overlay(Circle().strokeBorder(T.pipInk, lineWidth: 2.5))
                                .background(Circle().fill(Color.black.opacity(0.4)).offset(y: 4))
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel(finished ? "Another session" : (running ? "Pause" : "Start"))
                        roundButton("+5") { adjust(300) }
                    }

                    if started && !finished {
                        Button("Finish early") { finish() }
                            .font(.isle(.subheadline, .heavy)).foregroundStyle(T.cream).underline()
                            .frame(minHeight: 44)
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
            }
            .onChange(of: l <= 0 && started && !finished) { _, done in
                if done { finish() }
            }
        }
        .onAppear {
            if let t = task { total = TimeInterval(min(50, max(15, t.minutes)) * 60) }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { glow = true }
        }
        .onDisappear {
            SoundEngine.shared.stopAmbient()
            IsleNotifications.cancelFocusEnd()
        }
    }

    private var buildDisplay: String {
        switch buildName {
        case "bench": return "Bench"
        case "lantern": return "Lantern"
        case "hammock": return "Hammock"
        case "lighthouse": return "Lighthouse"
        default: return "Flowerbed"
        }
    }

    private func roundButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.isle(.headline)).foregroundStyle(T.cream)
                .frame(width: 56, height: 56)
                .overlay(Circle().strokeBorder(T.cream, lineWidth: 2))
        }
        .buttonStyle(PressStyle())
        .disabled(finished)
        .accessibilityLabel(label == "+5" ? "Add 5 minutes" : "Take 5 minutes off")
    }

    private func clock(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    private func previewAmbient(_ kind: String) {
        if kind == "off" { SoundEngine.shared.stopAmbient() } else { SoundEngine.shared.startAmbient(kind) }
    }

    private func toggle() {
        if finished {
            Feedback.play(.bowl)
            finished = false
            started = false
            pausedLeft = nil
            endAt = nil
            start()
            return
        }
        if !started {
            start()
        } else if let p = pausedLeft {
            Feedback.play(.resume)
            endAt = Date().addingTimeInterval(p)
            pausedLeft = nil
            SoundEngine.shared.startAmbient(sound)
            IsleNotifications.scheduleFocusEnd(at: endAt!, title: task?.title ?? "your focus")
        } else {
            Feedback.play(.pause)
            pausedLeft = left(at: Date())
            SoundEngine.shared.stopAmbient()
            IsleNotifications.cancelFocusEnd()
        }
    }

    private func start() {
        Feedback.play(.bowl)
        started = true
        endAt = Date().addingTimeInterval(total)
        SoundEngine.shared.startAmbient(sound)
        IsleNotifications.scheduleFocusEnd(at: endAt!, title: task?.title ?? "your focus")
    }

    private func adjust(_ delta: TimeInterval) {
        Feedback.play(.chip(delta > 0 ? 6 : 1))
        if !started {
            total = max(5 * 60, total + delta)
            return
        }
        let current = left(at: Date())
        let newLeft = max(60, current + delta)
        total = max(total + (newLeft - current), newLeft)
        if pausedLeft != nil { pausedLeft = newLeft } else {
            endAt = Date().addingTimeInterval(newLeft)
            IsleNotifications.scheduleFocusEnd(at: endAt!, title: task?.title ?? "your focus")
        }
    }

    private func finish() {
        guard !finished else { return }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { finished = true }
        SoundEngine.shared.stopAmbient()
        IsleNotifications.cancelFocusEnd()
        Feedback.play(.bowl)
        Feedback.play(.celebrate, after: 0.9)
        let store = Store(context: context)
        let isle = store.isle()
        isle.focusSessions += 1
        var owned = isle.owned
        owned.insert(buildName)
        isle.owned = owned
        store.earn(Rewards.focus)
        store.save()
    }

    private func leave() {
        if started && !finished {
            Feedback.play(.undo)
        }
        SoundEngine.shared.stopAmbient()
        dismiss()
    }
}

struct StarField: View {
    @State private var twinkle = false
    private let stars: [(CGFloat, CGFloat, CGFloat, Double)] = (0..<26).map { i in
        let x = CGFloat((i * 137) % 100) / 100
        let y = CGFloat((i * 71 + 13) % 100) / 100
        return (x, y * 0.7, CGFloat(2 + i % 2), Double(i % 5) * 0.4)
    }

    var body: some View {
        GeometryReader { g in
            ForEach(0..<stars.count, id: \.self) { i in
                let s = stars[i]
                Circle().fill(T.cream)
                    .frame(width: s.2, height: s.2)
                    .position(x: s.0 * g.size.width, y: s.1 * g.size.height)
                    .opacity(twinkle ? 0.9 : 0.25)
                    .animation(.easeInOut(duration: 3 + s.3).repeatForever(autoreverses: true).delay(s.3), value: twinkle)
            }
        }
        .ignoresSafeArea()
        .onAppear { twinkle = true }
        .accessibilityHidden(true)
    }
}
