import SwiftUI

struct MateParticleView: View {
    var triggerID: UUID?
    var reduceMotion: Bool

    @State private var isActive = false

    var body: some View {
        ZStack {
            if isActive && !reduceMotion {
                ForEach(0..<14, id: \.self) { index in
                    Circle()
                        .fill(particleColor(index).opacity(0.75))
                        .frame(width: CGFloat.random(in: 5...9), height: CGFloat.random(in: 5...9))
                        .offset(isActive ? burstOffset(index) : .zero)
                        .opacity(isActive ? 0 : 1)
                        .scaleEffect(isActive ? 0.25 : 1)
                        .animation(.easeOut(duration: 0.9).delay(Double(index) * 0.018), value: isActive)
                }
            }
        }
        .frame(width: 170, height: 170)
        .allowsHitTesting(false)
        .onChange(of: triggerID) { _, newValue in
            guard newValue != nil else { return }
            isActive = false
            DispatchQueue.main.async {
                isActive = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isActive = false
                }
            }
        }
    }

    private func burstOffset(_ index: Int) -> CGSize {
        let angle = Double(index) / 14.0 * Double.pi * 2
        let radius = CGFloat(42 + (index % 4) * 12)
        return CGSize(width: cos(angle) * radius, height: sin(angle) * radius)
    }

    private func particleColor(_ index: Int) -> Color {
        [Color(hex: "#ffcc00"), Color(hex: "#30d158"), Color(hex: "#2488ff"), Color(hex: "#fff6b8")][index % 4]
    }
}
