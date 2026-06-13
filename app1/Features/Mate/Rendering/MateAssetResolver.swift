import Foundation

struct MateAssetResolver {
    func assetName(stage: MateGrowthStage, mood: MateMood, event: MateEvent?) -> String {
        if let event {
            switch event {
            case .dailyPlanCompleted:
                return stage == .adult ? "MateAdultLaugh" : "MateChildPeace"
            case .importantTaskCompleted:
                return stage == .adult ? "MateAdultPose" : "MateChildPeace"
            case .taskCompleted, .tapped, .schedulePlanningCompleted:
                return stage == .adult ? "MateAdultPose" : "MateChildWink"
            case .taskOverdue:
                return "MateChildTilt"
            case .growthStageChanged:
                return stage == .adult ? "MateAdultLaugh" : "MateChildPeace"
            case .appOpened:
                return stage == .adult ? "MateAdultPose" : "MateChildPeace"
            case .dragged, .schedulePlanningStarted:
                break
            }
        }

        switch stage {
        case .adult:
            switch mood {
            case .celebrating, .happy, .encouraging:
                return "MateAdultPose"
            default:
                return "MateAdultPose"
            }
        case .child, .growing:
            switch mood {
            case .curious, .thinking, .sleepy:
                return "MateChildTilt"
            case .happy, .celebrating, .encouraging:
                return "MateChildWink"
            case .idle:
                return "MateChildTilt"
            }
        }
    }
}
