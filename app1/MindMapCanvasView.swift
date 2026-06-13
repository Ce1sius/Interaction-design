import SwiftUI

struct MindMapCanvasView: View {
    @ObservedObject var viewModel: MindMapViewModel
    var onNodeSelected: ((MindNode, CGSize) -> Void)?
    @State private var lastOffset: CGSize
    @State private var lastScale: CGFloat

    init(viewModel: MindMapViewModel, onNodeSelected: ((MindNode, CGSize) -> Void)? = nil) {
        self.viewModel = viewModel
        self.onNodeSelected = onNodeSelected
        _lastOffset = State(initialValue: viewModel.offset)
        _lastScale = State(initialValue: viewModel.scale)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Canvas { context, size in
                    drawBackground(in: &context, size: size)
                    drawEdges(in: &context, size: size)
                }
                .allowsHitTesting(false)

                ForEach(viewModel.visibleNodes) { node in
                    let metrics = nodeMetrics(for: node, in: proxy.size)
                    MindMapNodeButton(
                        node: node,
                        isSelected: viewModel.selectedNodeID == node.id,
                        isFocusedBranch: viewModel.isNodeInFocusedBranch(node),
                        hasChildren: !node.children.isEmpty || node.tags.contains("可展开"),
                        isExpanded: viewModel.expandedNodeIDs.contains(node.id)
                    ) {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            viewModel.selectNode(node)
                            viewModel.gentlyCenter(nodeID: node.id, in: proxy.size)
                        }
                        onNodeSelected?(node, proxy.size)
                    }
                    .scaleEffect(metrics.finalScale)
                    .opacity(metrics.opacity)
                    .position(metrics.screenPosition)
                    .transition(.scale(scale: 0.84).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
            .background(PMColor.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(PMColor.hairline, lineWidth: 1)
            }
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(magnificationGesture)
            .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.visibleNodes.count)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: viewModel.selectedNodeID)
            .onChange(of: viewModel.offset) { _, newOffset in
                lastOffset = newOffset
            }
            .onChange(of: viewModel.scale) { _, newScale in
                lastScale = newScale
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                viewModel.offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = viewModel.offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                viewModel.scale = viewModel.clampedScale(lastScale * value)
            }
            .onEnded { _ in
                lastScale = viewModel.scale
            }
    }

    private func drawBackground(in context: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        context.fill(Path(rect), with: .color(PMColor.surfaceRaised))

        let gridColor = PMColor.hairline.opacity(0.2)
        let step: CGFloat = 42
        var x = viewModel.offset.width.truncatingRemainder(dividingBy: step)
        while x < size.width {
            var line = Path()
            line.move(to: CGPoint(x: x, y: 0))
            line.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(line, with: .color(gridColor), lineWidth: 0.45)
            x += step
        }

        var y = viewModel.offset.height.truncatingRemainder(dividingBy: step)
        while y < size.height {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y))
            line.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(line, with: .color(gridColor), lineWidth: 0.45)
            y += step
        }
    }

    private func drawEdges(in context: inout GraphicsContext, size: CGSize) {
        let nodeByID = Dictionary(uniqueKeysWithValues: viewModel.visibleNodes.map { ($0.id, $0) })
        for edge in viewModel.visibleEdges {
            guard let sourceNode = nodeByID[edge.sourceID],
                  let targetNode = nodeByID[edge.targetID] else {
                continue
            }

            let sourceMetrics = nodeMetrics(for: sourceNode, in: size)
            let targetMetrics = nodeMetrics(for: targetNode, in: size)
            let source = edgeAnchor(for: sourceNode, metrics: sourceMetrics, side: .trailing)
            let target = edgeAnchor(for: targetNode, metrics: targetMetrics, side: .leading)
            let controlDistance = max(54, min(150, abs(target.x - source.x) * 0.52))

            var path = Path()
            path.move(to: source)
            path.addCurve(
                to: target,
                control1: CGPoint(x: source.x + controlDistance, y: source.y),
                control2: CGPoint(x: target.x - controlDistance, y: target.y)
            )

            let isFocused = viewModel.isEdgeInFocusedBranch(edge)
            let distanceOpacity = edgeOpacity(for: source, target: target, in: size)
            let opacity = (isFocused ? 0.78 : 0.14) * distanceOpacity
            let lineWidth = (isFocused ? 2.4 : 1.05) * min(max(viewModel.scale, 0.7), 1.35)
            if isFocused {
                context.stroke(
                    path,
                    with: .color(edgeColor(for: sourceNode).opacity(0.12 * distanceOpacity)),
                    style: StrokeStyle(lineWidth: lineWidth + 5, lineCap: .round, lineJoin: .round)
                )
            }
            context.stroke(
                path,
                with: .color((isFocused ? edgeColor(for: sourceNode) : PMColor.muted).opacity(opacity)),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            )

            drawConnectorDot(at: source, color: edgeColor(for: sourceNode), opacity: isFocused ? 0.92 : 0.24, in: &context)
            drawConnectorDot(at: target, color: edgeColor(for: targetNode), opacity: isFocused ? 0.72 : 0.18, in: &context)
        }
    }

    private func nodeMetrics(for node: MindNode, in size: CGSize) -> NodeRenderMetrics {
        let screenPosition = screenPoint(for: node.position)
        let distance = hypot(screenPosition.x - size.width / 2, screenPosition.y - size.height / 2)
        let centerScale = max(0.75, min(1.35, 1.35 - distance / 700))
        let centerOpacity = max(0.35, min(1.0, 1.15 - distance / 700))
        let selectedBoost: CGFloat = viewModel.selectedNodeID == node.id ? 1.08 : 1
        let branchScale: CGFloat = viewModel.isNodeInFocusedBranch(node) ? 1 : 0.96
        let branchOpacity: CGFloat = viewModel.isNodeInFocusedBranch(node) ? 1 : 0.34
        return NodeRenderMetrics(
            screenPosition: screenPosition,
            finalScale: viewModel.scale * centerScale * selectedBoost * branchScale,
            opacity: centerOpacity * branchOpacity
        )
    }

    private func screenPoint(for worldPosition: CGPoint) -> CGPoint {
        CGPoint(
            x: worldPosition.x * viewModel.scale + viewModel.offset.width,
            y: worldPosition.y * viewModel.scale + viewModel.offset.height
        )
    }

    private func edgeOpacity(for source: CGPoint, target: CGPoint, in size: CGSize) -> CGFloat {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let mid = CGPoint(x: (source.x + target.x) / 2, y: (source.y + target.y) / 2)
        let distance = hypot(mid.x - center.x, mid.y - center.y)
        return max(0.35, min(1, 1.15 - distance / 760))
    }

    private func edgeAnchor(for node: MindNode, metrics: NodeRenderMetrics, side: EdgeAnchorSide) -> CGPoint {
        let halfWidth = nodeBaseWidth(for: node) * metrics.finalScale / 2
        let padding: CGFloat = 8
        switch side {
        case .leading:
            return CGPoint(x: metrics.screenPosition.x - halfWidth - padding, y: metrics.screenPosition.y)
        case .trailing:
            return CGPoint(x: metrics.screenPosition.x + halfWidth + padding, y: metrics.screenPosition.y)
        }
    }

    private func nodeBaseWidth(for node: MindNode) -> CGFloat {
        let estimatedTextWidth = CGFloat(node.title.count) * 15 + 54
        return min(152, max(112, estimatedTextWidth))
    }

    private func edgeColor(for node: MindNode) -> Color {
        switch node.level {
        case 0: return PMColor.primary
        case 1: return PMColor.success
        case 2: return PMColor.warning
        default: return PMColor.goal
        }
    }

    private func drawConnectorDot(at point: CGPoint, color: Color, opacity: CGFloat, in context: inout GraphicsContext) {
        let rect = CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7)
        context.fill(Path(ellipseIn: rect), with: .color(color.opacity(opacity)))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: -1.2, dy: -1.2)), with: .color(color.opacity(opacity * 0.18)), lineWidth: 2)
    }
}

private struct NodeRenderMetrics {
    var screenPosition: CGPoint
    var finalScale: CGFloat
    var opacity: CGFloat
}

private enum EdgeAnchorSide {
    case leading
    case trailing
}

private struct MindMapNodeButton: View {
    var node: MindNode
    var isSelected: Bool
    var isFocusedBranch: Bool
    var hasChildren: Bool
    var isExpanded: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Circle()
                    .fill(levelColor)
                    .frame(width: 8, height: 8)

                Text(node.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .white : PMColor.charcoal)

                if hasChildren {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : PMColor.primary)
                }
            }
            .frame(minWidth: 92, maxWidth: 132, minHeight: 36)
            .padding(.horizontal, 10)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(borderColor, lineWidth: isSelected ? 1.5 : 1)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.16 : 0.08))
                    .frame(height: 16)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
                    .allowsHitTesting(false)
            }
            .shadow(color: shadowColor, radius: isSelected ? 16 : 8, x: 0, y: isSelected ? 7 : 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(node.title)
    }

    private var background: Color {
        if isSelected {
            return PMColor.primary
        }
        return isFocusedBranch ? PMColor.canvas.opacity(0.96) : PMColor.surface.opacity(0.88)
    }

    private var borderColor: Color {
        if isSelected {
            return PMColor.primaryPressed.opacity(0.65)
        }
        return isFocusedBranch ? PMColor.primary.opacity(0.28) : PMColor.hairline
    }

    private var levelColor: Color {
        switch node.level {
        case 0: return PMColor.primary
        case 1: return PMColor.success
        case 2: return PMColor.warning
        default: return PMColor.goal
        }
    }

    private var shadowColor: Color {
        if isSelected {
            return PMColor.primary.opacity(0.28)
        }
        return .black.opacity(isFocusedBranch ? 0.08 : 0.03)
    }
}
