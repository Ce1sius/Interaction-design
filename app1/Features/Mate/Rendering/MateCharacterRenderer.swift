import SwiftUI

protocol MateRenderable {
    associatedtype Body: View

    @ViewBuilder
    func makeBody(assetName: String, size: CGFloat) -> Body
}

struct StaticImageMateRenderer: MateRenderable {
    func makeBody(assetName: String, size: CGFloat) -> some View {
        Image(assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
