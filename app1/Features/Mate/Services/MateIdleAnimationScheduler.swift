import Foundation

enum MateIdleMotion: CaseIterable {
    case breathe
    case float
    case tilt
    case blink
    case observe
}

@MainActor
final class MateIdleAnimationScheduler {
    private var task: Task<Void, Never>?
    private var lastMotions: [MateIdleMotion] = []
    var onMotion: ((MateIdleMotion) -> Void)?

    func start() {
        stop()
        task = Task { [weak self] in
            while !Task.isCancelled {
                let seconds = Double.random(in: 6...12)
                try? await Task.sleep(for: .seconds(seconds))
                guard !Task.isCancelled else { break }
                self?.emitNextMotion()
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func emitNextMotion() {
        let motion = nextMotion()
        lastMotions.append(motion)
        if lastMotions.count > 3 {
            lastMotions.removeFirst()
        }
        onMotion?(motion)
    }

    private func nextMotion() -> MateIdleMotion {
        let repeated = lastMotions.count >= 2 && Set(lastMotions.suffix(2)).count == 1 ? lastMotions.last : nil
        let candidates = MateIdleMotion.allCases.filter { $0 != repeated }
        return candidates.randomElement() ?? .breathe
    }
}
