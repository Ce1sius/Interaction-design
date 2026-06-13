import SwiftUI

struct MateActionButton: View {
    var action: MateAction
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: action.iconName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color(hex: "#7b5a00"))
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(Color.white.opacity(0.78), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.14), radius: 9, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.accessibilityLabel)
        .accessibilityHint(action.accessibilityHint)
    }
}
