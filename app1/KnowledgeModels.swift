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
    var prompt: String = ""
    var hints: [String] = []
    var solution: String = ""
    var pitfalls: [String] = []
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

private struct CourseSampleQuestion {
    var scenario: String
    var prompt: String
    var hints: [String]
    var solution: String
    var practicePrompt: String
    var practiceHints: [String]
    var practiceSolution: String
    var pitfalls: [String]
}

enum KnowledgeRepository {
    static func detail(for node: MindNode, path: String, course: Course?) -> KnowledgeDetail {
        guard let course else {
            return detail(for: node, path: path)
        }
        return courseDetail(for: node, path: path, course: course)
    }

    static func detail(for node: MindNode, path: String) -> KnowledgeDetail {
        if let detail = specialDetails[path] ?? specialDetails[node.title] {
            var copy = detail
            copy.path = path
            return copy
        }
        return genericDetail(for: node, path: path)
    }

    private static func courseDetail(for node: MindNode, path: String, course: Course) -> KnowledgeDetail {
        let topic = matchedTopic(in: course, path: path, nodeTitle: node.title)
        let title = node.title
        let topicTitle = topic?.title ?? title
        let explanation = topic?.explanation ?? node.summary ?? course.summary
        let example = topic?.example ?? "结合 \(course.name) 的课件、作业和课堂例题理解 \(topicTitle)。"
        let recommendation = topic?.recommendation ?? course.courseNote
        let homeworkTitles = course.homework.map(\.title)
        let exercises = courseExercises(
            topicTitle: topicTitle,
            courseName: course.name,
            explanation: explanation,
            example: example,
            homeworkTitles: homeworkTitles
        )
        let mistakes = courseMistakes(topicTitle: topicTitle, courseName: course.name, homeworkTitles: homeworkTitles)

        return KnowledgeDetail(
            title: title,
            path: path,
            difficulty: course.weight == .high ? "重点课程" : "课程专项",
            estimatedTime: course.weight == .high ? "45-60 分钟" : "25-45 分钟",
            goals: course.keyPoints.isEmpty ? ["理解 \(course.name) 的核心内容", "完成相关练习", "形成复习记录"] : course.keyPoints,
            prerequisites: [course.name, course.teacher, course.goalRelation].filter { !$0.isEmpty },
            coreConcepts: [
                KnowledgeCoreConcept(title: "课程关联", content: course.goalRelation),
                KnowledgeCoreConcept(title: "知识点学习", content: explanation),
                KnowledgeCoreConcept(title: "典型例子", content: example),
                KnowledgeCoreConcept(title: "学习建议", content: recommendation)
            ],
            examplesAndExercises: exercises,
            mistakes: mistakes,
            faqs: [
                KnowledgeFAQ(question: "这一块为什么重要？", answer: "\(topicTitle) 与 \(course.goalRelation) 相关，复习时建议优先掌握概念和典型例子。"),
                KnowledgeFAQ(question: "我应该怎么复习？", answer: recommendation)
            ],
            quickQuestions: [
                "\(topicTitle) 的核心概念是什么？",
                "给我一个 \(course.name) 的例子",
                "这一块有哪些易错点？",
                "帮我生成复习步骤"
            ],
            relatedNodes: course.studyTopics.map { RelatedKnowledgeNode(relation: $0.title == topicTitle ? "当前位置" : "相关", title: $0.title) }
        )
    }

    private static func matchedTopic(in course: Course, path: String, nodeTitle: String) -> StudyAidTopic? {
        course.studyTopics.first { topic in
            topic.title == nodeTitle || path.contains(topic.title)
        }
    }

    private static func courseExercises(
        topicTitle: String,
        courseName: String,
        explanation: String,
        example: String,
        homeworkTitles: [String]
    ) -> [KnowledgeExercise] {
        let sample = sampleQuestion(for: topicTitle, courseName: courseName)
        let homeworkText = homeworkTitles.isEmpty ? "\(topicTitle)易错复盘" : homeworkTitles.joined(separator: "、")
        return [
            KnowledgeExercise(
                category: "讲解例题",
                title: "\(topicTitle)基础例题",
                description: sample.scenario,
                actionTitle: "查看解析",
                prompt: sample.prompt,
                hints: sample.hints,
                solution: sample.solution,
                pitfalls: sample.pitfalls
            ),
            KnowledgeExercise(
                category: "跟练题",
                title: "\(topicTitle)跟练",
                description: "换一个小数据，按同样步骤完成判断、计算或解释。",
                actionTitle: "获取提示",
                prompt: sample.practicePrompt,
                hints: sample.practiceHints,
                solution: sample.practiceSolution,
                pitfalls: sample.pitfalls
            ),
            KnowledgeExercise(
                category: "自测题",
                title: "\(topicTitle)自测",
                description: "不看答案，先写出概念条件，再完成一道 3 分钟小题。",
                actionTitle: "开始自测",
                prompt: "用自己的话说明「\(topicTitle)」在 \(courseName) 中解决什么问题，并给出一个最小例子。",
                hints: ["先写适用条件", "再写一个两三行的小样例", "最后说明结论为什么成立"],
                solution: "参考回答：\(explanation) 可以先用课件中的例子理解：\(example) 完成后检查是否说清了条件、对象和结论。",
                pitfalls: ["只背名称，没有说明适用条件", "例子太复杂，反而看不出核心关系"]
            ),
            KnowledgeExercise(
                category: "错题复盘",
                title: homeworkText,
                description: homeworkTitles.isEmpty ? "整理 \(topicTitle) 最容易漏掉的条件、公式或步骤。" : "关联本周作业：\(homeworkText)",
                actionTitle: "查看易错点",
                prompt: "检查一道与「\(topicTitle)」有关的错题：错误发生在概念判断、公式代入、条件遗漏还是计算步骤？",
                hints: ["先把题目条件逐条圈出", "标出使用的定义或定理", "把错误原因写成一句话"],
                solution: "复盘模板：本题考查 \(topicTitle)。我原先的问题是____；正确做法是先确认____，再进行____；下次看到类似条件时先检查____。",
                pitfalls: courseMistakes(topicTitle: topicTitle, courseName: courseName, homeworkTitles: homeworkTitles)
            )
        ]
    }

    private static func courseMistakes(topicTitle: String, courseName: String, homeworkTitles: [String]) -> [String] {
        var items = [
            "只记 \(topicTitle) 的结论，没有检查适用条件",
            "把 \(courseName) 课件中的例子直接套用，忽略题目条件变化",
            "计算或推导时没有写清随机变量、样本量、事件或参数的含义",
            "答案写到数值就停止，没有解释结论在题目语境中的意义"
        ]
        if !homeworkTitles.isEmpty {
            items.append("本周作业 \(homeworkTitles.joined(separator: "、")) 中相似题型需要重点复盘")
        }
        return items
    }

    private static func sampleQuestion(for topicTitle: String, courseName: String) -> CourseSampleQuestion {
        let lowered = topicTitle.lowercased()
        if topicTitle.contains("大数") {
            return CourseSampleQuestion(
                scenario: "用抛硬币频率理解大数定理。",
                prompt: "一枚均匀硬币连续抛 1000 次，正面次数记为 X。用大数定理解释为什么 X/1000 通常会接近 0.5。",
                hints: ["把每次是否正面看成 0-1 随机变量", "写出这些随机变量的期望", "样本均值会向期望靠近"],
                solution: "令 Xi 表示第 i 次是否正面，Xi 取 1 或 0，E(Xi)=0.5。X/1000 是 X1...X1000 的样本均值。大数定理说明当试验次数足够大时，样本均值会以较高概率接近总体期望 0.5。",
                practicePrompt: "某射手命中率为 0.8，独立射击 500 次。命中频率大约会接近多少？为什么？",
                practiceHints: ["命中可看作 1，未命中看作 0", "单次期望是命中概率", "频率是样本均值"],
                practiceSolution: "命中频率约接近 0.8。因为 500 次独立射击的命中频率是 0-1 随机变量的样本均值，大数定理说明它会接近单次命中的期望 0.8。",
                pitfalls: ["把“大概率接近”误写成“必然等于”", "忘记独立同分布或样本量足够大的前提", "把次数 X 和频率 X/n 混在一起"]
            )
        }
        if topicTitle.contains("中心极限") || topicTitle.contains("正态近似") {
            return CourseSampleQuestion(
                scenario: "用样本和的正态近似理解中心极限定理。",
                prompt: "某零件重量均值为 10g，标准差为 2g，随机抽取 36 个。样本均值大约服从什么分布？",
                hints: ["中心极限定理关注样本均值或样本和", "样本均值的均值仍是总体均值", "样本均值标准差是 σ/√n"],
                solution: "样本均值近似服从正态分布 N(10, (2/√36)^2)，即 N(10, 1/9)。这里使用的是样本量较大时样本均值的正态近似。",
                practicePrompt: "若总体均值为 50，标准差为 10，样本量为 25，样本均值的标准误是多少？",
                practiceHints: ["标准误公式是 σ/√n", "把 10 和 25 代入", "注意不是 σ/n"],
                practiceSolution: "标准误为 10/√25=2。",
                pitfalls: ["把总体标准差和样本均值标准误混淆", "忘记样本量开根号", "样本量很小时机械使用正态近似"]
            )
        }
        if topicTitle.contains("估计") || topicTitle.contains("参数") {
            return CourseSampleQuestion(
                scenario: "用样本均值估计总体均值。",
                prompt: "抽取 5 个样本：2、4、4、5、5。用样本均值估计总体均值。",
                hints: ["先求样本总和", "除以样本个数", "说明这是点估计"],
                solution: "样本均值为 (2+4+4+5+5)/5=4。因此总体均值的一个点估计是 4。",
                practicePrompt: "样本 6、7、8、9 的样本均值是多少？它估计的是什么参数？",
                practiceHints: ["总和是 30", "样本量是 4", "估计总体均值"],
                practiceSolution: "样本均值为 30/4=7.5，用来估计总体均值。",
                pitfalls: ["把样本统计量和总体参数混为一谈", "忘记说明估计对象", "区间估计中漏掉置信水平"]
            )
        }
        if topicTitle.contains("假设") || topicTitle.contains("检验") {
            return CourseSampleQuestion(
                scenario: "用显著性水平理解假设检验。",
                prompt: "原假设 H0：某药无效。若 p 值为 0.03，显著性水平 α=0.05，应该拒绝 H0 吗？",
                hints: ["比较 p 值和 α", "p 值小于 α 时拒绝 H0", "结论要回到题意"],
                solution: "因为 p=0.03 < 0.05，所以在 5% 显著性水平下拒绝 H0。可表述为：数据提供了足够证据认为该药并非无效。",
                practicePrompt: "若 p 值为 0.12，α=0.05，能拒绝 H0 吗？",
                practiceHints: ["仍然比较 p 和 α", "p 大于 α", "注意不能说 H0 一定成立"],
                practiceSolution: "不能拒绝 H0。更准确地说，是当前数据不足以支持拒绝原假设，而不是证明原假设一定正确。",
                pitfalls: ["把“不拒绝”说成“接受且证明为真”", "忘记说明显著性水平", "把 p 值理解成原假设为真的概率"]
            )
        }
        if topicTitle.contains("随机变量") || topicTitle.contains("分布") {
            return CourseSampleQuestion(
                scenario: "用离散分布表计算期望。",
                prompt: "随机变量 X 取 0、1、2 的概率分别为 0.2、0.5、0.3，求 E(X)。",
                hints: ["使用 Σ x·P(X=x)", "逐项相乘再相加", "概率和应为 1"],
                solution: "E(X)=0×0.2+1×0.5+2×0.3=1.1。",
                practicePrompt: "若 X 取 1、3 的概率分别为 0.4、0.6，E(X) 是多少？",
                practiceHints: ["1×0.4", "3×0.6", "两项相加"],
                practiceSolution: "E(X)=1×0.4+3×0.6=2.2。",
                pitfalls: ["漏乘概率", "概率和没有检查是否为 1", "把取值和概率位置写反"]
            )
        }
        return CourseSampleQuestion(
            scenario: "用一个最小情境理解 \(topicTitle)。",
            prompt: "请用 \(courseName) 中的「\(topicTitle)」解释一个两步小例子：先写条件，再写结论。",
            hints: ["先抄出题目已知条件", "找出使用的定义、公式或定理", "把结论翻译回题目语境"],
            solution: "参考步骤：1. 明确对象和条件；2. 选择 \(topicTitle) 的定义或结论；3. 代入小数据完成计算或判断；4. 用一句话解释结果。",
            practicePrompt: "把「\(topicTitle)」换成你课件中的一个例题，列出已知、所求和使用的公式。",
            practiceHints: ["已知条件不超过 3 条", "所求量单独写一行", "公式旁边写适用条件"],
            practiceSolution: "完成后检查：条件是否足够、公式是否匹配、结论是否回答了题目问题。",
            pitfalls: ["只写公式不写条件", "例题步骤跳太大", "没有把符号含义说明清楚"]
        )
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
                KnowledgeExercise(
                    category: "讲解例题",
                    title: "\(node.title)入门例题",
                    description: "用一个小规模样例走完整过程。",
                    actionTitle: "查看解析",
                    prompt: "给定一个只含 3 个元素或 3 个步骤的小例子，说明「\(node.title)」如何从条件推出结论。",
                    hints: ["先写输入或已知条件", "标出当前使用的规则", "每一步只改变一个量"],
                    solution: "参考解析：先把题目对象抽象成 \(node.title) 能处理的形式，再按定义或模板推进。最后用样例检查结果是否符合边界。",
                    pitfalls: ["例子太大导致步骤看不清", "没有说明每个变量的含义"]
                ),
                KnowledgeExercise(
                    category: "跟练题",
                    title: "\(node.title)模板练习",
                    description: "根据提示补全关键步骤。",
                    actionTitle: "获取提示",
                    prompt: "补全「条件 -> 判断 -> 结论」三步：条件是____；需要判断____；因此结论是____。",
                    hints: ["不要先写答案，先写条件", "判断依据必须来自定义或模板", "结论要回到题目目标"],
                    solution: "标准写法：条件列全后，选择 \(node.title) 的核心规则；如果条件满足，写出结论；如果不满足，说明缺少哪一项。",
                    pitfalls: ["跳过判断直接套结论", "模板和题目目标不匹配"]
                ),
                KnowledgeExercise(
                    category: "自测题",
                    title: "\(node.title)独立实现",
                    description: "不看模板完成一题。",
                    actionTitle: "开始自测",
                    prompt: "用 3 分钟写出「\(node.title)」的适用条件、核心步骤和一个反例。",
                    hints: ["适用条件写 2 条即可", "核心步骤控制在 3 步", "反例用来说明什么时候不能用"],
                    solution: "自查标准：能说清什么时候用、怎么用、什么时候不能用，就说明已经从记忆进入理解。",
                    pitfalls: ["只会正例，不会判断反例", "步骤顺序不稳定"]
                ),
                KnowledgeExercise(
                    category: "错题复盘",
                    title: "\(node.title)边界复盘",
                    description: "整理本知识点最容易漏掉的边界。",
                    actionTitle: "查看易错点",
                    prompt: "找一道与「\(node.title)」有关的错题，写出错误原因和修正后的第一步。",
                    hints: ["错误原因要具体到条件、公式、边界或计算", "修正后的第一步越短越好", "最后补一个类似小题"],
                    solution: "复盘模板：我错在____；正确第一步应是____；下次看到____时先检查____。",
                    pitfalls: ["只写“粗心”", "没有提炼可迁移的检查动作"]
                )
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
