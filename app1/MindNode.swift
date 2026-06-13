import CoreGraphics
import Foundation

struct MindNode: Identifiable, Equatable {
    let id: UUID
    var title: String
    var children: [MindNode]
    var level: Int
    var position: CGPoint
    var parentID: UUID?
    var summary: String?
    var tags: [String]

    init(
        id: UUID = UUID(),
        title: String,
        summary: String? = nil,
        tags: [String] = [],
        children: [MindNode] = [],
        level: Int = 0,
        position: CGPoint = .zero,
        parentID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.children = children
        self.level = level
        self.position = position
        self.parentID = parentID
        self.summary = summary
        self.tags = tags
    }
}

extension MindNode {
    static func algorithmTree() -> MindNode {
        MindNode(
            title: "算法",
            summary: "用可执行步骤解决问题的知识体系。",
            tags: ["知识体系", "竞赛", "工程基础"],
            children: [
                MindNode(
                    title: "基础思想",
                    summary: "把复杂问题拆成可枚举、可模拟、可递归的基本过程。",
                    tags: ["入门", "思维"],
                    children: [
                        MindNode(title: "枚举", summary: "按范围列举候选答案并验证。", tags: ["基础"]),
                        MindNode(title: "模拟", summary: "按题意维护状态并推进过程。", tags: ["基础"]),
                        MindNode(title: "递归", summary: "把问题拆成同构子问题。", tags: ["基础"])
                    ]
                ),
                MindNode(
                    title: "贪心算法",
                    summary: "每一步选择当前最优方案，并证明它能导向全局最优。",
                    tags: ["证明", "策略"],
                    children: [
                        MindNode(title: "局部最优", summary: "在当前状态下做最有利的选择。", tags: ["贪心"]),
                        MindNode(title: "排序贪心", summary: "先排序，再按顺序做不可逆选择。", tags: ["贪心"]),
                        MindNode(title: "区间贪心", summary: "常见于选择、覆盖和调度类区间问题。", tags: ["区间"])
                    ]
                ),
                MindNode(
                    title: "二分算法",
                    summary: "利用单调性把搜索范围持续折半。",
                    tags: ["单调性", "边界"],
                    children: [
                        MindNode(title: "普通二分", summary: "在有序序列或单调条件中查找目标。", tags: ["模板"]),
                        MindNode(
                            title: "二分答案",
                            summary: "不直接找位置，而是在答案范围里二分可行值。",
                            tags: ["check", "边界"],
                            children: [
                                MindNode(title: "单调性判断", summary: "确认答案越大或越小，可行性是否单调变化。", tags: ["判断"]),
                                MindNode(title: "check 函数", summary: "把某个候选答案转化成 true / false。", tags: ["模板"]),
                                MindNode(title: "边界处理", summary: "处理 left / right 更新、闭区间与开区间。", tags: ["易错"])
                            ]
                        ),
                        MindNode(title: "浮点二分", summary: "在连续答案空间中迭代逼近。", tags: ["精度"]),
                        MindNode(title: "二分边界", summary: "查找第一个满足或最后一个满足的位置。", tags: ["边界"])
                    ]
                ),
                MindNode(
                    title: "动态规划",
                    summary: "通过状态定义与转移复用子问题结果。",
                    tags: ["状态", "转移"],
                    children: [
                        MindNode(title: "状态定义", summary: "明确 dp 数组含义。", tags: ["DP"]),
                        MindNode(title: "状态转移", summary: "从已知状态推导未知状态。", tags: ["DP"]),
                        MindNode(title: "初始化", summary: "设置边界状态和初始值。", tags: ["DP"])
                    ]
                ),
                MindNode(
                    title: "图论",
                    summary: "研究点与边构成的结构及其遍历、路径和连通性质。",
                    tags: ["图", "路径"],
                    children: [
                        MindNode(title: "DFS / BFS", summary: "深度优先与广度优先遍历。", tags: ["遍历"]),
                        MindNode(title: "最短路", summary: "求图中路径代价最小的路线。", tags: ["路径"]),
                        MindNode(title: "最小生成树", summary: "连接所有点且边权总和最小的树。", tags: ["生成树"])
                    ]
                )
            ]
        )
        .assigningHierarchy(level: 0, parentID: nil)
    }

    static func courseTree(for course: Course) -> MindNode {
        let topicNodes = courseMindTopics(for: course).map { topic in
            MindNode(
                title: topic.title,
                summary: topic.explanation,
                tags: ["重点"],
                children: [
                    MindNode(title: "概念解释", summary: topic.explanation, tags: ["概念"]),
                    MindNode(title: "典型例子", summary: topic.example, tags: ["例题"]),
                    MindNode(title: "常见误区", summary: "\(topic.title) 的易错点需要结合课堂例题和作业反馈整理。", tags: ["易错"]),
                    MindNode(title: "复习路径", summary: topic.recommendation, tags: ["复习"])
                ]
            )
        }

        let resourceNodes = [
            MindNode(title: "课件摘要", summary: course.summary, tags: ["课件"]),
            MindNode(title: "作业关联", summary: course.homework.map(\.title).joined(separator: "、"), tags: ["作业"]),
            MindNode(title: "复习建议", summary: course.courseNote, tags: ["Agent"])
        ]

        return MindNode(
            title: course.name,
            summary: course.summary,
            tags: Array(Set(course.tags + [course.weight.rawValue])).sorted(),
            children: [
                MindNode(title: "课程重点", summary: "从课件、作业和课堂重点中抽取的核心知识点。", tags: ["知识点"], children: topicNodes),
                MindNode(title: "学习资源", summary: "课件、作业和复习建议的课程资源入口。", tags: ["资源"], children: resourceNodes)
            ]
        )
        .assigningHierarchy(level: 0, parentID: nil)
    }

    private static func courseMindTopics(for course: Course) -> [CourseMindTopic] {
        if !course.studyTopics.isEmpty {
            return course.studyTopics.map {
                CourseMindTopic(title: $0.title, explanation: $0.explanation, example: $0.example, recommendation: $0.recommendation)
            }
        }
        let keyPoints = course.keyPoints.isEmpty ? [course.name] : course.keyPoints
        return keyPoints.map { title in
            CourseMindTopic(
                title: title,
                explanation: "\(title) 是 \(course.name) 中需要优先理解的核心知识点。",
                example: "结合课程章节和课堂例题，先识别 \(title) 出现的典型情境。",
                recommendation: "先画出概念关系，再完成一道对应练习。"
            )
        }
    }

    func assigningHierarchy(level: Int, parentID: UUID?) -> MindNode {
        var copy = self
        copy.level = level
        copy.parentID = parentID
        copy.children = children.map { $0.assigningHierarchy(level: level + 1, parentID: copy.id) }
        return copy
    }

    func find(id targetID: UUID) -> MindNode? {
        if id == targetID {
            return self
        }
        for child in children {
            if let match = child.find(id: targetID) {
                return match
            }
        }
        return nil
    }

    func find(title targetTitle: String) -> MindNode? {
        if title == targetTitle {
            return self
        }
        for child in children {
            if let match = child.find(title: targetTitle) {
                return match
            }
        }
        return nil
    }

    func contains(id targetID: UUID) -> Bool {
        find(id: targetID) != nil
    }

    func path(to targetID: UUID) -> [MindNode]? {
        if id == targetID {
            return [self]
        }
        for child in children {
            if let childPath = child.path(to: targetID) {
                return [self] + childPath
            }
        }
        return nil
    }

    func descendantIDs() -> Set<UUID> {
        children.reduce(into: Set<UUID>()) { result, child in
            result.insert(child.id)
            result.formUnion(child.descendantIDs())
        }
    }
}

private struct CourseMindTopic {
    var title: String
    var explanation: String
    var example: String
    var recommendation: String
}
