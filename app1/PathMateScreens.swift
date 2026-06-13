import SwiftUI
import Combine
import WebKit

struct MainTabView: View {
    @ObservedObject var store: PathMateStore

    var body: some View {
        TabView {
            AlgorithmMindMapScreen()
                .tabItem { Label("图谱", systemImage: "point.3.connected.trianglepath.dotted") }

            NextUpView(store: store)
                .tabItem { Label("接下来", systemImage: "clock") }

            ScheduleView(store: store)
                .tabItem { Label("日程", systemImage: "calendar") }

            AcademicsView(store: store)
                .tabItem { Label("学业", systemImage: "graduationcap.fill") }

            SettingsView(store: store)
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .tint(PMColor.primary)
        .background(PMColor.softCanvas)
    }
}

struct OnboardingFlow: View {
    @ObservedObject var store: PathMateStore

    private enum ProfileField: Hashable {
        case school
        case major
    }

    @State private var showingLaunch = true
    @State private var step = 0
    @State private var navigationDirection = 1
    @State private var grade = UserProfile.sample.grade
    @State private var school = UserProfile.sample.school
    @State private var major = UserProfile.sample.major
    @State private var goal = UserProfile.sample.goal
    @State private var habit = UserProfile.sample.habit
    @State private var detail = UserProfile.sample.detail
    @State private var importCourses = true
    @State private var showingAcademicSystemSelection = false
    @State private var showingFileImporter = false
    @State private var selectedImportTerm = AcademicTerm.current()
    @State private var addingCourse = false
    @State private var importMessage: String?
    @FocusState private var focusedProfileField: ProfileField?

    private let totalSteps = 4

    var body: some View {
        Group {
            if showingLaunch {
                LaunchPage {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                        showingLaunch = false
                    }
                }
            } else {
                setupFlow
            }
        }
        .background(PMColor.softCanvas.ignoresSafeArea())
        .sheet(isPresented: $showingAcademicSystemSelection) {
            NavigationStack {
                AcademicSystemSchoolSelectionView(store: store, selectedTerm: selectedImportTerm) { message in
                    markOnboardingImportComplete(message)
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("完成") { showingAcademicSystemSelection = false }
                    }
                }
            }
        }
        .sheet(isPresented: $addingCourse) {
            CourseEditorSheet(store: store, course: nil) {
                markOnboardingImportComplete("单节课程已保存。完成引导后仍可在学业页继续编辑。")
            }
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: CourseImportService.supportedFileTypes,
            allowsMultipleSelection: false
        ) { result in
            handleOnboardingFileSelection(result)
        }
    }

    private var setupFlow: some View {
        VStack(spacing: 0) {
            progress
                .padding(.horizontal, 20)
                .padding(.top, 20)

            ZStack {
                page
                    .id(step)
                    .transition(pageTransition)
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: step)

            controls
                .padding(20)
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("PathMate 设置")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(PMColor.ink)
                Spacer()
                Text("\(step + 1)/\(totalSteps)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(PMColor.steel)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(PMColor.hairline)
                    Capsule()
                        .fill(PMColor.primary)
                        .frame(width: proxy.size.width * CGFloat(step + 1) / CGFloat(totalSteps))
                }
            }
            .frame(height: 6)
        }
    }

    @ViewBuilder
    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch step {
                case 0:
                    onboardingHeader(icon: "person.text.rectangle", title: "建立你的学习画像", message: "这些信息会影响 Agent 的课程权重、任务优先级和调整建议。")
                    Text("年级")
                        .sectionLabel()
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 78), spacing: 8)], spacing: 8) {
                        ForEach(PathMateTime.gradeOptions, id: \.self) { item in
                            choiceButton(title: item, selected: grade == item) { grade = item }
                        }
                    }
                    schoolSearchField
                    majorSearchField
                    Text("发展目标")
                        .sectionLabel()
                    ChoiceGrid(items: CareerGoal.allCases, selection: $goal) { item in
                        Label(item.rawValue, systemImage: item.iconName)
                    }

                case 1:
                    onboardingHeader(icon: "clock.arrow.2.circlepath", title: "选择学习习惯", message: "这里的选择会直接影响复习节奏和计划颗粒度。")
                    Text("复习方式")
                        .sectionLabel()
                    ChoiceGrid(items: LearningHabit.allCases, selection: $habit) { item in
                        Text(item.rawValue)
                    }
                    InfoBox(title: habit.rawValue, message: habit.explanation)
                    Text("计划方式")
                        .sectionLabel()
                    ChoiceGrid(items: PlanDetail.allCases, selection: $detail) { item in
                        Text(item.rawValue)
                    }
                    InfoBox(title: detail.rawValue, message: detail.explanation, icon: "slider.horizontal.3")

                case 2:
                    onboardingHeader(icon: "square.and.arrow.down", title: "导入课程表", message: "先用示例课程完成设置。进入 App 后，可在学业页连接已适配教务系统、导入文件或补录单节课程。")
                    Toggle("使用示例课程表", isOn: $importCourses)
                        .font(.system(size: 16, weight: .semibold))
                        .padding(14)
                        .pathCardStyle()
                    VStack(spacing: 10) {
                        Button {
                            selectedImportTerm = defaultImportTerm
                            showingAcademicSystemSelection = true
                        } label: {
                            ImportMethodRow(icon: "building.columns.fill", title: "教务系统授权", message: "选择学校并进入对应身份认证页面。")
                        }
                        .buttonStyle(.plain)
                        Button {
                            selectedImportTerm = defaultImportTerm
                            showingFileImporter = true
                        } label: {
                            ImportMethodRow(icon: "tablecells", title: "JSON / 表格文件", message: "支持 JSON、CSV、TSV 和 XML Spreadsheet 2003 格式的 .xls 文件。")
                        }
                        .buttonStyle(.plain)
                        Button {
                            addingCourse = true
                        } label: {
                            ImportMethodRow(icon: "pencil.and.list.clipboard", title: "添加单节课程", message: "可补录临时课程、实验课，或修正导入结果。")
                        }
                        .buttonStyle(.plain)
                    }
                    if let importMessage {
                        InfoBox(title: "课程表已更新", message: importMessage, icon: "checkmark.circle.fill", tint: PMColor.success)
                    }
                    InfoBox(title: importCourses ? "将导入示例课程" : "将跳过导入", message: importCourses ? "进入 App 后会看到课程、作业、课件和辅学模拟数据。" : "你仍可在学业页手动添加课程。", tint: importCourses ? PMColor.success : PMColor.warning)

                default:
                    onboardingHeader(icon: "checkmark.seal.fill", title: "设置完成", message: "\(school) · \(grade) · \(major)\n目标：\(goal.rawValue)，\(habit.rawValue)，\(detail.rawValue)。")
                    FeatureLine(icon: "calendar", title: "日程主页已准备", message: "月历、周课表、当天安排和冲突检测会作为主入口。")
                    FeatureLine(icon: "graduationcap.fill", title: "学业数据已准备", message: "课程详情包含课件、作业、重点知识点和辅学入口。")
                    FeatureLine(icon: "sparkles", title: "Agent 协作已准备", message: "建议会保留原因解释和接受、修改、拒绝操作。")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if step > 0 {
                PathButton(title: "上一步", systemImage: "chevron.left", style: .secondary) {
                    navigationDirection = -1
                    withAnimation { step -= 1 }
                }
            }

            PathButton(title: step == totalSteps - 1 ? "进入 PathMate" : "继续", systemImage: step == totalSteps - 1 ? "arrow.right.circle.fill" : "chevron.right") {
                if step == totalSteps - 1 {
                    let profile = UserProfile(grade: grade, school: school, major: major, goal: goal, habit: habit, detail: detail, appearanceMode: store.profile.appearanceMode)
                    withAnimation {
                        store.finishOnboarding(profile: profile, importSampleCourses: importCourses)
                    }
                } else {
                    navigationDirection = 1
                    withAnimation { step += 1 }
                }
            }
        }
    }

    private var pageTransition: AnyTransition {
        if navigationDirection >= 0 {
            return .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity))
        }
        return .asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity))
    }

    private var defaultImportTerm: AcademicTerm {
        let terms = AcademicTerm.learningStageTerms(for: grade)
        let current = AcademicTerm.current()
        return terms.first(where: { $0 == current }) ?? terms.first ?? current
    }

    private func markOnboardingImportComplete(_ message: String) {
        importCourses = false
        importMessage = message
    }

    private func handleOnboardingFileSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let courses = try CourseImportService.courses(from: url, defaultTerm: selectedImportTerm)
            let count = store.importCourses(courses, source: "文件 \(url.lastPathComponent)", term: selectedImportTerm)
            let message = count == 0
                ? "文件中的课程均已存在，没有新增课程。"
                : "已从 \(url.lastPathComponent) 导入 \(count) 门\(selectedImportTerm.shortName)课程。"
            markOnboardingImportComplete(message)
        } catch {
            importCourses = false
            importMessage = error.localizedDescription
        }
    }

    private var schoolSearchField: some View {
        searchablePickerField(
            title: "学校",
            placeholder: "输入学校名称",
            value: $school,
            field: .school,
            results: PathMateTime.filteredSchools(query: school),
            itemIcon: "building.columns",
            emptyMessage: "未找到匹配的学校"
        )
    }

    private var majorSearchField: some View {
        searchablePickerField(
            title: "专业",
            placeholder: "输入专业名称",
            value: $major,
            field: .major,
            results: PathMateTime.filteredMajors(query: major),
            itemIcon: "graduationcap",
            emptyMessage: "未找到匹配的专业"
        )
    }

    private func searchablePickerField(
        title: String,
        placeholder: String,
        value: Binding<String>,
        field: ProfileField,
        results: [String],
        itemIcon: String,
        emptyMessage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).sectionLabel()
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(PMColor.steel)
                TextField(placeholder, text: value)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($focusedProfileField, equals: field)
                    .onTapGesture {
                        focusedProfileField = field
                    }
                if !value.wrappedValue.isEmpty {
                    Button {
                        value.wrappedValue = ""
                        focusedProfileField = field
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(PMColor.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清空\(title)名称")
                }
            }
            .padding(12)
            .background(PMColor.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(focusedProfileField == field ? PMColor.primary : PMColor.hairline, lineWidth: 1)
            }

            if focusedProfileField == field {
                VStack(spacing: 0) {
                    if results.isEmpty {
                        Text(emptyMessage)
                            .font(.system(size: 14))
                            .foregroundStyle(PMColor.steel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(results, id: \.self) { item in
                                    Button {
                                        value.wrappedValue = item
                                        focusedProfileField = nil
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: itemIcon)
                                                .foregroundStyle(PMColor.primary)
                                            Text(item)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(PMColor.charcoal)
                                            Spacer()
                                            if value.wrappedValue == item {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(PMColor.success)
                                            }
                                        }
                                        .padding(.horizontal, 14)
                                        .frame(minHeight: 48)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    if item != results.last {
                                        Divider()
                                            .padding(.leading, 44)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 244)
                    }
                }
                .background(PMColor.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(PMColor.hairline, lineWidth: 1)
                }
                .shadow(color: PMColor.ink.opacity(0.08), radius: 12, y: 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.18), value: focusedProfileField)
        .zIndex(focusedProfileField == field ? 1 : 0)
    }

    private func onboardingHeader(icon: String, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(PMColor.primary)
                .frame(width: 52, height: 52)
                .background(PMColor.primary.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(PMColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(message)
                .font(.system(size: 16))
                .foregroundStyle(PMColor.slate)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pathCardStyle()
    }

    private func labeledTextField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).sectionLabel()
            TextField(title, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .padding(12)
                .background(PMColor.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(PMColor.hairline, lineWidth: 1)
                }
        }
    }

    private func choiceButton(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(selected ? .white : PMColor.charcoal)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(selected ? PMColor.primary : PMColor.surfaceRaised)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(selected ? .clear : PMColor.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

struct LaunchPage: View {
    var onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(PMColor.primary)
                .frame(width: 72, height: 72)
                .background(PMColor.primary.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            Text("PathMate")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(PMColor.ink)
            Text("把课程、作业、复习、个人事项和长期目标放进同一个可协作的 Agent 日程里。")
                .font(.system(size: 18))
                .foregroundStyle(PMColor.slate)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            PathButton(title: "开始设置", systemImage: "arrow.right.circle.fill", action: onStart)
        }
        .padding(28)
    }
}

struct NextUpView: View {
    @ObservedObject var store: PathMateStore
    @EnvironmentObject private var mateEventBus: MateEventBus
    @State private var now = Date()
    @State private var expandedIDs: Set<UUID> = []
    @State private var editingTask: PlanTask?
    @State private var isGenerating = false
    @State private var toast: String?

    private var currentTerm: AcademicTerm {
        AcademicTerm.current(for: now)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    focusSection
                    laterSection
                    suggestionsSection
                    agentReminder
                }
                .padding(16)
            }
            .background(PMColor.softCanvas)
            .navigationTitle("接下来")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        now = Date()
                        toast = "已刷新当前安排"
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .tint(PMColor.primary)
                }
            }
            .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
                now = date
            }
            .sheet(item: $editingTask) { task in
                TaskEditorSheet(store: store, task: task)
            }
            .toast($toast)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近安排")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(PMColor.ink)
            Text("\(store.profile.school) · \(store.profile.goal.strategyTitle)")
                .font(.system(size: 14))
                .foregroundStyle(PMColor.slate)
            Text(currentTerm.displayName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(PMColor.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .pathCardStyle()
    }

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.currentTask(now: now, term: currentTerm) == nil ? "即将开始" : "正在进行")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(PMColor.ink)
            if let task = focusTask {
                NavigationLink {
                    destination(for: task)
                } label: {
                    CountdownFocusCard(task: task, course: store.course(id: task.courseID), now: now, isCurrent: store.currentTask(now: now, term: currentTerm)?.id == task.id)
                }
                .buttonStyle(.plain)
            } else {
                EmptyStateView(systemImage: "clock.badge.checkmark", title: "暂无未完成安排", message: "课程、复习和个人事项都会出现在这里。")
            }
        }
    }

    private var laterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("之后的安排")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(PMColor.ink)

            let later = laterTasks
            if later.isEmpty {
                EmptyStateView(systemImage: "calendar.badge.checkmark", title: "没有更多未完成安排", message: "新增课程、复习任务或个人事项后这里会自动更新。")
            } else {
                ForEach(later) { task in
                    TaskCard(task: task, courseName: store.course(id: task.courseID)?.name) {
                        withAnimation {
                            store.completeTask(task)
                            mateEventBus.send(task.priority >= 4 ? .importantTaskCompleted : .taskCompleted)
                            toast = "已完成任务"
                        }
                    } onPostpone: {
                        withAnimation {
                            store.postponeTask(task)
                            toast = "已延后任务"
                        }
                    }
                    .onLongPressGesture {
                        editingTask = task
                    }
                    .contextMenu {
                        Button("编辑") { editingTask = task }
                        Button(role: .destructive) {
                            store.deleteTask(task)
                            toast = "已删除任务"
                        } label: {
                            Text("删除")
                        }
                    }
                }
            }
        }
    }

    private var focusTask: PlanTask? {
        store.nextPendingTask(now: now, term: currentTerm)
    }

    private var laterTasks: [PlanTask] {
        let upcoming = store.upcomingTasksWithin24Hours(now: now, term: currentTerm)
        guard let focusTask else { return upcoming }
        return upcoming.filter { $0.id != focusTask.id }
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PathButton(title: "重新生成 Agent 建议", systemImage: "wand.and.stars", isLoading: isGenerating) {
                regenerate()
            }
            if !store.suggestions.isEmpty {
                ForEach(store.suggestions) { suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        affectedTaskTitle: store.task(id: suggestion.affectedTaskID)?.title,
                        isExpanded: expandedIDs.contains(suggestion.id),
                        onToggleReason: {
                            withAnimation {
                                if expandedIDs.contains(suggestion.id) {
                                    expandedIDs.remove(suggestion.id)
                                } else {
                                    expandedIDs.insert(suggestion.id)
                                }
                            }
                        },
                        onAccept: {
                            withAnimation {
                                store.acceptSuggestion(suggestion)
                                toast = "已接受 Agent 建议"
                            }
                        },
                        onModify: {
                            if let task = store.task(id: suggestion.affectedTaskID) {
                                editingTask = task
                            } else {
                                store.acceptSuggestion(suggestion)
                                editingTask = store.tasks.last
                            }
                        },
                        onReject: {
                            withAnimation {
                                store.rejectSuggestion(suggestion)
                                toast = "已拒绝建议"
                            }
                        }
                    )
                }
            }
        }
    }

    private var agentReminder: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Agent 提醒", systemImage: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            Text(store.suggestions.first?.reason ?? "当前计划稳定。新增比赛、社团或个人事项后，Agent 会自动检查冲突。")
                .font(.system(size: 14))
                .foregroundStyle(PMColor.slate)
        }
        .padding(16)
        .pathCardStyle()
    }

    @ViewBuilder
    private func destination(for task: PlanTask) -> some View {
        TaskDestinationView(store: store, task: task)
    }

    private func regenerate() {
        mateEventBus.send(.schedulePlanningStarted)
        isGenerating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                store.regeneratePlan()
                isGenerating = false
                toast = "已生成新建议"
                mateEventBus.send(.schedulePlanningCompleted)
            }
        }
    }
}

struct ScheduleView: View {
    @ObservedObject var store: PathMateStore
    @EnvironmentObject private var mateEventBus: MateEventBus
    @State private var selectedDate = Date()
    @State private var selectedTerm = AcademicTerm.current()
    @State private var isCalendarExpanded = false
    @State private var showingAddEvent = false
    @State private var conflictSuggestion: AgentSuggestion?
    @State private var editingTask: PlanTask?
    @State private var toast: String?

    private var selectedWeekday: Int { PathMateTime.weekday(from: selectedDate) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    scheduleHeader
                    MonthCalendarView(selectedDate: $selectedDate, tasks: store.scheduleTasks(in: selectedTerm), isExpanded: $isCalendarExpanded)
                    dayAgenda
                }
                .padding(16)
            }
            .background(PMColor.softCanvas)
            .navigationTitle("日程")
            .onAppear {
                syncSelectedTerm(for: selectedDate)
            }
            .onChange(of: selectedDate) { _, newDate in
                syncSelectedTerm(for: newDate)
            }
            .sheet(isPresented: $showingAddEvent) {
                AddPersonalEventSheet(store: store, defaultDate: selectedDate) { suggestion in
                    toast = "个人事项已保存"
                    if let suggestion {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            conflictSuggestion = suggestion
                        }
                    }
                }
            }
            .sheet(item: $conflictSuggestion) { suggestion in
                ConflictSuggestionSheet(store: store, suggestion: suggestion) { task in
                    editingTask = task
                }
            }
            .sheet(item: $editingTask) { task in
                TaskEditorSheet(store: store, task: task)
            }
            .toast($toast)
        }
    }

    private var scheduleHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(monthTitle)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(PMColor.ink)
                    Text("\(PathMateTime.weekdayName(selectedWeekday)) · \(selectedDayScheduleTasks.count) 项安排")
                        .font(.system(size: 14))
                        .foregroundStyle(PMColor.slate)
                    termMenu
                }
                Spacer()
                IconButton(systemImage: "plus") { showingAddEvent = true }
                Button {
                    withAnimation {
                        let today = Date()
                        selectedDate = today
                        syncSelectedTerm(for: today)
                    }
                } label: {
                    Text("今天")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(PMColor.primary)
                        .frame(height: 42)
                        .padding(.horizontal, 12)
                        .background(PMColor.surfaceRaised)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(PMColor.hairline, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    CourseTimetableView(store: store, term: selectedTerm)
                } label: {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PMColor.primary)
                        .frame(width: 42, height: 42)
                        .background(PMColor.surfaceRaised)
                        .clipShape(Circle())
                        .overlay {
                            Circle().stroke(PMColor.hairline, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .pathCardStyle()
    }

    private var termMenu: some View {
        Menu {
            ForEach(store.availableAcademicTerms()) { term in
                Button {
                    selectTerm(term)
                } label: {
                    Label(term.displayName, systemImage: term == selectedTerm ? "checkmark" : "calendar")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "calendar.badge.clock")
                Text(selectedTerm.displayName)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(PMColor.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(PMColor.primary.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var dayAgenda: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(PathMateTime.weekdayName(selectedWeekday))安排")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(PMColor.ink)
            let dayTasks = selectedDayScheduleTasks
            if dayTasks.isEmpty {
                EmptyStateView(systemImage: "calendar.badge.plus", title: "这一天没有安排", message: "点击右上角加号添加比赛、社团活动或个人事项。")
            } else {
                ForEach(dayTasks) { task in
                    NavigationLink {
                        TaskDestinationView(store: store, task: task)
                    } label: {
                        AgendaCard(task: task, course: store.course(id: task.courseID))
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("编辑") { editingTask = task }
                        Button("延后") {
                            store.postponeTask(task)
                            toast = "已延后任务"
                        }
                        Button(role: .destructive) {
                            store.deleteTask(task)
                            toast = "已删除任务"
                        } label: {
                            Text("删除")
                        }
                    }
                }
            }
        }
    }

    private var monthTitle: String {
        let components = Calendar.current.dateComponents([.year, .month], from: selectedDate)
        return "\(components.year ?? 2026) 年 \(components.month ?? 1) 月"
    }

    private var selectedDayScheduleTasks: [PlanTask] {
        store.scheduleTasks(on: selectedDate, term: selectedTerm)
    }

    private func selectTerm(_ term: AcademicTerm) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            selectedTerm = term
            selectedDate = term.representativeDate
        }
    }

    private func syncSelectedTerm(for date: Date) {
        let terms = store.availableAcademicTerms()
        let dateTerm = AcademicTerm.current(for: date)
        if terms.contains(dateTerm) {
            selectedTerm = dateTerm
        } else if !terms.contains(selectedTerm), let firstTerm = terms.first {
            selectedTerm = firstTerm
        }
    }
}

struct TaskHubView: View {
    @ObservedObject var store: PathMateStore
    @EnvironmentObject private var mateEventBus: MateEventBus
    @State private var expandedIDs: Set<UUID> = []
    @State private var editingTask: PlanTask?
    @State private var isGenerating = false
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    taskHeader
                    PathButton(title: "重新生成 Agent 建议", systemImage: "wand.and.stars", isLoading: isGenerating) {
                        regenerate()
                    }
                    suggestionsSection
                    tasksSection
                }
                .padding(16)
            }
            .background(PMColor.softCanvas)
            .navigationTitle("任务")
            .sheet(item: $editingTask) { task in
                TaskEditorSheet(store: store, task: task)
            }
            .toast($toast)
        }
    }

    private var taskHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Agent 任务协作", systemImage: "sparkles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(PMColor.ink)
            Text("接受、修改、拒绝建议都在这里完成。任务仍可手动编辑，Agent 只提供可解释的调整。")
                .font(.system(size: 14))
                .foregroundStyle(PMColor.slate)
        }
        .padding(16)
        .pathCardStyle()
    }

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Agent 建议")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PMColor.ink)
            if store.suggestions.isEmpty {
                EmptyStateView(systemImage: "sparkles", title: "暂无建议", message: "点击重新生成，让 Agent 根据当前目标和课程生成建议。")
            } else {
                ForEach(store.suggestions) { suggestion in
                    SuggestionCard(
                        suggestion: suggestion,
                        affectedTaskTitle: store.task(id: suggestion.affectedTaskID)?.title,
                        isExpanded: expandedIDs.contains(suggestion.id),
                        onToggleReason: {
                            withAnimation {
                                if expandedIDs.contains(suggestion.id) {
                                    expandedIDs.remove(suggestion.id)
                                } else {
                                    expandedIDs.insert(suggestion.id)
                                }
                            }
                        },
                        onAccept: {
                            withAnimation {
                                store.acceptSuggestion(suggestion)
                                toast = "已接受 Agent 建议"
                            }
                        },
                        onModify: {
                            if let task = store.task(id: suggestion.affectedTaskID) {
                                editingTask = task
                            } else {
                                store.acceptSuggestion(suggestion)
                                editingTask = store.tasks.last
                            }
                        },
                        onReject: {
                            withAnimation {
                                store.rejectSuggestion(suggestion)
                                toast = "已拒绝建议"
                            }
                        }
                    )
                }
            }
        }
    }

    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("全部任务")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(PMColor.ink)
            if store.tasks.isEmpty {
                EmptyStateView(systemImage: "checklist", title: "暂无任务", message: "去日程页添加个人事项，或进入课程详情添加课程待办。")
            } else {
                ForEach(store.tasks.sorted { $0.weekday == $1.weekday ? $0.startMinute < $1.startMinute : $0.weekday < $1.weekday }) { task in
                    TaskCard(task: task, courseName: store.course(id: task.courseID)?.name) {
                        withAnimation {
                            store.completeTask(task)
                            mateEventBus.send(task.priority >= 4 ? .importantTaskCompleted : .taskCompleted)
                            toast = "已完成任务"
                        }
                    } onPostpone: {
                        withAnimation {
                            store.postponeTask(task)
                            toast = "已延后任务"
                        }
                    }
                    .onLongPressGesture {
                        editingTask = task
                    }
                    .contextMenu {
                        Button("编辑") { editingTask = task }
                        Button(role: .destructive) {
                            store.deleteTask(task)
                            toast = "已删除任务"
                        } label: {
                            Text("删除")
                        }
                    }
                }
            }
        }
    }

    private func regenerate() {
        mateEventBus.send(.schedulePlanningStarted)
        isGenerating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation {
                store.regeneratePlan()
                isGenerating = false
                toast = "已生成新建议"
                mateEventBus.send(.schedulePlanningCompleted)
            }
        }
    }
}

struct AcademicsView: View {
    @ObservedObject var store: PathMateStore
    @State private var addingCourse = false
    @State private var editingCourse: Course?
    @State private var schedulingTodoCourse: Course?
    @State private var studyAidCourseID: UUID?
    @State private var showingImportCenter = false
    @State private var addSingleCourseAfterImport = false
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if academicCourses.isEmpty {
                        EmptyStateView(systemImage: "books.vertical", title: "还没有课程", message: "添加课程后，课件、作业和辅学内容会在这里展示。")
                    } else {
                        ForEach(academicCourses) { course in
                            VStack(spacing: 10) {
                                NavigationLink {
                                    CourseDetailView(store: store, courseID: course.id, highlightHomeworkID: nil)
                                } label: {
                                    CourseCard(course: course) {
                                        studyAidCourseID = course.id
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("编辑课程") { editingCourse = course }
                                    Button("添加待办") { schedulingTodoCourse = course }
                                    Button(role: .destructive) {
                                        store.deleteCourses(named: course.name)
                                        toast = "已删除课程"
                                    } label: {
                                        Text("删除课程")
                                    }
                                }
                                PathButton(title: "添加待办", systemImage: "calendar.badge.plus", style: .secondary) {
                                    schedulingTodoCourse = course
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(PMColor.softCanvas)
            .navigationTitle("学业")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingImportCenter = true
                        } label: {
                            Label("导入课程表", systemImage: "square.and.arrow.down")
                        }
                        Button {
                            addingCourse = true
                        } label: {
                            Label("添加单节课程", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .tint(PMColor.primary)
                }
            }
            .sheet(isPresented: $addingCourse) {
                CourseEditorSheet(store: store, course: nil) {
                    toast = "课程已保存"
                }
            }
            .sheet(item: $editingCourse) { course in
                CourseEditorSheet(store: store, course: course) {
                    toast = "课程已更新"
                }
            }
            .sheet(item: $schedulingTodoCourse) { course in
                CourseTodoScheduleSheet(store: store, course: course) {
                    toast = "课程待办已加入日历"
                }
            }
            .navigationDestination(item: $studyAidCourseID) { courseID in
                CourseStudyAidPage(store: store, courseID: courseID)
            }
            .sheet(isPresented: $showingImportCenter, onDismiss: {
                if addSingleCourseAfterImport {
                    addSingleCourseAfterImport = false
                    addingCourse = true
                }
            }) {
                CourseImportSheet(store: store) { message in
                    toast = message
                } onAddSingleCourse: {
                    addSingleCourseAfterImport = true
                }
            }
            .toast($toast)
        }
    }

    private var academicCourses: [Course] {
        store.academicCourseSummaries()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("课程与辅学")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(PMColor.ink)
            Text("课程详情里可以查看课件、作业、重点知识点和辅学解释。")
                .font(.system(size: 14))
                .foregroundStyle(PMColor.slate)
            Button {
                showingImportCenter = true
            } label: {
                Label("导入课程表", systemImage: "square.and.arrow.down")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .tint(PMColor.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .pathCardStyle()
    }
}

struct CourseImportSheet: View {
    @ObservedObject var store: PathMateStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingFileImporter = false
    @State private var showingSchoolSelection = false
    @State private var selectedTerm = AcademicTerm.current()
    @State private var statusMessage: String?
    @State private var statusTint = PMColor.primary
    var onImported: (String) -> Void
    var onAddSingleCourse: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    intro
                    termSelectionCard
                    academicSystemCard
                    fileImportCard
                    manualAddCard
                    if let statusMessage {
                        InfoBox(title: "导入结果", message: statusMessage, icon: statusTint == PMColor.success ? "checkmark.circle.fill" : "info.circle.fill", tint: statusTint)
                    }
                    schemaCard
                }
                .padding(16)
            }
            .background(PMColor.softCanvas)
            .navigationTitle("导入课程表")
            .navigationDestination(isPresented: $showingSchoolSelection) {
                AcademicSystemSchoolSelectionView(store: store, selectedTerm: selectedTerm, onImported: onImported)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: CourseImportService.supportedFileTypes,
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择导入方式")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(PMColor.ink)
            Text("教务系统适配、文件导入和单节课程补录可以组合使用。导入后仍可逐节编辑。")
                .font(.system(size: 14))
                .foregroundStyle(PMColor.slate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .pathCardStyle()
    }

    private var termSelectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("导入学期", systemImage: "calendar.badge.clock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            Text("默认根据当前日期和年级选择，只显示当前学习阶段内的学期。")
                .font(.system(size: 13))
                .foregroundStyle(PMColor.slate)
            Picker("导入学期", selection: $selectedTerm) {
                ForEach(store.importableAcademicTerms()) { term in
                    Text(term.displayName).tag(term)
                }
            }
            .pickerStyle(.menu)
            .tint(PMColor.primary)
        }
        .padding(14)
        .pathCardStyle()
    }

    private var academicSystemCard: some View {
        importCard(
            icon: "building.columns.fill",
            title: "从教务系统导入",
            message: "选择学校后进入对应的身份认证页面。登录完成后，学校适配器会自动尝试读取\(selectedTerm.shortName)课程。",
            badge: "\(CourseImportService.academicSystemSchools.count) 所认证入口",
            buttonTitle: "选择学校"
        ) {
            showingSchoolSelection = true
        }
    }

    private var fileImportCard: some View {
        importCard(
            icon: "doc.badge.arrow.up.fill",
            title: "从文件导入",
            message: "支持 JSON、CSV、TSV 和 XML Spreadsheet 2003 格式的 .xls。导入时会自动跳过重复课程。",
            badge: "本地解析",
            buttonTitle: "选择文件"
        ) {
            showingFileImporter = true
        }
    }

    private var manualAddCard: some View {
        importCard(
            icon: "plus.rectangle.on.rectangle",
            title: "添加单节课程",
            message: "适合补录临时课程、实验课，或修正教务系统中缺少的课程。",
            badge: "随时补录",
            buttonTitle: "新建课程"
        ) {
            onAddSingleCourse()
            dismiss()
        }
    }

    private var schemaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("文件字段说明", systemImage: "list.bullet.rectangle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            Text("表格标题行可使用：课程名称、教师、星期、开始时间、结束时间、地点、权重。JSON 使用 name、teacher、weekday、startMinute、durationMinutes、location、weight。")
                .font(.system(size: 13))
                .foregroundStyle(PMColor.slate)
            Text("星期支持 1-7 或周一至周日；时间支持分钟数或 HH:mm。旧版二进制 XLS / XLSX 请先另存为 CSV、TSV 或 XML Spreadsheet 2003。")
                .font(.system(size: 13))
                .foregroundStyle(PMColor.steel)
        }
        .padding(14)
        .pathCardStyle()
    }

    private func importCard(
        icon: String,
        title: String,
        message: String,
        badge: String,
        buttonTitle: String,
        badgeTint: Color = PMColor.primary,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(PMColor.primary)
                    .frame(width: 40, height: 40)
                    .background(PMColor.primary.opacity(0.13))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PMColor.charcoal)
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(PMColor.slate)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack {
                TagChip(title: badge, systemImage: nil, tint: badgeTint)
                Spacer()
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(PMColor.primary)
                    .disabled(isDisabled)
            }
        }
        .padding(14)
        .pathCardStyle()
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let courses = try CourseImportService.courses(from: url, defaultTerm: selectedTerm)
            let count = store.importCourses(courses, source: "文件 \(url.lastPathComponent)", term: selectedTerm)
            showSuccess(count == 0 ? "文件中的课程均已存在，没有新增课程。" : "已从 \(url.lastPathComponent) 导入 \(count) 门\(selectedTerm.shortName)课程。")
        } catch {
            statusTint = PMColor.warning
            statusMessage = error.localizedDescription
        }
    }

    private func showSuccess(_ message: String) {
        statusTint = PMColor.success
        statusMessage = message
        onImported(message)
    }
}

struct AcademicSystemSchoolSelectionView: View {
    @ObservedObject var store: PathMateStore
    var selectedTerm: AcademicTerm
    @State private var query = ""
    var onImported: (String) -> Void

    private var filteredSchools: [AcademicSystemSchool] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return CourseImportService.academicSystemSchools
        }
        return CourseImportService.academicSystemSchools.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.adapterName.localizedCaseInsensitiveContains(query)
                || $0.initial.localizedCaseInsensitiveContains(query)
        }
    }

    private var groupedSchools: [(initial: String, schools: [AcademicSystemSchool])] {
        Dictionary(grouping: filteredSchools, by: \.initial)
            .map { (initial: $0.key, schools: $0.value) }
            .sorted { $0.initial < $1.initial }
    }

    var body: some View {
        List {
            Section {
                InfoBox(
                    title: "选择学校认证入口",
                    message: "学校按拼音首字母排列。账号和密码只会提交到学校自己的页面；当前原型已接通认证流程，逐校课表解析器仍需继续适配。",
                    icon: "lock.shield.fill"
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            ForEach(groupedSchools, id: \.initial) { group in
                Section(group.initial) {
                    ForEach(group.schools) { school in
                        NavigationLink {
                            AcademicSystemLoginView(store: store, school: school, selectedTerm: selectedTerm, onImported: onImported)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(school.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(PMColor.charcoal)
                                Text(school.adapterName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(PMColor.slate)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PMColor.softCanvas)
        .navigationTitle("选择学校")
        .searchable(text: $query, prompt: "搜索学校或教务系统")
        .overlay {
            if filteredSchools.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }
}

struct AcademicSystemLoginView: View {
    @ObservedObject var store: PathMateStore
    @Environment(\.openURL) private var openURL
    let school: AcademicSystemSchool
    var selectedTerm: AcademicTerm
    var onImported: (String) -> Void
    @State private var currentURL: URL?
    @State private var isLoading = false
    @State private var reloadID = UUID()
    @State private var isSyncing = false
    @State private var visitedLoginFlow = false
    @State private var hasTriggeredAutomaticSync = false
    @State private var statusMessage: String?
    @State private var loadErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Label(school.adapterName, systemImage: "lock.shield.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PMColor.charcoal)
                Text(school.message)
                    .font(.system(size: 13))
                    .foregroundStyle(PMColor.slate)
                Text(school.id == "zju"
                     ? "请在浙江大学统一身份认证页面登录。返回本科教务后会自动读取\(selectedTerm.shortName)课表，也可以手动触发。"
                     : "登录成功返回教务系统后会自动尝试同步。若学校页面没有明显跳转，也可以手动触发。")
                    .font(.system(size: 12))
                    .foregroundStyle(PMColor.steel)
                HStack(spacing: 6) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text("当前页面：\(currentURL?.host ?? school.authenticationURL.host ?? "学校认证入口")")
                        .font(.system(size: 12))
                        .foregroundStyle(PMColor.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(PMColor.softCanvas)

            ZStack {
                AcademicSystemAuthenticationWebView(
                    url: school.authenticationURL,
                    reloadID: reloadID,
                    currentURL: $currentURL,
                    isLoading: $isLoading,
                    onNavigationFinished: handleNavigationFinished,
                    onNavigationError: handleNavigationError
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isLoading {
                    ProgressView("正在加载学校页面...")
                        .padding(14)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .frame(minHeight: 280)

            VStack(alignment: .leading, spacing: 10) {
                if let loadErrorText = loadErrorMessage {
                    InfoBox(title: "学校页面加载失败", message: loadErrorText, icon: "exclamationmark.triangle.fill", tint: PMColor.warning)
                    HStack {
                        Button {
                            loadErrorMessage = nil
                            reloadID = UUID()
                        } label: {
                            Label("重新加载", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            openURL(school.authenticationURL)
                        } label: {
                            Label(school.id == "zju" ? "在 Safari 中检查网站" : "在 Safari 中打开", systemImage: "safari")
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.system(size: 13, weight: .semibold))
                    if school.id == "zju" {
                        Text("Safari 仅用于检查学校网站是否可访问。请回到应用内完成登录，Safari 的登录状态无法用于自动导入。")
                            .font(.system(size: 12))
                            .foregroundStyle(PMColor.steel)
                    }
                }
                if let statusMessage {
                    InfoBox(title: "同步状态", message: statusMessage, icon: "info.circle.fill", tint: PMColor.warning)
                }
                Button {
                    syncCourses()
                } label: {
                    Label(isSyncing ? "正在获取课表..." : school.id == "zju" ? "获取浙江大学\(selectedTerm.shortName)课表" : "我已完成登录，获取课表", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PMColor.primary)
                .disabled(isSyncing)
            }
            .padding(14)
            .background(PMColor.softCanvas)
        }
        .navigationTitle(school.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handleNavigationFinished(_ url: URL) {
        loadErrorMessage = nil
        let lowercaseURL = url.absoluteString.lowercased()
        if url.host != school.authenticationURL.host
            || lowercaseURL.contains("login")
            || lowercaseURL.contains("cas/") {
            visitedLoginFlow = true
        }
        guard visitedLoginFlow,
              !hasTriggeredAutomaticSync,
              school.isLikelyAuthenticated(url) else {
            return
        }
        hasTriggeredAutomaticSync = true
        syncCourses()
    }

    private func handleNavigationError(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorSecureConnectionFailed {
            loadErrorMessage = "学校服务器的 TLS 安全连接失败。应用不会绕过证书校验；可尝试切换校园网、稍后重试，或在 Safari 中检查该站点。"
        } else {
            loadErrorMessage = "\(error.localizedDescription) 可尝试重新加载；若学校仅允许校园网访问，请先切换网络。"
        }
    }

    private func syncCourses() {
        guard !isSyncing else { return }
        if school.id == "zju" {
            syncZJUCourses()
        } else {
            syncPrototypeCourses()
        }
    }

    private func syncZJUCourses() {
        isSyncing = true
        Task {
            do {
                let courses = try await ZJUTimetableImportService.courses(for: selectedTerm)
                let count = store.importCourses(courses, source: school.adapterName, term: selectedTerm)
                isSyncing = false
                let message = count == 0
                    ? "浙江大学本科教务\(selectedTerm.shortName)课表已同步，课程均已存在，没有新增课程。"
                    : "已从浙江大学本科教务导入 \(count) 门\(selectedTerm.shortName)课程。请核对单双周、短学期和调休安排。"
                statusMessage = message
                onImported(message)
            } catch {
                isSyncing = false
                statusMessage = error.localizedDescription
            }
        }
    }

    private func syncPrototypeCourses() {
        isSyncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            let courses = CourseImportService.coursesFromAcademicSystem(school, term: selectedTerm)
            let count = store.importCourses(courses, source: school.adapterName, term: selectedTerm)
            isSyncing = false
            let result = count == 0 ? "演示课程均已存在，没有新增课程。" : "已导入 \(count) 门\(selectedTerm.shortName)演示课程。"
            let message = "\(result)\(school.name) 的身份认证入口已经接通；真实课表接口解析器仍待接入，当前结果不是从学校服务器抓取的数据。"
            statusMessage = message
            onImported(message)
        }
    }
}

struct AcademicSystemAuthenticationWebView: UIViewRepresentable {
    let url: URL
    let reloadID: UUID
    @Binding var currentURL: URL?
    @Binding var isLoading: Bool
    var onNavigationFinished: (URL) -> Void
    var onNavigationError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.loadedReloadID = reloadID
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        guard context.coordinator.loadedReloadID != reloadID else { return }
        context.coordinator.loadedReloadID = reloadID
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: AcademicSystemAuthenticationWebView
        var loadedReloadID: UUID?

        init(parent: AcademicSystemAuthenticationWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.currentURL = webView.url
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            parent.currentURL = webView.url
            if let url = webView.url {
                parent.onNavigationFinished(url)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.onNavigationError(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            parent.onNavigationError(error)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: PathMateStore
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    profileCard
                    appearanceCard
                    preferencesCard
                    #if DEBUG
                    mateDemoCard
                    #endif
                    dataCard
                }
                .padding(16)
            }
            .background(PMColor.softCanvas)
            .navigationTitle("设置")
            .toast($toast)
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("个人信息", systemImage: "person.crop.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            settingRow("学校", store.profile.school)
            settingRow("年级", store.profile.grade)
            settingRow("专业", store.profile.major)
            settingRow("发展目标", store.profile.goal.rawValue)
            InfoBox(title: "目标是常驻信息", message: "目标会影响任务优先级。需要调整时请在下方设置区修改。", icon: "lock.fill")
        }
        .padding(16)
        .pathCardStyle()
    }

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("外观", systemImage: "paintpalette.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            ChoiceGrid(items: AppearanceMode.allCases, selection: Binding(get: {
                store.profile.appearanceMode
            }, set: { value in
                store.updateProfile { $0.appearanceMode = value }
                toast = "外观已切换为\(value.rawValue)"
            })) { item in
                Label(item.rawValue, systemImage: item.iconName)
            }
        }
        .padding(16)
        .pathCardStyle()
    }

    private var preferencesCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("目标与习惯", systemImage: "slider.horizontal.3")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            Text("发展目标").sectionLabel()
            ChoiceGrid(items: CareerGoal.allCases, selection: Binding(get: {
                store.profile.goal
            }, set: { value in
                store.updateProfile { $0.goal = value }
                toast = "目标已更新"
            })) { item in
                Label(item.rawValue, systemImage: item.iconName)
            }
            Text("学习习惯").sectionLabel()
            ChoiceGrid(items: LearningHabit.allCases, selection: Binding(get: {
                store.profile.habit
            }, set: { value in
                store.updateProfile { $0.habit = value }
                toast = "学习习惯已更新"
            })) { item in
                Text(item.rawValue)
            }
            InfoBox(title: store.profile.habit.rawValue, message: store.profile.habit.explanation)
            Text("计划方式").sectionLabel()
            ChoiceGrid(items: PlanDetail.allCases, selection: Binding(get: {
                store.profile.detail
            }, set: { value in
                store.updateProfile { $0.detail = value }
                toast = "计划方式已更新"
            })) { item in
                Text(item.rawValue)
            }
        }
        .padding(16)
        .pathCardStyle()
    }

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("数据管理", systemImage: "internaldrive.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            Text("数据保存在本地 UserDefaults 中，关闭重开后仍会保留。")
                .font(.system(size: 14))
                .foregroundStyle(PMColor.slate)
            PathButton(title: "恢复示例数据", systemImage: "arrow.counterclockwise", style: .secondary) {
                store.loadSampleData(completedOnboarding: true, keepProfile: true)
                toast = "已恢复示例数据"
            }
            PathButton(title: "重新进入引导流程", systemImage: "rectangle.portrait.and.arrow.right", style: .secondary) {
                store.restartOnboarding()
            }
            PathButton(title: "清空本地数据", systemImage: "trash", style: .destructive) {
                store.clearAllData()
            }
        }
        .padding(16)
        .pathCardStyle()
    }

    #if DEBUG
    private var mateDemoCard: some View {
        NavigationLink {
            MateDemoView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(PMColor.primary)
                    .frame(width: 38, height: 38)
                    .background(PMColor.primary.opacity(0.12))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mate Demo")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PMColor.charcoal)
                    Text("调试悬浮角色、成长、最小化和事件反馈。")
                        .font(.system(size: 13))
                        .foregroundStyle(PMColor.slate)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(PMColor.muted)
            }
            .padding(16)
            .pathCardStyle()
        }
        .buttonStyle(.plain)
    }
    #endif

    private func settingRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(PMColor.steel)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct CourseDetailView: View {
    @ObservedObject var store: PathMateStore
    var courseID: UUID
    var highlightHomeworkID: UUID?

    @State private var summaryExpanded = false
    @State private var editingCourse: Course?
    @State private var schedulingTodoCourse: Course?
    @State private var studyAidCourseID: UUID?
    @State private var highlight = false
    @State private var isAddingTag = false
    @State private var newTagText = ""
    @State private var toast: String?

    var body: some View {
        Group {
            if let course = store.course(id: courseID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        CourseCard(course: course) {
                            studyAidCourseID = course.id
                        }
                        noteCard(course)
                        summaryCard(course)
                        homeworkCard(course)
                        knowledgeCard(course)
                        reviewCard(course)
                    }
                    .padding(16)
                }
                .background(PMColor.softCanvas)
                .navigationTitle(course.name)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            schedulingTodoCourse = course
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .accessibilityLabel("添加课程待办")
                    }
                    ToolbarItem(placement: .secondaryAction) {
                        Button {
                            editingCourse = course
                        } label: {
                            Label("编辑课程", systemImage: "pencil")
                        }
                    }
                }
                .sheet(item: $editingCourse) { course in
                    CourseEditorSheet(store: store, course: course) {
                        toast = "课程已更新"
                    }
                }
                .sheet(item: $schedulingTodoCourse) { course in
                    CourseTodoScheduleSheet(store: store, course: course) {
                        toast = "课程待办已加入日历"
                    }
                }
                .alert("添加课程标签", isPresented: $isAddingTag) {
                    TextField("10字以内", text: $newTagText)
                    Button("取消", role: .cancel) {
                        newTagText = ""
                    }
                    Button("添加") {
                        addTag(to: course)
                    }
                    .disabled(trimmedNewTag.isEmpty)
                } message: {
                    Text("标签会显示在课程标签栏中。")
                }
                .navigationDestination(item: $studyAidCourseID) { courseID in
                    CourseStudyAidPage(store: store, courseID: courseID)
                }
                .toast($toast)
                .onChange(of: newTagText) { _, value in
                    if value.count > 10 {
                        newTagText = String(value.prefix(10))
                    }
                }
                .onAppear {
                    guard highlightHomeworkID != nil else { return }
                    withAnimation(.easeInOut(duration: 0.45).repeatCount(3, autoreverses: true)) {
                        highlight = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                        highlight = false
                    }
                }
            } else {
                EmptyStateView(systemImage: "exclamationmark.triangle", title: "课程不存在", message: "该课程可能已经被删除。")
                    .padding()
                    .background(PMColor.softCanvas)
            }
        }
    }

    private func noteCard(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("课程标签", systemImage: "tag.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PMColor.charcoal)
                Spacer()
                Button {
                    newTagText = ""
                    isAddingTag = true
                } label: {
                    Label("添加", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(PMColor.primary)
            }
            FlowTags(tags: course.tags, tint: PMColor.primary)
            Text(course.courseNote)
                .font(.system(size: 14))
                .foregroundStyle(PMColor.slate)
        }
        .padding(16)
        .pathCardStyle()
    }

    private var trimmedNewTag: String {
        String(newTagText.trimmingCharacters(in: .whitespacesAndNewlines).prefix(10))
    }

    private func addTag(to course: Course) {
        let tag = trimmedNewTag
        guard !tag.isEmpty else { return }
        guard !course.tags.contains(tag) else {
            toast = "标签已存在"
            newTagText = ""
            return
        }
        var edited = course
        edited.tags.append(tag)
        store.updateCourse(edited)
        newTagText = ""
        toast = "标签已添加"
    }

    private func summaryCard(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("课件摘要", systemImage: "doc.text.magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(PMColor.charcoal)
                Spacer()
                NavigationLink {
                    CourseMaterialsView(store: store, courseID: course.id)
                } label: {
                    Label("查看课件", systemImage: "folder.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
            Text(course.summary)
                .font(.system(size: 15))
                .foregroundStyle(PMColor.slate)
                .lineLimit(summaryExpanded ? nil : 3)
            Button(summaryExpanded ? "收起摘要" : "展开完整摘要") {
                withAnimation { summaryExpanded.toggle() }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(PMColor.primary)
        }
        .padding(16)
        .pathCardStyle()
    }

    private func homeworkCard(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("本周作业", systemImage: "doc.badge.clock")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            if course.homework.isEmpty {
                Text("本周暂无作业。")
                    .font(.system(size: 14))
                    .foregroundStyle(PMColor.slate)
            } else {
                ForEach(course.homework) { homework in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(homework.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PMColor.charcoal)
                            Spacer()
                            TagChip(title: homework.isCompleted ? "已完成" : "未完成", systemImage: homework.isCompleted ? "checkmark" : "clock", tint: homework.isCompleted ? PMColor.success : PMColor.warning)
                        }
                        Text("截止：\(PathMateTime.weekdayName(homework.dueWeekday)) \(PathMateTime.timeString(homework.dueMinute))")
                            .font(.system(size: 13))
                            .foregroundStyle(PMColor.steel)
                        Text(homework.detail)
                            .font(.system(size: 14))
                            .foregroundStyle(PMColor.slate)
                        Button(homework.isCompleted ? "标记未完成" : "标记完成") {
                            store.toggleHomework(courseID: course.id, homeworkID: homework.id)
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PMColor.primary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(highlightHomeworkID == homework.id && highlight ? PMColor.warning.opacity(0.25) : PMColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pathCardStyle()
    }

    private func knowledgeCard(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("重点知识点", systemImage: "lightbulb.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                ForEach(course.studyTopics) { topic in
                    NavigationLink {
                        StudyAidView(course: course, topic: topic)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "arrow.up.forward.circle.fill")
                                .foregroundStyle(PMColor.primary)
                            Text(topic.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(PMColor.charcoal)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(PMColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .pathCardStyle()
    }

    private func reviewCard(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Agent 复习建议", systemImage: "sparkles")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            Text("建议在课程结束后当天完成 \(store.profile.detail == .detailed ? "45 分钟" : "25 分钟")复盘。若本周存在作业或小测，优先完成公式、概念和典型题整理。")
                .font(.system(size: 15))
                .foregroundStyle(PMColor.slate)
            PathButton(title: "生成复习任务", systemImage: "plus.circle.fill") {
                store.generateReviewTask(for: course)
                toast = "已生成复习任务"
            }
            PathButton(title: "添加课程待办", systemImage: "calendar.badge.plus", style: .secondary) {
                schedulingTodoCourse = course
            }
        }
        .padding(16)
        .pathCardStyle()
    }
}

struct CourseMaterialsView: View {
    @ObservedObject var store: PathMateStore
    var courseID: UUID
    @State private var toast: String?

    var body: some View {
        Group {
            if let course = store.course(id: courseID) {
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(course.materials) { material in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(material.title)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(PMColor.charcoal)
                                        Text("\(material.type) · \(material.dateText)")
                                            .font(.system(size: 13))
                                            .foregroundStyle(PMColor.steel)
                                    }
                                    Spacer()
                                    TagChip(title: material.isDownloaded ? "已下载" : "未下载", systemImage: material.isDownloaded ? "checkmark" : "arrow.down", tint: material.isDownloaded ? PMColor.success : PMColor.primary)
                                }
                                Text(material.summary)
                                    .font(.system(size: 14))
                                    .foregroundStyle(PMColor.slate)
                                HStack {
                                    Button("查看") {
                                        toast = "已打开「\(material.title)」预览"
                                    }
                                    .buttonStyle(.bordered)
                                    Button("下载") {
                                        store.markMaterialDownloaded(courseID: course.id, materialID: material.id)
                                        toast = "已模拟下载课件"
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(PMColor.primary)
                                }
                                .font(.system(size: 13, weight: .semibold))
                            }
                            .padding(16)
                            .pathCardStyle()
                        }
                    }
                    .padding(16)
                }
                .background(PMColor.softCanvas)
                .navigationTitle("课件")
                .toast($toast)
            } else {
                EmptyStateView(systemImage: "folder", title: "课程不存在", message: "无法查看课件。")
                    .padding()
            }
        }
    }
}

private enum CourseAidSource: String, CaseIterable, Identifiable {
    case courseware = "课件"
    case replay = "回放"

    var id: String { rawValue }

    var mediaTitle: String {
        switch self {
        case .courseware: return "课件"
        case .replay: return "视频回放"
        }
    }
}

private struct StudyMapTopic: Identifiable, Equatable {
    var id: String
    var title: String
    var explanation: String
    var example: String
    var recommendation: String
}

struct CourseStudyAidPage: View {
    @ObservedObject var store: PathMateStore
    var courseID: UUID

    @State private var selectedSource: CourseAidSource = .courseware
    @State private var focusedTitle: String?
    @State private var confirmedTitle: String?
    @State private var isConfirmed = false

    private let panelColor = Color(hex: "#d9d9d9")
    private let mediaColor = Color(hex: "#3a2f31")

    var body: some View {
        Group {
            if let course = store.course(id: courseID) {
                ScrollView {
                    VStack(spacing: 18) {
                        sourcePanel(course)
                        mindMapPanel(course)
                        if isConfirmed {
                            learningContent(course)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 18)
                }
                .background(Color.white)
                .navigationTitle("辅学")
                .navigationBarTitleDisplayMode(.inline)
            } else {
                EmptyStateView(systemImage: "graduationcap", title: "课程不存在", message: "无法打开辅学内容。")
                    .padding()
                    .background(PMColor.softCanvas)
            }
        }
    }

    private func sourcePanel(_ course: Course) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 18) {
                ForEach(CourseAidSource.allCases) { source in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            selectedSource = source
                            isConfirmed = false
                            confirmedTitle = nil
                            focusedTitle = nil
                        }
                    } label: {
                        Text(source.rawValue)
                            .font(.system(size: 20, weight: selectedSource == source ? .bold : .semibold))
                            .foregroundStyle(selectedSource == source ? Color.black : Color.gray)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("课程章节（包含哪些知识点）")
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(Color.black)
                .padding(.leading, 22)

            ZStack {
                mediaColor
                Text(selectedSource.mediaTitle)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 150)
        }
        .padding(22)
        .background(panelColor)
    }

    private func mindMapPanel(_ course: Course) -> some View {
        VStack(spacing: 16) {
            if isConfirmed {
                collapsedMap(course)
            } else {
                StudyMindMapCanvas(
                    centerTitle: centerTitle(for: course),
                    branches: branchTitles(for: course),
                    onSelect: { title in
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            focusedTitle = title
                        }
                    }
                )
                .frame(height: 410)

                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        confirmedTitle = centerTitle(for: course)
                        isConfirmed = true
                    }
                } label: {
                    Text("确定")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .background(Color.black)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(panelColor)
    }

    private func collapsedMap(_ course: Course) -> some View {
        HStack(spacing: 12) {
            Text(confirmedTitle ?? centerTitle(for: course))
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 18)
                .frame(height: 46)
                .background(mediaColor)
            ForEach(branchTitles(for: course).prefix(2), id: \.self) { title in
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.72))
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(Color.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            Text("已确定")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }

    private func learningContent(_ course: Course) -> some View {
        let topic = selectedTopic(in: course)
        return VStack(alignment: .leading, spacing: 18) {
            Text(confirmedTitle ?? topic.title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Color.black)

            contentBlock(title: "知识点学习", text: topic.explanation)
            contentBlock(title: "典型例子", text: topic.example)
            contentBlock(title: "相关知识点", text: branchTitles(for: course).prefix(4).joined(separator: "、"))
            contentBlock(title: "学习建议", text: topic.recommendation)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(panelColor)
    }

    private func contentBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(Color.black)
            Text(text.isEmpty ? "围绕该知识点补充学习内容。" : text)
                .font(.system(size: 16))
                .foregroundStyle(Color.black.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func topics(for course: Course) -> [StudyMapTopic] {
        if !course.studyTopics.isEmpty {
            return course.studyTopics.map {
                StudyMapTopic(id: $0.id.uuidString, title: $0.title, explanation: $0.explanation, example: $0.example, recommendation: $0.recommendation)
            }
        }
        return course.keyPoints.enumerated().map { index, title in
            StudyMapTopic(
                id: "\(index)-\(title)",
                title: title,
                explanation: "\(title) 是 \(course.name) 中需要优先理解的核心知识点。",
                example: "结合课程章节和课堂例题，先识别 \(title) 出现的典型情境。",
                recommendation: "先画出概念关系，再完成一道对应练习。"
            )
        }
    }

    private func centerTitle(for course: Course) -> String {
        focusedTitle ?? "\(course.name)核心内容"
    }

    private func branchTitles(for course: Course) -> [String] {
        let allTopics = topics(for: course).map(\.title)
        guard let focusedTitle else {
            return Array(allTopics.prefix(5))
        }

        let generated = ["概念解释", "典型例子", "应用场景", "常见误区", "复习路径"].map { "\(focusedTitle)·\($0)" }
        let related = allTopics.filter { $0 != focusedTitle }
        return Array((generated + related).prefix(5))
    }

    private func selectedTopic(in course: Course) -> StudyMapTopic {
        let title = confirmedTitle ?? focusedTitle
        if let title, let topic = topics(for: course).first(where: { $0.title == title }) {
            return topic
        }
        return StudyMapTopic(
            id: "generated",
            title: title ?? "\(course.name)核心内容",
            explanation: "围绕 \(title ?? course.name) 展开学习，先建立中心概念，再向相关知识点扩展。",
            example: "把课件或回放中的关键片段作为例子，对照章节中的概念关系进行理解。",
            recommendation: "完成这一块后，再回到思维导图选择下一个分支继续学习。"
        )
    }
}

struct StudyMindMapCanvas: View {
    var centerTitle: String
    var branches: [String]
    var onSelect: (String) -> Void

    private let nodeColor = Color(hex: "#3a2f31")

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let positions = branchPositions(in: size)

            ZStack {
                Path { path in
                    for point in positions.prefix(branches.count) {
                        path.move(to: center)
                        path.addLine(to: point)
                    }
                }
                .stroke(Color.black.opacity(0.26), lineWidth: 2)

                ForEach(Array(branches.enumerated()), id: \.offset) { index, title in
                    Button {
                        onSelect(title)
                    } label: {
                        mapNode(title: title, isCenter: false)
                    }
                    .buttonStyle(.plain)
                    .position(positions[index])
                }

                mapNode(title: centerTitle, isCenter: true)
                    .position(center)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    private func mapNode(title: String, isCenter: Bool) -> some View {
        Text(title)
            .font(.system(size: isCenter ? 16 : 12, weight: isCenter ? .bold : .semibold))
            .foregroundStyle(isCenter ? .white : Color.black)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, isCenter ? 16 : 10)
            .frame(width: isCenter ? 138 : 104, height: isCenter ? 62 : 48)
            .background(isCenter ? nodeColor : Color.white.opacity(0.72))
    }

    private func branchPositions(in size: CGSize) -> [CGPoint] {
        [
            CGPoint(x: size.width * 0.22, y: size.height * 0.22),
            CGPoint(x: size.width * 0.78, y: size.height * 0.22),
            CGPoint(x: size.width * 0.18, y: size.height * 0.67),
            CGPoint(x: size.width * 0.82, y: size.height * 0.67),
            CGPoint(x: size.width * 0.5, y: size.height * 0.84)
        ]
    }
}

struct TopicAidCard: View {
    var topic: StudyAidTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(PMColor.warning)
                    .frame(width: 34, height: 34)
                    .background(PMColor.warning.opacity(0.13))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(topic.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(PMColor.charcoal)
                    Text(topic.explanation)
                        .font(.system(size: 14))
                        .foregroundStyle(PMColor.slate)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .foregroundStyle(PMColor.muted)
                    .padding(.top, 8)
            }
            HStack(spacing: 8) {
                TagChip(title: "例子", systemImage: "pencil.and.outline", tint: PMColor.primary)
                TagChip(title: "复习建议", systemImage: "sparkles", tint: PMColor.success)
            }
        }
        .padding(16)
        .pathCardStyle()
    }
}

struct StudyAidView: View {
    var course: Course
    var topic: StudyAidTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(topic.title)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(PMColor.ink)
                    Text(course.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PMColor.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .pathCardStyle()
                aidCard(title: "概念解释", icon: "lightbulb.fill", text: topic.explanation)
                aidCard(title: "典型例子", icon: "pencil.and.outline", text: topic.example)
                aidCard(title: "复习建议", icon: "sparkles", text: topic.recommendation)
                aidCard(title: "推荐资源", icon: "play.rectangle.fill", text: "公开视频 / 实验演示 / 可视化材料：原型中以模拟资源呈现，后续可接入真实课程平台或公开视频搜索。")
            }
            .padding(16)
        }
        .background(PMColor.softCanvas)
        .navigationTitle("辅学")
    }

    private func aidCard(title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(PMColor.slate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .pathCardStyle()
    }
}

struct NonCourseDetailView: View {
    var task: PlanTask

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    Label(task.title, systemImage: task.kind.iconName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(PMColor.ink)
                    Text(PathMateTime.scheduleText(for: task))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(PMColor.slate)
                    FlowTags(tags: [task.kind.rawValue, "优先级 \(task.priority)", task.isMovable ? "可调整" : "固定"], tint: PMColor.task(task.kind))
                }
                .padding(16)
                .pathCardStyle()
                aidCard(title: "事项说明", text: task.note.isEmpty ? "这是用户自定义的非课程事项，可用于比赛、社团、出行或个人安排。" : task.note)
                if let conflictSource = task.conflictSource {
                    aidCard(title: "冲突与调整记录", text: conflictSource)
                }
            }
            .padding(16)
        }
        .background(PMColor.softCanvas)
        .navigationTitle("事项详情")
    }

    private func aidCard(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(PMColor.charcoal)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(PMColor.slate)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .pathCardStyle()
    }
}

struct TaskDestinationView: View {
    @ObservedObject var store: PathMateStore
    var task: PlanTask

    var body: some View {
        if let course = store.course(id: task.courseID) {
            CourseDetailView(store: store, courseID: course.id, highlightHomeworkID: task.kind == .assignment ? task.homeworkID : nil)
        } else {
            NonCourseDetailView(task: task)
        }
    }
}

struct MonthCalendarView: View {
    @Binding var selectedDate: Date
    var tasks: [PlanTask]
    @Binding var isExpanded: Bool

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { item in
                    Text(item)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PMColor.steel)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: isExpanded ? 14 : 8) {
                ForEach(Array(displayDates.enumerated()), id: \.offset) { _, date in
                    if let date {
                        dayCell(date)
                    } else {
                        Color.clear.frame(height: 58)
                    }
                }
            }

            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    Text(isExpanded ? "收起为本周" : "展开整月")
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PMColor.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .pathCardStyle()
        .gesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    let horizontalDistance = value.translation.width
                    let verticalDistance = value.translation.height
                    if abs(horizontalDistance) > abs(verticalDistance) {
                        if horizontalDistance < -32 {
                            moveSelectedMonth(by: 1)
                        } else if horizontalDistance > 32 {
                            moveSelectedMonth(by: -1)
                        }
                    } else if verticalDistance > 18 {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            isExpanded = true
                        }
                    } else if verticalDistance < -18 {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                            isExpanded = false
                        }
                    }
                }
        )
    }

    private func dayCell(_ date: Date) -> some View {
        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let day = Calendar.current.component(.day, from: date)
        let dayTasks = tasks.filter { PathMateTime.taskOccurs($0, on: date) }

        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 7) {
                Text("\(day)")
                    .font(.system(size: 22, weight: selected ? .bold : .medium))
                    .foregroundStyle(selected ? .white : PMColor.ink)
                    .frame(width: 46, height: 40)
                    .background(selected ? PMColor.primary : .clear)
                    .clipShape(Circle())
                HStack(spacing: 3) {
                    ForEach(Array(dayTasks.prefix(5).enumerated()), id: \.offset) { _, task in
                        Circle()
                            .fill(PMColor.task(task.kind))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 6)
            }
            .frame(height: 58)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func moveSelectedMonth(by offset: Int) {
        let calendar = Calendar.current
        let preferredDay = calendar.component(.day, from: selectedDate)
        let currentMonth = startOfMonth(containing: selectedDate)
        guard let targetMonth = calendar.date(byAdding: .month, value: offset, to: currentMonth) else {
            return
        }

        let dayCount = calendar.range(of: .day, in: .month, for: targetMonth)?.count ?? preferredDay
        let clampedDay = min(preferredDay, dayCount)
        guard let targetDate = calendar.date(byAdding: .day, value: clampedDay - 1, to: targetMonth) else {
            return
        }

        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            selectedDate = targetDate
        }
    }

    private func startOfMonth(containing date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private var displayDates: [Date?] {
        if isExpanded {
            return monthDates
        }
        return weekDates(containing: selectedDate).map { Optional($0) }
    }

    private var monthDates: [Date?] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        guard let start = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: start)
        else { return [] }
        let leading = max(0, PathMateTime.weekday(from: start) - 1)
        var result = Array<Date?>(repeating: nil, count: leading)
        result += range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: start)
        }
        return result
    }

    private func weekDates(containing date: Date) -> [Date] {
        let calendar = Calendar.current
        let weekday = PathMateTime.weekday(from: date)
        guard let monday = calendar.date(byAdding: .day, value: 1 - weekday, to: date) else {
            return []
        }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: monday)
        }
    }
}

struct CourseTimetableView: View {
    @ObservedObject var store: PathMateStore
    var term: AcademicTerm = AcademicTerm.current()

    private let weekdayTitles = ["一", "二", "三", "四", "五", "六", "日"]
    private let timeColumnWidth: CGFloat = 54
    private let dayWidth: CGFloat = 84
    private let headerHeight: CGFloat = 48
    private let periodHeight: CGFloat = 64

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                timetable
            }
            .padding(16)
        }
        .background(PMColor.softCanvas)
        .navigationTitle("周课表")
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(term.displayName)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(PMColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("第 1-13 节 · \(courseTasks.count) 门固定课程")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PMColor.slate)
            }
            Spacer()
            Image(systemName: "list.bullet")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(PMColor.primary)
                .frame(width: 44, height: 44)
                .background(PMColor.primary.opacity(0.12))
                .clipShape(Circle())
        }
    }

    private var timetable: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            ZStack(alignment: .topLeading) {
                grid
                ForEach(courseTasks) { task in
                    courseBlock(task)
                        .frame(width: dayWidth - 8, height: blockHeight(for: task))
                        .offset(x: blockX(for: task), y: blockY(for: task))
                }
            }
            .frame(width: totalWidth, height: totalHeight)
            .padding(.vertical, 4)
        }
        .padding(14)
        .pathCardStyle(cornerRadius: 18)
    }

    private var grid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Color.clear
                    .frame(width: timeColumnWidth, height: headerHeight)
                ForEach(weekdayTitles, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(PMColor.charcoal)
                        .frame(width: dayWidth, height: headerHeight)
                }
            }

            ForEach(PathMateTime.classPeriods) { period in
                HStack(spacing: 0) {
                    VStack(spacing: 2) {
                        Text(PathMateTime.timeString(period.startMinute))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PMColor.steel)
                        Text("\(period.number)")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(PMColor.ink)
                        Text(PathMateTime.timeString(period.endMinute))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PMColor.steel)
                    }
                    .frame(width: timeColumnWidth, height: periodHeight)

                    ForEach(1...7, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: dayWidth, height: periodHeight)
                            .overlay {
                                Rectangle()
                                    .stroke(PMColor.hairline.opacity(0.7), lineWidth: 0.5)
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func courseBlock(_ task: PlanTask) -> some View {
        NavigationLink {
            TaskDestinationView(store: store, task: task)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(trimmedCourseTitle(task.title))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)
                Text(store.course(id: task.courseID)?.location ?? "地点待定")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(blockColor(for: task))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: blockColor(for: task).opacity(0.22), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }

    private var courseTasks: [PlanTask] {
        store.tasks(in: term)
            .filter { $0.kind == .course }
            .sorted { lhs, rhs in
                if lhs.weekday == rhs.weekday {
                    return lhs.startMinute < rhs.startMinute
                }
                return lhs.weekday < rhs.weekday
            }
    }

    private var totalWidth: CGFloat {
        timeColumnWidth + dayWidth * 7
    }

    private var totalHeight: CGFloat {
        headerHeight + periodHeight * CGFloat(PathMateTime.classPeriods.count)
    }

    private func blockColor(for task: PlanTask) -> Color {
        switch store.course(id: task.courseID)?.weight {
        case .high: return PMColor.primary
        case .medium: return Color(hex: "#2f73b8")
        case .low: return PMColor.goal
        case nil: return PMColor.primary
        }
    }

    private func blockX(for task: PlanTask) -> CGFloat {
        timeColumnWidth + CGFloat(max(0, task.weekday - 1)) * dayWidth + 4
    }

    private func blockY(for task: PlanTask) -> CGFloat {
        headerHeight + CGFloat(startPeriodIndex(for: task)) * periodHeight + 4
    }

    private func blockHeight(for task: PlanTask) -> CGFloat {
        CGFloat(periodSpan(for: task)) * periodHeight - 8
    }

    private func startPeriodIndex(for task: PlanTask) -> Int {
        guard let index = PathMateTime.classPeriods.firstIndex(where: { task.startMinute < $0.endMinute }) else {
            return max(PathMateTime.classPeriods.count - 1, 0)
        }
        return index
    }

    private func endPeriodIndex(for task: PlanTask) -> Int {
        let reference = max(task.endMinute - 1, task.startMinute)
        guard let index = PathMateTime.classPeriods.firstIndex(where: { reference < $0.endMinute }) else {
            return max(PathMateTime.classPeriods.count - 1, 0)
        }
        return index
    }

    private func periodSpan(for task: PlanTask) -> Int {
        max(1, endPeriodIndex(for: task) - startPeriodIndex(for: task) + 1)
    }

    private func trimmedCourseTitle(_ title: String) -> String {
        title.replacingOccurrences(of: "课堂", with: "")
    }
}

struct AgendaCard: View {
    var task: PlanTask
    var course: Course?

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(PMColor.task(task.kind))
                .frame(width: 16, height: 16)
            VStack(alignment: .leading, spacing: 7) {
                Text(task.title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(PMColor.charcoal)
                    .lineLimit(2)
                Label("时间：\(PathMateTime.rangeString(start: task.startMinute, duration: task.durationMinutes))", systemImage: "clock.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(PMColor.steel)
                Label("地点：\(course?.location ?? "自定义事项")", systemImage: "mappin.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(PMColor.steel)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(PMColor.muted)
        }
        .padding(18)
        .pathCardStyle(cornerRadius: 18)
    }
}

struct UpcomingCard: View {
    var task: PlanTask
    var course: Course?
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: task.kind.iconName)
                    .foregroundStyle(PMColor.task(task.kind))
                    .frame(width: 36, height: 36)
                    .background(PMColor.task(task.kind).opacity(0.13))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(task.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(PMColor.charcoal)
                    Text("\(relativeDayText) \(PathMateTime.rangeString(start: task.startMinute, duration: task.durationMinutes)) · \(course?.location ?? task.kind.rawValue)")
                        .font(.system(size: 13))
                        .foregroundStyle(PMColor.steel)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(PMColor.muted)
            }
            if minutesUntilStart <= 20 {
                HStack {
                    Label("还有 \(PathMateTime.countdownText(minutes: minutesUntilStart)) 开始", systemImage: "timer")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(PMColor.warning)
                    Spacer()
                }
                ProgressView(value: 1 - Double(minutesUntilStart) / 20.0)
                    .tint(PMColor.warning)
            }
        }
        .padding(16)
        .pathCardStyle()
    }

    private var minutesUntilStart: Int {
        PathMateTime.minutesUntilStart(of: task, from: now)
    }

    private var relativeDayText: String {
        PathMateTime.relativeDayText(for: task, from: now)
    }
}

struct CountdownFocusCard: View {
    var task: PlanTask
    var course: Course?
    var now: Date
    var isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(PMColor.task(task.kind))
                    .frame(width: 16, height: 16)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 10) {
                    Text(task.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(PMColor.charcoal)
                        .lineLimit(1)
                    Label(course?.location ?? task.kind.rawValue, systemImage: "mappin.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(PMColor.charcoal)
                        .lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Label(PathMateTime.rangeString(start: task.startMinute, duration: task.durationMinutes), systemImage: "clock.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PMColor.slate)
                    Text(isCurrent ? "离结束还有" : "离开始还有")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PMColor.slate)
                    Text(countdown)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(PMColor.charcoal)
                        .monospacedDigit()
                }
            }
            ProgressView(value: progress)
                .tint(PMColor.task(task.kind))
        }
        .padding(18)
        .pathCardStyle(cornerRadius: 18)
    }

    private var countdown: String {
        if isCurrent {
            return PathMateTime.remainingText(for: task, at: now)
        }
        return PathMateTime.countdownText(minutes: PathMateTime.minutesUntilStart(of: task, from: now))
    }

    private var progress: Double {
        if isCurrent {
            return PathMateTime.progress(of: task, at: now)
        }
        let minutes = min(max(PathMateTime.minutesUntilStart(of: task, from: now), 0), 24 * 60)
        return 1 - Double(minutes) / Double(24 * 60)
    }
}

struct ImportMethodRow: View {
    var icon: String
    var title: String
    var message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(PMColor.primary)
                .frame(width: 34, height: 34)
                .background(PMColor.primary.opacity(0.13))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PMColor.charcoal)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(PMColor.slate)
            }
            Spacer()
        }
        .padding(14)
        .pathCardStyle()
    }
}

struct FeatureLine: View {
    var icon: String
    var title: String
    var message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(PMColor.primary)
                .frame(width: 32, height: 32)
                .background(PMColor.primary.opacity(0.12))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(PMColor.charcoal)
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(PMColor.slate)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .pathCardStyle()
    }
}

struct ChoiceGrid<Item: Identifiable & Hashable, LabelContent: View>: View {
    var items: [Item]
    @Binding var selection: Item
    var label: (Item) -> LabelContent

    private let columns = [GridItem(.adaptive(minimum: 128), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { item in
                Button {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.86)) {
                        selection = item
                    }
                } label: {
                    label(item)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selection == item ? .white : PMColor.charcoal)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 10)
                        .background(selection == item ? PMColor.primary : PMColor.surfaceRaised)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(selection == item ? .clear : PMColor.hairline, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct TimeWheelPickerRow: View {
    var title: String
    @Binding var minute: Int
    var allowedHours: ClosedRange<Int>
    var minuteStep: Int

    private var minuteOptions: [Int] {
        stride(from: 0, through: 59, by: minuteStep).map { $0 }
    }

    var body: some View {
        DisclosureGroup {
            HStack(spacing: 0) {
                Picker("小时", selection: hourBinding) {
                    ForEach(Array(allowedHours), id: \.self) { hour in
                        Text("\(hour)时").tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .clipped()

                Picker("分钟", selection: minuteBinding) {
                    ForEach(minuteOptions, id: \.self) { value in
                        Text(String(format: "%02d分", value)).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .clipped()
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(PathMateTime.timeString(minute))
                    .foregroundStyle(PMColor.steel)
                    .monospacedDigit()
            }
        }
        .onAppear {
            minute = clamped(minute)
        }
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { min(max(minute / 60, allowedHours.lowerBound), allowedHours.upperBound) },
            set: { newHour in
                minute = clamped(newHour * 60 + nearestMinuteOption(minute % 60))
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { nearestMinuteOption(minute % 60) },
            set: { newMinute in
                minute = clamped((minute / 60) * 60 + newMinute)
            }
        )
    }

    private func nearestMinuteOption(_ value: Int) -> Int {
        minuteOptions.min { abs($0 - value) < abs($1 - value) } ?? 0
    }

    private func clamped(_ value: Int) -> Int {
        min(max(value, allowedHours.lowerBound * 60), allowedHours.upperBound * 60)
    }
}

struct DurationWheelPickerRow: View {
    var title: String
    @Binding var minutes: Int
    var range: ClosedRange<Int>
    var minuteStep: Int

    private var hourOptions: [Int] {
        Array(0...(range.upperBound / 60))
    }

    private var minuteOptions: [Int] {
        stride(from: 0, through: 59, by: minuteStep).map { $0 }
    }

    var body: some View {
        DisclosureGroup {
            HStack(spacing: 0) {
                Picker("小时", selection: hourBinding) {
                    ForEach(hourOptions, id: \.self) { hour in
                        Text("\(hour)小时").tag(hour)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .clipped()

                Picker("分钟", selection: minuteBinding) {
                    ForEach(minuteOptions, id: \.self) { value in
                        Text(String(format: "%02d分", value)).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .clipped()
            }
            .padding(.vertical, 4)
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(durationText)
                    .foregroundStyle(PMColor.steel)
                    .monospacedDigit()
            }
        }
        .onAppear {
            minutes = clamped(minutes)
        }
    }

    private var hourBinding: Binding<Int> {
        Binding(
            get: { minutes / 60 },
            set: { newHour in
                minutes = clamped(newHour * 60 + nearestMinuteOption(minutes % 60))
            }
        )
    }

    private var minuteBinding: Binding<Int> {
        Binding(
            get: { nearestMinuteOption(minutes % 60) },
            set: { newMinute in
                minutes = clamped((minutes / 60) * 60 + newMinute)
            }
        )
    }

    private var durationText: String {
        let hour = minutes / 60
        let minutePart = minutes % 60
        if hour > 0 && minutePart > 0 {
            return "\(hour)小时\(minutePart)分钟"
        }
        if hour > 0 {
            return "\(hour)小时"
        }
        return "\(minutePart)分钟"
    }

    private func nearestMinuteOption(_ value: Int) -> Int {
        minuteOptions.min { abs($0 - value) < abs($1 - value) } ?? 0
    }

    private func clamped(_ value: Int) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}

struct TaskEditorSheet: View {
    @ObservedObject var store: PathMateStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: PlanTask

    init(store: PathMateStore, task: PlanTask) {
        self.store = store
        _draft = State(initialValue: task)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("任务") {
                    TextField("任务名称", text: $draft.title)
                    Picker("类型", selection: $draft.kind) {
                        ForEach(TaskKind.allCases) { kind in
                            Text(kind.rawValue).tag(kind)
                        }
                    }
                    Stepper("优先级 \(draft.priority)", value: $draft.priority, in: 1...5)
                    Toggle("允许 Agent 移动", isOn: $draft.isMovable)
                }
                Section("时间") {
                    Picker("星期", selection: $draft.weekday) {
                        ForEach(1...7, id: \.self) { day in
                            Text(PathMateTime.weekdayName(day)).tag(day)
                        }
                    }
                    Stepper("开始 \(PathMateTime.timeString(draft.startMinute))", value: $draft.startMinute, in: 7 * 60...22 * 60, step: 30)
                    Stepper("时长 \(draft.durationMinutes) 分钟", value: $draft.durationMinutes, in: 15...240, step: 15)
                }
                Section("说明") {
                    TextEditor(text: $draft.note)
                        .frame(minHeight: 90)
                }
            }
            .navigationTitle("编辑任务")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.updateTask(draft)
                        dismiss()
                    }
                    .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct CourseEditorSheet: View {
    @ObservedObject var store: PathMateStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Course
    @State private var selectedTerm: AcademicTerm
    @State private var tagsText: String
    var onSaved: () -> Void

    init(store: PathMateStore, course: Course?, onSaved: @escaping () -> Void) {
        self.store = store
        self.onSaved = onSaved
        let initial = course ?? Course(
            id: UUID(),
            name: "新课程",
            teacher: "教师",
            weekday: 1,
            startMinute: 8 * 60 + 30,
            durationMinutes: 95,
            location: "教学楼",
            weight: .medium,
            goalRelation: "与当前目标相关",
            summary: "在这里填写课程摘要。",
            keyPoints: ["知识点一", "知识点二"],
            tags: ["新课程"],
            homework: [],
            materials: [],
            courseNote: "补充课程说明。",
            studyTopics: [],
            academicTerm: AcademicTerm.current()
        )
        _draft = State(initialValue: initial)
        _selectedTerm = State(initialValue: initial.academicTerm ?? AcademicTerm.current())
        _tagsText = State(initialValue: initial.tags.joined(separator: "、"))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("课程信息") {
                    TextField("课程名", text: $draft.name)
                    TextField("教师", text: $draft.teacher)
                    TextField("地点", text: $draft.location)
                    Picker("权重", selection: $draft.weight) {
                        ForEach(CourseWeight.allCases) { weight in
                            Text(weight.rawValue).tag(weight)
                        }
                    }
                    Picker("学期", selection: $selectedTerm) {
                        ForEach(store.editableAcademicTerms()) { term in
                            Text(term.displayName).tag(term)
                        }
                    }
                }
                Section("上课时间") {
                    Picker("星期", selection: $draft.weekday) {
                        ForEach(1...7, id: \.self) { day in
                            Text(PathMateTime.weekdayName(day)).tag(day)
                        }
                    }
                    Stepper("开始 \(PathMateTime.timeString(draft.startMinute))", value: $draft.startMinute, in: 7 * 60...22 * 60, step: 30)
                    Stepper("时长 \(draft.durationMinutes) 分钟", value: $draft.durationMinutes, in: 45...180, step: 5)
                }
                Section("标签与目标") {
                    TextField("课程标签，用顿号分隔", text: $tagsText)
                    TextField("目标关系", text: $draft.goalRelation)
                    TextEditor(text: $draft.courseNote)
                        .frame(minHeight: 70)
                }
                Section("摘要") {
                    TextEditor(text: $draft.summary)
                        .frame(minHeight: 90)
                }
            }
            .navigationTitle("编辑课程")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        draft.tags = tagsText.split(separator: "、").map { String($0) }.filter { !$0.isEmpty }
                        draft.academicTerm = selectedTerm
                        if store.courses.contains(where: { $0.id == draft.id }) {
                            store.updateCourse(draft)
                        } else {
                            store.addCourse(draft)
                        }
                        onSaved()
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

struct AddPersonalEventSheet: View {
    @ObservedObject var store: PathMateStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = "比赛训练"
    @State private var selectedDate: Date
    @State private var isFixedSchedule = false
    @State private var recurrenceUnit: ScheduleRecurrenceUnit = .week
    @State private var recurrenceWeekday: Int
    @State private var recurrenceDayOfMonth: Int
    @State private var startMinute = 14 * 60
    @State private var durationMinutes = 120
    @State private var importance = 4
    @State private var isMovable = false
    var onSaved: (AgentSuggestion?) -> Void

    init(store: PathMateStore, defaultDate: Date, onSaved: @escaping (AgentSuggestion?) -> Void) {
        self.store = store
        self.onSaved = onSaved
        _selectedDate = State(initialValue: defaultDate)
        _recurrenceWeekday = State(initialValue: PathMateTime.weekday(from: defaultDate))
        _recurrenceDayOfMonth = State(initialValue: Calendar.current.component(.day, from: defaultDate))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("个人事项") {
                    TextField("事项名称", text: $title)
                    TimeWheelPickerRow(title: "开始时间", minute: $startMinute, allowedHours: 7...22, minuteStep: 5)
                    DurationWheelPickerRow(title: "时长", minutes: $durationMinutes, range: 30...240, minuteStep: 5)
                    Stepper("重要程度 \(importance)", value: $importance, in: 1...5)
                    Toggle("允许 Agent 后续移动该事项", isOn: $isMovable)
                }
                Section("日期") {
                    DatePicker("添加日期", selection: $selectedDate, displayedComponents: .date)
                    Toggle("长期固定日程", isOn: $isFixedSchedule)
                    if isFixedSchedule {
                        Picker("重复频率", selection: $recurrenceUnit) {
                            ForEach(ScheduleRecurrenceUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        if recurrenceUnit.isMonthly {
                            Picker("每次日期", selection: $recurrenceDayOfMonth) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)号").tag(day)
                                }
                            }
                        } else {
                            Picker("每次日期", selection: $recurrenceWeekday) {
                                ForEach(1...7, id: \.self) { day in
                                    Text(PathMateTime.weekdayName(day)).tag(day)
                                }
                            }
                        }
                    }
                }
                Section {
                    Text(isFixedSchedule ? "长期固定日程会从选定日期开始向后生成，不会影响过去日期。" : "临时日程只会添加在选定当天，日历小点也只显示在这一天。")
                        .font(.system(size: 13))
                        .foregroundStyle(PMColor.steel)
                }
            }
            .navigationTitle("添加事项")
            .onChange(of: selectedDate) { _, newDate in
                recurrenceWeekday = PathMateTime.weekday(from: newDate)
                recurrenceDayOfMonth = Calendar.current.component(.day, from: newDate)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let suggestion = store.addPersonalEvent(
                            title: title,
                            date: selectedDate,
                            recurrence: recurrence,
                            startMinute: startMinute,
                            durationMinutes: durationMinutes,
                            importance: importance,
                            isMovable: isMovable
                        )
                        onSaved(suggestion)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var recurrence: TaskRecurrence? {
        guard isFixedSchedule else { return nil }
        let anchorDate = recurrenceAnchorDate(
            after: selectedDate,
            startMinute: startMinute,
            unit: recurrenceUnit,
            weekday: recurrenceWeekday,
            dayOfMonth: recurrenceDayOfMonth
        )
        if recurrenceUnit.isMonthly {
            return TaskRecurrence(unit: recurrenceUnit, anchorDate: anchorDate, weekday: nil, dayOfMonth: recurrenceDayOfMonth)
        }
        return TaskRecurrence(unit: recurrenceUnit, anchorDate: anchorDate, weekday: recurrenceWeekday, dayOfMonth: nil)
    }
}

private enum CourseTodoTitleOption: String, CaseIterable, Identifiable {
    case quiz = "小测"
    case assignment = "作业"
    case presentation = "课程汇报"
    case other = "其他"

    var id: String { rawValue }

    func title(for course: Course, customTitle: String) -> String {
        switch self {
        case .other:
            return customTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        case .quiz, .assignment, .presentation:
            return "\(course.name)\(rawValue)"
        }
    }
}

struct CourseTodoScheduleSheet: View {
    @ObservedObject var store: PathMateStore
    @Environment(\.dismiss) private var dismiss
    var course: Course
    var onSaved: () -> Void

    @State private var selectedTitleOption: CourseTodoTitleOption = .assignment
    @State private var customTitle = ""
    @State private var selectedDate: Date
    @State private var isFixedSchedule = false
    @State private var recurrenceUnit: ScheduleRecurrenceUnit = .week
    @State private var recurrenceWeekday: Int
    @State private var recurrenceDayOfMonth: Int
    @State private var startMinute: Int
    @State private var durationMinutes = 45
    @State private var priority: Int

    init(store: PathMateStore, course: Course, onSaved: @escaping () -> Void) {
        self.store = store
        self.course = course
        self.onSaved = onSaved
        let defaultDate = Self.nextDate(for: course.weekday)
        _selectedDate = State(initialValue: defaultDate)
        _recurrenceWeekday = State(initialValue: course.weekday)
        _recurrenceDayOfMonth = State(initialValue: Calendar.current.component(.day, from: defaultDate))
        _startMinute = State(initialValue: min(course.endMinute + 90, 21 * 60))
        _priority = State(initialValue: course.weight == .high ? 4 : 3)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("课程待办") {
                    Picker("个人事项标题", selection: $selectedTitleOption) {
                        ForEach(CourseTodoTitleOption.allCases) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    if selectedTitleOption == .other {
                        TextField("自定义标题", text: $customTitle)
                    } else {
                        LabeledContent("待办名称", value: resolvedTitle)
                    }
                    TimeWheelPickerRow(title: "开始时间", minute: $startMinute, allowedHours: 7...22, minuteStep: 5)
                    DurationWheelPickerRow(title: "时长", minutes: $durationMinutes, range: 15...240, minuteStep: 5)
                    Stepper("重要程度 \(priority)", value: $priority, in: 1...5)
                }
                Section("日期") {
                    DatePicker("添加日期", selection: $selectedDate, displayedComponents: .date)
                    Toggle("长期固定日程", isOn: $isFixedSchedule)
                    if isFixedSchedule {
                        Picker("重复频率", selection: $recurrenceUnit) {
                            ForEach(ScheduleRecurrenceUnit.allCases) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        if recurrenceUnit.isMonthly {
                            Picker("每次日期", selection: $recurrenceDayOfMonth) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)号").tag(day)
                                }
                            }
                        } else {
                            Picker("每次日期", selection: $recurrenceWeekday) {
                                ForEach(1...7, id: \.self) { day in
                                    Text(PathMateTime.weekdayName(day)).tag(day)
                                }
                            }
                        }
                    }
                }
                Section {
                    Text(isFixedSchedule ? "长期课程待办会从选定日期开始进入日历，过去日期不会补加。" : "临时课程待办只会出现在选定当天的日历和接下来页面。")
                        .font(.system(size: 13))
                        .foregroundStyle(PMColor.steel)
                }
            }
            .navigationTitle("添加课程待办")
            .onChange(of: selectedDate) { _, newDate in
                recurrenceDayOfMonth = Calendar.current.component(.day, from: newDate)
                if !isFixedSchedule {
                    recurrenceWeekday = PathMateTime.weekday(from: newDate)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.addCourseTodo(
                            for: course,
                            title: resolvedTitle,
                            date: selectedDate,
                            recurrence: recurrence,
                            startMinute: startMinute,
                            durationMinutes: durationMinutes,
                            priority: priority
                        )
                        onSaved()
                        dismiss()
                    }
                    .disabled(resolvedTitle.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var resolvedTitle: String {
        selectedTitleOption.title(for: course, customTitle: customTitle)
    }

    private var recurrence: TaskRecurrence? {
        guard isFixedSchedule else { return nil }
        let anchorDate = recurrenceAnchorDate(
            after: selectedDate,
            startMinute: startMinute,
            unit: recurrenceUnit,
            weekday: recurrenceWeekday,
            dayOfMonth: recurrenceDayOfMonth
        )
        if recurrenceUnit.isMonthly {
            return TaskRecurrence(unit: recurrenceUnit, anchorDate: anchorDate, weekday: nil, dayOfMonth: recurrenceDayOfMonth)
        }
        return TaskRecurrence(unit: recurrenceUnit, anchorDate: anchorDate, weekday: recurrenceWeekday, dayOfMonth: nil)
    }

    private static func nextDate(for weekday: Int) -> Date {
        let today = Date()
        let offset = PathMateTime.dayOffset(from: PathMateTime.weekday(from: today), to: weekday)
        return Calendar.current.date(byAdding: .day, value: offset, to: today) ?? today
    }
}

private func recurrenceAnchorDate(after selectedDate: Date, startMinute: Int, unit: ScheduleRecurrenceUnit, weekday: Int, dayOfMonth: Int) -> Date {
    let calendar = Calendar.current
    let selectedDay = calendar.startOfDay(for: selectedDate)

    if unit.isMonthly {
        for monthOffset in 0...24 {
            guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: selectedDay) else {
                continue
            }
            let components = calendar.dateComponents([.year, .month], from: monthDate)
            let targetDay = clampedDay(dayOfMonth, in: monthDate)
            guard let candidateDay = calendar.date(from: DateComponents(year: components.year, month: components.month, day: targetDay)),
                  let candidateStart = calendar.date(byAdding: .minute, value: startMinute, to: candidateDay)
            else { continue }
            if candidateStart >= selectedDate {
                return candidateDay
            }
        }
        return selectedDay
    }

    for dayOffset in 0...14 {
        guard let candidateDay = calendar.date(byAdding: .day, value: dayOffset, to: selectedDay),
              PathMateTime.weekday(from: candidateDay) == weekday,
              let candidateStart = calendar.date(byAdding: .minute, value: startMinute, to: candidateDay)
        else { continue }
        if candidateStart >= selectedDate {
            return candidateDay
        }
    }

    let fallbackOffset = PathMateTime.dayOffset(from: PathMateTime.weekday(from: selectedDay), to: weekday)
    return calendar.date(byAdding: .day, value: fallbackOffset, to: selectedDay) ?? selectedDay
}

private func clampedDay(_ day: Int, in monthDate: Date) -> Int {
    let range = Calendar.current.range(of: .day, in: .month, for: monthDate)
    return min(max(day, 1), range?.count ?? day)
}

struct ConflictSuggestionSheet: View {
    @ObservedObject var store: PathMateStore
    @Environment(\.dismiss) private var dismiss
    var suggestion: AgentSuggestion
    var onManualEdit: (PlanTask) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(PMColor.conflict)
                        .frame(width: 52, height: 52)
                        .background(PMColor.conflict.opacity(0.13))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    Text("计划发生冲突")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(PMColor.ink)
                    Text(suggestion.reason)
                        .font(.system(size: 15))
                        .foregroundStyle(PMColor.slate)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .pathCardStyle()
                PathButton(title: "接受调整", systemImage: "checkmark.circle.fill") {
                    store.acceptSuggestion(suggestion)
                    dismiss()
                }
                PathButton(title: "手动修改低优先级任务", systemImage: "slider.horizontal.3", style: .secondary) {
                    if let task = store.task(id: suggestion.affectedTaskID) {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            onManualEdit(task)
                        }
                    }
                }
                PathButton(title: "拒绝建议", systemImage: "xmark", style: .destructive) {
                    store.rejectSuggestion(suggestion)
                    dismiss()
                }
                Spacer()
            }
            .padding(20)
            .background(PMColor.softCanvas)
            .navigationTitle("Agent 调整建议")
        }
        .presentationDetents([.medium, .large])
    }
}

private extension Text {
    func sectionLabel() -> some View {
        self
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(PMColor.slate)
    }
}
