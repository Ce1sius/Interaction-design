import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PMColor {
    static let canvas = Color(light: "#F8FAFC", dark: "#020617")
    static let softCanvas = Color(light: "#EFF4F8", dark: "#050A18")
    static let surface = Color(light: "#E8EEF5", dark: "#0F172A")
    static let surfaceRaised = Color(light: "#FFFFFF", dark: "#111827")
    static let hairline = Color(light: "#D8E0EA", dark: "#1E293B")
    static let strongHairline = Color(light: "#B8C4D2", dark: "#334155")
    static let ink = Color(light: "#111827", dark: "#F8FAFC")
    static let charcoal = Color(light: "#1F2937", dark: "#E5EDF6")
    static let slate = Color(light: "#536170", dark: "#CBD5E1")
    static let steel = Color(light: "#7B8794", dark: "#94A3B8")
    static let muted = Color(light: "#A9B6C6", dark: "#64748B")
    static let primary = Color(hex: "#2563EB")
    static let primaryPressed = Color(hex: "#1D4ED8")
    static let linkBlue = Color(hex: "#2563EB")
    static let studyIndigo = Color(hex: "#5E6AD2")
    static let studyIndigoPressed = Color(hex: "#4651B8")
    static let agent = Color(hex: "#0EA5E9")
    static let agentPressed = Color(hex: "#0284C7")
    static let parchment = Color(light: "#FBFDFF", dark: "#111827")
    static let course = Color(hex: "#ff453a")
    static let assignment = Color(hex: "#ffcc00")
    static let review = Color(hex: "#22C55E")
    static let personal = Color(hex: "#2563EB")
    static let goal = Color(hex: "#06B6D4")
    static let conflict = Color(hex: "#ff453a")
    static let warning = Color(hex: "#ff9f0a")
    static let success = Color(hex: "#30d158")

    static func task(_ kind: TaskKind) -> Color {
        switch kind {
        case .course: return course
        case .assignment: return assignment
        case .review: return review
        case .personal: return personal
        case .goal: return goal
        }
    }
}

extension AppearanceMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var iconName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red: UInt64
        let green: UInt64
        let blue: UInt64
        let alpha: UInt64

        switch sanitized.count {
        case 3:
            red = (value >> 8) * 17
            green = (value >> 4 & 0xF) * 17
            blue = (value & 0xF) * 17
            alpha = 255
        case 6:
            red = value >> 16
            green = value >> 8 & 0xFF
            blue = value & 0xFF
            alpha = 255
        case 8:
            red = value >> 24
            green = value >> 16 & 0xFF
            blue = value >> 8 & 0xFF
            alpha = value & 0xFF
        default:
            red = 0
            green = 0
            blue = 0
            alpha = 255
        }

        self.init(
            .sRGB,
            red: Double(red) / 255,
            green: Double(green) / 255,
            blue: Double(blue) / 255,
            opacity: Double(alpha) / 255
        )
    }

    init(light: String, dark: String) {
        #if canImport(UIKit)
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
        #elseif canImport(AppKit)
        self.init(NSColor(name: nil) { appearance in
            let best = appearance.bestMatch(from: [.darkAqua, .aqua])
            return best == .darkAqua ? NSColor(hex: dark) : NSColor(hex: light)
        })
        #else
        self.init(hex: light)
        #endif
    }
}

#if canImport(UIKit)
private extension UIColor {
    convenience init(hex: String) {
        let color = Color(hex: hex)
        #if swift(>=5.9)
        self.init(color)
        #else
        self.init(white: 0, alpha: 1)
        #endif
    }
}
#elseif canImport(AppKit)
private extension NSColor {
    convenience init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        self.init(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}
#endif

extension View {
    func pathCardStyle(cornerRadius: CGFloat = 14) -> some View {
        self
            .background(PMColor.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(PMColor.hairline, lineWidth: 1)
            }
            .shadow(color: Color(light: "#0F172A", dark: "#000000").opacity(0.08), radius: 16, x: 0, y: 8)
    }

    func pathPremiumCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PMColor.parchment)
                    .overlay(alignment: .topLeading) {
                        LinearGradient(
                            colors: [Color.white.opacity(0.72), PMColor.primary.opacity(0.06), PMColor.agent.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.82), PMColor.hairline, PMColor.agent.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: Color(light: "#0F172A", dark: "#000000").opacity(0.09), radius: 22, x: 0, y: 12)
    }

    func pathPageBackground() -> some View {
        self.background(
            ZStack {
                PMColor.softCanvas.ignoresSafeArea()
                LinearGradient(
                    colors: [
                        PMColor.agent.opacity(0.12),
                        PMColor.canvas.opacity(0.96),
                        PMColor.primary.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        )
    }
}
