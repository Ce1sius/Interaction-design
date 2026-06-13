import CoreGraphics
import Foundation

struct MateLayoutMetrics {
    var normalSize: CGFloat = 78
    var minimizedSize: CGFloat = 54
    var expandedSize: CGFloat = 96
    var celebrationSize: CGFloat = 142
    var minimizedVisibleHeight: CGFloat = 54
    var edgePadding: CGFloat = 16
    var bottomPadding: CGFloat = 100
    var topMinimizedPadding: CGFloat = 8
    var menuButtonSize: CGFloat = 48
    var menuRadius: CGFloat = 82
    var snapAnimationResponse: Double = 0.42
    var snapAnimationDamping: Double = 0.72

    static let standard = MateLayoutMetrics()
}

enum MateHorizontalEdge: String, Codable {
    case left
    case right
}

struct MateBoundsCalculator {
    static func clampedPosition(
        _ position: CGPoint,
        in size: CGSize,
        safeArea: EdgeInsetsValue,
        characterSize: CGFloat,
        metrics: MateLayoutMetrics = .standard
    ) -> CGPoint {
        guard size.width > 0, size.height > 0 else { return position }
        let half = characterSize / 2
        let minX = safeArea.leading + metrics.edgePadding + half
        let maxX = max(minX, size.width - safeArea.trailing - metrics.edgePadding - half)
        let minY = safeArea.top + metrics.edgePadding + half
        let maxY = max(minY, size.height - safeArea.bottom - metrics.bottomPadding + half)
        return CGPoint(
            x: min(max(position.x, minX), maxX),
            y: min(max(position.y, minY), maxY)
        )
    }

    static func snappedPosition(
        from position: CGPoint,
        predictedEnd: CGPoint,
        in size: CGSize,
        safeArea: EdgeInsetsValue,
        characterSize: CGFloat,
        metrics: MateLayoutMetrics = .standard
    ) -> CGPoint {
        let candidate = abs(predictedEnd.x - position.x) > 34 ? predictedEnd : position
        let edge = candidate.x < size.width / 2 ? MateHorizontalEdge.left : .right
        let half = characterSize / 2
        let x: CGFloat
        switch edge {
        case .left:
            x = safeArea.leading + metrics.edgePadding + half
        case .right:
            x = size.width - safeArea.trailing - metrics.edgePadding - half
        }
        return clampedPosition(
            CGPoint(x: x, y: candidate.y),
            in: size,
            safeArea: safeArea,
            characterSize: characterSize,
            metrics: metrics
        )
    }

    static func defaultPosition(
        in size: CGSize,
        safeArea: EdgeInsetsValue,
        characterSize: CGFloat,
        metrics: MateLayoutMetrics = .standard
    ) -> CGPoint {
        clampedPosition(
            CGPoint(
                x: size.width - safeArea.trailing - metrics.edgePadding - characterSize / 2,
                y: size.height - safeArea.bottom - metrics.bottomPadding
            ),
            in: size,
            safeArea: safeArea,
            characterSize: characterSize,
            metrics: metrics
        )
    }

    static func minimizedPosition(
        edge: MateHorizontalEdge,
        in size: CGSize,
        safeArea: EdgeInsetsValue,
        characterSize: CGFloat,
        metrics: MateLayoutMetrics = .standard
    ) -> CGPoint {
        let half = characterSize / 2
        let x = safeArea.leading + metrics.edgePadding + half
        return CGPoint(
            x: x,
            y: safeArea.top + metrics.topMinimizedPadding + half
        )
    }
}

struct EdgeInsetsValue: Codable, Equatable {
    var top: CGFloat
    var leading: CGFloat
    var bottom: CGFloat
    var trailing: CGFloat

    static let zero = EdgeInsetsValue(top: 0, leading: 0, bottom: 0, trailing: 0)
}
