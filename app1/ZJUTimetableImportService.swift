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

enum ZJULearningMaterialImportError: LocalizedError {
    case notAuthenticated
    case sessionExpired
    case noMatchingCourse(String)
    case noMaterials(String)
    case malformedResponse
    case downloadUnavailable
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "尚未取得学在浙大会话。请先在浙江大学统一身份认证页面登录，再同步课件。"
        case .sessionExpired:
            return "学在浙大会话已过期，请重新登录后再同步课件。"
        case let .noMatchingCourse(courseName):
            return "学在浙大中没有匹配到「\(courseName)」。请确认课程名称与学在浙大一致。"
        case let .noMaterials(courseName):
            return "「\(courseName)」暂未读取到可导入课件。"
        case .malformedResponse:
            return "无法解析学在浙大返回的课件数据。"
        case .downloadUnavailable:
            return "该课件缺少学在浙大下载标识，无法直接下载。"
        case let .requestFailed(message):
            return "学在浙大请求失败：\(message)"
        }
    }
}

struct ZJULearningRemoteCourse: Identifiable, Equatable {
    var id: Int64
    var name: String
    var semesterID: Int64
    var academicYearID: Int64
}

enum ZJULearningMaterialService {
    private static let baseURL = URL(string: "https://courses.zju.edu.cn")!
    private static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 26_5 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148"
    static let authenticationURL = URL(string: "https://courses.zju.edu.cn/user/courses")!

    static func materials(for course: Course) async throws -> [CourseMaterial] {
        let cookies = await authenticationCookies()
        guard containsLearningCookie(cookies) || containsCASCookie(cookies) else {
            throw ZJULearningMaterialImportError.notAuthenticated
        }

        let session = makeSession(cookies: cookies)
        try await warmLearningSession(session: session)
        let remoteCourses = try await remoteCourses(session: session)
        guard let remoteCourse = bestMatch(for: course, in: remoteCourses) else {
            throw ZJULearningMaterialImportError.noMatchingCourse(course.name)
        }

        let uploads = try await uploads(courseID: remoteCourse.id, courseName: remoteCourse.name, session: session)
        guard !uploads.isEmpty else {
            throw ZJULearningMaterialImportError.noMaterials(course.name)
        }
        return uploads
    }

    static func download(_ material: CourseMaterial) async throws -> URL {
        guard let remoteID = material.remoteID,
              let remoteReferenceID = material.remoteReferenceID else {
            throw ZJULearningMaterialImportError.downloadUnavailable
        }
        let cookies = await authenticationCookies()
        guard containsLearningCookie(cookies) || containsCASCookie(cookies) else {
            throw ZJULearningMaterialImportError.notAuthenticated
        }

        let session = makeSession(cookies: cookies)
        try await warmLearningSession(session: session)
        let data = try await downloadData(remoteID: remoteID, referenceID: remoteReferenceID, session: session)
        let directory = try materialsDirectory(for: material.remoteCourseName ?? "LearningMaterials")
        let fileName = sanitizedFileName(material.localFileName ?? material.title)
        let fileURL = directory.appendingPathComponent(fileName)
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    static func cachedFileURL(for material: CourseMaterial) -> URL? {
        if let localFilePath = material.localFilePath {
            let fileURL = URL(fileURLWithPath: localFilePath)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }
        guard material.remoteID != nil else { return nil }
        do {
            let directory = try materialsDirectory(for: material.remoteCourseName ?? "LearningMaterials")
            let fileName = sanitizedFileName(material.localFileName ?? material.title)
            let fileURL = directory.appendingPathComponent(fileName)
            return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
        } catch {
            return nil
        }
    }

    private static func authenticationCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies.filter {
                    $0.domain.contains("zju.edu.cn")
                })
            }
        }
    }

    private static func containsLearningCookie(_ cookies: [HTTPCookie]) -> Bool {
        cookies.contains { $0.domain.contains("courses.zju.edu.cn") || $0.domain == ".zju.edu.cn" }
    }

    private static func containsCASCookie(_ cookies: [HTTPCookie]) -> Bool {
        cookies.contains { $0.domain.contains("zjuam.zju.edu.cn") || $0.name.uppercased().contains("CASTGC") }
    }

    private static func makeSession(cookies: [HTTPCookie]) -> URLSession {
        let storage = HTTPCookieStorage.shared
        cookies.forEach { storage.setCookie($0) }
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = storage
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        configuration.httpAdditionalHeaders = HTTPCookie.requestHeaderFields(with: cookies)
        configuration.timeoutIntervalForRequest = 18
        configuration.timeoutIntervalForResource = 60
        return URLSession(configuration: configuration)
    }

    private static func warmLearningSession(session: URLSession) async throws {
        var request = URLRequest(url: URL(string: "https://courses.zju.edu.cn/user/courses")!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ZJULearningMaterialImportError.malformedResponse
            }
            if (300..<400).contains(httpResponse.statusCode) || httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw ZJULearningMaterialImportError.sessionExpired
            }
            if let text = String(data: data, encoding: .utf8),
               text.contains("统一身份认证") || text.contains("cas/login") {
                throw ZJULearningMaterialImportError.sessionExpired
            }
            guard httpResponse.statusCode < 500 else {
                throw ZJULearningMaterialImportError.requestFailed("user/courses HTTP \(httpResponse.statusCode): \(responseSnippet(from: data))")
            }
        } catch let error as ZJULearningMaterialImportError {
            throw error
        } catch {
            throw ZJULearningMaterialImportError.requestFailed("user/courses: \(error.localizedDescription)")
        }
    }

    private static func remoteCourses(session: URLSession) async throws -> [ZJULearningRemoteCourse] {
        var page = 1
        var pages = 1
        var results: [ZJULearningRemoteCourse] = []

        repeat {
            let json = try await firstValidCourseListJSON(page: page, session: session)
            guard let courses = json["courses"] as? [[String: Any]] else {
                if looksLikeLoginPage(json) {
                    throw ZJULearningMaterialImportError.sessionExpired
                }
                throw ZJULearningMaterialImportError.malformedResponse
            }
            pages = int(json["pages"]) ?? pages
            results.append(contentsOf: courses.compactMap(remoteCourse(from:)))
            page += 1
        } while page <= pages

        return results
    }

    private static func uploads(courseID: Int64, courseName: String, session: URLSession) async throws -> [CourseMaterial] {
        async let activities = activityUploads(courseID: courseID, courseName: courseName, session: session)
        async let homeworks = homeworkUploads(courseID: courseID, courseName: courseName, session: session)
        let merged = try await activities + homeworks
        return Dictionary(grouping: merged) { material in
            material.remoteReferenceID.map(String.init) ?? material.title
        }
        .compactMap(\.value.first)
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private static func activityUploads(courseID: Int64, courseName: String, session: URLSession) async throws -> [CourseMaterial] {
        let url = URL(string: "https://courses.zju.edu.cn/api/courses/\(courseID)/activities")!
        let json = try await jsonObject(url: url, session: session)
        guard let activities = json["activities"] as? [[String: Any]] else {
            throw ZJULearningMaterialImportError.malformedResponse
        }
        return activities.flatMap { activity in
            (activity["uploads"] as? [[String: Any]] ?? []).compactMap {
                material(from: $0, courseID: courseID, courseName: courseName, source: "课堂活动")
            }
        }
    }

    private static func homeworkUploads(courseID: Int64, courseName: String, session: URLSession) async throws -> [CourseMaterial] {
        var page = 1
        var pages = 1
        var results: [CourseMaterial] = []

        repeat {
            let json = try await jsonObject(url: homeworkURL(courseID: courseID, page: page), session: session)
            guard let activities = json["homework_activities"] as? [[String: Any]] else {
                throw ZJULearningMaterialImportError.malformedResponse
            }
            pages = int(json["pages"]) ?? pages
            results.append(contentsOf: activities.flatMap { activity in
                (activity["uploads"] as? [[String: Any]] ?? []).compactMap {
                    material(from: $0, courseID: courseID, courseName: courseName, source: "作业附件")
                }
            })
            page += 1
        } while page <= pages

        return results
    }

    private static func downloadData(remoteID: Int64, referenceID: Int64, session: URLSession) async throws -> Data {
        if let data = try await dataIfAvailable(url: URL(string: "https://courses.zju.edu.cn/api/uploads/reference/\(referenceID)/blob")!, session: session) {
            return data
        }
        if let data = try await dataIfAvailable(url: URL(string: "https://courses.zju.edu.cn/api/uploads/\(remoteID)/blob")!, session: session) {
            return data
        }
        throw ZJULearningMaterialImportError.downloadUnavailable
    }

    private static func dataIfAvailable(url: URL, session: URLSession) async throws -> Data? {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ZJULearningMaterialImportError.malformedResponse
            }
            if (200..<300).contains(httpResponse.statusCode) {
                return data
            }
            if (300..<400).contains(httpResponse.statusCode) || httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                return nil
            }
            throw ZJULearningMaterialImportError.requestFailed("\(url.lastPathComponent) HTTP \(httpResponse.statusCode): \(responseSnippet(from: data))")
        } catch let error as ZJULearningMaterialImportError {
            throw error
        } catch {
            throw ZJULearningMaterialImportError.requestFailed(error.localizedDescription)
        }
    }

    private static func jsonObject(url: URL, session: URLSession) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("https://courses.zju.edu.cn/user/courses", forHTTPHeaderField: "Referer")
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ZJULearningMaterialImportError.malformedResponse
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                if (300..<400).contains(httpResponse.statusCode) || httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw ZJULearningMaterialImportError.sessionExpired
                }
                throw ZJULearningMaterialImportError.requestFailed("\(url.lastPathComponent) HTTP \(httpResponse.statusCode): \(responseSnippet(from: data))")
            }
            if let text = String(data: data, encoding: .utf8),
               text.contains("统一身份认证") || text.contains("cas/login") {
                throw ZJULearningMaterialImportError.sessionExpired
            }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ZJULearningMaterialImportError.malformedResponse
            }
            return json
        } catch let error as ZJULearningMaterialImportError {
            throw error
        } catch {
            throw ZJULearningMaterialImportError.requestFailed(error.localizedDescription)
        }
    }

    private static func myCoursesURL(page: Int) -> URL {
        URL(string: "https://courses.zju.edu.cn/api/my-courses?conditions=%7B%22status%22:%5B%22ongoing%22,%22notStarted%22%5D,%22keyword%22:%22%22,%22classify_type%22:%22recently_started%22,%22display_studio_list%22:false%7D&fields=id,name,course_code,department(id,name),grade(id,name),klass(id,name),course_type,cover,small_cover,start_date,end_date,is_started,is_closed,academic_year_id,semester_id,credit,compulsory,second_name,display_name,created_user(id,name),org(is_enterprise_or_organization),org_id,public_scope,audit_status,audit_remark,can_withdraw_course,imported_from,allow_clone,is_instructor,is_team_teaching,is_default_course_cover,instructors(id,name,email,avatar_small_url),course_attributes(teaching_class_name,is_during_publish_period,copy_status,tip,data),user_stick_course_record(id),classroom_schedule&page=\(page)&page_size=100&showScorePassedStatus=false")!
    }

    private static func fallbackMyCoursesURL(page: Int) -> URL {
        URL(string: "https://courses.zju.edu.cn/api/my-courses?conditions=%7B%22status%22:%5B%22ongoing%22,%22notStarted%22%5D,%22keyword%22:%22%22,%22classify_type%22:%22recently_started%22,%22display_studio_list%22:false%7D&fields=id,name,academic_year_id,semester_id&page=\(page)&page_size=100&showScorePassedStatus=false")!
    }

    private static func firstValidCourseListJSON(page: Int, session: URLSession) async throws -> [String: Any] {
        do {
            return try await jsonObject(url: myCoursesURL(page: page), session: session)
        } catch {
            return try await jsonObject(url: fallbackMyCoursesURL(page: page), session: session)
        }
    }

    private static func homeworkURL(courseID: Int64, page: Int) -> URL {
        URL(string: "https://courses.zju.edu.cn/api/courses/\(courseID)/homework-activities?conditions=%7B%22itemsSortBy%22:%7B%22predicate%22:%22module%22,%22reverse%22:false%7D%7D&page=\(page)&page_size=20&reloadPage=false")!
    }

    private static func remoteCourse(from json: [String: Any]) -> ZJULearningRemoteCourse? {
        guard let id = int64(json["id"]),
              let name = string(json["name"]),
              !name.isEmpty else {
            return nil
        }
        return ZJULearningRemoteCourse(
            id: id,
            name: name,
            semesterID: int64(json["semester_id"]) ?? 0,
            academicYearID: int64(json["academic_year_id"]) ?? 0
        )
    }

    private static func material(from json: [String: Any], courseID: Int64, courseName: String, source: String) -> CourseMaterial? {
        guard let id = int64(json["id"]),
              let referenceID = int64(json["reference_id"]),
              let fileName = string(json["name"]),
              !fileName.isEmpty else {
            return nil
        }
        let size = int64(json["size"])
        return CourseMaterial(
            id: UUID(),
            title: fileName,
            type: fileType(for: fileName),
            dateText: "学在浙大",
            summary: "\(source) · \(byteCountText(size))",
            isDownloaded: false,
            remoteID: id,
            remoteReferenceID: referenceID,
            remoteCourseID: courseID,
            remoteCourseName: courseName,
            remoteSize: size,
            localFileName: fileName
        )
    }

    private static func bestMatch(for course: Course, in remoteCourses: [ZJULearningRemoteCourse]) -> ZJULearningRemoteCourse? {
        let localName = normalizedCourseName(course.name)
        if let exact = remoteCourses.first(where: { normalizedCourseName($0.name) == localName }) {
            return exact
        }
        return remoteCourses.first {
            let remoteName = normalizedCourseName($0.name)
            return remoteName.contains(localName) || localName.contains(remoteName)
        }
    }

    private static func normalizedCourseName(_ name: String) -> String {
        name.replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .lowercased()
    }

    private static func materialsDirectory(for courseName: String) throws -> URL {
        let documents = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = documents
            .appendingPathComponent("PathMateMaterials", isDirectory: true)
            .appendingPathComponent(sanitizedFileName(courseName), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func sanitizedFileName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        return value.components(separatedBy: invalid).joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fileType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.uppercased()
        return ext.isEmpty ? "文件" : ext
    }

    private static func byteCountText(_ size: Int64?) -> String {
        guard let size else { return "大小未知" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private static func responseSnippet(from data: Data) -> String {
        guard let text = String(data: data, encoding: .utf8) else { return "无可读响应正文" }
        let normalized = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return String(normalized.prefix(180))
    }

    private static func looksLikeLoginPage(_ json: [String: Any]) -> Bool {
        string(json["title"])?.contains("登录") == true
    }

    private static func string(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        if let value = value as? String { return Int64(value) }
        return nil
    }
}
