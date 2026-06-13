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
    @State private var didRequestBackendMindMap = false
    @State private var isLoadingBackendMindMap = false
    @State private var expandingBackendNodeIDs: Set<String> = []

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
        .task(id: course?.id) {
            await loadBackendMindMapIfAvailable()
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
                RoundedRectangle(cornerRadius: PMRadius.button, style: .continuous)
                    .fill(Color(light: "#312a25", dark: "#161414"))
                RoundedRectangle(cornerRadius: PMRadius.button, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [PMColor.primary.opacity(0.18), .clear, PMColor.warning.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                resourceMediaContent
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(12)
            }
            .frame(height: resourceWindowHeight)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: PMRadius.panel, style: .continuous)
                .fill(PMColor.surfaceRaised)
            RoundedRectangle(cornerRadius: PMRadius.panel, style: .continuous)
                .fill(LinearGradient(colors: [PMColor.primaryMist, .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .clipShape(RoundedRectangle(cornerRadius: PMRadius.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: PMRadius.panel, style: .continuous)
                .strokeBorder(PMColor.hairline, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.055), radius: 12, x: 0, y: 4)
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
        .pathCardStyle(cornerRadius: PMRadius.card, accent: PMColor.primary)
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
                    Text(mindMapSubtitle)
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

            MindMapCanvasView(viewModel: viewModel) { node, canvasSize in
                Task {
                    await expandBackendNodeIfAvailable(node, canvasSize: canvasSize)
                }
            }
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
                .background {
                    RoundedRectangle(cornerRadius: PMRadius.card, style: .continuous)
                        .fill(LinearGradient(colors: [PMColor.primary, PMColor.primaryPressed], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .clipShape(RoundedRectangle(cornerRadius: PMRadius.card, style: .continuous))
                .shadow(color: PMColor.primary.opacity(0.24), radius: 14, x: 0, y: 7)
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
        .pathCardStyle(cornerRadius: PMRadius.panel, accent: PMColor.primary)
    }

    private var breadcrumbTitle: String {
        viewModel.selectedPathText.replacingOccurrences(of: " / ", with: ">")
    }

    private var mediaTitle: String {
        let sourceTitle = selectedResourceMode == .replay ? "视频回放" : "课件预览"
        guard let course else { return sourceTitle }
        return "\(course.name) · \(sourceTitle)"
    }

    private var mindMapSubtitle: String {
        if isLoadingBackendMindMap {
            return "正在从后端同步课件并生成课程知识图谱"
        }
        return course == nil
            ? "点击节点展开分支，确认后进入该知识点学习内容"
            : "围绕 \(course?.name ?? "课程") 的课件、作业和重点知识点展开"
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

    private func loadBackendMindMapIfAvailable() async {
        guard let course, !didRequestBackendMindMap else { return }
        didRequestBackendMindMap = true
        isLoadingBackendMindMap = true
        do {
            let rootNode = try await MindMapBackendClient.shared.loadMindMap(for: course)
            viewModel.replaceRoot(rootNode)
            applyInitialTopicIfNeeded()
            toast = "已接入大模型课程图谱"
        } catch {
            toast = "大模型图谱生成失败：\(error.localizedDescription)"
        }
        isLoadingBackendMindMap = false
    }

    private func expandBackendNodeIfAvailable(_ node: MindNode, canvasSize: CGSize) async {
        guard let course,
              let remoteID = node.remoteID,
              node.tags.contains("可展开"),
              node.children.isEmpty,
              !expandingBackendNodeIDs.contains(remoteID) else {
            return
        }
        expandingBackendNodeIDs.insert(remoteID)
        do {
            let rootNode = try await MindMapBackendClient.shared.expandMindMap(for: course, nodeID: remoteID)
            viewModel.replaceRoot(rootNode, focusingRemoteID: remoteID)
            if let selectedNodeID = viewModel.selectedNodeID {
                viewModel.gentlyCenter(nodeID: selectedNodeID, in: canvasSize)
            }
            toast = "已展开大模型分支"
        } catch {
            // Expansion should not break the existing local graph interaction.
        }
        expandingBackendNodeIDs.remove(remoteID)
    }
}

struct AlgorithmMindMapScreen_Previews: PreviewProvider {
    static var previews: some View {
        AlgorithmMindMapScreen()
    }
}

private final class MindMapBackendClient {
    static let shared = MindMapBackendClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var baseURL: URL {
        URL(string: UserDefaults.standard.string(forKey: "PathMateBackendBaseURL") ?? "http://127.0.0.1:8000")!
    }

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func loadMindMap(for course: Course) async throws -> MindNode {
        let courseID = backendCourseID(for: course)
        try await configureImportedCourse(course, courseID: courseID)
        try await syncMaterials(for: course, courseID: courseID)
        let response: BackendMindMapResponse = try await request(path: "/courses/\(courseID)/mind-map/regenerate", method: "POST", body: Optional<BackendEmptyRequest>.none)
        return try response.toMindNode()
    }

    func expandMindMap(for course: Course, nodeID: String) async throws -> MindNode {
        let courseID = backendCourseID(for: course)
        let body = BackendMindMapExpansionRequest(nodeId: nodeID, requestedDepth: 1)
        let response: BackendMindMapResponse = try await request(path: "/courses/\(courseID)/mind-map/expand", method: "POST", body: body)
        return try response.toMindNode()
    }

    private func configureImportedCourse(_ course: Course, courseID: String) async throws {
        let body = ImportedCoursesBackendRequest(courses: [
            ImportedCourseBackendConfig(id: courseID, name: course.name, semester: course.academicTerm?.shortName ?? "2026-spring")
        ])
        let _: [BackendCourseResponse] = try await request(path: "/courses/imported/zju-learning", method: "POST", body: body)
    }

    private func syncMaterials(for course: Course, courseID: String) async throws {
        let uploadedCount = try await uploadImportedPDFMaterialsIfAvailable(course.materials, courseID: courseID)
        if uploadedCount > 0 {
            return
        }

        let cookieHeader = await ZJULearningMaterialService.cookieHeader()
        let body = SyncMaterialsBackendRequest(
            adapter: "zjuLearning",
            auth: BackendAuthSession(cookieHeader: cookieHeader),
            useBrowserFallback: true
        )
        let _: BackendSyncStats = try await request(path: "/courses/\(courseID)/sync-materials", method: "POST", body: body)
    }

    private func uploadImportedPDFMaterialsIfAvailable(_ materials: [CourseMaterial], courseID: String) async throws -> Int {
        let uploadableMaterials = materials.filter { material in
            material.remoteID != nil
        }
        guard !uploadableMaterials.isEmpty else { return 0 }

        var uploadedCount = 0
        var failures: [String] = []
        for material in uploadableMaterials.prefix(8) {
            do {
                let fileURL = try await ZJULearningMaterialService.download(material)
                let data = try Data(contentsOf: fileURL)
                try await uploadDocument(data, material: material, courseID: courseID)
                uploadedCount += 1
            } catch {
                failures.append("\(material.title): \(error.localizedDescription)")
            }
        }
        if uploadedCount == 0, let firstFailure = failures.first {
            throw MindMapBackendError.message("已导入课件上传失败，\(firstFailure)")
        }
        return uploadedCount
    }

    private func uploadDocument(_ data: Data, material: CourseMaterial, courseID: String) async throws {
        var components = URLComponents(url: backendURL(path: "/courses/\(courseID)/documents/imported"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "title", value: material.title),
            URLQueryItem(name: "sourceUrl", value: materialSourceURL(for: material))
        ]
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.timeoutInterval = 90
        request.httpBody = data
        request.setValue(contentType(for: material), forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let _: BackendCourseDocumentResponse = try await perform(request)
    }

    private func contentType(for material: CourseMaterial) -> String {
        let title = material.title.lowercased()
        if title.hasSuffix(".pdf") {
            return "application/pdf"
        }
        if title.hasSuffix(".pptx") {
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        }
        if title.hasSuffix(".docx") {
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        }
        return "application/octet-stream"
    }

    private func materialSourceURL(for material: CourseMaterial) -> String {
        if let remoteID = material.remoteID {
            return "https://courses.zju.edu.cn/api/uploads/\(remoteID)/blob"
        }
        if let referenceID = material.remoteReferenceID {
            return "https://courses.zju.edu.cn/api/uploads/reference/\(referenceID)/blob"
        }
        return "https://courses.zju.edu.cn/materials/\(material.id.uuidString.lowercased()).pdf"
    }

    private func request<Response: Decodable>(path: String) async throws -> Response {
        var request = URLRequest(url: backendURL(path: path))
        request.httpMethod = "GET"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request)
    }

    private func request<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        var request = URLRequest(url: backendURL(path: path))
        request.httpMethod = method
        request.timeoutInterval = 60
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request)
    }

    private func perform<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = (try? decoder.decode(BackendErrorResponse.self, from: data).message)
            throw MindMapBackendError.httpStatus(httpResponse.statusCode, message)
        }
        return try decoder.decode(Response.self, from: data)
    }

    private func backendURL(path: String) -> URL {
        baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
    }

    private func backendCourseID(for course: Course) -> String {
        course.id.uuidString.lowercased()
    }
}

private enum MindMapBackendError: Error {
    case httpStatus(Int, String?)
    case malformedTree
    case message(String)
}

extension MindMapBackendError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case let .httpStatus(status, message):
            if let message, !message.isEmpty {
                return "HTTP \(status)：\(message)"
            }
            return "HTTP \(status)"
        case .malformedTree:
            return "后端返回的思维导图结构不完整"
        case let .message(message):
            return message
        }
    }
}

private struct ImportedCoursesBackendRequest: Encodable {
    var courses: [ImportedCourseBackendConfig]
}

private struct ImportedCourseBackendConfig: Encodable {
    var id: String
    var name: String
    var semester: String
}

private struct BackendAuthSession: Encodable {
    var cookieHeader: String?
}

private struct SyncMaterialsBackendRequest: Encodable {
    var adapter: String
    var auth: BackendAuthSession?
    var useBrowserFallback: Bool
}

private struct BackendCourseResponse: Decodable {
    var id: String
}

private struct BackendEmptyRequest: Encodable {}

private struct BackendSyncStats: Decodable {
    var courseId: String
    var discovered: Int
}

private struct BackendCourseDocumentResponse: Decodable {
    var id: String
}

private struct BackendErrorResponse: Decodable {
    var detail: BackendErrorDetail

    var message: String {
        detail.message
    }
}

private enum BackendErrorDetail: Decodable {
    case string(String)
    case object(String)

    var message: String {
        switch self {
        case let .string(value):
            return value
        case let .object(value):
            return value
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        if let object = try? container.decode([String: String].self),
           let message = object["message"] ?? object["detail"] {
            self = .object(message)
            return
        }
        self = .object("后端请求失败")
    }
}

private struct BackendMindMapExpansionRequest: Encodable {
    var nodeId: String
    var requestedDepth: Int
}

private struct BackendMindMapResponse: Decodable {
    var courseId: String
    var title: String
    var rootNodeId: String
    var nodes: [BackendMindMapNode]
    var edges: [BackendMindMapEdge]

    func toMindNode() throws -> MindNode {
        let grouped = Dictionary(grouping: nodes) { $0.parentId }
        guard let root = nodes.first(where: { $0.id == rootNodeId }) ?? grouped[nil]?.first else {
            throw MindMapBackendError.malformedTree
        }
        return buildNode(root, grouped: grouped).assigningHierarchy(level: 0, parentID: nil)
    }

    private func buildNode(_ node: BackendMindMapNode, grouped: [String?: [BackendMindMapNode]]) -> MindNode {
        let children = grouped[node.id, default: []]
            .sorted { $0.importance > $1.importance }
            .map { buildNode($0, grouped: grouped) }
        var tags = [node.type, node.evidenceLevel]
        if node.hasMoreChildren {
            tags.append("可展开")
        }
        return MindNode(
            title: node.title,
            summary: node.summary,
            tags: tags,
            children: children,
            remoteID: node.id
        )
    }
}

private struct BackendMindMapNode: Decodable {
    var id: String
    var parentId: String?
    var title: String
    var summary: String
    var type: String
    var depth: Int
    var importance: Double
    var hasMoreChildren: Bool
    var evidenceLevel: String
    var sourceRefs: [BackendMindMapSourceReference]
}

private struct BackendMindMapSourceReference: Decodable {
    var documentId: String
    var documentTitle: String
    var sourceUrl: String
    var page: Int?
    var chunkId: String?
}

private struct BackendMindMapEdge: Decodable {
    var id: String
    var from: String
    var to: String
    var relation: String
}
