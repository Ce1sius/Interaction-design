import Combine
import SwiftUI

@MainActor
final class PathMateStore: ObservableObject {
    @Published var hasCompletedOnboarding = false
    @Published var profile: UserProfile = .sample
    @Published var courses: [Course] = []
    @Published var tasks: [PlanTask] = []
    @Published var personalEvents: [PersonalEvent] = []
    @Published var suggestions: [AgentSuggestion] = []

    private let storageKey = "PathMatePrototypeState.v2"

    init() {
        if !restore() {
            profile = .sample
        }
    }

    var currentAcademicTerm: AcademicTerm {
        AcademicTerm.current()
    }

    func availableAcademicTerms() -> [AcademicTerm] {
        let imported = courses.compactMap(\.academicTerm)
        if !imported.isEmpty {
            return Array(Set(imported)).sorted(by: >)
        }
        return importableAcademicTerms()
    }

    func importableAcademicTerms(reference date: Date = Date()) -> [AcademicTerm] {
        AcademicTerm.learningStageTerms(for: profile.grade, reference: date)
    }

    func editableAcademicTerms(reference date: Date = Date()) -> [AcademicTerm] {
        Array(Set(importableAcademicTerms(reference: date) + courses.compactMap(\.academicTerm)))
            .sorted(by: >)
    }

    func finishOnboarding(profile: UserProfile, importSampleCourses: Bool) {
        self.profile = profile
        if importSampleCourses {
            loadSampleData(completedOnboarding: true, keepProfile: true)
        } else {
            tasks = []
            personalEvents = []
            suggestions = []
            hasCompletedOnboarding = true
            save()
        }
    }

    func loadSampleData(completedOnboarding: Bool, keepProfile: Bool = false) {
        let originalProfile = profile
        let physicsID = UUID()
        let dataID = UUID()
        let designID = UUID()
        let englishID = UUID()
        let physicsHomeworkID = UUID()
        let designHomeworkID = UUID()

        courses = [
            Course(
                id: physicsID,
                name: "大学物理",
                teacher: "陈老师",
                weekday: 2,
                startMinute: 8 * 60 + 30,
                durationMinutes: 95,
                location: "紫金港北3-203",
                weight: .high,
                goalRelation: "保研核心课",
                summary: "本周围绕动量守恒、冲量和碰撞模型展开。课件先通过实验现象引出动量守恒条件，再比较弹性碰撞与非弹性碰撞的能量差异，最后给出典型题的建模步骤。",
                keyPoints: ["动量守恒条件", "弹性碰撞", "非弹性碰撞", "冲量-动量定理"],
                tags: ["作业占比高", "绩点核心", "小测密集"],
                homework: [
                    CourseHomework(id: physicsHomeworkID, title: "大学物理作业 3", dueWeekday: 2, dueMinute: 21 * 60, detail: "完成动量守恒与碰撞模型 8 道题，提交前检查单位和方向。", isCompleted: false)
                ],
                materials: [
                    CourseMaterial(id: UUID(), title: "第 6 讲 动量与冲量", type: "PPT", dateText: "5月19日", summary: "动量守恒、冲量、碰撞模型与典型例题。", isDownloaded: false),
                    CourseMaterial(id: UUID(), title: "碰撞实验演示", type: "视频", dateText: "5月20日", summary: "通过小车碰撞演示弹性与非弹性碰撞的差异。", isDownloaded: false)
                ],
                courseNote: "这门课与保研绩点强相关，Agent 会尽量避免把复习任务挪到太晚。",
                studyTopics: [
                    StudyAidTopic(id: UUID(), title: "动量守恒条件", explanation: "系统所受合外力为零，或外力冲量远小于内力冲量时，总动量近似守恒。", example: "两个小车在水平气垫导轨上碰撞，可把水平方向看作动量守恒。", recommendation: "先画系统边界，再判断外力冲量是否可以忽略。"),
                    StudyAidTopic(id: UUID(), title: "弹性碰撞", explanation: "弹性碰撞同时满足动量守恒和机械能守恒，常见于理想化模型。", example: "两球正碰后速度交换是等质量弹性碰撞的特殊结果。", recommendation: "典型题先列动量方程，再列能量方程。"),
                    StudyAidTopic(id: UUID(), title: "冲量-动量定理", explanation: "合外力冲量等于物体动量变化量，适合处理短时间作用问题。", example: "球撞墙反弹时，墙给球的冲量改变了球的动量方向。", recommendation: "注意速度方向，矢量符号不要丢。")
                ]
            ),
            Course(
                id: dataID,
                name: "数据结构",
                teacher: "李老师",
                weekday: 1,
                startMinute: 10 * 60 + 10,
                durationMinutes: 95,
                location: "紫金港西1-505",
                weight: .high,
                goalRelation: "就业与考研基础能力",
                summary: "本周学习树结构、递归遍历和复杂度分析。课程强调代码实现和手推过程的对应关系。",
                keyPoints: ["二叉树遍历", "递归栈", "复杂度分析", "层序遍历"],
                tags: ["项目相关", "代码练习", "基础核心"],
                homework: [
                    CourseHomework(id: UUID(), title: "树遍历代码题", dueWeekday: 5, dueMinute: 18 * 60, detail: "实现前序、中序、后序和层序遍历，并写出复杂度。", isCompleted: false)
                ],
                materials: [
                    CourseMaterial(id: UUID(), title: "树结构与遍历", type: "PPT", dateText: "5月18日", summary: "树的概念、遍历顺序和递归实现。", isDownloaded: true),
                    CourseMaterial(id: UUID(), title: "遍历代码模板", type: "代码", dateText: "5月18日", summary: "Swift / C++ 版本的遍历模板。", isDownloaded: false)
                ],
                courseNote: "就业导向时，Agent 会把数据结构练习排到更高优先级。",
                studyTopics: [
                    StudyAidTopic(id: UUID(), title: "递归遍历", explanation: "递归遍历把树拆成根、左子树、右子树三个部分。", example: "中序遍历顺序是左子树、根、右子树。", recommendation: "用三行伪代码记忆，再画递归栈。"),
                    StudyAidTopic(id: UUID(), title: "层序遍历", explanation: "层序遍历用队列保存下一层节点，是 BFS 在树上的应用。", example: "从根节点入队，出队时把左右孩子依次入队。", recommendation: "代码练习时重点检查空节点边界。")
                ]
            ),
            Course(
                id: designID,
                name: "信息与交互设计技术",
                teacher: "王老师",
                weekday: 3,
                startMinute: 13 * 60 + 25,
                durationMinutes: 145,
                location: "紫金港北3-109",
                weight: .medium,
                goalRelation: "项目作品集与设计能力",
                summary: "本周围绕 Agent App 原型、信息架构、交互路径和设计规范展开，要求能演示核心任务流。",
                keyPoints: ["Human-in-the-loop", "信息架构", "冲突反馈", "原型演示路径"],
                tags: ["大作业", "原型", "交互重点"],
                homework: [
                    CourseHomework(id: designHomeworkID, title: "PathMate 原型二次修改", dueWeekday: 4, dueMinute: 22 * 60, detail: "根据小组评估意见更新日程、课程详情、设置和辅学页面。", isCompleted: false)
                ],
                materials: [
                    CourseMaterial(id: UUID(), title: "Agent App 设计要求", type: "文档", dateText: "5月19日", summary: "说明 Agent、用户场景、人机协作和技术限制。", isDownloaded: true),
                    CourseMaterial(id: UUID(), title: "Celechron 日程参考", type: "图片", dateText: "5月19日", summary: "日历 + 当天课程卡片的页面组织参考。", isDownloaded: false)
                ],
                courseNote: "这门课是当前原型演示的核心场景，详情页会突出本周作业。",
                studyTopics: [
                    StudyAidTopic(id: UUID(), title: "Human-in-the-loop", explanation: "Agent 给出建议，用户保留确认、修改、拒绝的最终控制权。", example: "新增比赛与复习冲突时，用户决定是否接受顺延建议。", recommendation: "演示时要说明为什么不是聊天机器人。"),
                    StudyAidTopic(id: UUID(), title: "冲突反馈", explanation: "冲突反馈需要说明发生了什么、为什么这样调整、用户还能怎么改。", example: "低优先级任务顺延到高优先级任务之后。", recommendation: "用明确的红色提示和可操作按钮。")
                ]
            ),
            Course(
                id: englishID,
                name: "大学英语",
                teacher: "赵老师",
                weekday: 4,
                startMinute: 8 * 60 + 30,
                durationMinutes: 95,
                location: "综合楼 A110",
                weight: .medium,
                goalRelation: "通识基础课",
                summary: "本周练习学术表达和短文结构，适合安排轻量复习。",
                keyPoints: ["主题句", "学术词汇", "听力速记"],
                tags: ["轻复习", "通识"],
                homework: [],
                materials: [
                    CourseMaterial(id: UUID(), title: "Academic Writing Basics", type: "PDF", dateText: "5月21日", summary: "短文结构与主题句示例。", isDownloaded: false)
                ],
                courseNote: "低压力任务，保持连续性即可。",
                studyTopics: [
                    StudyAidTopic(id: UUID(), title: "主题句", explanation: "主题句负责说明段落核心观点，通常放在段首。", example: "A well-designed schedule reduces cognitive load.", recommendation: "阅读时先圈出每段主题句。")
                ]
            )
        ]
        courses = courses.map { course in
            var copy = course
            copy.academicTerm = AcademicTerm.current()
            return copy
        }

        tasks = [
            PlanTask(id: UUID(), title: "大学物理课堂", kind: .course, courseID: physicsID, homeworkID: nil, weekday: 2, startMinute: 8 * 60 + 30, durationMinutes: 95, priority: 5, isAgentGenerated: false, status: .pending, note: "固定课程，不参与自动顺延。", isMovable: false, conflictSource: nil),
            PlanTask(id: UUID(), title: "大学物理课后公式复盘", kind: .review, courseID: physicsID, homeworkID: nil, weekday: 2, startMinute: 14 * 60, durationMinutes: 50, priority: 4, isAgentGenerated: true, status: .pending, note: "根据课后及时复习偏好生成。", isMovable: true, conflictSource: nil),
            PlanTask(id: UUID(), title: "大学物理作业 3", kind: .assignment, courseID: physicsID, homeworkID: physicsHomeworkID, weekday: 2, startMinute: 19 * 60, durationMinutes: 60, priority: 5, isAgentGenerated: true, status: .pending, note: "小测前完成，避免周末堆积。", isMovable: true, conflictSource: nil),
            PlanTask(id: UUID(), title: "数据结构课堂", kind: .course, courseID: dataID, homeworkID: nil, weekday: 1, startMinute: 10 * 60 + 10, durationMinutes: 95, priority: 5, isAgentGenerated: false, status: .pending, note: "固定课程。", isMovable: false, conflictSource: nil),
            PlanTask(id: UUID(), title: "树遍历代码练习", kind: .goal, courseID: dataID, homeworkID: nil, weekday: 1, startMinute: 19 * 60 + 30, durationMinutes: 75, priority: 4, isAgentGenerated: true, status: .pending, note: "就业导向和考研基础都需要代码熟练度。", isMovable: true, conflictSource: nil),
            PlanTask(id: UUID(), title: "信息与交互设计技术课堂", kind: .course, courseID: designID, homeworkID: nil, weekday: 3, startMinute: 13 * 60 + 25, durationMinutes: 145, priority: 4, isAgentGenerated: false, status: .pending, note: "固定课程。", isMovable: false, conflictSource: nil),
            PlanTask(id: UUID(), title: "PathMate 原型二次修改", kind: .assignment, courseID: designID, homeworkID: designHomeworkID, weekday: 4, startMinute: 19 * 60, durationMinutes: 90, priority: 5, isAgentGenerated: true, status: .pending, note: "课程作业，点击可跳到课程详情并高亮作业区。", isMovable: true, conflictSource: nil),
            PlanTask(id: UUID(), title: "英语听力轻复盘", kind: .review, courseID: englishID, homeworkID: nil, weekday: 4, startMinute: 20 * 60 + 40, durationMinutes: 30, priority: 2, isAgentGenerated: true, status: .pending, note: "低压力任务，保持连续性。", isMovable: true, conflictSource: nil)
        ]

        personalEvents = []
        suggestions = sampleSuggestions()
        if keepProfile {
            profile = originalProfile
        } else {
            profile = .sample
        }
        hasCompletedOnboarding = completedOnboarding
        save()
    }

    func updateProfile(_ edit: (inout UserProfile) -> Void) {
        var copy = profile
        edit(&copy)
        profile = copy
        save()
    }

    func term(for course: Course) -> AcademicTerm {
        course.academicTerm ?? currentAcademicTerm
    }

    func term(for task: PlanTask) -> AcademicTerm? {
        guard let course = course(id: task.courseID) else { return nil }
        return term(for: course)
    }

    func courses(in term: AcademicTerm) -> [Course] {
        courses
            .filter { self.term(for: $0) == term }
            .sorted { lhs, rhs in
                if lhs.weekday == rhs.weekday {
                    return lhs.startMinute < rhs.startMinute
                }
                return lhs.weekday < rhs.weekday
            }
    }

    func academicCourseSummaries() -> [Course] {
        Dictionary(grouping: courses, by: { normalizedCourseName($0.name) })
            .values
            .compactMap { group in
                representativeCourse(from: group)
            }
            .sorted { lhs, rhs in
                lhs.name.localizedCompare(rhs.name) == .orderedAscending
            }
    }

    func tasks(in term: AcademicTerm) -> [PlanTask] {
        tasks.filter { isTask($0, visibleIn: term) }
    }

    func scheduleTasks(in term: AcademicTerm) -> [PlanTask] {
        tasks
            .filter { isScheduleTask($0) && isTask($0, visibleIn: term) }
            .sorted(by: taskWeekSort)
    }

    func scheduleTasks(on date: Date, term: AcademicTerm) -> [PlanTask] {
        scheduleTasks(in: term)
            .filter { PathMateTime.taskOccurs($0, on: date) }
            .sorted { lhs, rhs in
                if lhs.startMinute == rhs.startMinute {
                    return lhs.priority > rhs.priority
                }
                return lhs.startMinute < rhs.startMinute
            }
    }

    func pendingTasks(in term: AcademicTerm, now: Date = Date()) -> [PlanTask] {
        tasks
            .filter { $0.status != .completed && isTask($0, visibleIn: term) }
            .sorted { lhs, rhs in
                let left = taskDistanceFromNow(lhs, now: now)
                let right = taskDistanceFromNow(rhs, now: now)
                if left == right {
                    return lhs.priority == rhs.priority ? lhs.title < rhs.title : lhs.priority > rhs.priority
                }
                return left < right
            }
    }

    func tasks(for weekday: Int, term: AcademicTerm? = nil) -> [PlanTask] {
        tasks
            .filter { task in
                task.weekday == weekday && term.map { isTask(task, visibleIn: $0) } ?? true
            }
            .sorted { lhs, rhs in
                lhs.startMinute == rhs.startMinute ? lhs.priority > rhs.priority : lhs.startMinute < rhs.startMinute
            }
    }

    func tasks(for date: Date, term: AcademicTerm? = nil) -> [PlanTask] {
        tasks
            .filter { task in
                PathMateTime.taskOccurs(task, on: date) && (term.map { isTask(task, visibleIn: $0) } ?? true)
            }
            .sorted { lhs, rhs in
                lhs.startMinute == rhs.startMinute ? lhs.priority > rhs.priority : lhs.startMinute < rhs.startMinute
            }
    }

    func currentTask(now: Date = Date(), term: AcademicTerm? = nil) -> PlanTask? {
        tasks
            .filter { task in
                task.status != .completed &&
                PathMateTime.isTaskInProgress(task, at: now) &&
                (term.map { isTask(task, visibleIn: $0) } ?? true)
            }
            .sorted { lhs, rhs in
                lhs.priority == rhs.priority ? lhs.startMinute < rhs.startMinute : lhs.priority > rhs.priority
            }
            .first
    }

    func upcomingTasksWithin24Hours(now: Date = Date(), term: AcademicTerm? = nil) -> [PlanTask] {
        tasks
            .filter { task in
                guard task.status != .completed else { return false }
                guard isScheduleTask(task) else { return false }
                if let term, !isTask(task, visibleIn: term) {
                    return false
                }
                let minutes = PathMateTime.minutesUntilStart(of: task, from: now)
                return minutes >= 0 && minutes <= 24 * 60
            }
            .sorted { lhs, rhs in
                let left = PathMateTime.minutesUntilStart(of: lhs, from: now)
                let right = PathMateTime.minutesUntilStart(of: rhs, from: now)
                if left == right {
                    return lhs.priority > rhs.priority
                }
                return left < right
            }
    }

    func tasksWithinNext24Hours(now: Date = Date(), term: AcademicTerm? = nil) -> [PlanTask] {
        var results = upcomingTasksWithin24Hours(now: now, term: term)
        if let current = currentTask(now: now, term: term), !results.contains(where: { $0.id == current.id }) {
            results.insert(current, at: 0)
        }
        return results
    }

    func nextPendingTask(now: Date = Date(), term: AcademicTerm) -> PlanTask? {
        currentTask(now: now, term: term) ?? upcomingTasksWithin24Hours(now: now, term: term).first
    }

    func course(id: UUID?) -> Course? {
        guard let id else { return nil }
        return courses.first { $0.id == id }
    }

    func task(id: UUID?) -> PlanTask? {
        guard let id else { return nil }
        return tasks.first { $0.id == id }
    }

    func homework(courseID: UUID?, homeworkID: UUID?) -> CourseHomework? {
        guard let courseID, let homeworkID else { return nil }
        return course(id: courseID)?.homework.first { $0.id == homeworkID }
    }

    func addCourse(_ course: Course) {
        var edited = course
        edited.academicTerm = edited.academicTerm ?? currentAcademicTerm
        appendCourse(edited, note: "手动添加的固定课程。")
        save()
    }

    @discardableResult
    func importCourses(_ importedCourses: [Course], source: String, term: AcademicTerm? = nil) -> Int {
        var insertedCount = 0
        for importedCourse in importedCourses {
            var course = importedCourse
            course.academicTerm = course.academicTerm ?? term ?? currentAcademicTerm
            let isDuplicate = courses.contains {
                $0.name == course.name
                    && $0.weekday == course.weekday
                    && $0.startMinute == course.startMinute
                    && $0.location == course.location
                    && self.term(for: $0) == self.term(for: course)
            }
            guard !isDuplicate else { continue }
            appendCourse(course, note: "由\(source)导入。")
            insertedCount += 1
        }
        save()
        return insertedCount
    }

    private func appendCourse(_ course: Course, note: String) {
        courses.append(course)
        tasks.append(
            PlanTask(
                id: UUID(),
                title: "\(course.name)课堂",
                kind: .course,
                courseID: course.id,
                homeworkID: nil,
                weekday: course.weekday,
                startMinute: course.startMinute,
                durationMinutes: course.durationMinutes,
                priority: course.weight == .high ? 5 : 4,
                isAgentGenerated: false,
                status: .pending,
                note: note,
                isMovable: false,
                conflictSource: nil
            )
        )
    }

    func updateCourse(_ course: Course) {
        guard let index = courses.firstIndex(where: { $0.id == course.id }) else { return }
        var edited = course
        edited.academicTerm = edited.academicTerm ?? currentAcademicTerm
        courses[index] = edited
        for taskIndex in tasks.indices where tasks[taskIndex].courseID == course.id && tasks[taskIndex].kind == .course {
            tasks[taskIndex].title = "\(edited.name)课堂"
            tasks[taskIndex].weekday = edited.weekday
            tasks[taskIndex].startMinute = edited.startMinute
            tasks[taskIndex].durationMinutes = edited.durationMinutes
            tasks[taskIndex].priority = edited.weight == .high ? 5 : 4
        }
        save()
    }

    func deleteCourse(_ course: Course) {
        courses.removeAll { $0.id == course.id }
        tasks.removeAll { $0.courseID == course.id }
        save()
    }

    func deleteCourses(named name: String) {
        let normalized = normalizedCourseName(name)
        let ids = courses
            .filter { normalizedCourseName($0.name) == normalized }
            .map(\.id)
        courses.removeAll { ids.contains($0.id) }
        tasks.removeAll { task in
            guard let courseID = task.courseID else { return false }
            return ids.contains(courseID)
        }
        save()
    }

    func addCourseTodo(for course: Course, title: String? = nil, date: Date = Date(), recurrence: TaskRecurrence? = nil, startMinute: Int? = nil, durationMinutes: Int = 45, priority: Int? = nil) {
        let taskWeekday = recurrence?.weekday ?? recurrence.map { PathMateTime.weekday(from: $0.anchorDate) } ?? PathMateTime.weekday(from: date)
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        tasks.append(
            PlanTask(
                id: UUID(),
                title: trimmedTitle?.isEmpty == false ? trimmedTitle! : "\(course.name)课后待办",
                kind: .assignment,
                courseID: course.id,
                homeworkID: course.homework.first?.id,
                weekday: taskWeekday,
                startMinute: startMinute ?? min(course.endMinute + 90, 21 * 60),
                durationMinutes: durationMinutes,
                priority: priority ?? (course.weight == .high ? 4 : 3),
                isAgentGenerated: false,
                status: .pending,
                note: recurrence == nil ? "从课程页添加的临时待办，会显示在日历当天。" : "从课程页添加的长期待办，会按固定频率显示在日历。",
                isMovable: true,
                conflictSource: nil,
                scheduledDate: recurrence == nil ? date : nil,
                recurrence: recurrence
            )
        )
        save()
    }

    func generateReviewTask(for course: Course, weekday: Int? = nil) {
        let targetWeekday = weekday ?? course.weekday
        let targetDate = nextDate(for: targetWeekday)
        tasks.append(
            PlanTask(
                id: UUID(),
                title: "\(course.name)重点复盘",
                kind: .review,
                courseID: course.id,
                homeworkID: nil,
                weekday: targetWeekday,
                startMinute: min(course.endMinute + 90, 20 * 60),
                durationMinutes: profile.detail == .detailed ? 45 : 25,
                priority: course.weight == .high ? 4 : 3,
                isAgentGenerated: true,
                status: .pending,
                note: "根据课件摘要生成。重点：\(course.keyPoints.prefix(2).joined(separator: "、"))。",
                isMovable: true,
                conflictSource: nil,
                scheduledDate: targetDate,
                recurrence: nil
            )
        )
        save()
    }

    func updateTask(_ task: PlanTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        if let eventIndex = personalEvents.firstIndex(where: { $0.linkedTaskID == task.id }) {
            personalEvents[eventIndex].title = task.title
            personalEvents[eventIndex].weekday = task.weekday
            personalEvents[eventIndex].startMinute = task.startMinute
            personalEvents[eventIndex].durationMinutes = task.durationMinutes
            personalEvents[eventIndex].importance = task.priority
            personalEvents[eventIndex].isMovable = task.isMovable
            personalEvents[eventIndex].scheduledDate = task.scheduledDate
            personalEvents[eventIndex].recurrence = task.recurrence
        }
        save()
    }

    func completeTask(_ task: PlanTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].status = .completed
        save()
    }

    func postponeTask(_ task: PlanTask) {
        guard var edited = self.task(id: task.id) else { return }
        edited.startMinute += 60
        if edited.endMinute > 22 * 60 {
            edited.weekday = edited.weekday == 7 ? 1 : edited.weekday + 1
            edited.startMinute = 19 * 60
        }
        edited.status = .delayed
        updateTask(edited)
    }

    func deleteTask(_ task: PlanTask) {
        tasks.removeAll { $0.id == task.id }
        personalEvents.removeAll { $0.linkedTaskID == task.id }
        save()
    }

    func addPersonalEvent(title: String, date: Date, recurrence: TaskRecurrence?, startMinute: Int, durationMinutes: Int, importance: Int, isMovable: Bool) -> AgentSuggestion? {
        let taskID = UUID()
        let weekday = recurrence?.weekday ?? recurrence.map { PathMateTime.weekday(from: $0.anchorDate) } ?? PathMateTime.weekday(from: date)
        let event = PersonalEvent(id: UUID(), linkedTaskID: taskID, title: title, weekday: weekday, startMinute: startMinute, durationMinutes: durationMinutes, importance: importance, isMovable: isMovable, scheduledDate: recurrence == nil ? date : nil, recurrence: recurrence)
        let eventTask = PlanTask(
            id: taskID,
            title: title,
            kind: .personal,
            courseID: nil,
            homeworkID: nil,
            weekday: weekday,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            priority: importance,
            isAgentGenerated: false,
            status: .pending,
            note: recurrence == nil ? "临时个人事项，仅显示在选定日期。" : "长期固定个人事项，仅从选定日期之后开始显示。",
            isMovable: isMovable,
            conflictSource: nil,
            scheduledDate: recurrence == nil ? date : nil,
            recurrence: recurrence
        )

        let conflict = tasks
            .filter { task in
                task.status != .completed &&
                PathMateTime.taskOccurs(task, on: date) &&
                PathMateTime.overlaps(start: startMinute, duration: durationMinutes, otherStart: task.startMinute, otherDuration: task.durationMinutes)
            }
            .sorted { $0.priority > $1.priority }
            .first

        personalEvents.append(event)
        tasks.append(eventTask)

        guard let conflict else {
            save()
            return nil
        }

        let moveNewEvent = !conflict.isMovable || conflict.priority >= importance
        let affectedID = moveNewEvent ? taskID : conflict.id
        let movedTitle = moveNewEvent ? title : conflict.title
        let anchorTitle = moveNewEvent ? conflict.title : title
        let proposedStart = min(max(conflict.endMinute + 30, startMinute + durationMinutes + 30), 21 * 60)
        let suggestion = AgentSuggestion(
            id: UUID(),
            title: "检测到冲突，建议顺延低优先级任务",
            reason: "「\(title)」与「\(conflict.title)」时间重叠。根据优先级判断，\(anchorTitle) 保持原时间，低优先级的「\(movedTitle)」顺延到 \(PathMateTime.timeString(proposedStart))。",
            affectedTaskID: affectedID,
            proposedTitle: nil,
            proposedKind: moveNewEvent ? .personal : conflict.kind,
            proposedWeekday: weekday,
            proposedStartMinute: proposedStart,
            proposedDurationMinutes: moveNewEvent ? durationMinutes : conflict.durationMinutes,
            status: .pending
        )

        if let index = tasks.firstIndex(where: { $0.id == affectedID }) {
            tasks[index].conflictSource = suggestion.reason
        }
        suggestions.insert(suggestion, at: 0)
        save()
        return suggestion
    }

    func acceptSuggestion(_ suggestion: AgentSuggestion) {
        if let taskID = suggestion.affectedTaskID, var task = task(id: taskID) {
            task.weekday = suggestion.proposedWeekday
            task.startMinute = suggestion.proposedStartMinute
            task.durationMinutes = suggestion.proposedDurationMinutes
            task.status = .pending
            task.conflictSource = suggestion.reason
            updateTask(task)
        } else if let title = suggestion.proposedTitle {
            tasks.append(
                PlanTask(
                    id: UUID(),
                    title: title,
                    kind: suggestion.proposedKind,
                    courseID: nil,
                    homeworkID: nil,
                    weekday: suggestion.proposedWeekday,
                    startMinute: suggestion.proposedStartMinute,
                    durationMinutes: suggestion.proposedDurationMinutes,
                    priority: 4,
                    isAgentGenerated: true,
                    status: .pending,
                    note: suggestion.reason,
                    isMovable: true,
                    conflictSource: nil
                )
            )
        }
        markSuggestion(suggestion, as: .accepted)
    }

    func rejectSuggestion(_ suggestion: AgentSuggestion) {
        markSuggestion(suggestion, as: .rejected)
    }

    func regeneratePlan() {
        suggestions.removeAll { $0.status == .pending }
        let suggestion = AgentSuggestion(
            id: UUID(),
            title: profile.goal.strategyTitle,
            reason: "当前目标是\(profile.goal.rawValue)，学校为\(profile.school)。Agent 会优先保留高权重课程与即将截止作业，并把可移动任务安排到空闲时段。",
            affectedTaskID: nil,
            proposedTitle: goalTaskTitle,
            proposedKind: .goal,
            proposedWeekday: 5,
            proposedStartMinute: 19 * 60 + 30,
            proposedDurationMinutes: profile.detail == .detailed ? 80 : 45,
            status: .pending
        )
        suggestions.insert(suggestion, at: 0)
        save()
    }

    func markMaterialDownloaded(courseID: UUID, materialID: UUID) {
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseID }),
              let materialIndex = courses[courseIndex].materials.firstIndex(where: { $0.id == materialID })
        else { return }
        courses[courseIndex].materials[materialIndex].isDownloaded = true
        save()
    }

    func mergeMaterials(_ materials: [CourseMaterial], into courseID: UUID) -> Int {
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseID }) else { return 0 }
        var insertedCount = 0
        for material in materials {
            let alreadyExists = courses[courseIndex].materials.contains { existing in
                if let existingReferenceID = existing.remoteReferenceID,
                   let materialReferenceID = material.remoteReferenceID {
                    return existingReferenceID == materialReferenceID
                }
                return existing.title == material.title && existing.type == material.type
            }
            guard !alreadyExists else { continue }
            courses[courseIndex].materials.append(material)
            insertedCount += 1
        }
        if insertedCount > 0 {
            save()
        }
        return insertedCount
    }

    func toggleHomework(courseID: UUID, homeworkID: UUID) {
        guard let courseIndex = courses.firstIndex(where: { $0.id == courseID }),
              let homeworkIndex = courses[courseIndex].homework.firstIndex(where: { $0.id == homeworkID })
        else { return }
        courses[courseIndex].homework[homeworkIndex].isCompleted.toggle()
        save()
    }

    func restartOnboarding() {
        hasCompletedOnboarding = false
        save()
    }

    func clearAllData() {
        hasCompletedOnboarding = false
        profile = .sample
        courses = []
        tasks = []
        personalEvents = []
        suggestions = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    private var goalTaskTitle: String {
        switch profile.goal {
        case .employment: return "项目实践：任务清单 Demo"
        case .graduate: return "绩点课程复盘与推免材料准备"
        case .exam: return "考研基础复习块"
        }
    }

    private func isTask(_ task: PlanTask, visibleIn term: AcademicTerm) -> Bool {
        guard let taskTerm = self.term(for: task) else {
            return true
        }
        return taskTerm == term
    }

    private func isScheduleTask(_ task: PlanTask) -> Bool {
        task.kind == .course || task.kind == .personal || (task.kind == .assignment && !task.isAgentGenerated)
    }

    private func taskWeekSort(_ lhs: PlanTask, _ rhs: PlanTask) -> Bool {
        if lhs.weekday == rhs.weekday {
            if lhs.startMinute == rhs.startMinute {
                return lhs.priority > rhs.priority
            }
            return lhs.startMinute < rhs.startMinute
        }
        return lhs.weekday < rhs.weekday
    }

    private func taskDistanceFromNow(_ task: PlanTask, now: Date) -> Int {
        if PathMateTime.isTaskInProgress(task, at: now) {
            return -1
        }
        let minutes = PathMateTime.minutesUntilStart(of: task, from: now)
        return minutes
    }

    private func nextDate(for weekday: Int, reference: Date = Date()) -> Date {
        let offset = PathMateTime.dayOffset(from: PathMateTime.weekday(from: reference), to: weekday)
        return Calendar.current.date(byAdding: .day, value: offset, to: reference) ?? reference
    }

    private func representativeCourse(from courses: [Course]) -> Course? {
        let current = currentAcademicTerm
        let sorted = courses.sorted { lhs, rhs in
            let lhsCurrent = term(for: lhs) == current
            let rhsCurrent = term(for: rhs) == current
            if lhsCurrent != rhsCurrent {
                return lhsCurrent
            }
            if term(for: lhs) != term(for: rhs) {
                return term(for: lhs) > term(for: rhs)
            }
            if lhs.weekday == rhs.weekday {
                return lhs.startMinute < rhs.startMinute
            }
            return lhs.weekday < rhs.weekday
        }
        guard var representative = sorted.first else { return nil }
        let termTags = Array(Set(courses.map { term(for: $0).shortName })).sorted(by: >)
        let originalTags = Array(Set(courses.flatMap(\.tags))).sorted()
        representative.tags = termTags + originalTags
        if Set(courses.map(\.location)).count > 1 {
            representative.location = "多个地点"
        }
        return representative
    }

    private func normalizedCourseName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func sampleSuggestions() -> [AgentSuggestion] {
        [
            AgentSuggestion(
                id: UUID(),
                title: "本周优先处理高权重课程与作业",
                reason: "保研导向下，大学物理和数据结构的绩点/基础权重较高。Agent 建议保留课后复盘与作业时间，不把它们挤到周末。",
                affectedTaskID: nil,
                proposedTitle: "长期目标进展整理",
                proposedKind: .goal,
                proposedWeekday: 5,
                proposedStartMinute: 19 * 60 + 30,
                proposedDurationMinutes: 60,
                status: .pending
            )
        ]
    }

    private func markSuggestion(_ suggestion: AgentSuggestion, as status: SuggestionStatus) {
        guard let index = suggestions.firstIndex(where: { $0.id == suggestion.id }) else { return }
        suggestions[index].status = status
        save()
    }

    private func save() {
        let snapshot = Snapshot(
            hasCompletedOnboarding: hasCompletedOnboarding,
            profile: profile,
            courses: courses,
            tasks: tasks,
            personalEvents: personalEvents,
            suggestions: suggestions
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func restore() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return false }
        hasCompletedOnboarding = snapshot.hasCompletedOnboarding
        profile = snapshot.profile
        courses = snapshot.courses.map { course in
            var copy = course
            copy.academicTerm = copy.academicTerm ?? AcademicTerm.current()
            return copy
        }
        tasks = snapshot.tasks
        personalEvents = snapshot.personalEvents
        suggestions = snapshot.suggestions
        return true
    }
}

private struct Snapshot: Codable {
    var hasCompletedOnboarding: Bool
    var profile: UserProfile
    var courses: [Course]
    var tasks: [PlanTask]
    var personalEvents: [PersonalEvent]
    var suggestions: [AgentSuggestion]
}
