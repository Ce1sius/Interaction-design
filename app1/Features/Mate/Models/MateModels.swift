import CoreGraphics
import Foundation

enum MateGrowthStage: String, Codable, CaseIterable, Identifiable {
    case child
    case growing
    case adult

    var id: String { rawValue }
}

enum MateMood: String, Codable, CaseIterable, Identifiable {
    case idle
    case curious
    case happy
    case thinking
    case celebrating
    case sleepy
    case encouraging

    var id: String { rawValue }
}

enum MateDisplayState: String, Codable {
    case normal
    case expanded
    case minimized
    case reacting
}

enum MateEvent: Int, CaseIterable {
    case appOpened
    case tapped
    case dragged
    case taskCompleted
    case importantTaskCompleted
    case taskOverdue
    case schedulePlanningStarted
    case schedulePlanningCompleted
    case dailyPlanCompleted
    case growthStageChanged

    var priority: Int {
        switch self {
        case .growthStageChanged: return 90
        case .dailyPlanCompleted: return 80
        case .importantTaskCompleted: return 70
        case .schedulePlanningCompleted: return 60
        case .taskCompleted: return 50
        case .schedulePlanningStarted: return 45
        case .taskOverdue: return 35
        case .appOpened, .tapped, .dragged: return 20
        }
    }
}

enum MateAction {
    case chat
    case smartPlanning
    case minimize

    var iconName: String {
        switch self {
        case .chat: return "message.fill"
        case .smartPlanning: return "calendar.badge.clock"
        case .minimize: return "chevron.up"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .chat: return "打开 Mate 聊天"
        case .smartPlanning: return "启动智能日程规划"
        case .minimize: return "最小化 Mate"
        }
    }

    var accessibilityHint: String {
        switch self {
        case .chat: return "进入聊天入口"
        case .smartPlanning: return "Mate 会进入规划状态"
        case .minimize: return "将 Mate 收到顶部"
        }
    }
}

struct MateProfile: Codable, Equatable {
    var growthStage: MateGrowthStage
    var growthPoints: Int
    var growthProgress: Double
    var completedTaskCount: Int
    var streakDays: Int
    var lastInteractionDate: Date?
    var isMinimized: Bool
    var normalizedPosition: CGPoint?

    static let initial = MateProfile(
        growthStage: .child,
        growthPoints: 0,
        growthProgress: 0,
        completedTaskCount: 0,
        streakDays: 0,
        lastInteractionDate: nil,
        isMinimized: false,
        normalizedPosition: nil
    )
}

struct MateActions {
    var openChat: () -> Void
    var openSmartPlanner: () -> Void
    var minimize: () -> Void

    static let noop = MateActions(openChat: {}, openSmartPlanner: {}, minimize: {})
}
