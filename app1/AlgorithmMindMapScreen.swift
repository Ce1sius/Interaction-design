import SwiftUI

struct AlgorithmMindMapScreen: View {
    private enum ResourceMode: String, CaseIterable, Identifiable {
        case courseware = "课件"
        case replay = "回放"

        var id: String { rawValue }
    }

    private let course: Course?
    private let initialTopicTitle: String?

    @StateObject private var viewModel: MindMapViewModel
    @State private var selectedResourceMode: ResourceMode = .replay
    @State private var isMindMapExpanded = true
    @State private var isResourceHeaderCollapsed = false
    @State private var selectedPracticeResource: PracticeResource?
    @State private var didApplyInitialTopic = false
    @State private var inlinePreviewItem: CourseMaterialPreviewItem?
    @State private var downloadingMaterialID: UUID?
    @State private var toast: String?

    init(course: Course? = nil, initialTopicTitle: String? = nil) {
        self.course = course
        self.initialTopicTitle = initialTopicTitle
        let rootNode = course.map { MindNode.courseTree(for: $0) } ?? MindNode.algorithmTree()
        _viewModel = StateObject(wrappedValue: MindMapViewModel(rootNode: rootNode))
    }

    var body: some View {
        ZStack {
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

            if let selectedPracticeResource {
                practiceResourceOverlay(selectedPracticeResource)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .background(PMColor.softCanvas.ignoresSafeArea())
        .navigationTitle(course == nil ? "图谱" : "\(course?.name ?? "")辅学")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            applyInitialTopicIfNeeded()
        }
        .onChange(of: selectedResourceMode) { _, mode in
            if mode != .courseware {
                inlinePreviewItem = nil
            }
        }
        .toast($toast)
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

            Text(course == nil ? "课程章节（包含哪些知识点）" : "\(course?.name ?? "")章节（包含哪些知识点）")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PMColor.ink)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(light: "#3d302f", dark: "#211b1b"))
                resourceMediaContent
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(12)
            }
            .frame(height: resourceWindowHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(light: "#dedede", dark: "#1e1e20"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var collapsedResourceHeader: some View {
        HStack(spacing: 10) {
            Text(course == nil ? "课件 / 回放" : "\(course?.name ?? "")课件 / 回放")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PMColor.steel)
                .lineLimit(1)
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
                    Text(course == nil ? "点击节点展开分支，确认后进入该知识点学习内容" : "围绕 \(course?.name ?? "课程") 的课件、作业和重点知识点展开")
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
                    detail: KnowledgeRepository.detail(for: viewModel.selectedNode, path: viewModel.selectedPathText, course: course),
                    relatedNodes: viewModel.selectedGraphRelatedNodes
                ) { title in
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        viewModel.jumpToNode(title: title)
                    }
                } onPracticeResourceTap: { resource in
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        selectedPracticeResource = resource
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func practiceResourceOverlay(_ resource: PracticeResource) -> some View {
        ZStack {
            PMColor.softCanvas
                .ignoresSafeArea()

            PracticeResourceDetailPage(resource: resource) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    selectedPracticeResource = nil
                }
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

    private var mediaTitle: String {
        let sourceTitle = selectedResourceMode == .replay ? "视频回放" : "课件预览"
        guard let course else { return sourceTitle }
        return "\(course.name) · \(sourceTitle)"
    }

    private var resourceWindowHeight: CGFloat {
        selectedResourceMode == .courseware && inlinePreviewItem != nil ? 260 : 118
    }

    @ViewBuilder
    private var resourceMediaContent: some View {
        if selectedResourceMode == .courseware,
           let inlinePreviewItem {
            inlineCoursewarePreview(inlinePreviewItem)
        } else if selectedResourceMode == .courseware,
           let course,
           !course.materials.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.richtext.fill")
                    Text("\(course.name) · 真实课件")
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Spacer()
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(course.materials.prefix(8)) { material in
                            coursewareChip(material)
                        }
                    }
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: selectedResourceMode == .replay ? "play.rectangle.fill" : "doc.richtext.fill")
                    .font(.system(size: 26, weight: .semibold))
                Text(mediaTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
        }
    }

    private func inlineCoursewarePreview(_ item: CourseMaterialPreviewItem) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "doc.text.magnifyingglass")
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        inlinePreviewItem = nil
                    }
                } label: {
                    Label("返回课件", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("返回课件列表")
            }
            .foregroundStyle(.white.opacity(0.92))

            CourseMaterialQuickLook(item: item)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func coursewareChip(_ material: CourseMaterial) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(material.title)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(2)
                .frame(width: 126, alignment: .leading)
            HStack(spacing: 6) {
                Button {
                    preview(material)
                } label: {
                    Text("预览")
                }
                .buttonStyle(.borderedProminent)
                .tint(.white.opacity(0.2))
                .disabled(downloadingMaterialID != nil)

                Button {
                    download(material)
                } label: {
                    if downloadingMaterialID == material.id {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Text(isMaterialCached(material) ? "已下" : "下载")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.white.opacity(0.75))
                .disabled(downloadingMaterialID != nil || material.remoteID == nil)
            }
            .font(.system(size: 11, weight: .semibold))
        }
        .padding(8)
        .frame(width: 142, height: 82, alignment: .leading)
        .background(.white.opacity(0.13))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func download(_ material: CourseMaterial) {
        guard material.remoteID != nil else {
            toast = "该课件没有远端下载地址。"
            return
        }
        guard downloadingMaterialID == nil else { return }
        downloadingMaterialID = material.id
        Task {
            do {
                let fileURL = try await ZJULearningMaterialService.download(material)
                downloadingMaterialID = nil
                toast = "已下载到 \(fileURL.lastPathComponent)"
            } catch {
                downloadingMaterialID = nil
                toast = error.localizedDescription
            }
        }
    }

    private func isMaterialCached(_ material: CourseMaterial) -> Bool {
        ZJULearningMaterialService.cachedFileURL(for: material) != nil
    }

    private func preview(_ material: CourseMaterial) {
        if let fileURL = ZJULearningMaterialService.cachedFileURL(for: material) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                inlinePreviewItem = CourseMaterialPreviewItem(url: fileURL, title: material.title)
            }
            return
        }
        guard material.remoteID != nil else {
            toast = "该课件还没有本地文件，无法预览。"
            return
        }
        guard downloadingMaterialID == nil else { return }
        downloadingMaterialID = material.id
        Task {
            do {
                let fileURL = try await ZJULearningMaterialService.download(material)
                downloadingMaterialID = nil
                withAnimation(.spring(response: 0.3, dampingFraction: 0.88)) {
                    inlinePreviewItem = CourseMaterialPreviewItem(url: fileURL, title: material.title)
                }
            } catch {
                downloadingMaterialID = nil
                toast = error.localizedDescription
            }
        }
    }

    private func applyInitialTopicIfNeeded() {
        guard !didApplyInitialTopic else { return }
        didApplyInitialTopic = true
        guard let initialTopicTitle else { return }
        viewModel.jumpToNode(title: initialTopicTitle)
        isMindMapExpanded = false
    }
}

struct AlgorithmMindMapScreen_Previews: PreviewProvider {
    static var previews: some View {
        AlgorithmMindMapScreen()
    }
}
