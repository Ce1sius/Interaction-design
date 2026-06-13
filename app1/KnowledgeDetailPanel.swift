import SwiftUI

struct KnowledgeDetailPanel: View {
    var detail: KnowledgeDetail
    var relatedNodes: [RelatedKnowledgeNode]
    var onRelatedNodeTap: (String) -> Void
    var onPracticeResourceTap: (PracticeResource) -> Void = { _ in }

    @State private var agentQuestion = ""
    @State private var hasRead = false
    @State private var hasPracticed = false
    @State private var markedUnknown = false
    @State private var isFavorited = false
    @State private var addedToReview = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            relatedNodesCard
            overviewCard
            coreConceptsCard
            dynamicDiagramCard
            practiceCard
            faqAgentCard
            learningRecordCard
        }
        .padding(.bottom, 24)
    }

    private var overviewCard: some View {
        detailCard(title: "知识概览", icon: "book.pages.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(detail.title)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(PMColor.ink)
                        Text(detail.path)
                            .font(.system(size: 13))
                            .foregroundStyle(PMColor.steel)
                    }
                    Spacer()
                    DetailTag(title: detail.difficulty, tint: PMColor.primary)
                }

                HStack(spacing: 8) {
                    DetailTag(title: detail.estimatedTime, systemImage: "clock.fill", tint: PMColor.success)
                    DetailTag(title: "Agent 可答疑", systemImage: "sparkles", tint: PMColor.warning)
                }

                bulletList(title: "学习目标", items: detail.goals)
            }
        }
    }

    private var coreConceptsCard: some View {
        detailCard(title: "核心知识", icon: "lightbulb.fill") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(detail.coreConcepts) { concept in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(concept.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(PMColor.charcoal)
                        Text(concept.content)
                            .font(.system(size: 14))
                            .foregroundStyle(PMColor.slate)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var dynamicDiagramCard: some View {
        detailCard(title: "动态图解", icon: "play.rectangle.fill") {
            HStack(spacing: 12) {
                Image(systemName: "arrow.left.and.right")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(PMColor.primary)
                    .frame(width: 44, height: 44)
                    .background(PMColor.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text("查看 left / right / mid 动态变化")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PMColor.charcoal)
                    Text("先以静态入口占位，后续可接入数组指针动画或 Canvas 算法演示。")
                        .font(.system(size: 13))
                        .foregroundStyle(PMColor.steel)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(PMColor.muted)
            }
            .padding(12)
            .background(PMColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var practiceCard: some View {
        detailCard(title: "例题与易错点", icon: "square.grid.2x2.fill") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
                ForEach(practiceResources) { resource in
                    Button {
                        onPracticeResourceTap(resource)
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: resource.systemImage)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(resource.tint)
                                .frame(width: 34, height: 34)
                                .background(resource.tint.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            Text(resource.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(PMColor.charcoal)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.78)
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .padding(8)
                        .background(PMColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var faqAgentCard: some View {
        detailCard(title: "FAQ / Agent 答疑", icon: "sparkles") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(detail.faqs) { faq in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(faq.question)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PMColor.charcoal)
                        Text(faq.answer)
                            .font(.system(size: 13))
                            .foregroundStyle(PMColor.slate)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(PMColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                HStack(spacing: 8) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .foregroundStyle(PMColor.primary)
                    TextField("向 Agent 提问，MVP 暂不连接真实 AI", text: $agentQuestion)
                        .textFieldStyle(.plain)
                    Button("发送") {
                        print("TODO: Agent question - \(agentQuestion)")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .disabled(agentQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
                .background(PMColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                StringFlowWrap(items: detail.quickQuestions) { question in
                    Button {
                        agentQuestion = question
                        print("TODO: quick question - \(question)")
                    } label: {
                        Text(question)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(PMColor.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(PMColor.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var learningRecordCard: some View {
        detailCard(title: "学习记录", icon: "checkmark.seal.fill") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), spacing: 8)], spacing: 8) {
                LearningRecordButton(title: "已阅读", systemImage: "book.fill", isOn: $hasRead)
                LearningRecordButton(title: "已练习", systemImage: "pencil.circle.fill", isOn: $hasPracticed)
                LearningRecordButton(title: "标记不会", systemImage: "questionmark.circle.fill", isOn: $markedUnknown)
                LearningRecordButton(title: "收藏", systemImage: "star.fill", isOn: $isFavorited)
                LearningRecordButton(title: "加入复习", systemImage: "calendar.badge.plus", isOn: $addedToReview)
            }
        }
    }

    private var relatedNodesCard: some View {
        detailCard(title: "关联知识点", icon: "point.3.connected.trianglepath.dotted") {
            FlowWrap(items: relatedNodes) { item in
                if item.relation == "当前位置" {
                    HStack(spacing: 6) {
                        Text(item.relation)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(PMColor.primary)
                    .clipShape(Capsule())
                } else {
                    Button {
                        onRelatedNodeTap(item.title)
                    } label: {
                        HStack(spacing: 6) {
                            Text(item.relation)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(PMColor.steel)
                            Text(item.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(PMColor.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(PMColor.primary.opacity(0.09))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var practiceResources: [PracticeResource] {
        let exercises = detail.examplesAndExercises.map { exercise in
            PracticeResource(
                category: exercise.category,
                title: displayTitle(for: exercise.category),
                description: "\(exercise.title)\n\n\(exercise.description)",
                actionTitle: exercise.actionTitle,
                prompt: exercise.prompt,
                hints: exercise.hints,
                solution: exercise.solution,
                pitfalls: exercise.pitfalls,
                systemImage: icon(for: exercise.category),
                tint: tint(for: exercise.category)
            )
        }
        let mistakes = [
            PracticeResource(
                category: "易错点",
                title: "易错点",
                description: detail.mistakes.map { "• \($0)" }.joined(separator: "\n"),
                actionTitle: "集中查看",
                prompt: "复盘「\(detail.title)」时，先判断错误属于哪一类：概念条件、公式选择、计算步骤、题意翻译或边界情况。",
                hints: ["每次只复盘一个错误", "把错误写成可检查动作", "给自己补一道同类型小题"],
                solution: "建议记录格式：错因：____；正确第一步：____；下次检查：____。",
                pitfalls: detail.mistakes,
                systemImage: "exclamationmark.triangle.fill",
                tint: PMColor.warning
            )
        ]
        return exercises + mistakes
    }

    private func detailCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PMColor.ink)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .pathCardStyle()
    }

    private func bulletList(title: String?, items: [String], tint: Color = PMColor.primary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PMColor.charcoal)
            }
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(tint)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)
                    Text(item)
                        .font(.system(size: 14))
                        .foregroundStyle(PMColor.slate)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func tint(for category: String) -> Color {
        switch category {
        case "讲解例题": return PMColor.primary
        case "跟练题": return PMColor.success
        case "自测题": return PMColor.warning
        default: return PMColor.course
        }
    }

    private func icon(for category: String) -> String {
        switch category {
        case "讲解例题": return "book.closed.fill"
        case "跟练题": return "hand.draw.fill"
        case "自测题": return "timer.circle.fill"
        case "错题复盘": return "arrow.counterclockwise.circle.fill"
        default: return "exclamationmark.triangle.fill"
        }
    }

    private func displayTitle(for category: String) -> String {
        switch category {
        case "讲解例题": return "典型例题"
        case "跟练题": return "跟练题"
        case "自测题": return "自测题"
        case "错题复盘": return "错题复盘"
        default: return category
        }
    }
}

struct PracticeResource: Identifiable {
    var id: String { "\(category)-\(title)-\(description)" }
    var category: String
    var title: String
    var description: String
    var actionTitle: String
    var prompt: String = ""
    var hints: [String] = []
    var solution: String = ""
    var pitfalls: [String] = []
    var systemImage: String
    var tint: Color
}

struct PracticeResourceDetailPage: View {
    var resource: PracticeResource
    var onClose: () -> Void = {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: resource.systemImage)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(resource.tint)
                            .frame(width: 54, height: 54)
                            .background(resource.tint.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        VStack(alignment: .leading, spacing: 5) {
                            DetailTag(title: resource.category, tint: resource.tint)
                            Text(resource.title)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(PMColor.ink)
                        }
                    }

                    Text(resource.description)
                        .font(.system(size: 15))
                        .foregroundStyle(PMColor.slate)
                        .fixedSize(horizontal: false, vertical: true)

                    if !resource.prompt.isEmpty {
                        contentSection(title: "题目", icon: "questionmark.circle.fill", tint: resource.tint) {
                            Text(resource.prompt)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(PMColor.charcoal)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !resource.hints.isEmpty {
                        contentSection(title: "提示", icon: "lightbulb.fill", tint: PMColor.warning) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(resource.hints.enumerated()), id: \.offset) { index, hint in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("\(index + 1)")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(width: 20, height: 20)
                                            .background(PMColor.warning)
                                            .clipShape(Circle())
                                        Text(hint)
                                            .font(.system(size: 14))
                                            .foregroundStyle(PMColor.slate)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    if !resource.solution.isEmpty {
                        contentSection(title: "参考解析", icon: "checkmark.seal.fill", tint: PMColor.success) {
                            Text(resource.solution)
                                .font(.system(size: 15))
                                .foregroundStyle(PMColor.slate)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if !resource.pitfalls.isEmpty {
                        contentSection(title: "易错提醒", icon: "exclamationmark.triangle.fill", tint: PMColor.course) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(resource.pitfalls, id: \.self) { item in
                                    HStack(alignment: .top, spacing: 8) {
                                        Circle()
                                            .fill(PMColor.course)
                                            .frame(width: 6, height: 6)
                                            .padding(.top, 7)
                                        Text(item)
                                            .font(.system(size: 14))
                                            .foregroundStyle(PMColor.slate)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                        }
                    }

                    InfoBox(
                        title: resource.actionTitle,
                        message: "完成后可以回到学习记录勾选「已练习」或「标记不会」，后续再接入自动判题与错题本。",
                        icon: "sparkles",
                        tint: resource.tint
                    )
                }
                .padding(16)
            }
            .background(PMColor.softCanvas)
            .navigationTitle(resource.category)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成", action: onClose)
                }
            }
        }
    }

    private func contentSection<Content: View>(
        title: String,
        icon: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(PMColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }
}

private struct DetailTag: View {
    var title: String
    var systemImage: String?
    var tint: Color

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(tint.opacity(0.11))
        .clipShape(Capsule())
    }
}

private struct LearningRecordButton: View {
    var title: String
    var systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.82)) {
                isOn.toggle()
            }
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(isOn ? .white : PMColor.charcoal)
                .background(isOn ? PMColor.primary : PMColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct FlowWrap<Item: Identifiable, Content: View>: View {
    var items: [Item]
    var content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items) { item in
                content(item)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct StringFlowWrap<Content: View>: View {
    var items: [String]
    var content: (String) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
