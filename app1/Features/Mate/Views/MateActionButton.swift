import SwiftUI

struct MateActionButton: View {
    var action: MateAction
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Image(systemName: action.iconName)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 48, height: 48)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .fill(tint.opacity(0.12))
                }
                .clipShape(Circle())
                .overlay {
                    Circle().stroke(PMColor.hairline.opacity(0.92), lineWidth: 1)
                }
                .shadow(color: tint.opacity(0.16), radius: 10, x: 0, y: 5)
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.accessibilityLabel)
        .accessibilityHint(action.accessibilityHint)
    }

    private var tint: Color {
        switch action {
        case .chat:
            return PMColor.primary
        case .smartPlanning:
            return PMColor.warning
        case .minimize:
            return PMColor.steel
        }
    }
}
