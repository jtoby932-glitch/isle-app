import SwiftUI
import SwiftData

struct CheckinView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var isles: [IsleState]

    @State private var level = 2
    @State private var moods: Set<String> = []

    private let levels: [(String, Double, UInt32)] = [("Empty", 0.1, 0xFF8A80), ("Low", 0.3, 0xFFB86B), ("Okay", 0.55, 0xFFD45C), ("Good", 0.78, 0xA6DE8F), ("Full", 1, 0x7CCB6B)]
    private let moodOptions = ["Tired", "Anxious", "Calm", "Busy brain", "Excited", "Sore", "Focused", "Low"]

    private var card: (title: String, body: String, tags: [String], cta: String, fill: Color) {
        switch level {
        case 0: return ("Rest-day mode", "Today is just your easiest habits. Every task moves to later this week, and streaks are safe.", ["All tasks moved", "Streaks safe"], "Rest up, \(pipName)", T.lilac)
        case 1: return ("Low-battery mode", "Big tasks move to later this week. Habits with a low-battery version show that instead, for double shells.", ["Big tasks moved", "2× shells for habits"], "Sounds good, \(pipName)", T.lilac)
        case 2: return ("Normal plan", "Your day stays as planned. One thing at a time.", ["Nothing moves"], "Let's go", T.surface)
        case 3: return ("Good day for it", "You've got room for more. Pull something from the Inbox if you fancy it.", ["Room to spare"], "Let's go", T.goodSoft)
        default: return ("Full battery!", "Big energy. A good day for the task you've been putting off.", ["Go for the big one"], "Let's go", T.goodSoft)
        }
    }

    private var pipName: String { isles.first?.pipName ?? "Pip" }

    var body: some View {
        let c = card
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .buttonStyle(IconButtonStyle()).accessibilityLabel("Skip check-in")
                    Spacer()
                    Text("Morning check-in · \(Fmt.clock(Day.minuteOfDay))").font(.isle(.subheadline, .heavy)).foregroundStyle(T.muted)
                }
                HStack(alignment: .center) {
                    Text("How's your battery today?").font(.isle(.largeTitle, .heavy)).foregroundStyle(T.ink)
                    Spacer(minLength: 0)
                    PipView(mood: level <= 1 ? .sleepy : (level == 2 ? .normal : (level == 3 ? .happy : .cheer)), size: 104,
                            colorIndex: isles.first?.bodyColorIndex ?? 0, outfit: isles.first?.outfit ?? "none")
                }

                HStack(spacing: 7) {
                    ForEach(0..<levels.count, id: \.self) { i in
                        let on = level == i
                        Button {
                            if level != i {
                                Feedback.play(.chip(i * 2))
                                if i <= 0 { Feedback.play(.sleepy, after: 0.1) }
                                if i >= 3 { Feedback.play(.chirp, after: 0.2) }
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { level = i }
                        } label: {
                            VStack(spacing: 8) {
                                BatteryIcon(fill: levels[i].1, color: Color(hex: levels[i].2), animate: on)
                                Text(levels[i].0).font(.isle(.caption, .heavy)).foregroundStyle(T.ink)
                            }
                            .frame(maxWidth: .infinity, minHeight: 92)
                            .background(RoundedRectangle(cornerRadius: 16).fill(on ? T.primarySoft : T.surface))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(T.outline, lineWidth: 2))
                            .background(RoundedRectangle(cornerRadius: 16).fill(T.outline).offset(y: on ? 4 : 0))
                            .offset(y: on ? -4 : 0)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(levels[i].0)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Anything else going on?").font(.isle(.headline)).foregroundStyle(T.ink)
                    FlowLayout(spacing: 7) {
                        ForEach(moodOptions, id: \.self) { m in
                            ToggleChip(text: m, on: moods.contains(m), onFill: Color(hex: 0xFFB4A2)) {
                                if moods.contains(m) { moods.remove(m); Feedback.play(.undo) } else { moods.insert(m); Feedback.play(.tick) }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(c.title).font(.isle(.title3, .heavy))
                    Text(c.body + (moods.contains("Anxious") ? " Take a breather between things today." : ""))
                        .font(.isle(.subheadline, .semibold))
                    FlowLayout(spacing: 6) {
                        ForEach(c.tags, id: \.self) { t in Tag(text: t, fill: T.surface) }
                    }
                }
                .foregroundStyle(T.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card(fill: c.fill, shadow: true)
                .animation(.easeOut(duration: 0.25), value: level)

                Button(c.cta) {
                    let message = Store(context: context).applyCheckin(battery: level, moods: Array(moods))
                    Feedback.play(level >= 3 ? .celebrate : .tick)
                    app.showToast(message)
                    dismiss()
                }
                .buttonStyle(ChunkyButtonStyle())

                Button("Keep my normal plan") {
                    _ = Store(context: context).applyCheckin(battery: 2, moods: Array(moods))
                    dismiss()
                }
                .font(.isle(.subheadline)).foregroundStyle(T.muted)
                .frame(minHeight: 44)
            }
            .padding(16)
        }
        .screenBackground()
    }
}

struct BatteryIcon: View {
    var fill: Double
    var color: Color
    var animate: Bool
    @State private var shown: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 1.5).fill(T.pipInk).frame(width: 8, height: 4)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4).fill(Color.white)
                RoundedRectangle(cornerRadius: 2).fill(color)
                    .frame(width: 12, height: 23 * shown)
                    .padding(.bottom, 3)
                RoundedRectangle(cornerRadius: 4).strokeBorder(T.pipInk, lineWidth: 2.5)
            }
            .frame(width: 20, height: 30)
        }
        .onAppear { shown = fill }
        .onChange(of: animate) { _, on in
            guard on else { return }
            shown = 0
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { shown = fill }
        }
        .accessibilityHidden(true)
    }
}
