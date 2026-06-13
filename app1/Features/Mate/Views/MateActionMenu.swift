import SwiftUI

struct MateActionMenu: View {
    var edge: MateHorizontalEdge
    var isNearTop: Bool
    var onAction: (MateAction) -> Void

    private let actions: [MateAction] = [.chat, .smartPlanning, .minimize]

    var body: some View {
        ZStack {
            ForEach(Array(actions.enumerated()), id: \.element.iconName) { index, action in
                MateActionButton(action: action) {
                    onAction(action)
                }
                .offset(offset(for: index))
                .transition(.scale(scale: 0.2).combined(with: .opacity))
                .animation(
                    .spring(response: 0.34, dampingFraction: 0.72).delay(Double(index) * 0.055),
                    value: edge.rawValue + String(isNearTop)
                )
            }
        }
        .allowsHitTesting(true)
    }

    private func offset(for index: Int) -> CGSize {
        let direction: CGFloat = edge == .right ? -1 : 1
        let vertical: CGFloat = isNearTop ? 1 : -1
        let offsets: [CGSize] = [
            CGSize(width: direction * 76, height: vertical * 12),
            CGSize(width: direction * 62, height: vertical * 66),
            CGSize(width: direction * 12, height: vertical * 88)
        ]
        return offsets[index]
    }
}
