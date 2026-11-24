import SwiftUI

struct SectionLabel: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.isle(.caption, .heavy))
            .tracking(0.8)
            .foregroundStyle(T.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The round tick used everywhere something can be completed.
struct CheckCircle: View {
    var done: Bool
    var size: CGFloat = 26
    var color: Color = T.good
    @State private var pop: CGFloat = 1

    var body: some View {
        ZStack {
            Circle().fill(done ? color : T.surface)
            Circle().strokeBorder(T.outline, lineWidth: 2)
            if done {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.48, weight: .black))
                    .foregroundStyle(T.primaryInk)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(pop)
        .onChange(of: done) { _, newValue in
            guard newValue else { return }
            pop = 0.5
            withAnimation(.spring(response: 0.38, dampingFraction: 0.45)) { pop = 1 }
        }
    }
}

struct ProgressBar: View {
    var value: Double
    var color: Color = T.good
    var height: CGFloat = 8
    var track: Color = T.line

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule().fill(color)
                    .frame(width: max(0, min(1, value)) * g.size.width)
            }
        }
        .frame(height: height)
        .animation(.spring(response: 0.6, dampingFraction: 0.85), value: value)
    }
}

struct ShellIcon: View {
    var size: CGFloat = 18
    var body: some View {
        Canvas { ctx, s in
            let w = s.width, h = s.height
            var p = Path()
            p.move(to: CGPoint(x: w * 0.5, y: h * 0.92))
            p.addLine(to: CGPoint(x: w * 0.1, y: h * 0.4))
            p.addQuadCurve(to: CGPoint(x: w * 0.9, y: h * 0.4), control: CGPoint(x: w * 0.5, y: -h * 0.05))
            p.closeSubpath()
            ctx.fill(p, with: .color(Color(hex: 0xFFB4A2)))
            ctx.stroke(p, with: .color(T.pipInk), style: StrokeStyle(lineWidth: 1.6, lineJoin: .round))
            var ribs = Path()
            for x in [0.32, 0.5, 0.68] {
                ribs.move(to: CGPoint(x: w * 0.5, y: h * 0.9))
                ribs.addLine(to: CGPoint(x: w * x, y: h * 0.3))
            }
            ctx.stroke(ribs, with: .color(T.pipInk), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct ShellBadge: View {
    var count: Int
    @State private var bump: CGFloat = 1

    var body: some View {
        HStack(spacing: 5) {
            ShellIcon(size: 18)
            Text("\(count)").font(.isle(.headline)).monospacedDigit()
                .contentTransition(.numericText())
        }
        .foregroundStyle(T.ink)
        .padding(.leading, 8).padding(.trailing, 12)
        .frame(height: 40)
        .background(Capsule().fill(T.surface))
        .overlay(Capsule().strokeBorder(T.outline, lineWidth: 2))
        .scaleEffect(bump)
        .onChange(of: count) { old, new in
            guard new > old else { return }
            bump = 1.18
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { bump = 1 }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) shells")
    }
}

struct Tag: View {
    var text: String
    var fill: Color = T.line
    var body: some View {
        Text(text)
            .font(.isle(.caption, .heavy))
            .foregroundStyle(T.ink)
            .padding(.horizontal, 7)
            .frame(minHeight: 22)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(fill))
    }
}

struct Chip: View {
    var text: String
    var dot: Color? = nil
    var fill: Color = T.surface
    var body: some View {
        HStack(spacing: 6) {
            if let dot {
                Circle().fill(dot).overlay(Circle().strokeBorder(T.outline, lineWidth: 1.5)).frame(width: 12, height: 12)
            }
            Text(text).font(.isle(.subheadline)).foregroundStyle(T.ink)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 34)
        .background(Capsule().fill(fill))
        .overlay(Capsule().strokeBorder(T.outline, lineWidth: 2))
    }
}

/// A selectable chip; used for moods, durations, filters.
struct ToggleChip: View {
    var text: String
    var on: Bool
    var onFill: Color = T.primarySoft
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.isle(.subheadline))
                .foregroundStyle(T.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(Capsule().fill(on ? onFill : T.surface))
                .overlay(Capsule().strokeBorder(T.outline, lineWidth: 2))
        }
        .buttonStyle(PressStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Wraps children onto new lines like text.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 360
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > 0 && x + s.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += s.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, s.height)
        }
        return CGSize(width: proposal.width ?? widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + s.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowHeight = max(rowHeight, s.height)
        }
    }
}

struct SegmentedPicker<Value: Hashable>: View {
    var options: [(Value, String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, opt in
                let on = opt.0 == selection
                Button {
                    if !on { Feedback.play(.tap) }
                    withAnimation(.easeOut(duration: 0.2)) { selection = opt.0 }
                } label: {
                    Text(opt.1)
                        .font(.isle(.subheadline))
                        .foregroundStyle(T.ink)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(on ? T.surface : Color.clear))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(on ? T.outline : Color.clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(T.line))
    }
}

struct ToggleSwitch: View {
    var label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            Feedback.play(isOn ? .pause : .resume)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isOn.toggle() }
        } label: {
            HStack {
                Text(label).font(.isle(.subheadline)).foregroundStyle(T.ink)
                Spacer()
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule().fill(isOn ? T.good : T.line)
                    Circle().fill(Color.white).overlay(Circle().strokeBorder(T.outline, lineWidth: 2))
                        .frame(width: 22, height: 22).padding(3)
                }
                .frame(width: 52, height: 30)
                .overlay(Capsule().strokeBorder(T.outline, lineWidth: 2))
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

struct ToastData: Equatable {
    var id = UUID()
    var text: String
    var canUndo: Bool
    static func == (a: ToastData, b: ToastData) -> Bool { a.id == b.id }
}

struct ToastView: View {
    var toast: ToastData
    var onUndo: () -> Void

    var body: some View {
        HStack {
            Text(toast.text).font(.isle(.subheadline)).foregroundStyle(T.cream)
            Spacer()
            if toast.canUndo {
                Button("Undo", action: onUndo)
                    .font(.isle(.subheadline))
                    .foregroundStyle(T.primaryInk)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(RoundedRectangle(cornerRadius: 12).fill(T.primary))
            }
        }
        .padding(.leading, 16).padding(.trailing, 8)
        .frame(minHeight: 56)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0x2B2848)))
        .padding(.horizontal, 16)
    }
}

/// "+10" that floats up and fades.
struct FloatingReward: View {
    var text: String
    @State private var up = false

    var body: some View {
        Text(text)
            .font(.isle(.headline, .heavy))
            .foregroundStyle(T.now)
            .offset(y: up ? -28 : 6)
            .opacity(up ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 0.9)) { up = true } }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct EmptyHint: View {
    var title: String
    var message: String
    var body: some View {
        VStack(spacing: 6) {
            Text(title).font(.isle(.headline)).foregroundStyle(T.ink)
            Text(message).font(.isle(.subheadline, .semibold)).foregroundStyle(T.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}
