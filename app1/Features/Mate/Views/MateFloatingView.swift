import SwiftUI

struct MateFloatingView: View {
    @ObservedObject var viewModel: MateViewModel
    var actions: MateActions

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if viewModel.displayState == .minimized {
                MateMinimizedView(
                    assetName: viewModel.currentAssetName,
                    size: viewModel.metrics.minimizedSize,
                    visibleHeight: viewModel.metrics.minimizedVisibleHeight
                ) {
                    viewModel.restoreFromMinimized()
                }
            } else {
                MateParticleView(triggerID: viewModel.particleBurstID, reduceMotion: reduceMotion)
                if viewModel.isThinking {
                    thinkingDots
                }
                character
                if viewModel.isMenuExpanded {
                    MateActionMenu(edge: viewModel.currentEdge, isNearTop: viewModel.position.y < 170) { action in
                        perform(action)
                    }
                }
            }
        }
        .frame(width: touchFrameSize, height: touchFrameSize)
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .onTapGesture {
            viewModel.toggleMenu()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mate 智能学习伙伴")
        .accessibilityValue(accessibilityValue)
    }

    private var character: some View {
        MateCharacterView(
            assetName: viewModel.currentAssetName,
            size: viewModel.characterSize,
            isGlowActive: viewModel.isGlowActive
        )
        .scaleEffect(scale)
        .offset(y: idleYOffset + reactionYOffset)
        .rotationEffect(.degrees(rotationDegrees))
        .shadow(color: .black.opacity(viewModel.isDragging ? 0.22 : 0.1), radius: viewModel.isDragging ? 18 : 10, x: 0, y: viewModel.isDragging ? 10 : 5)
        .animation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.28, dampingFraction: 0.7), value: viewModel.displayState)
        .animation(reduceMotion ? .easeOut(duration: 0.16) : .easeInOut(duration: 0.65), value: viewModel.activeIdleMotion)
        .animation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.32, dampingFraction: 0.62), value: viewModel.isDragging)
    }

    private var thinkingDots: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color(hex: "#2488ff").opacity(0.6))
                    .frame(width: 8, height: 8)
                    .offset(x: CGFloat(index - 1) * 16, y: -62)
                    .scaleEffect(reduceMotion ? 1 : 0.85)
                    .opacity(0.8)
            }
        }
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                if !viewModel.isDragging {
                    viewModel.beginDrag()
                }
                viewModel.dragChanged(translation: value.translation)
            }
            .onEnded { value in
                withAnimation(.spring(response: viewModel.metrics.snapAnimationResponse, dampingFraction: viewModel.metrics.snapAnimationDamping)) {
                    viewModel.endDrag(predictedTranslation: value.predictedEndTranslation)
                }
            }
    }

    private var touchFrameSize: CGFloat {
        if viewModel.displayState == .minimized {
            return max(viewModel.metrics.minimizedTouchFrameSize, viewModel.metrics.minimizedSize + 8)
        }
        return max(170, viewModel.metrics.expandedSize + viewModel.metrics.menuRadius)
    }

    private var scale: CGFloat {
        if viewModel.isDragging { return 0.96 }
        if viewModel.displayState == .expanded { return 1.08 }
        if viewModel.currentEvent == .tapped { return 0.94 }
        if viewModel.activeIdleMotion == .breathe && !reduceMotion { return 1.025 }
        return 1
    }

    private var idleYOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        return viewModel.activeIdleMotion == .float ? -5 : 0
    }

    private var reactionYOffset: CGFloat {
        guard !reduceMotion else { return 0 }
        switch viewModel.currentEvent {
        case .taskCompleted, .importantTaskCompleted, .dailyPlanCompleted, .schedulePlanningCompleted, .growthStageChanged:
            return -14
        default:
            return 0
        }
    }

    private var rotationDegrees: Double {
        guard !reduceMotion else { return 0 }
        if viewModel.isDragging {
            return viewModel.currentEdge == .right ? 6 : -6
        }
        switch viewModel.activeIdleMotion {
        case .tilt:
            return viewModel.currentEdge == .right ? -6 : 6
        case .observe:
            return viewModel.currentEdge == .right ? 4 : -4
        default:
            return 0
        }
    }

    private var accessibilityValue: String {
        if viewModel.isMenuExpanded { return "菜单已展开" }
        if viewModel.isThinking { return "正在规划日程" }
        if viewModel.displayState == .minimized { return "已最小化" }
        return "待机中"
    }

    private func perform(_ action: MateAction) {
        switch action {
        case .chat:
            viewModel.collapseMenu()
            actions.openChat()
        case .smartPlanning:
            viewModel.collapseMenu()
            viewModel.handle(event: .schedulePlanningStarted)
            actions.openSmartPlanner()
        case .minimize:
            actions.minimize()
            viewModel.minimize()
        }
    }
}
