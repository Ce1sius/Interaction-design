import Foundation

enum CareerGoal: String, Codable, CaseIterable, Identifiable {
    case exam = "考研"
    case graduate = "保研"
    case employment = "就业"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .employment: return "briefcase.fill"
        case .graduate: return "graduationcap.fill"
        case .exam: return "book.closed.fill"
        }
    }

    var strategyTitle: String {
        switch self {
        case .employment: return "优先项目实践与实用课程"
        case .graduate: return "优先绩点课程与推免材料准备"
        case .exam: return "优先基础复习与阶段测验"
        }
    }
}

enum LearningHabit: String, Codable, CaseIterable, Identifiable {
    case immediateReview = "课后及时复习"
    case examFocused = "考前集中复习"
    case balanced = "平衡安排"

    var id: String { rawValue }

    var explanation: String {
        switch self {
        case .immediateReview: return "课程结束后当天安排短复盘，适合希望降低周末压力的同学。"
        case .examFocused: return "围绕作业、小测和考试节点集中复习，适合习惯大块学习时间的同学。"
        case .balanced: return "重要课程及时复盘，低权重课程靠近考核节点再集中处理。"
        }
    }
}

enum PlanDetail: String, Codable, CaseIterable, Identifiable {
    case detailed = "详细安排"
    case light = "方向性建议"

    var id: String { rawValue }

    var explanation: String {
        switch self {
        case .detailed: return "Agent 会给出具体日期、时间段、优先级和调整理由。"
        case .light: return "Agent 只给出重点方向和建议任务，保留更多自主安排空间。"
        }
    }
}

enum CourseWeight: String, Codable, CaseIterable, Identifiable {
    case high = "高"
    case medium = "中"
    case low = "低"

    var id: String { rawValue }
}

enum TaskKind: String, Codable, CaseIterable, Identifiable {
    case course = "课程"
    case assignment = "作业"
    case review = "复习"
    case personal = "个人"
    case goal = "目标任务"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .course: return "calendar"
        case .assignment: return "doc.text.fill"
        case .review: return "arrow.triangle.2.circlepath"
        case .personal: return "person.crop.circle.fill"
        case .goal: return "target"
        }
    }
}

enum TaskStatus: String, Codable, CaseIterable {
    case pending = "待完成"
    case completed = "已完成"
    case delayed = "已延后"
}

enum SuggestionStatus: String, Codable {
    case pending = "待确认"
    case accepted = "已接受"
    case rejected = "已拒绝"
}

enum AppearanceMode: String, Codable, CaseIterable, Identifiable {
    case system = "跟随系统"
    case light = "浅色"
    case dark = "深色"

    var id: String { rawValue }
}

struct ClassPeriod: Identifiable, Equatable {
    var number: Int
    var startMinute: Int
    var endMinute: Int

    var id: Int { number }
}

struct UserProfile: Codable, Equatable {
    var grade: String
    var school: String
    var major: String
    var goal: CareerGoal
    var habit: LearningHabit
    var detail: PlanDetail
    var appearanceMode: AppearanceMode

    static let sample = UserProfile(
        grade: "大二",
        school: "浙江大学",
        major: "信息管理与信息系统",
        goal: .graduate,
        habit: .immediateReview,
        detail: .detailed,
        appearanceMode: .system
    )
}

struct AcademicTerm: Identifiable, Codable, Equatable, Hashable, Comparable {
    enum Season: String, Codable, CaseIterable {
        case fallWinter = "秋冬"
        case springSummer = "春夏"
    }

    var startYear: Int
    var season: Season

    var id: String {
        "\(startYear)-\(startYear + 1)-\(season.rawValue)"
    }

    var displayName: String {
        shortName
    }

    var shortName: String {
        String(format: "%02d-%02d%@", startYear % 100, (startYear + 1) % 100, season.rawValue)
    }

    var representativeDate: Date {
        let month = season == .fallWinter ? 9 : 3
        return Calendar.current.date(from: DateComponents(year: startYear + (season == .fallWinter ? 0 : 1), month: month, day: 1)) ?? Date()
    }

    static func < (lhs: AcademicTerm, rhs: AcademicTerm) -> Bool {
        if lhs.startYear == rhs.startYear {
            return lhs.season == .fallWinter && rhs.season == .springSummer
        }
        return lhs.startYear < rhs.startYear
    }

    static func current(for date: Date = Date()) -> AcademicTerm {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        let year = components.year ?? 2026
        let month = components.month ?? 1
        if month == 1 {
            return AcademicTerm(startYear: year - 1, season: .fallWinter)
        }
        if (2...7).contains(month) {
            return AcademicTerm(startYear: year - 1, season: .springSummer)
        }
        return AcademicTerm(startYear: year, season: .fallWinter)
    }

    static func nearbyTerms(center date: Date = Date(), yearRadius: Int = 3) -> [AcademicTerm] {
        let current = AcademicTerm.current(for: date)
        return (current.startYear - yearRadius...current.startYear + yearRadius)
            .flatMap { year in
                [
                    AcademicTerm(startYear: year, season: .fallWinter),
                    AcademicTerm(startYear: year, season: .springSummer)
                ]
            }
            .sorted()
    }

    static func learningStageTerms(for grade: String, reference date: Date = Date()) -> [AcademicTerm] {
        let current = AcademicTerm.current(for: date)
        let startYear = current.startYear - max(academicYearCount(for: grade) - 1, 0)
        return (startYear...current.startYear)
            .flatMap { year in
                [
                    AcademicTerm(startYear: year, season: .fallWinter),
                    AcademicTerm(startYear: year, season: .springSummer)
                ]
            }
            .sorted(by: >)
    }

    private static func academicYearCount(for grade: String) -> Int {
        if grade.contains("大一") || grade.contains("研一") { return 1 }
        if grade.contains("大二") || grade.contains("研二") { return 2 }
        if grade.contains("大三") || grade.contains("研三") { return 3 }
        if grade.contains("大四") { return 4 }
        return 1
    }
}

struct Course: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var teacher: String
    var weekday: Int
    var startMinute: Int
    var durationMinutes: Int
    var location: String
    var weight: CourseWeight
    var goalRelation: String
    var summary: String
    var keyPoints: [String]
    var tags: [String]
    var homework: [CourseHomework]
    var materials: [CourseMaterial]
    var courseNote: String
    var studyTopics: [StudyAidTopic]
    var academicTerm: AcademicTerm? = nil

    var endMinute: Int { startMinute + durationMinutes }
}

struct CourseMaterial: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var type: String
    var dateText: String
    var summary: String
    var isDownloaded: Bool
    var remoteID: Int64? = nil
    var remoteReferenceID: Int64? = nil
    var remoteCourseID: Int64? = nil
    var remoteCourseName: String? = nil
    var remoteSize: Int64? = nil
    var localFileName: String? = nil
    var localFilePath: String? = nil
}

struct CourseHomework: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var dueWeekday: Int
    var dueMinute: Int
    var detail: String
    var isCompleted: Bool
}

struct StudyAidTopic: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var explanation: String
    var example: String
    var recommendation: String
}

enum ScheduleRecurrenceUnit: String, Codable, CaseIterable, Identifiable {
    case week = "每周"
    case twoWeeks = "每两周"
    case month = "每月"
    case twoMonths = "每两月"

    var id: String { rawValue }

    var interval: Int {
        switch self {
        case .week, .month: return 1
        case .twoWeeks, .twoMonths: return 2
        }
    }

    var isMonthly: Bool {
        self == .month || self == .twoMonths
    }
}

struct TaskRecurrence: Codable, Equatable {
    var unit: ScheduleRecurrenceUnit
    var anchorDate: Date
    var weekday: Int?
    var dayOfMonth: Int?
}

struct PlanTask: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var kind: TaskKind
    var courseID: UUID?
    var homeworkID: UUID?
    var weekday: Int
    var startMinute: Int
    var durationMinutes: Int
    var priority: Int
    var isAgentGenerated: Bool
    var status: TaskStatus
    var note: String
    var isMovable: Bool
    var conflictSource: String?
    var scheduledDate: Date? = nil
    var recurrence: TaskRecurrence? = nil

    var endMinute: Int { startMinute + durationMinutes }
}

struct PersonalEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var linkedTaskID: UUID
    var title: String
    var weekday: Int
    var startMinute: Int
    var durationMinutes: Int
    var importance: Int
    var isMovable: Bool
    var scheduledDate: Date? = nil
    var recurrence: TaskRecurrence? = nil

    var endMinute: Int { startMinute + durationMinutes }
}

struct AgentSuggestion: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var reason: String
    var affectedTaskID: UUID?
    var proposedTitle: String?
    var proposedKind: TaskKind
    var proposedWeekday: Int
    var proposedStartMinute: Int
    var proposedDurationMinutes: Int
    var status: SuggestionStatus
}

enum PathMateTime {
    static let weekdayNames = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
    static let gradeOptions = ["大一", "大二", "大三", "大四", "研一", "研二", "研三"]

    static let classPeriods: [ClassPeriod] = [
        ClassPeriod(number: 1, startMinute: 8 * 60, endMinute: 8 * 60 + 45),
        ClassPeriod(number: 2, startMinute: 8 * 60 + 50, endMinute: 9 * 60 + 35),
        ClassPeriod(number: 3, startMinute: 10 * 60, endMinute: 10 * 60 + 45),
        ClassPeriod(number: 4, startMinute: 10 * 60 + 50, endMinute: 11 * 60 + 35),
        ClassPeriod(number: 5, startMinute: 11 * 60 + 40, endMinute: 12 * 60 + 25),
        ClassPeriod(number: 6, startMinute: 13 * 60 + 25, endMinute: 14 * 60 + 10),
        ClassPeriod(number: 7, startMinute: 14 * 60 + 15, endMinute: 15 * 60),
        ClassPeriod(number: 8, startMinute: 15 * 60 + 5, endMinute: 15 * 60 + 50),
        ClassPeriod(number: 9, startMinute: 16 * 60 + 15, endMinute: 17 * 60),
        ClassPeriod(number: 10, startMinute: 17 * 60 + 5, endMinute: 17 * 60 + 50),
        ClassPeriod(number: 11, startMinute: 18 * 60 + 50, endMinute: 19 * 60 + 35),
        ClassPeriod(number: 12, startMinute: 19 * 60 + 40, endMinute: 20 * 60 + 25),
        ClassPeriod(number: 13, startMinute: 20 * 60 + 30, endMinute: 21 * 60 + 15)
    ]

    static var currentWeekday: Int {
        weekday(from: Date())
    }

    static func filteredSchools(query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Array(SchoolCatalog.all.prefix(8))
        }
        let matches = SchoolCatalog.all.filter { school in
            school.localizedCaseInsensitiveContains(trimmed)
        }
        return Array(matches.prefix(8))
    }

    static func filteredMajors(query: String) -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Array(MajorCatalog.all.prefix(8))
        }
        let matches = MajorCatalog.all.filter { major in
            major.localizedCaseInsensitiveContains(trimmed)
        }
        return Array(matches.prefix(8))
    }

    static func weekday(from date: Date) -> Int {
        let calendarWeekday = Calendar.current.component(.weekday, from: date)
        return calendarWeekday == 1 ? 7 : calendarWeekday - 1
    }

    static func minuteOfDay(from date: Date = Date()) -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func weekdayName(_ weekday: Int) -> String {
        guard (1...7).contains(weekday) else { return "周一" }
        return weekdayNames[weekday - 1]
    }

    static func timeString(_ minute: Int) -> String {
        let hour = max(0, minute / 60)
        let minutePart = max(0, minute % 60)
        return String(format: "%02d:%02d", hour, minutePart)
    }

    static func rangeString(start: Int, duration: Int) -> String {
        "\(timeString(start))-\(timeString(start + duration))"
    }

    static func overlaps(start: Int, duration: Int, otherStart: Int, otherDuration: Int) -> Bool {
        start < otherStart + otherDuration && otherStart < start + duration
    }

    static func dayOffset(from start: Int, to target: Int) -> Int {
        let raw = target - start
        return raw >= 0 ? raw : raw + 7
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.isDate(lhs, inSameDayAs: rhs)
    }

    static func taskOccurs(_ task: PlanTask, on date: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        if let scheduledDate = task.scheduledDate {
            return calendar.isDate(scheduledDate, inSameDayAs: date)
        }

        if let recurrence = task.recurrence {
            let anchorStart = calendar.startOfDay(for: recurrence.anchorDate)
            guard dayStart >= anchorStart else { return false }

            if recurrence.unit.isMonthly {
                let months = calendar.dateComponents([.month], from: startOfMonth(containing: anchorStart), to: startOfMonth(containing: dayStart)).month ?? 0
                guard months >= 0, months % recurrence.unit.interval == 0 else { return false }
                let preferredDay = recurrence.dayOfMonth ?? calendar.component(.day, from: anchorStart)
                return calendar.component(.day, from: dayStart) == clampedDay(preferredDay, in: dayStart)
            }

            let targetWeekday = recurrence.weekday ?? weekday(from: anchorStart)
            guard weekday(from: dayStart) == targetWeekday else { return false }
            let days = calendar.dateComponents([.day], from: anchorStart, to: dayStart).day ?? 0
            return days >= 0 && (days / 7) % recurrence.unit.interval == 0
        }

        return weekday(from: date) == task.weekday
    }

    static func nextOccurrenceStart(of task: PlanTask, from date: Date = Date()) -> Date? {
        let calendar = Calendar.current
        for offset in 0...730 {
            guard let candidateDay = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: date)),
                  taskOccurs(task, on: candidateDay),
                  let startDate = calendar.date(byAdding: .minute, value: task.startMinute, to: candidateDay)
            else { continue }
            if startDate >= date {
                return startDate
            }
        }
        return nil
    }

    static func minutesUntilStart(of task: PlanTask, from date: Date = Date()) -> Int {
        guard let start = nextOccurrenceStart(of: task, from: date) else {
            return Int.max / 4
        }
        return max(0, Calendar.current.dateComponents([.minute], from: date, to: start).minute ?? 0)
    }

    static func isTaskInProgress(_ task: PlanTask, at date: Date = Date()) -> Bool {
        taskOccurs(task, on: date) &&
        minuteOfDay(from: date) >= task.startMinute &&
        minuteOfDay(from: date) < task.endMinute
    }

    static func progress(of task: PlanTask, at date: Date = Date()) -> Double {
        guard isTaskInProgress(task, at: date), task.durationMinutes > 0 else { return 0 }
        let elapsed = minuteOfDay(from: date) - task.startMinute
        return min(max(Double(elapsed) / Double(task.durationMinutes), 0), 1)
    }

    static func remainingText(for task: PlanTask, at date: Date = Date()) -> String {
        let remaining = max(task.endMinute - minuteOfDay(from: date), 0)
        return countdownText(minutes: remaining)
    }

    static func countdownText(minutes: Int) -> String {
        let safeMinutes = max(minutes, 0)
        let hours = safeMinutes / 60
        let mins = safeMinutes % 60
        if hours > 0 {
            return "\(hours)小时\(mins)分钟"
        }
        return "\(mins)分钟"
    }

    static func relativeDayText(for task: PlanTask, from date: Date = Date()) -> String {
        guard let start = nextOccurrenceStart(of: task, from: date) else {
            return weekdayName(task.weekday)
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let target = calendar.startOfDay(for: start)
        let days = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        if days == 0 { return "今天" }
        if days == 1 { return "明天" }
        if days < 7 { return weekdayName(weekday(from: start)) }

        let components = calendar.dateComponents([.month, .day], from: start)
        return "\(components.month ?? 1)月\(components.day ?? 1)日"
    }

    static func scheduleText(for task: PlanTask) -> String {
        if let scheduledDate = task.scheduledDate {
            let components = Calendar.current.dateComponents([.month, .day], from: scheduledDate)
            return "\(components.month ?? 1)月\(components.day ?? 1)日 \(rangeString(start: task.startMinute, duration: task.durationMinutes))"
        }

        if let recurrence = task.recurrence {
            if recurrence.unit.isMonthly {
                let day = recurrence.dayOfMonth ?? Calendar.current.component(.day, from: recurrence.anchorDate)
                return "\(recurrence.unit.rawValue) \(day)号 \(rangeString(start: task.startMinute, duration: task.durationMinutes))"
            }
            return "\(recurrence.unit.rawValue) \(weekdayName(recurrence.weekday ?? task.weekday)) \(rangeString(start: task.startMinute, duration: task.durationMinutes))"
        }

        return "\(weekdayName(task.weekday)) \(rangeString(start: task.startMinute, duration: task.durationMinutes))"
    }

    private static func startOfMonth(containing date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    private static func clampedDay(_ day: Int, in monthDate: Date) -> Int {
        let range = Calendar.current.range(of: .day, in: .month, for: monthDate)
        return min(max(day, 1), range?.count ?? day)
    }
}
