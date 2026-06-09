import Foundation

enum MajorCatalog {
    static let all: [String] = {
        guard
            let url = Bundle.main.url(forResource: "majors", withExtension: "txt"),
            let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            return fallback
        }

        let majors = contents
            .split(whereSeparator: \.isNewline)
            .map(String.init)

        return majors.isEmpty ? fallback : majors
    }()

    private static let fallback = [
        "信息管理与信息系统",
        "计算机科学与技术",
        "软件工程",
        "电子信息工程",
        "视觉传达设计",
        "工业设计"
    ]
}
