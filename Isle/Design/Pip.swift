import SwiftUI

enum PipMood {
    case normal, happy, sleepy, cheer
}

/// Pip, drawn in a 120 × 120 space and scaled. Idle loop: bob, blink, leaf sway, wave.
struct PipView: View {
    var mood: PipMood = .happy
    var size: CGFloat = 120
    var colorIndex: Int = 0
    var outfit: String = "none"
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let moving = animated && !reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !moving)) { timeline in
            let t = moving ? timeline.date.timeIntervalSinceReferenceDate : 0
            Canvas { context, canvasSize in
                PipDrawing.draw(in: context, size: canvasSize, t: t, mood: mood, colorIndex: colorIndex, outfit: outfit)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        switch mood {
        case .normal: return "Pip"
        case .happy: return "Pip, smiling"
        case .sleepy: return "Pip, sleepy"
        case .cheer: return "Pip, cheering"
        }
    }
}

enum PipDrawing {
    static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    static func draw(in base: GraphicsContext, size: CGSize, t: Double, mood: PipMood, colorIndex: Int, outfit: String) {
        var ctx = base
        let s = min(size.width, size.height) / 120
        ctx.scaleBy(x: s, y: s)

        let ink = T.pipInk
        let ci = ((colorIndex % 4) + 4) % 4
        let body = T.pipBodies[ci], belly = T.pipBellies[ci], feet = T.pipFeet[ci]
        let line = StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
        let thin = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)

        let bobPeriod: Double = mood == .cheer ? 0.7 : (mood == .sleepy ? 3.6 : 2.6)
        let bobAmp: Double = mood == .cheer ? 9 : (mood == .sleepy ? 2 : 3)
        let phase = sin(t * 2 * .pi / bobPeriod)
        let bob = CGFloat(mood == .cheer ? -abs(phase) * bobAmp : -((phase + 1) / 2) * bobAmp)

        // shadow
        let shadowRx = CGFloat(30 - 4 * ((phase + 1) / 2))
        ctx.fill(ellipse(60, 112, shadowRx, 5), with: .color(ink.opacity(0.15)))
        // feet
        for fx in [CGFloat(46), CGFloat(74)] {
            let p = ellipse(fx, 104, 10, 6)
            ctx.fill(p, with: .color(feet))
            ctx.stroke(p, with: .color(ink), style: thin)
        }

        var b = ctx
        b.translateBy(x: 0, y: bob)

        // waving arm
        if mood == .happy || mood == .cheer {
            let wavePeriod: Double = mood == .cheer ? 1.0 : 3.0
            let w = sin(t * 2 * .pi / wavePeriod)
            var arm = b
            arm.translateBy(x: 22, y: 76)
            arm.rotate(by: .degrees(-9 + 9 * w))
            var p = Path()
            p.move(to: .zero)
            p.addQuadCurve(to: CGPoint(x: -8, y: -16), control: CGPoint(x: -12, y: -6))
            arm.stroke(p, with: .color(ink), style: line)
        }

        // body + belly
        let bodyPath = ellipse(60, 70, 40, 36)
        b.fill(bodyPath, with: .color(body))
        b.stroke(bodyPath, with: .color(ink), style: line)
        b.fill(ellipse(60, 82, 23, 17), with: .color(belly))

        // outfit (behind the sprout)
        drawOutfit(outfit, in: b, ink: ink)

        // sprout, swaying
        var sprout = b
        let swayPeriod: Double = mood == .sleepy ? 5 : 3.2
        sprout.translateBy(x: 60, y: 34)
        sprout.rotate(by: .degrees(7 * sin(t * 2 * .pi / swayPeriod)))
        sprout.translateBy(x: -60, y: -34)
        var stem = Path()
        stem.move(to: CGPoint(x: 60, y: 34)); stem.addLine(to: CGPoint(x: 60, y: 20))
        sprout.stroke(stem, with: .color(ink), style: thin)
        var leafL = Path()
        leafL.move(to: CGPoint(x: 60, y: 22))
        leafL.addQuadCurve(to: CGPoint(x: 36, y: 15), control: CGPoint(x: 47, y: 6))
        leafL.addQuadCurve(to: CGPoint(x: 60, y: 22), control: CGPoint(x: 46, y: 28))
        sprout.fill(leafL, with: .color(Color(hex: 0x7CCB6B)))
        sprout.stroke(leafL, with: .color(ink), style: thin)
        var leafR = Path()
        leafR.move(to: CGPoint(x: 60, y: 22))
        leafR.addQuadCurve(to: CGPoint(x: 86, y: 12), control: CGPoint(x: 73, y: 4))
        leafR.addQuadCurve(to: CGPoint(x: 60, y: 22), control: CGPoint(x: 76, y: 27))
        sprout.fill(leafR, with: .color(Color(hex: 0x94DA82)))
        sprout.stroke(leafR, with: .color(ink), style: thin)

        // eyes
        switch mood {
        case .normal:
            let cycle = t.truncatingRemainder(dividingBy: 4.2) / 4.2
            let blink: CGFloat = (cycle > 0.9 && cycle < 0.98) ? 0.12 : 1
            for ex in [CGFloat(46), CGFloat(74)] {
                b.fill(ellipse(ex, 66, 4.8, 6.5 * blink), with: .color(ink))
                if blink > 0.5 { b.fill(ellipse(ex + 1.6, 63.6, 1.8, 1.8), with: .color(.white)) }
            }
        case .happy, .cheer:
            for ex in [CGFloat(46), CGFloat(74)] {
                var e = Path()
                e.move(to: CGPoint(x: ex - 6, y: 68))
                e.addQuadCurve(to: CGPoint(x: ex + 6, y: 68), control: CGPoint(x: ex, y: 59))
                b.stroke(e, with: .color(ink), style: line)
            }
        case .sleepy:
            for ex in [CGFloat(46), CGFloat(74)] {
                var e = Path()
                e.move(to: CGPoint(x: ex - 6, y: 66))
                e.addQuadCurve(to: CGPoint(x: ex + 6, y: 66), control: CGPoint(x: ex, y: 70))
                b.stroke(e, with: .color(ink), style: line)
            }
            let z = t.truncatingRemainder(dividingBy: 2.4) / 2.4
            let o1 = z < 0.5 ? z * 2 : (1 - z) * 2
            b.draw(Text("z").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundColor(ink.opacity(o1)), at: CGPoint(x: 92, y: 36))
            let z2 = (z + 0.35).truncatingRemainder(dividingBy: 1)
            let o2 = z2 < 0.5 ? z2 * 2 : (1 - z2) * 2
            b.draw(Text("z").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundColor(ink.opacity(o2)), at: CGPoint(x: 101, y: 24))
        }

        // cheeks + mouth
        b.fill(ellipse(35, 76, 6.5, 4), with: .color(Color(hex: 0xFF6F86).opacity(0.45)))
        b.fill(ellipse(85, 76, 6.5, 4), with: .color(Color(hex: 0xFF6F86).opacity(0.45)))
        var mouth = Path()
        if mood == .cheer {
            mouth.move(to: CGPoint(x: 53, y: 74))
            mouth.addQuadCurve(to: CGPoint(x: 67, y: 74), control: CGPoint(x: 60, y: 86))
            mouth.closeSubpath()
            b.fill(mouth, with: .color(Color(hex: 0xFF6F86)))
            b.stroke(mouth, with: .color(ink), style: thin)
        } else {
            mouth.move(to: CGPoint(x: 55, y: 76))
            mouth.addQuadCurve(to: CGPoint(x: 65, y: 76), control: CGPoint(x: 60, y: 81))
            b.stroke(mouth, with: .color(ink), style: thin)
        }
    }

    static func drawOutfit(_ outfit: String, in ctx: GraphicsContext, ink: Color) {
        let style = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
        switch outfit {
        case "beanie":
            var hat = Path()
            hat.move(to: CGPoint(x: 24, y: 58))
            hat.addQuadCurve(to: CGPoint(x: 60, y: 24), control: CGPoint(x: 26, y: 26))
            hat.addQuadCurve(to: CGPoint(x: 96, y: 58), control: CGPoint(x: 94, y: 26))
            hat.closeSubpath()
            ctx.fill(hat, with: .color(Color(hex: 0xB8A4F5)))
            ctx.stroke(hat, with: .color(ink), style: style)
            let band = Path(roundedRect: CGRect(x: 21, y: 52, width: 78, height: 11), cornerRadius: 5.5)
            ctx.fill(band, with: .color(Color(hex: 0x9C86EC)))
            ctx.stroke(band, with: .color(ink), style: style)
        case "crown":
            var vine = Path()
            vine.move(to: CGPoint(x: 26, y: 46))
            vine.addQuadCurve(to: CGPoint(x: 94, y: 46), control: CGPoint(x: 60, y: 28))
            ctx.stroke(vine, with: .color(Color(hex: 0x3F8A3A)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            let flowers: [(CGFloat, CGFloat, UInt32)] = [(30, 44, 0xFFB4A2), (44, 37, 0xFFD45C), (60, 34, 0xB8A4F5), (76, 37, 0x8FD0F0), (90, 44, 0xFFB4A2)]
            for (x, y, c) in flowers {
                let f = ellipse(x, y, 6, 6)
                ctx.fill(f, with: .color(Color(hex: c)))
                ctx.stroke(f, with: .color(ink), style: StrokeStyle(lineWidth: 2.2))
            }
        case "scarf":
            var scarf = Path()
            scarf.move(to: CGPoint(x: 28, y: 88))
            scarf.addQuadCurve(to: CGPoint(x: 92, y: 88), control: CGPoint(x: 60, y: 100))
            scarf.addLine(to: CGPoint(x: 92, y: 96))
            scarf.addQuadCurve(to: CGPoint(x: 28, y: 96), control: CGPoint(x: 60, y: 108))
            scarf.closeSubpath()
            ctx.fill(scarf, with: .color(Color(hex: 0xFF8A65)))
            ctx.stroke(scarf, with: .color(ink), style: style)
            let tail = Path(roundedRect: CGRect(x: 70, y: 96, width: 12, height: 16), cornerRadius: 3)
            ctx.fill(tail, with: .color(Color(hex: 0xFF8A65)))
            ctx.stroke(tail, with: .color(ink), style: style)
        default:
            break
        }
    }
}

/// A single plant for the isle: stem + round head; `grow` 0…1 animates it in.
struct PlantView: View {
    var color: Color
    var height: CGFloat = 26
    var head: CGFloat = 12
    var grow: CGFloat = 1

    var body: some View {
        VStack(spacing: -2) {
            Circle()
                .fill(color)
                .overlay(Circle().strokeBorder(T.pipInk, lineWidth: 2))
                .frame(width: head, height: head)
                .scaleEffect(grow)
            Capsule()
                .fill(Color(hex: 0x3F8A3A))
                .frame(width: 3, height: max(2, (height - head) * grow))
        }
        .frame(height: height, alignment: .bottom)
    }
}
