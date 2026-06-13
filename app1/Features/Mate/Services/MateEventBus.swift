import Combine
import Foundation

@MainActor
final class MateEventBus: ObservableObject {
    private weak var viewModel: MateViewModel?

    func bind(_ viewModel: MateViewModel) {
        self.viewModel = viewModel
    }

    func send(_ event: MateEvent) {
        viewModel?.handle(event: event)
    }
}
