import Combine
import CoreGraphics
import Foundation
import SwiftUI

@MainActor
final class MateViewModel: ObservableObject {
    @Published private(set) var profile: MateProfile
    @Published var mood: MateMood = .idle
    @Published var displayState: MateDisplayState = .normal
    @Published var position: CGPoint = .zero
    @Published var isDragging = false
    @Published var isMenuExpanded = false
    @Published var isFeedbackAnimationPlaying = false
    @Published var currentEvent: MateEvent?
    @Published var activeIdleMotion: MateIdleMotion?
    @Published var particleBurstID: UUID?
    @Published var isThinking = false
    @Published var isGlowActive = false

    private let profileStore: MateProfileStore
    private let growthPolicy: MateGrowthPolicy
    private let haptics: MateHapticService
    private let assetResolver = MateAssetResolver()
    private let idleScheduler = MateIdleAnimationScheduler()
    private var animationTask: Task<Void, Never>?
    private var dragStartPosition: CGPoint?
    private var lastNormalPosition: CGPoint?
    private var containerSize: CGSize = .zero
    private var safeArea = EdgeInsetsValue.zero
    private var activeEventPriority = 0

    let metrics: MateLayoutMetrics

    init(
        profileStore: MateProfileStore? = nil,
        growthPolicy: MateGrowthPolicy? = nil,
        haptics: MateHapticService? = nil,
        metrics: MateLayoutMetrics? = nil
    ) {
        let resolvedProfileStore = profileStore ?? UserDefaultsMateProfileStore()
        let resolvedGrowthPolicy = growthPolicy ?? MateGrowthPolicy.standard
        let resolvedHaptics = haptics ?? MateHapticService()
        let resolvedMetrics = metrics ?? MateLayoutMetrics.standard

        self.profileStore = resolvedProfileStore
        self.growthPolicy = resolvedGrowthPolicy
        self.haptics = resolvedHaptics
        self.metrics = resolvedMetrics
        let storedProfile = resolvedProfileStore.load()
        self.profile = storedProfile
        self.displayState = storedProfile.isMinimized ? .minimized : .normal

        idleScheduler.onMotion = { [weak self] motion in
            self?.playIdle(motion)
        }
    }

    var growthStage: MateGrowthStage { profile.growthStage }
    var growthProgress: Double { profile.growthProgress }
    var completedTaskCount: Int { profile.completedTaskCount }
    var streakDays: Int { profile.streakDays }
    var currentAssetName: String {
        if displayState == .minimized {
            return profile.growthStage == .adult ? "MateAdultSleep" : "MateChildSleep"
        }
        if isMenuExpanded {
            return profile.growthStage == .adult ? "MateAdultPose" : "MateChildWink"
        }
        return assetResolver.assetName(stage: profile.growthStage, mood: mood, event: currentEvent)
    }
    var currentEdge: MateHorizontalEdge {
        position.x < containerSize.width / 2 ? .left : .right
    }
    var characterSize: CGFloat {
        switch displayState {
        case .expanded:
            return metrics.expandedSize
        case .reacting:
            if currentEvent == .dailyPlanCompleted || currentEvent == .growthStageChanged {
                return metrics.celebrationSize
            }
            return metrics.expandedSize
        case .normal:
            return metrics.normalSize
        case .minimized:
            return metrics.minimizedSize
        }
    }

    func startIdleAnimations() {
        idleScheduler.start()
    }

    func stopIdleAnimations() {
        idleScheduler.stop()
    }

    func updateGeometry(size: CGSize, safeArea: EdgeInsetsValue) {
        containerSize = size
        self.safeArea = safeArea
        guard size.width > 0, size.height > 0 else { return }

        if position == .zero {
            position = restoredPosition(in: size, safeArea: safeArea)
            lastNormalPosition = displayState == .minimized ? MateBoundsCalculator.defaultPosition(in: size, safeArea: safeArea, characterSize: metrics.normalSize, metrics: metrics) : position
        }

        if displayState == .minimized {
            position = MateBoundsCalculator.minimizedPosition(edge: currentEdge, in: size, safeArea: safeArea, characterSize: characterSize, metrics: metrics)
        } else {
            position = MateBoundsCalculator.clampedPosition(position, in: size, safeArea: safeArea, characterSize: characterSize, metrics: metrics)
            lastNormalPosition = position
            persistPosition()
        }
    }

    func beginDrag() {
        guard displayState != .minimized else { return }
        isDragging = true
        isMenuExpanded = false
        displayState = .normal
        dragStartPosition = position
        haptics.impact(.light)
        idleScheduler.stop()
    }

    func dragChanged(translation: CGSize) {
        guard let dragStartPosition, displayState != .minimized else { return }
        let next = CGPoint(x: dragStartPosition.x + translation.width, y: dragStartPosition.y + translation.height)
        position = MateBoundsCalculator.clampedPosition(next, in: containerSize, safeArea: safeArea, characterSize: characterSize, metrics: metrics)
    }

    func endDrag(predictedTranslation: CGSize) {
        guard displayState != .minimized else { return }
        let predicted = CGPoint(
            x: (dragStartPosition?.x ?? position.x) + predictedTranslation.width,
            y: (dragStartPosition?.y ?? position.y) + predictedTranslation.height
        )
        position = MateBoundsCalculator.snappedPosition(
            from: position,
            predictedEnd: predicted,
            in: containerSize,
            safeArea: safeArea,
            characterSize: characterSize,
            metrics: metrics
        )
        lastNormalPosition = position
        dragStartPosition = nil
        isDragging = false
        displayState = .normal
        handle(event: .dragged)
        persistPosition()
        haptics.impact(.rigid)
        idleScheduler.start()
    }

    func toggleMenu() {
        guard displayState != .minimized else {
            restoreFromMinimized()
            return
        }
        handle(event: .tapped)
        isMenuExpanded.toggle()
        mood = isMenuExpanded ? .happy : .idle
        displayState = isMenuExpanded ? .expanded : .normal
        haptics.impact(.soft)
    }

    func collapseMenu() {
        guard isMenuExpanded else { return }
        isMenuExpanded = false
        if !isThinking && !isFeedbackAnimationPlaying {
            mood = .idle
        }
        if displayState == .expanded {
            displayState = .normal
        }
    }

    func minimize() {
        collapseMenu()
        haptics.impact(.light)
        lastNormalPosition = position
        profile.isMinimized = true
        profileStore.save(profile)
        withAnimation(.spring(response: metrics.snapAnimationResponse, dampingFraction: metrics.snapAnimationDamping)) {
            displayState = .minimized
            position = MateBoundsCalculator.minimizedPosition(edge: .left, in: containerSize, safeArea: safeArea, characterSize: metrics.minimizedSize, metrics: metrics)
        }
    }

    func restoreFromMinimized() {
        haptics.impact(.soft)
        profile.isMinimized = false
        profileStore.save(profile)
        let restored = lastNormalPosition ?? restoredPosition(in: containerSize, safeArea: safeArea)
        withAnimation(.spring(response: metrics.snapAnimationResponse, dampingFraction: metrics.snapAnimationDamping)) {
            displayState = .normal
            position = MateBoundsCalculator.clampedPosition(restored, in: containerSize, safeArea: safeArea, characterSize: metrics.normalSize, metrics: metrics)
        }
        lastNormalPosition = position
        persistPosition()
    }

    func setGrowthStage(_ stage: MateGrowthStage) {
        profile.growthStage = stage
        switch stage {
        case .child:
            profile.growthPoints = 0
            profile.growthProgress = 0
        case .growing:
            profile.growthPoints = Int(Double(growthPolicy.adultThreshold) * growthPolicy.growingProgressThreshold)
            profile.growthProgress = growthPolicy.growingProgressThreshold
        case .adult:
            profile.growthPoints = growthPolicy.adultThreshold
            profile.growthProgress = 1
        }
        profileStore.save(profile)
    }

    func addGrowth(points: Int) {
        let previousStage = profile.growthStage
        profile = growthPolicy.profile(afterAdding: points, to: profile)
        profileStore.save(profile)
        if previousStage != profile.growthStage {
            handle(event: .growthStageChanged)
        }
    }

    func resetProfile() {
        animationTask?.cancel()
        profileStore.reset()
        profile = .initial
        mood = .idle
        displayState = .normal
        currentEvent = nil
        isMenuExpanded = false
        isThinking = false
        isGlowActive = false
        activeEventPriority = 0
        position = MateBoundsCalculator.defaultPosition(in: containerSize, safeArea: safeArea, characterSize: metrics.normalSize, metrics: metrics)
        persistPosition()
    }

    func handle(event: MateEvent) {
        guard event.priority >= activeEventPriority || !isFeedbackAnimationPlaying else { return }
        activeEventPriority = event.priority
        animationTask?.cancel()
        let shouldAnimateOpen = event == .appOpened ? shouldPlayOpenAnimation() : true
        profile.lastInteractionDate = Date()

        let wasPromotedToGrowth = applyGrowthReward(for: event)
        let eventToPlay: MateEvent = wasPromotedToGrowth ? .growthStageChanged : event
        currentEvent = eventToPlay
        activeEventPriority = eventToPlay.priority
        applyMood(for: eventToPlay)
        applyHaptic(for: eventToPlay)

        switch eventToPlay {
        case .schedulePlanningStarted:
            isThinking = true
            isFeedbackAnimationPlaying = true
            isMenuExpanded = false
            displayState = .reacting
        case .growthStageChanged:
            isGlowActive = true
            runTransientFeedback(duration: 3.0, particles: true)
        case .dailyPlanCompleted:
            runTransientFeedback(duration: 2.0, particles: true)
        case .importantTaskCompleted:
            runTransientFeedback(duration: 1.7, particles: true)
        case .schedulePlanningCompleted:
            isThinking = false
            runTransientFeedback(duration: 1.2, particles: true)
        case .taskCompleted:
            runTransientFeedback(duration: 1.2, particles: true)
        case .taskOverdue:
            runTransientFeedback(duration: 1.0, particles: false)
        case .appOpened:
            if shouldAnimateOpen {
                runTransientFeedback(duration: 1.0, particles: false)
            } else {
                clearTransientEvent()
            }
        case .tapped:
            runTransientFeedback(duration: 0.45, particles: false, keepDisplayState: true)
        case .dragged:
            clearTransientEvent(after: 0.2)
        }

        profileStore.save(profile)
    }

    private func restoredPosition(in size: CGSize, safeArea: EdgeInsetsValue) -> CGPoint {
        if profile.isMinimized {
            return MateBoundsCalculator.minimizedPosition(edge: .left, in: size, safeArea: safeArea, characterSize: metrics.minimizedSize, metrics: metrics)
        }
        if let normalized = profile.normalizedPosition, size.width > 0, size.height > 0 {
            return MateBoundsCalculator.clampedPosition(
                CGPoint(x: normalized.x * size.width, y: normalized.y * size.height),
                in: size,
                safeArea: safeArea,
                characterSize: metrics.normalSize,
                metrics: metrics
            )
        }
        return MateBoundsCalculator.defaultPosition(in: size, safeArea: safeArea, characterSize: metrics.normalSize, metrics: metrics)
    }

    private func persistPosition() {
        guard containerSize.width > 0, containerSize.height > 0 else { return }
        profile.normalizedPosition = CGPoint(
            x: position.x / containerSize.width,
            y: position.y / containerSize.height
        )
        profileStore.save(profile)
    }

    private func applyGrowthReward(for event: MateEvent) -> Bool {
        let reward = growthPolicy.reward(for: event)
        guard reward > 0 else { return false }
        let previousStage = profile.growthStage
        var updated = profile
        if event == .taskCompleted || event == .importantTaskCompleted || event == .dailyPlanCompleted {
            updated.completedTaskCount += 1
        }
        profile = growthPolicy.profile(afterAdding: reward, to: updated)
        return previousStage != profile.growthStage
    }

    private func applyMood(for event: MateEvent) {
        switch event {
        case .schedulePlanningStarted:
            mood = .thinking
        case .taskCompleted, .schedulePlanningCompleted, .appOpened, .tapped:
            mood = .happy
        case .importantTaskCompleted, .dailyPlanCompleted, .growthStageChanged:
            mood = .celebrating
        case .taskOverdue:
            mood = .curious
        case .dragged:
            break
        }
    }

    private func applyHaptic(for event: MateEvent) {
        switch event {
        case .tapped:
            haptics.impact(.light)
        case .dragged:
            haptics.impact(.light)
        case .taskCompleted, .schedulePlanningCompleted:
            haptics.notification(.success)
        case .importantTaskCompleted, .dailyPlanCompleted, .growthStageChanged:
            haptics.notification(.success)
            haptics.impact(.rigid)
        default:
            break
        }
    }

    private func runTransientFeedback(duration: Double, particles: Bool, keepDisplayState: Bool = false) {
        isFeedbackAnimationPlaying = true
        if !keepDisplayState {
            displayState = .reacting
        }
        if particles {
            particleBurstID = UUID()
        }
        clearTransientEvent(after: duration)
    }

    private func clearTransientEvent(after seconds: Double = 0) {
        animationTask = Task { [weak self] in
            if seconds > 0 {
                try? await Task.sleep(for: .seconds(seconds))
            }
            guard !Task.isCancelled else { return }
            self?.clearTransientEvent()
        }
    }

    private func clearTransientEvent() {
        currentEvent = nil
        isFeedbackAnimationPlaying = false
        isGlowActive = false
        if !isThinking {
            mood = isMenuExpanded ? .happy : .idle
            if displayState == .reacting || displayState == .expanded {
                displayState = isMenuExpanded ? .expanded : .normal
            }
        }
        activeEventPriority = 0
    }

    private func shouldPlayOpenAnimation() -> Bool {
        guard let last = profile.lastInteractionDate else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    private func playIdle(_ motion: MateIdleMotion) {
        guard !isDragging, !isMenuExpanded, displayState != .minimized, !isFeedbackAnimationPlaying else { return }
        activeIdleMotion = motion
        if motion == .blink {
            mood = .happy
        } else if motion == .tilt {
            mood = .curious
        }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.activeIdleMotion = nil
                if self?.isThinking == false {
                    self?.mood = .idle
                }
            }
        }
    }
}
