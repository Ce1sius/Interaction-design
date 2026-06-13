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
                        colors: [PMColor.studyWarm, PMColor.surfaceRaised, PMColor.agentGlow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Circle()
                        .stroke(PMColor.hairline.opacity(0.72), lineWidth: 1.5)
                }
                .overlay(alignment: .topLeading) {
                    Circle()
                        .fill(.white.opacity(0.32))
                        .frame(width: size * 0.36, height: size * 0.36)
                        .offset(x: size * 0.13, y: size * 0.1)
                        .blur(radius: 5)
                        .allowsHitTesting(false)
                }
                .shadow(color: PMColor.primary.opacity(isGlowActive ? 0.28 : 0.14), radius: isGlowActive ? 26 : 14, x: 0, y: 8)
                .shadow(color: PMColor.warning.opacity(isGlowActive ? 0.2 : 0.1), radius: isGlowActive ? 18 : 10, x: 0, y: 5)

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
        .foregroundStyle(PMColor.warning)
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
