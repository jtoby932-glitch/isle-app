import SwiftUI
import SwiftData

/// Empty first day: one-tap starter habits.
struct StarterSeedsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query private var habits: [Habit]

    struct Idea: Identifiable {
        let id: String
        let name: String
        let sub: String
        let color: Int
        let target: Int
        let time: Int?
        let minutes: Int
    }

    let ideas: [Idea] = [
        Idea(id: "read", name: "Read 10 pages", sub: "Habit · every evening · 15m", color: 1, target: 7, time: 21 * 60, minutes: 15),
        Idea(id: "walk", name: "Walk outside", sub: "Habit · 3× a week · 30m", color: 2, target: 3, time: nil, minutes: 30),
        Idea(id: "water", name: "Drink water with lunch", sub: "Habit · daily · 1m", color: 6, target: 7, time: 12 * 60 + 30, minutes: 1),
        Idea(id: "bed", name: "In bed by 11", sub: "Habit · weeknights", color: 3, target: 5, time: 22 * 60 + 30, minutes: 30)
    ]

    var body: some View {
        VStack(spacing: 12) {
            VStack(spacing: 6) {
                PipView(mood: .normal, size: 96)
                Text("Your isle is a bit bare…").font(.isle(.title3, .heavy)).foregroundStyle(T.ink)
                Text("Plant a couple of easy habits to start. Small ones stick best.")
                    .font(.isle(.subheadline, .semibold)).foregroundStyle(T.muted).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .card(padding: 14)

            SectionLabel(text: "Easy ones to start with")
            ForEach(ideas) { idea in
                let planted = habits.contains { $0.name == idea.name }
                Button {
                    guard !planted else { return }
                    let store = Store(context: context)
                    store.addHabit(name: idea.name, colorIndex: idea.color, target: idea.target,
                                   daysMask: idea.id == "bed" ? 0b0011111 : 127, time: idea.time, minutes: idea.minutes)
                    Feedback.play(.bloom(habits.count))
                    if habits.isEmpty { Feedback.play(.chirp, after: 0.25) }
                } label: {
                    HStack(spacing: 10) {
                        Rectangle().fill(T.habit(idea.color)).frame(width: 6)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(idea.name).font(.isle(.body, .heavy)).foregroundStyle(T.ink)
                            Text(idea.sub).font(.isle(.caption, .bold)).foregroundStyle(T.muted)
                        }
                        Spacer()
                        Text(planted ? "Planted" : "Plant")
                            .font(.isle(.caption, .heavy)).foregroundStyle(T.primaryInk)
                            .padding(.horizontal, 10).frame(height: 30)
                            .background(RoundedRectangle(cornerRadius: 10).fill(planted ? T.good : T.primary))
                            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(T.outline, lineWidth: 2))
                            .padding(.trailing, 10)
                    }
                    .frame(minHeight: 54)
                    .background(planted ? T.goodSoft : T.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(T.outline, style: StrokeStyle(lineWidth: 2, dash: planted ? [] : [5, 4])))
                }
                .buttonStyle(PressStyle())
            }
            HStack(spacing: 8) {
                Button("Type my own") { app.showQuickAdd = true }
                    .buttonStyle(ChunkyButtonStyle(fill: T.surface, height: 46, shadow: false))
                Button("Plan my week") { app.showSunday = true }
                    .buttonStyle(ChunkyButtonStyle(height: 46, shadow: false))
            }
        }
    }
}
