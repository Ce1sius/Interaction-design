import SwiftUI

private struct MateActionsKey: EnvironmentKey {
    static let defaultValue = MateActions.noop
}

extension EnvironmentValues {
    var mateActions: MateActions {
        get { self[MateActionsKey.self] }
        set { self[MateActionsKey.self] = newValue }
    }
}
