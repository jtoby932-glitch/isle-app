import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32) { self.init(uiColor: UIColor(hex: hex)) }

    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// Isle's design tokens (spec: Design system).
enum T {
    static let bg = Color.dynamic(0xFBF7F0, 0x17152B)
    static let surface = Color.dynamic(0xFFFFFF, 0x232042)
    static let surface2 = Color.dynamic(0xF7F3EA, 0x2D2A52)
    static let ink = Color.dynamic(0x2B2848, 0xF3EDE1)
    static let muted = Color.dynamic(0x5B5776, 0xB2ACCE)
    static let line = Color.dynamic(0xEFE9DD, 0x3A3668)
    static let outline = Color.dynamic(0x2B2848, 0x5A558F)
    static let primary = Color(hex: 0xFFD45C)
    static let primarySoft = Color.dynamic(0xFFE7A3, 0x4A4130)
    static let primaryInk = Color(hex: 0x2B2848)
    static let good = Color.dynamic(0x7CCB6B, 0x8FDB7C)
    static let goodSoft = Color.dynamic(0xE6F6DF, 0x24382A)
    static let warn = Color(hex: 0xF0A23B)
    static let warnText = Color.dynamic(0xA0560F, 0xF3B668)
    static let warnSoft = Color.dynamic(0xFFF4E3, 0x3A2E1E)
    static let now = Color.dynamic(0xF2764E, 0xFF9A72)
    static let lilac = Color.dynamic(0xEDE7FF, 0x2D2A52)
    static let lilacStrong = Color.dynamic(0xDCD3FC, 0x3F3A78)
    static let sky = Color.dynamic(0xDDF0FA, 0x1E2B45)
    static let sea = Color.dynamic(0x8FD3F0, 0x1F3A5C)
    static let sand = Color.dynamic(0xF6E3B4, 0x5C5240)
    static let grass = Color.dynamic(0xA6DE8F, 0x3E6B3A)
    static let soil = Color.dynamic(0xC99B6B, 0x7A5A3E)
    static let soilWet = Color.dynamic(0x9C7B62, 0x5A4636)
    static let night = Color(hex: 0x24204A)
    static let cream = Color(hex: 0xFFF1D6)
    static let danger = Color.dynamic(0xB23B2A, 0xFF8A7A)

    static let habitColors: [Color] = [
        Color.dynamic(0x8FD0F0, 0x9AD7F5),
        Color.dynamic(0xFFB4A2, 0xFFBDAE),
        Color.dynamic(0x7CCB6B, 0x8FDB7C),
        Color.dynamic(0xB8A4F5, 0xC4B3FA),
        Color(hex: 0xFFD45C),
        Color.dynamic(0xFF9C7A, 0xFFAA8C),
        Color.dynamic(0x6EC3EA, 0x7FCFF0),
        Color.dynamic(0xF2A6C8, 0xF5B4D2)
    ]

    static func habit(_ i: Int) -> Color { habitColors[((i % habitColors.count) + habitColors.count) % habitColors.count] }

    static let pipBodies: [Color] = [Color(hex: 0xFF9C7A), Color(hex: 0x8FD0F0), Color(hex: 0xB8A4F5), Color(hex: 0xFFD45C)]
    static let pipBellies: [Color] = [Color(hex: 0xFFD6C4), Color(hex: 0xD6EFFA), Color(hex: 0xE5DCFC), Color(hex: 0xFFF0BF)]
    static let pipFeet: [Color] = [Color(hex: 0xF2764E), Color(hex: 0x5DB4DE), Color(hex: 0x9C86EC), Color(hex: 0xF0B429)]
    static let pipInk = Color(hex: 0x2B2848)

    static let radius: CGFloat = 16
    static let border: CGFloat = 2
}

extension Font {
    static func isle(_ style: Font.TextStyle, _ weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

// MARK: - Modifiers

struct CardModifier: ViewModifier {
    var fill: Color = T.surface
    var radius: CGFloat = T.radius
    var padding: CGFloat = 12
    var shadow: Bool = false

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    if shadow {
                        RoundedRectangle(cornerRadius: radius, style: .continuous).fill(T.outline).offset(y: 3)
                    }
                    RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(T.outline, lineWidth: T.border))
    }
}

extension View {
    func card(fill: Color = T.surface, radius: CGFloat = T.radius, padding: CGFloat = 12, shadow: Bool = false) -> some View {
        modifier(CardModifier(fill: fill, radius: radius, padding: padding, shadow: shadow))
    }

    func screenBackground() -> some View {
        background(T.bg.ignoresSafeArea())
    }
}

/// Big yellow button with the hard offset shadow.
struct ChunkyButtonStyle: ButtonStyle {
    var fill: Color = T.primary
    var textColor: Color = T.primaryInk
    var height: CGFloat = 54
    var shadow: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(.isle(.headline))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(
                ZStack {
                    if shadow {
                        RoundedRectangle(cornerRadius: 18, style: .continuous).fill(T.outline).offset(y: pressed ? 1 : 4)
                    }
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(fill)
                }
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(T.outline, lineWidth: 2.5))
            .offset(y: pressed && shadow ? 3 : 0)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

/// Small outlined pill button.
struct PillButtonStyle: ButtonStyle {
    var fill: Color = T.surface
    var textColor: Color = T.ink
    var height: CGFloat = 38

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.isle(.subheadline))
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .frame(minHeight: height)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(T.outline, lineWidth: T.border))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Any tappable thing: a little press-down.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct IconButtonStyle: ButtonStyle {
    var fill: Color = T.surface

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold, design: .rounded))
            .foregroundStyle(T.ink)
            .frame(width: 44, height: 44)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(T.outline, lineWidth: T.border))
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
