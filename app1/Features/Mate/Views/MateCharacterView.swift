import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct MateCharacterView: View {
    var assetName: String
    var size: CGFloat
    var isGlowActive: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#fff6b8"), Color(hex: "#fffdf0")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.75), lineWidth: 2)
                }
                .shadow(color: Color(hex: "#ffcc00").opacity(isGlowActive ? 0.38 : 0.18), radius: isGlowActive ? 24 : 12, x: 0, y: 8)

            if assetExists {
                StaticImageMateRenderer().makeBody(assetName: assetName, size: size * 0.92)
                    .padding(size * 0.04)
                    .clipShape(Circle())
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isGlowActive ? 1.06 : 1)
        .animation(.easeInOut(duration: 0.7), value: isGlowActive)
    }

    private var placeholder: some View {
        VStack(spacing: 3) {
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.25, weight: .semibold))
            Text("Mate")
                .font(.system(size: size * 0.16, weight: .bold))
        }
        .foregroundStyle(Color(hex: "#c58b00"))
    }

    private var assetExists: Bool {
        #if canImport(UIKit)
        return UIImage(named: assetName) != nil
        #else
        return true
        #endif
    }
}

struct MateCharacterView_Previews: PreviewProvider {
    static var previews: some View {
        MateCharacterView(assetName: "MateChildWink", size: 96, isGlowActive: false)
            .padding()
    }
}
