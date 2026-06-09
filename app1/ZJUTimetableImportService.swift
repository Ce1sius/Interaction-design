import Foundation
import WebKit

enum ZJUTimetableImportError: LocalizedError {
    case notAuthenticated
    case sessionExpired
    case captchaRequired
    case malformedResponse
    case noCourses
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "尚未取得浙江大学本科教务会话。请先在上方页面完成统一身份认证。"
        case .sessionExpired:
            return "浙江大学本科教务会话已过期，请重新登录后再同步。"
        case .captchaRequired:
            return "本科教务系统要求填写验证码。请先在网页中进入课表查询并完成验证码，再返回同步。"
        case .malformedResponse:
            return "无法解析浙江大学本科教务返回的课表数据。"
        case .noCourses:
            return "当前学年没有读取到课程，请确认登录状态或切换到校园网后重试。"
        case let .requestFailed(message):
            return "浙江大学本科教务请求失败：\(message)"
        }
    }
}

enum ZJUTimetableImportService {
    private static let timetableURL = URL(string: "https://zdbk.zju.edu.cn/jwglxt/kbcx/xskbcx_cxXsKb.html")!
    private static let referer = "https://zdbk.zju.edu.cn/jwglxt/xtgl/index_initMenu.html"
    private static let seasonCodes: [AcademicTerm.Season: [String]] = [
        .fallWinter: ["1|秋", "1|冬"],
        .springSummer: ["2|春", "2|夏"]
    ]

    static func courses(for term: AcademicTerm) async throws -> [Course] {
        let cookies = await authenticationCookies()
        guard cookies.contains(where: { $0.name == "JSESSIONID" }),
              cookies.contains(where: { $0.name == "route" }) else {
            throw ZJUTimetableImportError.notAuthenticated
        }

        var courses: [Course] = []
        for season in seasonCodes[term.season, default: []] {
            courses.append(contentsOf: try await fetchCourses(term: term, season: season, cookies: cookies))
        }

        let deduplicated = Dictionary(grouping: courses) {
            "\($0.name)|\($0.weekday)|\($0.startMinute)|\($0.location)|\(term.id)"
        }.compactMap(\.value.first)

        guard !deduplicated.isEmpty else {
            throw ZJUTimetableImportError.noCourses
        }
        return deduplicated.sorted {
            $0.weekday == $1.weekday ? $0.startMinute < $1.startMinute : $0.weekday < $1.weekday
        }
    }

    private static func authenticationCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies.filter {
                    $0.domain.contains("zju.edu.cn") || $0.domain.contains("zdbk.zju.edu.cn")
                })
            }
        }
    }

    private static func fetchCourses(term: AcademicTerm, season: String, cookies: [HTTPCookie]) async throws -> [Course] {
        var request = URLRequest(url: timetableURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 12
        request.httpBody = "xnm=\(term.startYear)-\(term.startYear + 1)&xqm=\(formEncoded(season))&captcha_value=".data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(referer, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 26_5 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148", forHTTPHeaderField: "User-Agent")
        for (field, value) in HTTPCookie.requestHeaderFields(with: cookies) {
            request.setValue(value, forHTTPHeaderField: field)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ZJUTimetableImportError.requestFailed(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ZJUTimetableImportError.malformedResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if (300..<400).contains(httpResponse.statusCode) {
                throw ZJUTimetableImportError.sessionExpired
            }
            throw ZJUTimetableImportError.requestFailed("HTTP \(httpResponse.statusCode)")
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw ZJUTimetableImportError.malformedResponse
        }
        if text.contains("captcha_error") {
            throw ZJUTimetableImportError.captchaRequired
        }
        if text.contains("login_ssologin") || text.contains("cas/login") || text.contains("统一身份认证") {
            throw ZJUTimetableImportError.sessionExpired
        }
        if text == "null" {
            return []
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let entries = json["kbList"] as? [[String: Any]] else {
            throw ZJUTimetableImportError.malformedResponse
        }
        return entries.compactMap { makeCourse($0, term: term) }
    }

    private static func makeCourse(_ entry: [String: Any], term: AcademicTerm) -> Course? {
        guard string(entry["sfyjskc"]) != "1",
              let weekday = Int(string(entry["xqj"])),
              let firstPeriodNumber = Int(string(entry["djj"])),
              let periodCount = Int(string(entry["skcd"])),
              let firstPeriod = PathMateTime.classPeriods.first(where: { $0.number == firstPeriodNumber }),
              let lastPeriod = PathMateTime.classPeriods.first(where: { $0.number == firstPeriodNumber + periodCount - 1 }),
              let courseHTML = entry["kcb"] as? String else {
            return nil
        }

        let details = courseDetails(from: courseHTML)
        guard !details.name.isEmpty else { return nil }
        let semesterPart = string(entry["xxq"])
        let weekPart: String
        switch string(entry["dsz"]) {
        case "0": weekPart = "单周"
        case "1": weekPart = "双周"
        default: weekPart = "每周"
        }

        return Course(
            id: UUID(),
            name: details.name,
            teacher: details.teacher.isEmpty ? "教师待定" : details.teacher,
            weekday: weekday,
            startMinute: firstPeriod.startMinute,
            durationMinutes: lastPeriod.endMinute - firstPeriod.startMinute,
            location: details.location.isEmpty ? "地点待定" : details.location,
            weight: .medium,
            goalRelation: "由浙江大学本科教务导入",
            summary: "该课程通过浙江大学统一身份认证后的本科教务接口导入。",
            keyPoints: [],
            tags: ["浙江大学教务导入", term.shortName, semesterPart, weekPart].filter { !$0.isEmpty },
            homework: [],
            materials: [],
            courseNote: "请对照本科教务系统核对单双周、短学期和调休安排。",
            studyTopics: [],
            academicTerm: term
        )
    }

    private static func courseDetails(from html: String) -> (name: String, teacher: String, location: String) {
        let pattern = #"(.*?)<br>(.*?)<br>(.*?)<br>(.*?)zwf"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
              let match = expression.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              match.numberOfRanges == 5 else {
            return (stripHTML(html), "", "")
        }

        return (
            normalizedHTMLGroup(match.range(at: 1), in: html),
            normalizedHTMLGroup(match.range(at: 3), in: html),
            normalizedHTMLGroup(match.range(at: 4), in: html)
        )
    }

    private static func normalizedHTMLGroup(_ range: NSRange, in text: String) -> String {
        guard let range = Range(range, in: text) else { return "" }
        return stripHTML(String(text[range]))
            .replacingOccurrences(of: "(", with: "（")
            .replacingOccurrences(of: ")", with: "）")
    }

    private static func stripHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func string(_ value: Any?) -> String {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return ""
    }

    private static func formEncoded(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }
}
