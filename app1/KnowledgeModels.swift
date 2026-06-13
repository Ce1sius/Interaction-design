import Foundation

struct KnowledgeDetail: Identifiable, Equatable {
    var id: String { title }
    var title: String
    var path: String
    var difficulty: String
    var estimatedTime: String
    var goals: [String]
    var prerequisites: [String]
    var coreConcepts: [KnowledgeCoreConcept]
    var examplesAndExercises: [KnowledgeExercise]
    var mistakes: [String]
    var faqs: [KnowledgeFAQ]
    var quickQuestions: [String]
    var relatedNodes: [RelatedKnowledgeNode]
}

struct KnowledgeCoreConcept: Identifiable, Equatable {
    var id: String { title }
    var title: String
    var content: String
}

struct KnowledgeExercise: Identifiable, Equatable {
    var id: String { "\(category)-\(title)" }
    var category: String
    var title: String
    var description: String
    var actionTitle: String
}

struct KnowledgeFAQ: Identifiable, Equatable {
    var id: String { question }
    var question: String
    var answer: String
}

struct RelatedKnowledgeNode: Identifiable, Equatable {
    var id: String { "\(relation)-\(title)" }
    var relation: String
    var title: String
}

enum KnowledgeRepository {
    static func detail(for node: MindNode, path: String) -> KnowledgeDetail {
        if let detail = specialDetails[path] ?? specialDetails[node.title] {
            var copy = detail
            copy.path = path
            return copy
        }
        return genericDetail(for: node, path: path)
    }

    private static let quickQuestions = [
        "为什么这里能二分？",
        "check 函数怎么写？",
        "left 和 right 到底怎么更新？",
        "能不能换个更简单的例子？"
    ]

    private static let binaryExercises = [
        KnowledgeExercise(category: "讲解例题", title: "木材切割最大长度", description: "给定若干木材，求能切出至少 k 段的最大长度。", actionTitle: "查看解析"),
        KnowledgeExercise(category: "跟练题", title: "运输货物的最小船容量", description: "判断某个容量能否在规定天数内完成运输。", actionTitle: "获取提示"),
        KnowledgeExercise(category: "自测题", title: "最小化最大值", description: "把数组分成若干段，求最大段和的最小可能值。", actionTitle: "开始自测"),
        KnowledgeExercise(category: "错题复盘", title: "边界死循环复盘", description: "对比 left = mid 与 left = mid + 1 的使用场景。", actionTitle: "查看易错点")
    ]

    private static let specialDetails: [String: KnowledgeDetail] = [
        "算法": KnowledgeDetail(
            title: "算法",
            path: "算法",
            difficulty: "体系入门",
            estimatedTime: "2-4 周建立框架",
            goals: ["理解算法学习路线", "知道不同算法适合解决什么问题", "建立题型与知识点的映射"],
            prerequisites: ["基础编程语法", "数组与字符串", "时间复杂度"],
            coreConcepts: [
                KnowledgeCoreConcept(title: "定义 / 概念", content: "算法是一组明确、有限、可执行的步骤，用来把输入转化为目标输出。"),
                KnowledgeCoreConcept(title: "核心思想", content: "先识别问题结构，再选择合适范式：枚举、贪心、二分、动态规划或图论。"),
                KnowledgeCoreConcept(title: "适用条件", content: "当问题可以抽象为状态、选择、顺序、单调性或图结构时，就能映射到对应算法。"),
                KnowledgeCoreConcept(title: "关键模板或口诀", content: "先问：规模多大？是否单调？能否拆子问题？是否是图？答案是否可验证？")
            ],
            examplesAndExercises: [
                KnowledgeExercise(category: "讲解例题", title: "从暴力到优化", description: "把 O(n²) 枚举优化到排序、哈希或双指针。", actionTitle: "查看解析"),
                KnowledgeExercise(category: "跟练题", title: "识别算法范式", description: "给题面判断优先尝试哪类算法。", actionTitle: "获取提示"),
                KnowledgeExercise(category: "自测题", title: "复杂度估算", description: "根据 n 的范围选择可接受复杂度。", actionTitle: "开始自测"),
                KnowledgeExercise(category: "错题复盘", title: "套模板失败", description: "复盘为什么题型相似但条件不满足。", actionTitle: "查看易错点")
            ],
            mistakes: ["只背模板，不判断适用条件", "忽略输入规模导致超时", "没有用样例验证边界", "不会把题面翻译成数据结构"],
            faqs: [
                KnowledgeFAQ(question: "先学哪一类算法？", answer: "先把枚举、模拟、递归和复杂度打牢，再进入二分、贪心、动态规划和图论。"),
                KnowledgeFAQ(question: "刷题时看不出算法怎么办？", answer: "先找关键词和约束：有序/单调常指向二分，最优选择可能是贪心，重叠子问题可能是动态规划。")
            ],
            quickQuestions: quickQuestions,
            relatedNodes: [
                RelatedKnowledgeNode(relation: "后续", title: "二分算法"),
                RelatedKnowledgeNode(relation: "后续", title: "动态规划"),
                RelatedKnowledgeNode(relation: "后续", title: "图论")
            ]
        ),
        "二分算法": KnowledgeDetail(
            title: "二分算法",
            path: "算法 / 二分算法",
            difficulty: "基础到中阶",
            estimatedTime: "2-3 天",
            goals: ["理解单调性", "掌握左右边界更新", "能区分普通二分和二分答案"],
            prerequisites: ["数组", "循环不变量", "时间复杂度"],
            coreConcepts: [
                KnowledgeCoreConcept(title: "定义 / 概念", content: "二分算法每次用中点判断，把不可能的半边搜索空间排除。"),
                KnowledgeCoreConcept(title: "核心思想", content: "维护一个仍可能包含答案的区间，并用 mid 的判断结果缩小区间。"),
                KnowledgeCoreConcept(title: "适用条件", content: "搜索空间必须存在某种单调关系，判断结果能稳定地排除一侧。"),
                KnowledgeCoreConcept(title: "关键模板或口诀", content: "先定答案含义，再定区间含义，最后写更新规则。")
            ],
            examplesAndExercises: binaryExercises,
            mistakes: ["把 mid 写成 (left + right) / 2 可能溢出", "边界更新没有收缩区间", "没有明确找第一个还是最后一个满足", "忽略空数组或单元素数组"],
            faqs: [
                KnowledgeFAQ(question: "二分一定要求数组有序吗？", answer: "普通位置查找通常要求有序，但二分答案只要求答案可行性存在单调性。"),
                KnowledgeFAQ(question: "为什么有时 right = mid，有时 right = mid - 1？", answer: "取决于 mid 本身是否仍可能是答案，以及你维护的是闭区间还是半开区间。")
            ],
            quickQuestions: quickQuestions,
            relatedNodes: [
                RelatedKnowledgeNode(relation: "前置", title: "基础思想"),
                RelatedKnowledgeNode(relation: "后续", title: "二分答案"),
                RelatedKnowledgeNode(relation: "易混", title: "双指针")
            ]
        ),
        "二分答案": KnowledgeDetail(
            title: "二分答案",
            path: "算法 / 二分算法 / 二分答案",
            difficulty: "中阶",
            estimatedTime: "3-5 小时",
            goals: ["能把最小化最大值、最大化最小值转成判定问题", "能写出 check 函数", "能稳定处理答案边界"],
            prerequisites: ["普通二分", "单调性", "时间复杂度"],
            coreConcepts: [
                KnowledgeCoreConcept(title: "定义 / 概念", content: "二分答案是在答案范围上二分，每次检查某个候选答案是否可行。"),
                KnowledgeCoreConcept(title: "核心思想", content: "原问题难以直接求最优值，但判断某个值能不能做到通常更简单。"),
                KnowledgeCoreConcept(title: "适用条件", content: "候选答案的可行性必须随答案变大或变小呈单调变化。"),
                KnowledgeCoreConcept(title: "关键模板或口诀", content: "答案范围二分，check 判可行；可行收一边，不可行收另一边。")
            ],
            examplesAndExercises: binaryExercises,
            mistakes: ["误以为二分答案要求原数组有序", "check 函数方向写反", "边界更新导致死循环", "答案范围设置错误"],
            faqs: [
                KnowledgeFAQ(question: "怎么判断能不能二分答案？", answer: "先问：如果某个答案 x 可行，那么更大或更小的答案是否也一定可行。"),
                KnowledgeFAQ(question: "check 函数返回 true 表示什么？", answer: "建议固定成“当前候选答案可行”，这样更新边界时更不容易混乱。"),
                KnowledgeFAQ(question: "最小化最大值怎么更新？", answer: "如果 mid 可行，说明答案可以更小，通常收缩右边界；否则增大左边界。")
            ],
            quickQuestions: quickQuestions,
            relatedNodes: [
                RelatedKnowledgeNode(relation: "前置", title: "普通二分"),
                RelatedKnowledgeNode(relation: "相关", title: "单调性判断"),
                RelatedKnowledgeNode(relation: "相关", title: "check 函数"),
                RelatedKnowledgeNode(relation: "易混", title: "贪心算法")
            ]
        ),
        "动态规划": KnowledgeDetail(
            title: "动态规划",
            path: "算法 / 动态规划",
            difficulty: "中阶到高阶",
            estimatedTime: "1-2 周",
            goals: ["能定义状态", "能写出状态转移", "能处理初始化和遍历顺序"],
            prerequisites: ["递归", "数组", "数学归纳思维"],
            coreConcepts: [
                KnowledgeCoreConcept(title: "定义 / 概念", content: "动态规划通过保存子问题结果，避免重复计算。"),
                KnowledgeCoreConcept(title: "核心思想", content: "把大问题拆成有重叠的子问题，并用状态转移连接它们。"),
                KnowledgeCoreConcept(title: "适用条件", content: "问题具有最优子结构，并且子问题会重复出现。"),
                KnowledgeCoreConcept(title: "关键模板或口诀", content: "状态表示什么，答案在哪里；从哪里来，到哪里去。")
            ],
            examplesAndExercises: [
                KnowledgeExercise(category: "讲解例题", title: "爬楼梯", description: "用一维 dp 理解状态转移。", actionTitle: "查看解析"),
                KnowledgeExercise(category: "跟练题", title: "打家劫舍", description: "练习选择与不选择的状态。", actionTitle: "获取提示"),
                KnowledgeExercise(category: "自测题", title: "最长上升子序列", description: "判断状态定义和转移顺序。", actionTitle: "开始自测"),
                KnowledgeExercise(category: "错题复盘", title: "初始化漏项", description: "复盘 dp[0]、dp[1] 与空状态。", actionTitle: "查看易错点")
            ],
            mistakes: ["状态含义不清晰", "遍历顺序与依赖关系相反", "初始化漏掉边界", "把贪心问题误写成 DP"],
            faqs: [
                KnowledgeFAQ(question: "为什么我想不到状态？", answer: "先从问题要求的答案倒推：答案需要哪些变量描述，就尝试把这些变量放进状态。"),
                KnowledgeFAQ(question: "什么时候需要二维 dp？", answer: "当一个维度不足以描述子问题，例如同时需要位置和容量、左右端点或两个序列下标。")
            ],
            quickQuestions: quickQuestions,
            relatedNodes: [
                RelatedKnowledgeNode(relation: "前置", title: "递归"),
                RelatedKnowledgeNode(relation: "相关", title: "状态定义"),
                RelatedKnowledgeNode(relation: "相关", title: "状态转移")
            ]
        )
    ]

    private static func genericDetail(for node: MindNode, path: String) -> KnowledgeDetail {
        KnowledgeDetail(
            title: node.title,
            path: path,
            difficulty: node.level <= 1 ? "基础" : "专项",
            estimatedTime: node.level <= 1 ? "1-2 小时" : "30-60 分钟",
            goals: [
                "理解\(node.title)的核心用途",
                "能说清它适合解决什么问题",
                "能完成 2-3 道基础练习"
            ],
            prerequisites: node.level <= 1 ? ["基础编程", "时间复杂度"] : ["上一级知识点", "基础模板"],
            coreConcepts: [
                KnowledgeCoreConcept(title: "定义 / 概念", content: node.summary ?? "\(node.title)是算法学习中的一个关键知识点。"),
                KnowledgeCoreConcept(title: "核心思想", content: "把题目条件转化为可检查、可转移或可遍历的结构。"),
                KnowledgeCoreConcept(title: "适用条件", content: "当题面出现与\(node.title)相关的结构、限制或目标时优先考虑。"),
                KnowledgeCoreConcept(title: "关键模板或口诀", content: "先写样例，再写不变量，最后补边界。")
            ],
            examplesAndExercises: [
                KnowledgeExercise(category: "讲解例题", title: "\(node.title)入门例题", description: "用一个小规模样例走完整过程。", actionTitle: "查看解析"),
                KnowledgeExercise(category: "跟练题", title: "\(node.title)模板练习", description: "根据提示补全关键步骤。", actionTitle: "获取提示"),
                KnowledgeExercise(category: "自测题", title: "\(node.title)独立实现", description: "不看模板完成一题。", actionTitle: "开始自测"),
                KnowledgeExercise(category: "错题复盘", title: "\(node.title)边界复盘", description: "整理本知识点最容易漏掉的边界。", actionTitle: "查看易错点")
            ],
            mistakes: ["只记结论不验证条件", "忽略边界输入", "没有估算复杂度", "变量含义写到一半发生变化"],
            faqs: [
                KnowledgeFAQ(question: "这个知识点什么时候用？", answer: "当题面约束、目标或数据结构与\(node.title)的核心条件一致时，可以优先尝试。"),
                KnowledgeFAQ(question: "学完怎么验证掌握？", answer: "能独立写出模板、解释复杂度，并说出至少两个易错边界。")
            ],
            quickQuestions: quickQuestions,
            relatedNodes: [
                RelatedKnowledgeNode(relation: "前置", title: "基础思想"),
                RelatedKnowledgeNode(relation: "相关", title: node.parentID == nil ? "二分算法" : "算法"),
                RelatedKnowledgeNode(relation: "后续", title: "动态规划")
            ]
        )
    }
}
