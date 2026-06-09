import Foundation
import UniformTypeIdentifiers

#if canImport(FoundationXML)
import FoundationXML
#endif

struct AcademicSystemSchool: Identifiable, Hashable {
    var id: String
    var name: String
    var initial: String
    var adapterName: String
    var authenticationURL: URL
    var authenticatedHost: String? = nil
    var message: String

    func isLikelyAuthenticated(_ url: URL) -> Bool {
        guard url.host == authenticatedHost ?? authenticationURL.host else { return false }
        let lowercaseURL = url.absoluteString.lowercased()
        return !lowercaseURL.contains("login") && !lowercaseURL.contains("cas/")
    }
}

enum CourseImportService {
    static let supportedFileTypes: [UTType] = [
        .json,
        .commaSeparatedText,
        .tabSeparatedText,
        .plainText,
        UTType(filenameExtension: "xls") ?? .data,
        UTType(filenameExtension: "xlsx") ?? .data
    ]

    private static let unsortedAcademicSystemSchools: [AcademicSystemSchool] = [
        AcademicSystemSchool(
            id: "bupt",
            name: "北京邮电大学",
            initial: "B",
            adapterName: "北京邮电大学教务系统",
            authenticationURL: URL(string: "https://jwgl.bupt.edu.cn/jsxsd/")!,
            message: "进入学校教务系统完成身份认证。"
        ),
        AcademicSystemSchool(
            id: "cust",
            name: "长春理工大学",
            initial: "C",
            adapterName: "长春理工大学教务系统",
            authenticationURL: URL(string: "https://mysso.cust.edu.cn/cas/login?service=https://jwgl.cust.edu.cn/welcome")!,
            message: "通过学校统一身份认证进入教务系统。"
        ),
        AcademicSystemSchool(
            id: "nenu",
            name: "东北师范大学",
            initial: "D",
            adapterName: "东北师范大学本科教学服务系统",
            authenticationURL: URL(string: "https://bkjx.nenu.edu.cn/")!,
            message: "进入本科教学服务系统完成身份认证。"
        ),
        AcademicSystemSchool(
            id: "jnu",
            name: "暨南大学",
            initial: "J",
            adapterName: "暨南大学教务系统",
            authenticationURL: URL(string: "https://jw.jnu.edu.cn")!,
            message: "进入学校教务系统完成身份认证。"
        ),
        AcademicSystemSchool(
            id: "njtech",
            name: "南京工业大学",
            initial: "N",
            adapterName: "南京工业大学教务系统",
            authenticationURL: URL(string: "https://jwgl.njtech.edu.cn/xtgl/login_slogin.html")!,
            message: "进入正方教务系统完成身份认证。"
        ),
        AcademicSystemSchool(
            id: "njfu",
            name: "南京林业大学",
            initial: "N",
            adapterName: "南京林业大学教务系统",
            authenticationURL: URL(string: "https://jwxt.njfu.edu.cn/sso.jsp")!,
            message: "通过学校单点登录进入教务系统。"
        ),
        AcademicSystemSchool(
            id: "tongji",
            name: "同济大学",
            initial: "T",
            adapterName: "同济大学教学管理系统",
            authenticationURL: URL(string: "https://1.tongji.edu.cn/")!,
            message: "进入学校教学管理系统完成身份认证。"
        ),
        AcademicSystemSchool(
            id: "zju",
            name: "浙江大学",
            initial: "Z",
            adapterName: "浙江大学本科教学管理系统",
            authenticationURL: URL(string: "https://zjuam.zju.edu.cn/cas/login?service=https%3A%2F%2Fzdbk.zju.edu.cn%2Fjwglxt%2Fxtgl%2Flogin_ssologin.html")!,
            authenticatedHost: "zdbk.zju.edu.cn",
            message: "通过浙江大学统一身份认证进入本科教学管理系统。登录后会按所选学期读取课表。"
        )
    ]

    static let academicSystemSchools: [AcademicSystemSchool] = unsortedAcademicSystemSchools.sorted {
        $0.initial == $1.initial
            ? $0.name.localizedCompare($1.name) == .orderedAscending
            : $0.initial < $1.initial
    }

    static func coursesFromAcademicSystem(_ school: AcademicSystemSchool, term: AcademicTerm = AcademicTerm.current()) -> [Course] {
        switch school.id {
        case "zju":
            return [
                importedCourse(name: "数据结构", teacher: "李老师", weekday: 1, startMinute: 10 * 60, durationMinutes: 95, location: "紫金港西1-505", term: term),
                importedCourse(name: "大学物理", teacher: "陈老师", weekday: 2, startMinute: 8 * 60, durationMinutes: 95, location: "紫金港北3-203", term: term),
                importedCourse(name: "信息与交互设计技术", teacher: "王老师", weekday: 3, startMinute: 13 * 60 + 25, durationMinutes: 145, location: "紫金港北3-109", term: term)
            ]
        default:
            return [
                importedCourse(name: "操作系统", teacher: "张老师", weekday: 2, startMinute: 10 * 60, durationMinutes: 95, location: "教学楼 301", term: term),
                importedCourse(name: "线性代数", teacher: "孙老师", weekday: 5, startMinute: 8 * 60, durationMinutes: 95, location: "教学楼 205", term: term)
            ]
        }
    }

    static func courses(from url: URL, defaultTerm: AcademicTerm = AcademicTerm.current()) throws -> [Course] {
        let data = try Data(contentsOf: url)
        let pathExtension = url.pathExtension.lowercased()

        switch pathExtension {
        case "json":
            return try parseJSON(data, defaultTerm: defaultTerm)
        case "csv":
            return try parseDelimited(data, preferredDelimiter: ",", defaultTerm: defaultTerm)
        case "tsv", "txt":
            return try parseDelimited(data, preferredDelimiter: "\t", defaultTerm: defaultTerm)
        case "xls":
            return try parseXLS(data, defaultTerm: defaultTerm)
        case "xlsx":
            throw CourseImportError.unsupportedBinarySpreadsheet
        default:
            if let courses = try? parseJSON(data, defaultTerm: defaultTerm) {
                return courses
            }
            return try parseDelimited(data, preferredDelimiter: nil, defaultTerm: defaultTerm)
        }
    }

    private static func parseJSON(_ data: Data, defaultTerm: AcademicTerm) throws -> [Course] {
        let decoder = JSONDecoder()
        if let courses = try? decoder.decode([Course].self, from: data), !courses.isEmpty {
            return courses.map { courseWithDefaultTerm($0, defaultTerm: defaultTerm) }
        }
        if let records = try? decoder.decode([ImportedCourseRecord].self, from: data) {
            return try records.map { try $0.makeCourse(defaultTerm: defaultTerm) }
        }
        if let wrapper = try? decoder.decode(ImportedCourseWrapper.self, from: data) {
            return try wrapper.courses.map { try $0.makeCourse(defaultTerm: defaultTerm) }
        }
        throw CourseImportError.invalidJSON
    }

    private static func parseXLS(_ data: Data, defaultTerm: AcademicTerm) throws -> [Course] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CourseImportError.unsupportedBinarySpreadsheet
        }
        if text.contains("<Workbook") || text.contains("<ss:Workbook") {
            let rows = SpreadsheetXMLRowParser.rows(from: data)
            return try courses(from: rows, defaultTerm: defaultTerm)
        }
        return try parseDelimited(data, preferredDelimiter: text.contains("\t") ? "\t" : ",", defaultTerm: defaultTerm)
    }

    private static func parseDelimited(_ data: Data, preferredDelimiter: Character?, defaultTerm: AcademicTerm) throws -> [Course] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CourseImportError.unreadableFile
        }
        let delimiter = preferredDelimiter ?? (text.contains("\t") ? "\t" : ",")
        return try courses(from: parseDelimitedRows(text, delimiter: delimiter), defaultTerm: defaultTerm)
    }

    private static func courses(from rows: [[String]], defaultTerm: AcademicTerm) throws -> [Course] {
        guard let header = rows.first, !header.isEmpty else {
            throw CourseImportError.missingHeader
        }
        let columns = Dictionary(uniqueKeysWithValues: header.enumerated().map { index, item in
            (normalizedHeader(item), index)
        })
        guard value(in: columns, aliases: ["name", "课程", "课程名", "课程名称"]) != nil else {
            throw CourseImportError.missingCourseNameColumn
        }

        let courses = try rows.dropFirst().compactMap { row -> Course? in
            let name = cell(row, columns, ["name", "课程", "课程名", "课程名称"]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }

            let weekday = try parseWeekday(cell(row, columns, ["weekday", "星期", "周几", "星期几"]))
            let startMinute = try parseMinute(cell(row, columns, ["startminute", "开始分钟", "starttime", "开始时间"]))
            let endMinute = parseMinuteIfPresent(cell(row, columns, ["endminute", "结束分钟", "endtime", "结束时间"]))
            let duration = parseInteger(cell(row, columns, ["durationminutes", "时长", "时长分钟"]))
                ?? endMinute.map { max($0 - startMinute, 45) }
                ?? 95
            let term = parseAcademicTerm(
                cell(row, columns, ["term", "semester", "academicterm", "学期", "学年学期", "学年"]),
                defaultTerm: defaultTerm
            )

            return importedCourse(
                name: name,
                teacher: cell(row, columns, ["teacher", "教师", "教师姓名"], fallback: "教师待定"),
                weekday: weekday,
                startMinute: startMinute,
                durationMinutes: duration,
                location: cell(row, columns, ["location", "地点", "教室", "上课地点"], fallback: "地点待定"),
                weight: parseWeight(cell(row, columns, ["weight", "权重"])),
                term: term
            )
        }
        guard !courses.isEmpty else {
            throw CourseImportError.noCourses
        }
        return courses
    }

    private static func parseDelimitedRows(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var iterator = text.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                isQuoted.toggle()
            } else if character == delimiter && !isQuoted {
                row.append(field)
                field = ""
            } else if (character == "\n" || character == "\r") && !isQuoted {
                if character == "\r" { continue }
                row.append(field)
                if row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    rows.append(row)
                }
                row = []
                field = ""
            } else {
                field.append(character)
            }
        }
        row.append(field)
        if row.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            rows.append(row)
        }
        return rows
    }

    private static func importedCourse(
        name: String,
        teacher: String,
        weekday: Int,
        startMinute: Int,
        durationMinutes: Int,
        location: String,
        weight: CourseWeight = .medium,
        term: AcademicTerm
    ) -> Course {
        Course(
            id: UUID(),
            name: name,
            teacher: teacher,
            weekday: weekday,
            startMinute: startMinute,
            durationMinutes: durationMinutes,
            location: location,
            weight: weight,
            goalRelation: "由课程表导入",
            summary: "该课程由课程表导入，可进入课程详情继续补充摘要、课件与作业。",
            keyPoints: [],
            tags: ["课程表导入"],
            homework: [],
            materials: [],
            courseNote: "导入后请对照教务系统核对课程时间、地点和周次。",
            studyTopics: [],
            academicTerm: term
        )
    }

    private static func courseWithDefaultTerm(_ course: Course, defaultTerm: AcademicTerm) -> Course {
        var edited = course
        edited.academicTerm = edited.academicTerm ?? defaultTerm
        return edited
    }

    private static func normalizedHeader(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: " ", with: "")
    }

    private static func value(in columns: [String: Int], aliases: [String]) -> Int? {
        aliases.compactMap { columns[normalizedHeader($0)] }.first
    }

    private static func cell(_ row: [String], _ columns: [String: Int], _ aliases: [String], fallback: String = "") -> String {
        guard let index = value(in: columns, aliases: aliases), row.indices.contains(index) else {
            return fallback
        }
        let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? fallback : value
    }

    private static func parseWeekday(_ value: String) throws -> Int {
        if let number = Int(value), (1...7).contains(number) {
            return number
        }
        let symbols = ["一", "二", "三", "四", "五", "六", "日"]
        if let index = symbols.firstIndex(where: { value.contains($0) }) {
            return index + 1
        }
        throw CourseImportError.invalidWeekday(value)
    }

    private static func parseMinute(_ value: String) throws -> Int {
        guard let minute = parseMinuteIfPresent(value) else {
            throw CourseImportError.invalidTime(value)
        }
        return minute
    }

    private static func parseMinuteIfPresent(_ value: String) -> Int? {
        if let minute = Int(value), (0..<24 * 60).contains(minute) {
            return minute
        }
        let parts = value.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else {
            return nil
        }
        return hour * 60 + minute
    }

    private static func parseInteger(_ value: String) -> Int? {
        Int(value)
    }

    private static func parseWeight(_ value: String) -> CourseWeight {
        CourseWeight(rawValue: value) ?? .medium
    }

    fileprivate static func parseAcademicTerm(_ value: String, defaultTerm: AcademicTerm) -> AcademicTerm {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultTerm }

        let season: AcademicTerm.Season
        if trimmed.contains("春夏") || trimmed.localizedCaseInsensitiveContains("spring") || trimmed.localizedCaseInsensitiveContains("summer") {
            season = .springSummer
        } else if trimmed.contains("秋冬") || trimmed.localizedCaseInsensitiveContains("fall") || trimmed.localizedCaseInsensitiveContains("autumn") || trimmed.localizedCaseInsensitiveContains("winter") {
            season = .fallWinter
        } else {
            return defaultTerm
        }

        let pattern = #"(\d{4})\s*[-—~至]\s*(\d{4})|(\d{4})"#
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
        else {
            return AcademicTerm(startYear: defaultTerm.startYear, season: season)
        }

        if let range = Range(match.range(at: 1), in: trimmed), let startYear = Int(trimmed[range]) {
            return AcademicTerm(startYear: startYear, season: season)
        }
        if let range = Range(match.range(at: 3), in: trimmed), let year = Int(trimmed[range]) {
            let startYear = season == .springSummer ? year - 1 : year
            return AcademicTerm(startYear: startYear, season: season)
        }
        return AcademicTerm(startYear: defaultTerm.startYear, season: season)
    }
}

private struct ImportedCourseWrapper: Decodable {
    var courses: [ImportedCourseRecord]
}

private struct ImportedCourseRecord: Decodable {
    var name: String
    var teacher: String?
    var weekday: Int
    var startMinute: Int
    var durationMinutes: Int?
    var location: String?
    var weight: CourseWeight?
    var academicTerm: AcademicTerm?
    var semester: String?
    var term: String?

    func makeCourse(defaultTerm: AcademicTerm) throws -> Course {
        guard (1...7).contains(weekday), (0..<24 * 60).contains(startMinute) else {
            throw CourseImportError.invalidRecord(name)
        }
        let resolvedTerm = academicTerm
            ?? CourseImportService.parseAcademicTerm(semester ?? term ?? "", defaultTerm: defaultTerm)
        return Course(
            id: UUID(),
            name: name,
            teacher: teacher ?? "教师待定",
            weekday: weekday,
            startMinute: startMinute,
            durationMinutes: durationMinutes ?? 95,
            location: location ?? "地点待定",
            weight: weight ?? .medium,
            goalRelation: "由课程表导入",
            summary: "该课程由课程表导入，可进入课程详情继续补充摘要、课件与作业。",
            keyPoints: [],
            tags: ["课程表导入"],
            homework: [],
            materials: [],
            courseNote: "导入后请对照教务系统核对课程时间、地点和周次。",
            studyTopics: [],
            academicTerm: resolvedTerm
        )
    }
}

private final class SpreadsheetXMLRowParser: NSObject, XMLParserDelegate {
    private var rows: [[String]] = []
    private var currentRow: [String]?
    private var currentValue = ""
    private var isReadingData = false

    static func rows(from data: Data) -> [[String]] {
        let delegate = SpreadsheetXMLRowParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.rows
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "Row" {
            currentRow = []
        } else if elementName == "Data" {
            currentValue = ""
            isReadingData = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isReadingData {
            currentValue += string
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "Data" {
            currentRow?.append(currentValue)
            isReadingData = false
        } else if elementName == "Cell", let row = currentRow, row.count < 1 {
            currentRow?.append("")
        } else if elementName == "Row", let row = currentRow {
            rows.append(row)
            currentRow = nil
        }
    }
}

enum CourseImportError: LocalizedError {
    case unreadableFile
    case unsupportedBinarySpreadsheet
    case invalidJSON
    case missingHeader
    case missingCourseNameColumn
    case noCourses
    case invalidWeekday(String)
    case invalidTime(String)
    case invalidRecord(String)

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "无法读取文件，请确认文件编码为 UTF-8。"
        case .unsupportedBinarySpreadsheet:
            return "当前本地原型无法直接解析二进制 XLS/XLSX。请在表格软件中另存为 CSV、TSV 或 XML Spreadsheet 2003 格式后导入。"
        case .invalidJSON:
            return "JSON 格式不正确，请检查字段 name、weekday、startMinute 与 durationMinutes。"
        case .missingHeader:
            return "表格缺少标题行。"
        case .missingCourseNameColumn:
            return "表格中未找到“课程名称”列。"
        case .noCourses:
            return "文件中没有可导入的课程。"
        case .invalidWeekday(let value):
            return "无法识别星期：\(value)。请使用 1-7 或周一至周日。"
        case .invalidTime(let value):
            return "无法识别时间：\(value)。请使用分钟数或 HH:mm 格式。"
        case .invalidRecord(let name):
            return "课程“\(name)”的星期或开始时间不正确。"
        }
    }
}
