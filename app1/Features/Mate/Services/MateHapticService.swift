import Foundation

#if canImport(UIKit)
import UIKit
#endif

struct MateHapticService {
    func impact(_ style: ImpactStyle) {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: style.uiKitStyle).impactOccurred()
        #endif
    }

    func notification(_ type: NotificationKind) {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(type.uiKitType)
        #endif
    }

    enum ImpactStyle {
        case light
        case soft
        case rigid

        #if canImport(UIKit)
        var uiKitStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light: return .light
            case .soft: return .soft
            case .rigid: return .rigid
            }
        }
        #endif
    }

    enum NotificationKind {
        case success

        #if canImport(UIKit)
        var uiKitType: UINotificationFeedbackGenerator.FeedbackType {
            switch self {
            case .success: return .success
            }
        }
        #endif
    }
}
