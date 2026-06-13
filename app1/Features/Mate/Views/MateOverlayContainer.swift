import SwiftUI

struct MateOverlayContainer<Content: View>: View {
    @ObservedObject var viewModel: MateViewModel
    var actions: MateActions
    @ViewBuilder var content: () -> Content
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                content()
                    .zIndex(0)

                if viewModel.isMenuExpanded {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                viewModel.collapseMenu()
                            }
                        }
                        .zIndex(9998)
                }

                MateFloatingView(viewModel: viewModel, actions: actions)
                    .position(viewModel.position)
                    .animation(.spring(response: viewModel.metrics.snapAnimationResponse, dampingFraction: viewModel.metrics.snapAnimationDamping), value: viewModel.position)
                    .zIndex(9999)
            }
            .onAppear {
                viewModel.updateGeometry(size: proxy.size, safeArea: EdgeInsetsValue(proxy.safeAreaInsets))
                viewModel.startIdleAnimations()
                viewModel.handle(event: .appOpened)
            }
            .onDisappear {
                viewModel.stopIdleAnimations()
            }
            .onChange(of: proxy.size) { _, newValue in
                viewModel.updateGeometry(size: newValue, safeArea: EdgeInsetsValue(proxy.safeAreaInsets))
            }
            .onChange(of: proxy.safeAreaInsets) { _, newValue in
                viewModel.updateGeometry(size: proxy.size, safeArea: EdgeInsetsValue(newValue))
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    viewModel.startIdleAnimations()
                case .background, .inactive:
                    viewModel.stopIdleAnimations()
                @unknown default:
                    break
                }
            }
        }
    }
}

private extension EdgeInsetsValue {
    init(_ insets: EdgeInsets) {
        self.init(top: insets.top, leading: insets.leading, bottom: insets.bottom, trailing: insets.trailing)
    }
}

struct MateOverlayContainer_Previews: PreviewProvider {
    static var previews: some View {
        MateOverlayContainer(viewModel: MateViewModel(), actions: .noop) {
            Color(hex: "#fafaf9").ignoresSafeArea()
        }
    }
}
