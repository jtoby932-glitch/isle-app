import SwiftUI
import SwiftData

struct ShopItem: Identifiable {
    let id: String
    let name: String
    let price: Int
    let level: Int
    let tint: UInt32
    let icon: String
    let note: String?
}

enum ShopCatalog {
    static let outfits: [ShopItem] = [
        ShopItem(id: "beanie", name: "Cosy beanie", price: 0, level: 0, tint: 0xDCD3FC, icon: "graduationcap.fill", note: nil),
        ShopItem(id: "crown", name: "Flower crown", price: 120, level: 0, tint: 0xFFD6E0, icon: "camera.macro", note: nil),
        ShopItem(id: "scarf", name: "Tiny scarf", price: 80, level: 0, tint: 0xFFD2BF, icon: "wind", note: nil)
    ]
    static let decor: [ShopItem] = [
        ShopItem(id: "bench", name: "Bench", price: 0, level: 0, tint: 0xF1E1CF, icon: "chair.lounge.fill", note: "Built in Focus"),
        ShopItem(id: "lantern", name: "Lantern", price: 60, level: 0, tint: 0xFFF0BF, icon: "lightbulb.fill", note: nil),
        ShopItem(id: "hammock", name: "Hammock", price: 150, level: 3, tint: 0xD6EFFA, icon: "bed.double.fill", note: nil),
        ShopItem(id: "lighthouse", name: "Lighthouse", price: 300, level: 5, tint: 0xFFD6E0, icon: "light.beacon.max.fill", note: nil)
    ]
    static let colors: [ShopItem] = [
        ShopItem(id: "color0", name: "Coral Pip", price: 0, level: 0, tint: 0xFF9C7A, icon: "circle.fill", note: nil),
        ShopItem(id: "color1", name: "Sky Pip", price: 100, level: 2, tint: 0x8FD0F0, icon: "circle.fill", note: nil),
        ShopItem(id: "color2", name: "Lilac Pip", price: 100, level: 3, tint: 0xB8A4F5, icon: "circle.fill", note: nil),
        ShopItem(id: "color3", name: "Sunny Pip", price: 150, level: 4, tint: 0xFFD45C, icon: "circle.fill", note: nil)
    ]
}

struct ShopView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var isles: [IsleState]
    @Query private var tasks: [TaskItem]
    @Query private var logs: [HabitLog]

    @State private var tab = 0
    @State private var bought: String? = nil
    @State private var denied: String? = nil

    private var store: Store { Store(context: context) }

    struct Quest: Identifiable {
        let id: String
        let name: String
        let have: Int
        let need: Int
        let reward: Int
    }

    private var quests: [Quest] {
        let ws = Day.weekStart(Day.today)
        let week = Set(Day.week(ws))
        let ticks = tasks.filter { $0.doneDayKey.map { week.contains($0) } ?? false }.count + logs.filter { week.contains($0.dayKey) }.count
        let isle = isles.first
        let planned = isle?.plannedWeeks.contains(ws) ?? false || isle?.plannedWeeks.contains(Day.add(ws, days: 7)) ?? false
        return [
            Quest(id: "q-ticks-\(ws)", name: "Tick off 15 things", have: min(15, ticks), need: 15, reward: 30),
            Quest(id: "q-plan-\(ws)", name: "Plan your week", have: planned ? 1 : 0, need: 1, reward: 20),
            Quest(id: "q-focus-\(ws)", name: "Finish 2 Focus sessions", have: min(2, focusThisWeek), need: 2, reward: 40)
        ]
    }

    @AppStorage("isle.focusWeek") private var focusWeek = 0
    @AppStorage("isle.focusWeekBase") private var focusWeekBase = 0

    private var focusThisWeek: Int {
        let ws = Day.weekStart(Day.today)
        let total = isles.first?.focusSessions ?? 0
        if focusWeek != ws { return 0 }
        return max(0, total - focusWeekBase)
    }

    var body: some View {
        let isle = isles.first
        let level = Rewards.level(forGrowth: isle?.growth ?? 0)
        let progress = Rewards.progress(forGrowth: isle?.growth ?? 0)
        ScrollView {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Button { dismiss() } label: { Image(systemName: "chevron.down") }
                        .buttonStyle(IconButtonStyle()).accessibilityLabel("Close")
                    Text("Shell Shop").font(.isle(.title, .heavy)).foregroundStyle(T.ink)
                    Spacer()
                    ShellBadge(count: isle?.shells ?? 0)
                }

                HStack(spacing: 8) {
                    ForEach(quests) { q in questCard(q, claimed: isle?.claimed.contains(q.id) ?? false) }
                }

                HStack(spacing: 12) {
                    PipView(mood: bought != nil ? .cheer : .happy, size: 104, colorIndex: isle?.bodyColorIndex ?? 0, outfit: isle?.outfit ?? "none")
                        .frame(width: 112, height: 112)
                        .background(Circle().fill(T.sky))
                        .overlay(Circle().strokeBorder(T.outline, lineWidth: 2))
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(isle?.pipName ?? "Pip") · Level \(level)").font(.isle(.title3, .heavy)).foregroundStyle(T.ink)
                        IsleProgressBar(value: Double(progress.have) / Double(max(1, progress.need)), color: Color(hex: 0xB8A4F5), height: 12)
                        Text("\(progress.have) / \(progress.need) growth to level \(level + 1)").font(.isle(.caption, .heavy)).foregroundStyle(T.muted)
                        Text("Wearing: \(outfitName(isle?.outfit ?? "none"))").font(.isle(.footnote, .heavy)).foregroundStyle(T.ink)
                    }
                }
                .card()

                SegmentedPicker(options: [(0, "Outfits"), (1, "Isle decor"), (2, "Pip colours")], selection: $tab)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(items) { item in itemCard(item, level: level, isle: isle) }
                }
            }
            .padding(16)
        }
        .screenBackground()
        .onAppear {
            let ws = Day.weekStart(Day.today)
            if focusWeek != ws {
                focusWeek = ws
                focusWeekBase = isles.first?.focusSessions ?? 0
            }
        }
    }

    private var items: [ShopItem] {
        switch tab {
        case 0: return ShopCatalog.outfits
        case 1: return ShopCatalog.decor
        default: return ShopCatalog.colors
        }
    }

    private func outfitName(_ id: String) -> String {
        ShopCatalog.outfits.first { $0.id == id }?.name ?? "nothing"
    }

    private func questCard(_ q: Quest, claimed: Bool) -> some View {
        let complete = q.have >= q.need
        return VStack(alignment: .leading, spacing: 6) {
            Text(q.name).font(.isle(.caption, .heavy)).foregroundStyle(T.ink).lineLimit(2).frame(minHeight: 30, alignment: .topLeading)
            IsleProgressBar(value: Double(q.have) / Double(q.need), color: complete ? T.primary : T.good)
            if complete && !claimed {
                Button("Claim +\(q.reward)") {
                    let isle = store.isle()
                    var c = isle.claimed
                    c.insert(q.id)
                    isle.claimed = c
                    store.earn(q.reward)
                    store.save()
                    Feedback.play(.shell)
                    Feedback.play(.tick)
                }
                .buttonStyle(PillButtonStyle(fill: T.primary, textColor: T.primaryInk, height: 30))
            } else {
                Text(claimed ? "Claimed" : "\(q.have) / \(q.need)").font(.isle(.caption, .heavy)).foregroundStyle(T.muted).frame(height: 30)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 8)
    }

    private func isOwned(_ item: ShopItem, isle: IsleState?) -> Bool {
        if item.price == 0 && item.level == 0 && item.note == nil { return true }
        return isle?.owned.contains(item.id) ?? false
    }

    private func itemCard(_ item: ShopItem, level: Int, isle: IsleState?) -> some View {
        let owned = isOwned(item, isle: isle)
        let locked = !owned && level < item.level
        let wearing: Bool = {
            if tab == 0 { return isle?.outfit == item.id }
            if tab == 2 { return "color\(isle?.bodyColorIndex ?? 0)" == item.id }
            return false
        }()
        let canAfford = (isle?.shells ?? 0) >= item.price
        return VStack(spacing: 8) {
            Image(systemName: item.icon)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(tab == 2 ? Color(hex: item.tint) : T.pipInk)
                .frame(width: 60, height: 60)
                .background(RoundedRectangle(cornerRadius: 16).fill(tab == 2 ? Color.white : Color(hex: item.tint)))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(T.outline, lineWidth: 2))
                .opacity(locked ? 0.5 : 1)
            Text(item.name).font(.isle(.subheadline, .heavy)).foregroundStyle(T.ink).multilineTextAlignment(.center)
            Button {
                act(item, owned: owned, locked: locked, wearing: wearing, canAfford: canAfford)
            } label: {
                HStack(spacing: 4) {
                    if locked { Image(systemName: "lock.fill").font(.system(size: 11, weight: .black)) }
                    if !owned && !locked { ShellIcon(size: 14) }
                    Text(buttonText(item, owned: owned, locked: locked, wearing: wearing))
                }
                .font(.isle(.footnote, .heavy))
                .foregroundStyle(T.primaryInk)
                .padding(.horizontal, 12)
                .frame(minWidth: 96, minHeight: 34)
                .background(Capsule().fill(buttonFill(owned: owned, locked: locked, wearing: wearing, canAfford: canAfford)))
                .overlay(Capsule().strokeBorder(T.outline, lineWidth: 2))
            }
            .buttonStyle(PressStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 18).fill(locked ? T.surface2 : T.surface))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(T.outline, style: StrokeStyle(lineWidth: 2, dash: locked ? [5, 4] : [])))
        .scaleEffect(bought == item.id ? 1.06 : 1)
        .offset(x: denied == item.id ? 4 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.4), value: bought)
        .animation(.spring(response: 0.15, dampingFraction: 0.2), value: denied)
    }

    private func buttonText(_ item: ShopItem, owned: Bool, locked: Bool, wearing: Bool) -> String {
        if locked { return "Level \(item.level)" }
        if owned {
            if tab == 1 { return item.note ?? "On your isle" }
            return wearing ? "Wearing" : "Use"
        }
        return "\(item.price)"
    }

    private func buttonFill(owned: Bool, locked: Bool, wearing: Bool, canAfford: Bool) -> Color {
        if locked { return T.surface }
        if owned { return wearing || tab == 1 ? T.goodSoft : T.surface }
        return canAfford ? T.primary : T.line
    }

    private func act(_ item: ShopItem, owned: Bool, locked: Bool, wearing: Bool, canAfford: Bool) {
        let isle = store.isle()
        if locked || (!owned && !canAfford) {
            Feedback.play(.hmm)
            denied = item.id
            Task { @MainActor in try? await Task.sleep(nanoseconds: 300_000_000); denied = nil }
            if !locked { app.showToast("Need \(item.price - isle.shells) more shells. Tick things off to earn them.") }
            return
        }
        if !owned {
            var o = isle.owned
            o.insert(item.id)
            isle.owned = o
            isle.shells -= item.price
            Feedback.play(.shell)
            Feedback.play(.celebrate, after: 0.15)
            bought = item.id
            Task { @MainActor in try? await Task.sleep(nanoseconds: 900_000_000); bought = nil }
        }
        switch tab {
        case 0:
            isle.outfit = (wearing && owned) ? "none" : item.id
            Feedback.play(isle.outfit == "none" ? .undo : .chirp)
        case 2:
            isle.bodyColorIndex = Int(item.id.dropFirst(5)) ?? 0
            Feedback.play(.chirp)
        default:
            if owned { Feedback.play(.tap) }
        }
        store.save()
    }
}
