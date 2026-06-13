import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum PMColor {
    static let canvas = Color(light: "#ffffff", dark: "#050506")
    static let softCanvas = Color(light: "#fafaf9", dark: "#000000")
    static let paper = Color(light: "#fffdf8", dark: "#151515")
    static let surface = Color(light: "#f6f5f4", dark: "#1c1c1e")
    static let surfaceRaised = Color(light: "#ffffff", dark: "#242426")
    static let surfaceGlass = Color(light: "#ffffffcc", dark: "#242426dd")
    static let hairline = Color(light: "#e5e3df", dark: "#343438")
    static let softHairline = Color(light: "#ede9e4", dark: "#2b2b30")
    static let strongHairline = Color(light: "#c8c4be", dark: "#4a4a50")
    static let ink = Color(light: "#1a1a1a", dark: "#f7f7f8")
    static let charcoal = Color(light: "#37352f", dark: "#f1f1f3")
    static let slate = Color(light: "#5d5b54", dark: "#c7c7cc")
    static let steel = Color(light: "#787671", dark: "#9b9ba1")
    static let muted = Color(light: "#bbb8b1", dark: "#6c6c72")
    static let primary = Color(hex: "#2488ff")
    static let primaryPressed = Color(hex: "#0b66d8")
    static let primarySoft = Color(light: "#e9f3ff", dark: "#10253f")
    static let primaryMist = Color(light: "#f4f9ff", dark: "#0a1728")
    static let linkBlue = Color(hex: "#2488ff")
    static let course = Color(hex: "#ff453a")
    static let assignment = Color(hex: "#ffcc00")
    static let review = Color(hex: "#8ee84f")
    static let personal = Color(hex: "#2488ff")
    static let goal = Color(hex: "#32d6d3")
    static let conflict = Color(hex: "#ff453a")
    static let warning = Color(hex: "#ff9f0a")
    static let success = Color(hex: "#30d158")
    static let agentGlow = Color(light: "#eaf4ff", dark: "#0d2038")
    static let studyWarm = Color(light: "#fff8e7", dark: "#261f12")
    static let studyMint = Color(light: "#effbe8", dark: "#152411")
    static let studyRose = Color(light: "#fff0ee", dark: "#2a1413")
    static let graphGrid = Color(light: "#d7d2ca", dark: "#3a3a40")

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

enum PMSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let page: CGFloat = 16
}

enum PMRadius {
    static let small: CGFloat = 8
    static let button: CGFloat = 10
    static let chip: CGFloat = 999
    static let card: CGFloat = 14
    static let panel: CGFloat = 16
    static let hero: CGFloat = 20
}

enum PMMotion {
    static let buttonResponse = 0.18
    static let buttonDamping = 0.75
    static let springResponse = 0.32
    static let springDamping = 0.86
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
    func pathCardStyle(cornerRadius: CGFloat = PMRadius.card, accent: Color? = nil) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PMColor.surfaceRaised)
                if let accent {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.08), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(PMColor.hairline, lineWidth: 1)
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .frame(height: 1)
                    .padding(.horizontal, 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.055), radius: 12, x: 0, y: 4)
    }

    func pathPanelStyle(cornerRadius: CGFloat = PMRadius.panel) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(PMColor.surface)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(PMColor.softHairline, lineWidth: 1)
            }
    }

    func pathIconWell(tint: Color = PMColor.primary, size: CGFloat = 42, cornerRadius: CGFloat = 13) -> some View {
        self
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}
