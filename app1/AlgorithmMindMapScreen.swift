import SwiftUI

struct AlgorithmMindMapScreen: View {
    private enum ResourceMode: String, CaseIterable, Identifiable {
        case courseware = "课件"
        case replay = "回放"

        var id: String { rawValue }
    }

    @StateObject private var viewModel = MindMapViewModel()
    @State private var selectedResourceMode: ResourceMode = .replay
    @State private var isMindMapExpanded = true
    @State private var isResourceHeaderCollapsed = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if isResourceHeaderCollapsed {
                    collapsedResourceHeader
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    resourceHeader
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, isResourceHeaderCollapsed ? 6 : 10)

            Divider()
                .overlay(PMColor.hairline)

            lowerLearningArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(PMColor.softCanvas.ignoresSafeArea())
    }

    private var resourceHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Picker("学习资源", selection: $selectedResourceMode) {
                    ForEach(ResourceMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 170)

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        isResourceHeaderCollapsed = true
                    }
                } label: {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(PMColor.steel)
                .accessibilityLabel("收起课件回放栏")
            }

            Text("课程章节（包含哪些知识点）")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PMColor.ink)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(light: "#3d302f", dark: "#211b1b"))
                VStack(spacing: 8) {
                    Image(systemName: selectedResourceMode == .replay ? "play.rectangle.fill" : "doc.richtext.fill")
                        .font(.system(size: 26, weight: .semibold))
                    Text(selectedResourceMode == .replay ? "视频回放" : "课件预览")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.92))
            }
            .frame(height: 118)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(light: "#dedede", dark: "#1e1e20"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var collapsedResourceHeader: some View {
        HStack(spacing: 10) {
            Text("课件 / 回放")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PMColor.steel)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                    isResourceHeaderCollapsed = false
                }
            } label: {
                Image(systemName: "triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .rotationEffect(.degrees(180))
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(PMColor.primary)
            .accessibilityLabel("展开课件回放栏")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(PMColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PMColor.hairline, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var lowerLearningArea: some View {
        if isMindMapExpanded {
            mindMapSelectionArea
                .transition(.asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .scale(scale: 0.18, anchor: .topLeading).combined(with: .opacity)
                ))
        } else {
            knowledgeFocusedArea
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
        }
    }

    private var mindMapSelectionArea: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("动态思维导图")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PMColor.ink)
                    Text("点击节点展开分支，确认后进入该知识点学习内容")
                        .font(.system(size: 12))
                        .foregroundStyle(PMColor.steel)
                }
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.84)) {
                        viewModel.resetView()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
                .tint(PMColor.primary)
                .accessibilityLabel("重置视图")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            MindMapCanvasView(viewModel: viewModel)
                .frame(maxHeight: .infinity)
                .frame(minHeight: 360)
                .padding(.horizontal, 16)

            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    isMindMapExpanded = false
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("确认学习 \(viewModel.selectedNode.title)")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(PMColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .buttonStyle(.plain)
        }
    }

    private var knowledgeFocusedArea: some View {
        VStack(spacing: 0) {
            compactMindMapHeader
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            ScrollView {
                KnowledgeDetailPanel(
                    detail: viewModel.selectedKnowledgeDetail,
                    relatedNodes: viewModel.selectedGraphRelatedNodes
                ) { title in
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        viewModel.jumpToNode(title: title)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var compactMindMapHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    isMindMapExpanded = true
                }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 19, weight: .semibold))
                    Text("图谱")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(PMColor.primary)
                .frame(width: 52, height: 48)
                .background(PMColor.primary.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("展开思维导图")

            VStack(alignment: .leading, spacing: 5) {
                Text(breadcrumbTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PMColor.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Text("当前知识点学习内容")
                    .font(.system(size: 12))
                    .foregroundStyle(PMColor.steel)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(PMColor.surfaceRaised)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PMColor.hairline, lineWidth: 1)
        }
    }

    private var breadcrumbTitle: String {
        viewModel.selectedPathText.replacingOccurrences(of: " / ", with: ">")
    }
}

struct AlgorithmMindMapScreen_Previews: PreviewProvider {
    static var previews: some View {
        AlgorithmMindMapScreen()
    }
}
