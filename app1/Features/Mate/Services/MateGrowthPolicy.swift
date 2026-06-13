import Foundation

struct MateGrowthPolicy {
    var pointsForTaskCompleted = 1
    var pointsForImportantTask = 3
    var pointsForDailyPlan = 5
    var pointsForStreakDay = 1
    var pointsForLongTermGoal = 10
    var adultThreshold = 100
    var growingProgressThreshold = 0.7

    static let standard = MateGrowthPolicy()

    func reward(for event: MateEvent) -> Int {
        switch event {
        case .taskCompleted: return pointsForTaskCompleted
        case .importantTaskCompleted: return pointsForImportantTask
        case .dailyPlanCompleted: return pointsForDailyPlan
        default: return 0
        }
    }

    func profile(afterAdding points: Int, to profile: MateProfile) -> MateProfile {
        var updated = profile
        updated.growthPoints = max(0, updated.growthPoints + points)
        updated.growthProgress = min(Double(updated.growthPoints) / Double(adultThreshold), 1)

        if updated.growthProgress >= 1 {
            updated.growthStage = .adult
        } else if updated.growthProgress >= growingProgressThreshold {
            updated.growthStage = .growing
        } else {
            updated.growthStage = .child
        }
        return updated
    }
}
