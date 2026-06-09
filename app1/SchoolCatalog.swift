import Foundation

enum SchoolCatalog {
    static let all: [String] = {
        guard
            let url = Bundle.main.url(forResource: "schools", withExtension: "txt"),
            let contents = try? String(contentsOf: url, encoding: .utf8)
        else {
            return fallback
        }

        let schools = contents
            .split(whereSeparator: \.isNewline)
            .map(String.init)

        return schools.isEmpty ? fallback : schools
    }()

    private static let fallback = [
        "浙江大学",
        "浙江工业大学",
        "浙江师范大学",
        "北京大学",
        "清华大学",
        "复旦大学",
        "上海交通大学"
    ]
}
