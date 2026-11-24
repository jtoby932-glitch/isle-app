import SwiftUI
import SwiftData

/// A real time grid for one day. Hold a task and drag to move it, hold its bottom
/// edge and drag to make it longer or shorter, tap an empty slot to add something there.
struct DayGridView: View {
    let day: Int
    /// Rows that have a start time. Untimed rows are shown elsewhere.
    let rows: [IsleDayRow]
    var onOpen: (IsleDayRow) -> Void
    var onToggle: (IsleDayRow) -> Void
    /// Called with the tapped minute of the day, snapped to 15 minutes.
    var onEmptyTap: (Int) -> Void

    @Environment(\.modelContext) private var context
    @GestureState private var live: DragState? = nil

    struct DragState: Equatable {
        var id: String
        var mode: Mode
        var delta: Int
    }

    enum Mode: Equatable { case move, resize }

    static let hourHeight: CGFloat = 64
    static let labelWidth: CGFloat = 42
    private let ppm: CGFloat = DayGridView.hourHeight / 60

    private struct Placed {
        let row: IsleDayRow
        let start: Int
        let end: Int
        var lane: Int = 0
        var lanes: Int = 1
    }

    // MARK: layout

    private var range: (start: Int, end: Int) {
        var lo = 7 * 60
        var hi = 22 * 60
        for r in rows {
            guard let s = r.start else { continue }
            lo = min(lo, (s / 60) * 60)
            hi = max(hi, min(24 * 60, ((s + max(15, r.minutes) + 59) / 60) * 60))
        }
        return (lo, hi)
    }

    /// Side-by-side lanes for blocks that overlap.
    private func layout() -> [Placed] {
        let items = rows.compactMap { r -> Placed? in
            guard let s = r.start else { return nil }
            return Placed(row: r, start: s, end: s + max(15, r.minutes))
        }
        .sorted { ($0.start, -$0.end) < ($1.start, -$1.end) }

        var result: [Placed] = []
        var cluster: [Int] = []
        var laneEnds: [Int] = []
        var clusterEnd = Int.min
        for var p in items {
            if !cluster.isEmpty && p.start >= clusterEnd {
                for i in cluster { result[i].lanes = laneEnds.count }
                cluster = []
                laneEnds = []
                clusterEnd = Int.min
            }
            if let free = laneEnds.firstIndex(where: { $0 <= p.start }) {
                p.lane = free
                laneEnds[free] = p.end
            } else {
                p.lane = laneEnds.count
                laneEnds.append(p.end)
            }
            clusterEnd = max(clusterEnd, p.end)
            result.append(p)
            cluster.append(result.count - 1)
        }
        for i in cluster { result[i].lanes = max(1, laneEnds.count) }
        return result
    }

    private func snap(_ translation: CGFloat) -> Int {
        Int((translation / ppm / 15).rounded()) * 15
    }

    // MARK: body

    var body: some View {
        let r = range
        let height = CGFloat(r.end - r.start) * ppm
        let placed = layout()
        GeometryReader { geo in
            let gridX = Self.labelWidth + 8
            let gridW = max(60, geo.size.width - gridX)
            ZStack(alignment: .topLeading) {
                // Empty space: tap to add at that time.
                Color.clear
                    .frame(width: gridW, height: height)
                    .contentShape(Rectangle())
                    .onTapGesture(coordinateSpace: .local) { point in
                        let minute = r.start + Int(point.y / ppm)
                        Feedback.play(.tap)
                        onEmptyTap(min(24 * 60 - 15, (minute / 15) * 15))
                    }
                    .offset(x: gridX)
                    .accessibilityLabel("Empty time. Tap to add something.")

                hourLines(r, gridX: gridX, gridW: gridW)

                if day == Day.today {
                    let now = Day.minuteOfDay
                    if now >= r.start && now <= r.end {
                        HStack(spacing: 0) {
                            NowDot()
                            Rectangle().fill(T.now).frame(height: 2)
                        }
                        .frame(width: gridW + 5)
                        .offset(x: gridX - 5, y: CGFloat(now - r.start) * ppm - 5)
                        .allowsHitTesting(false)
                    }
                }

                ForEach(placed, id: \.row.id) { p in
                    block(p, range: r, gridX: gridX, gridW: gridW)
                }
            }
            .frame(width: geo.size.width, height: height, alignment: .topLeading)
        }
        .frame(height: height)
        .onChange(of: live) { old, new in
            guard let new else { return }
            if old == nil {
                Feedback.play(.lift)
            } else if old?.delta != new.delta {
                if Feedback.hapticsOn { IsleHaptics.play(.light) }
            }
        }
    }

    private func hourLines(_ r: (start: Int, end: Int), gridX: CGFloat, gridW: CGFloat) -> some View {
        let hours = Array(stride(from: r.start / 60, through: r.end / 60, by: 1))
        return ZStack(alignment: .topLeading) {
            ForEach(hours, id: \.self) { h in
                let y = CGFloat(h * 60 - r.start) * ppm
                Text(Fmt.clock(min(h * 60, 23 * 60 + 59)))
                    .font(.isle(.caption2, .heavy))
                    .foregroundStyle(T.muted)
                    .frame(width: Self.labelWidth, alignment: .trailing)
                    .offset(y: y - 7)
                Rectangle().fill(T.line).frame(width: gridW, height: 1.5).offset(x: gridX, y: y)
                if h * 60 + 30 < r.end {
                    Rectangle().fill(T.line.opacity(0.45)).frame(width: gridW, height: 1).offset(x: gridX, y: y + 30 * ppm)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: blocks

    @ViewBuilder
    private func block(_ p: Placed, range r: (start: Int, end: Int), gridX: CGFloat, gridW: CGFloat) -> some View {
        let dragging = live?.id == p.row.id
        let moveDelta = dragging && live?.mode == .move ? (live?.delta ?? 0) : 0
        let sizeDelta = dragging && live?.mode == .resize ? (live?.delta ?? 0) : 0
        let start = min(max(0, p.start + moveDelta), 24 * 60 - 15)
        let minutes = max(15, (p.end - p.start) + sizeDelta)
        let laneW = gridW / CGFloat(p.lanes)
        let y = CGFloat(start - r.start) * ppm + 1
        let h = max(22, CGFloat(minutes) * ppm - 2)
        let task: TaskItem? = { if case .task(let t) = p.row.kind { return t } else { return nil } }()
        let canDrag = task != nil && !p.row.done

        let card = GridBlock(row: p.row, start: start, minutes: minutes, height: h, lifted: dragging,
                             canResize: canDrag && h >= 34, onToggle: { onToggle(p.row) })
            .frame(width: dragging ? gridW : max(24, laneW - 3), height: h)
            .contentShape(RoundedRectangle(cornerRadius: 10))

        Group {
            if let task, canDrag {
                card
                    .overlay(alignment: .bottom) {
                        if h >= 34 {
                            Color.clear
                                .frame(height: 18)
                                .contentShape(Rectangle())
                                .gesture(holdDrag(task: task, id: p.row.id, mode: .resize, from: p))
                                .accessibilityLabel("Resize \(p.row.title)")
                        }
                    }
                    // Hold wins first; a quick tap falls through to opening the task.
                    .gesture(holdDrag(task: task, id: p.row.id, mode: .move, from: p)
                        .exclusively(before: TapGesture().onEnded { onOpen(p.row) }))
                    .accessibilityHint("Hold and drag to move. Hold the bottom edge to change its length.")
            } else {
                card.onTapGesture {
                    guard !p.row.isEvent else { return }
                    onOpen(p.row)
                }
            }
        }
        .offset(x: gridX + (dragging ? 0 : CGFloat(p.lane) * laneW), y: y)
        .zIndex(dragging ? 10 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: dragging)
    }

    private func holdDrag(task: TaskItem, id: String, mode: Mode, from p: Placed) -> some Gesture {
        LongPressGesture(minimumDuration: mode == .move ? 0.28 : 0.12)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($live) { value, state, _ in
                if case .second(true, let drag) = value {
                    state = DragState(id: id, mode: mode, delta: snap(drag?.translation.height ?? 0))
                }
            }
            .onEnded { value in
                guard case .second(true, let drag?) = value else { return }
                let delta = snap(drag.translation.height)
                guard delta != 0 else { return }
                let store = Store(context: context)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    switch mode {
                    case .move:
                        store.setStart(task, p.start + delta)
                    case .resize:
                        let newLength = max(15, (p.end - p.start) + delta)
                        task.minutes = newLength
                        task.sizeRaw = TaskItem.size(for: newLength).rawValue
                        store.save()
                    }
                }
                Feedback.play(.place(Day.weekday(day)))
            }
    }
}

/// One block on the grid.
private struct GridBlock: View {
    let row: IsleDayRow
    let start: Int
    let minutes: Int
    let height: CGFloat
    let lifted: Bool
    let canResize: Bool
    var onToggle: () -> Void

    private var compact: Bool { height < 46 }

    var body: some View {
        HStack(alignment: compact ? .center : .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(row.color).frame(width: 4)
                .padding(.vertical, compact ? 4 : 0)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                    .font(.isle(compact ? .caption : .subheadline, .heavy))
                    .foregroundStyle(row.done ? T.muted : T.ink)
                    .strikethrough(row.done, color: T.muted)
                    .lineLimit(compact ? 1 : 2)
                if !compact || lifted {
                    Text("\(Fmt.clock(start))–\(Fmt.clock(start + minutes)) · \(Fmt.duration(minutes))")
                        .font(.isle(.caption2, .bold))
                        .foregroundStyle(lifted ? T.ink : T.muted)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if !row.isEvent {
                Button(action: onToggle) {
                    CheckCircle(done: row.done, size: compact ? 20 : 24)
                        .frame(width: 34, height: compact ? max(20, height - 4) : 34)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(row.done ? "Undo \(row.title)" : "Complete \(row.title)")
            }
        }
        .padding(.leading, 5)
        .padding(.trailing, 2)
        .padding(.vertical, compact ? 1 : 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(row.isEvent ? T.surface2 : T.surface)
                RoundedRectangle(cornerRadius: 10, style: .continuous).fill(row.done ? T.goodSoft.opacity(0.6) : row.color.opacity(row.isEvent ? 0.08 : 0.2))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(T.outline.opacity(lifted ? 1 : 0.7),
                              style: StrokeStyle(lineWidth: lifted ? 2.5 : 1.5, dash: row.isEvent ? [4, 3] : []))
        )
        .overlay(alignment: .bottom) {
            if canResize {
                Capsule().fill(T.muted.opacity(lifted ? 0.9 : 0.45)).frame(width: 24, height: 4).padding(.bottom, 3)
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(lifted ? 1.025 : 1)
        .shadow(color: .black.opacity(lifted ? 0.2 : 0), radius: lifted ? 10 : 0, y: lifted ? 5 : 0)
    }
}
