import SwiftUI

struct MateMinimizedView: View {
    var assetName: String
    var size: CGFloat
    var visibleHeight: CGFloat
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            MateCharacterView(assetName: assetName, size: size, isGlowActive: false)
                .frame(width: size, height: visibleHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mate 智能学习伙伴")
        .accessibilityValue("已最小化")
        .accessibilityHint("轻点恢复悬浮角色")
    }
}
