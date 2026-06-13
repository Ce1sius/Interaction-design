你是一名资深全栈工程师，请在现有项目中实现一个“基于远程课程课件动态生成思维导图”的系统。

本项目包含：

- iOS 前端：SwiftUI
- 后端：优先使用 FastAPI，也可以根据现有项目改用 Node.js
- 数据库存储课程、课件元数据、思维导图缓存
- 大模型 API 负责根据课件内容生成结构化知识节点
- PDF 主要来自课程网站，数量可能很多，不一定下载到用户手机本地

请先阅读现有项目结构和依赖，再进行开发。不要破坏已有页面和业务逻辑，不要重写无关模块。

==================================================
一、产品目标
==================================================

用户在 App 中进入不同课程时，页面展示的思维导图必须根据该课程网站上的真实课件动态生成。

例如：

进入“数据结构”课程：

数据结构
├── 线性表
├── 栈和队列
├── 树
├── 图
├── 排序
└── 查找

进入“大学英语”课程：

大学英语
├── 词汇
├── 语法
├── 阅读
├── 写作
├── 听力
└── 翻译

这些具体节点不能写死在 Swift 代码中，也不能预先硬编码在后端。

知识结构必须来源于当前课程关联的网站课件。

课程网站可能包含：

- 多个 PDF
- 不同章节课件
- 不断更新的 PDF
- JavaScript 动态加载的资源列表
- 临时文件链接
- 需要登录授权的课程资源

第一版优先支持：

- 无需登录即可访问的课程网站
- 网站中公开可访问的 PDF
- 每个课程配置一个或多个资源页面
- 只抓取指定学校域名中的 PDF

==================================================
二、核心架构
==================================================

请按以下数据流实现：

iOS App
→ 用户点击某门课程
→ App 发送 courseId
→ 后端查询该课程对应的资源网站
→ 后端扫描网站中的 PDF
→ 后端获取 PDF 内容或建立文档索引
→ 根据当前课程检索相关课件
→ 调用大模型生成结构化 MindMap JSON
→ 后端校验并缓存结果
→ SwiftUI 动态渲染节点和连线

重要原则：

1. iPhone 不需要下载和长期保存所有 PDF。
2. PDF 由后端获取、临时处理或建立索引。
3. App 只接收结构化的节点和连线数据。
4. 大模型 API Key 不得写入 iOS App。
5. 不允许不同课程之间的课件互相混用。
6. 大模型不得脱离课件自行补充知识点。
7. 每个生成节点都需要保留来源信息。

==================================================
三、课程与资料来源模型
==================================================

请设计课程模型。

示例：

Course

- id
- name
- semester
- sourcePages
- allowedDomains
- accessType
- createdAt
- updatedAt

建议结构：

{
  "id": "data-structure",
  "name": "数据结构",
  "semester": "2026-spring",
  "sourcePages": [
    "https://school.example.edu/courses/data-structure/resources"
  ],
  "allowedDomains": [
    "school.example.edu",
    "cdn.school.example.edu"
  ],
  "accessType": "publicWeb"
}

AccessType：

- publicWeb
- officialAPI
- authenticated

第一版只要求完整支持 publicWeb。

为 officialAPI 和 authenticated 保留接口和扩展位置，但不要把校园账号密码、Cookie 或 Token 写死在代码里。

==================================================
四、后端课件发现功能
==================================================

实现 CourseMaterialSyncService。

输入：

- courseId

功能：

1. 获取课程配置中的一个或多个 sourcePages。
2. 请求课程资源页面。
3. 解析 HTML。
4. 找到所有 PDF 链接。
5. 支持相对链接转绝对链接。
6. 去除 URL fragment。
7. 对 URL 进行标准化和去重。
8. 只允许抓取 allowedDomains 中的链接。
9. 根据响应头或文件扩展名判断是否为 PDF。
10. 保存 PDF 元数据。
11. 输出同步统计结果。

建议接口：

POST /courses/{courseId}/sync-materials

返回：

{
  "courseId": "data-structure",
  "discovered": 18,
  "added": 3,
  "updated": 1,
  "unchanged": 14,
  "removed": 0,
  "failed": 0
}

需要处理：

- 相对 URL
- URL 编码
- 重复 PDF
- HTTP 重定向
- 404
- 超时
- 非 PDF 伪装链接
- 大文件限制
- Content-Type 缺失
- 同名但不同 URL 的 PDF
- 不同 URL 指向同一内容

不要实现无限制的互联网爬虫。

只抓取课程配置中的资源页面以及允许域名中的 PDF。

不要递归遍历整个网站。

==================================================
五、PDF 元数据与版本管理
==================================================

为每个远程文件保存：

CourseDocument

- id
- courseId
- title
- sourceUrl
- normalizedUrl
- contentType
- fileSize
- etag
- lastModified
- contentHash
- status
- vectorFileId
- indexedAt
- lastCheckedAt
- createdAt
- updatedAt

状态建议：

- discovered
- fetching
- indexed
- failed
- outdated
- removed

同步时优先通过以下信息判断文件是否变化：

1. ETag
2. Last-Modified
3. Content-Length
4. 内容 SHA-256

规则：

- 文件没有变化：不重新索引
- 新增 PDF：新增并索引
- PDF 内容变化：删除或替换旧索引
- PDF 从网页中消失：标记 removed，不立即永久删除
- 单个 PDF 失败：不阻止其他文件同步

需要避免每次同步都重新下载和处理所有 PDF。

==================================================
六、远程 PDF 获取策略
==================================================

实现 RemoteDocumentFetcher。

后端可以采用以下方式：

方案一：临时下载到服务器

远程 PDF
→ 下载到临时目录
→ 校验文件类型和大小
→ 上传到文档索引服务
→ 完成后删除临时文件

方案二：流式读取

远程 PDF
→ 流式读取
→ 计算哈希
→ 上传或解析
→ 不长期保留原文件

要求：

- 不把 PDF 永久下载到用户手机
- 后端临时目录需自动清理
- 设置最大文件大小
- 设置请求超时
- 限制同时下载数量
- 拒绝非允许域名
- 防止 SSRF
- 禁止访问 localhost、私有 IP、云元数据地址
- 检查重定向后的最终域名
- 验证文件 MIME 和 PDF 文件头
- 记录错误日志，但不要泄露敏感信息

==================================================
七、JavaScript 动态页面
==================================================

如果普通 HTML 请求中找不到 PDF：

优先顺序：

1. 检查网站是否有公开 API。
2. 分析页面实际调用的课程资源接口。
3. 对接该正式或公开接口。
4. 最后才考虑 Playwright 等无头浏览器。

第一版不需要实现通用浏览器自动化系统。

请为后续实现保留接口：

protocol CourseSourceAdapter

示例适配器：

- StaticHTMLSourceAdapter
- JSONAPISourceAdapter
- BrowserSourceAdapter

默认实现 StaticHTMLSourceAdapter。

==================================================
八、文档索引与课程隔离
==================================================

课件数量可能很多，因此不要在每次生成思维导图时把所有 PDF 全部重新发送给模型。

请实现可复用的课程文档索引。

推荐两种设计之一：

方案 A：每个课程一个独立 Vector Store

数据结构：
- vectorStoreId = vs_data_structure

大学英语：
- vectorStoreId = vs_college_english

方案 B：共用一个 Vector Store，但使用严格元数据过滤

每个文件必须携带：

- courseId
- semester
- documentId
- sourceUrl
- title

检索时必须过滤：

courseId == 当前课程 ID

不得让“大学英语”的课件出现在“数据结构”的生成结果中。

请封装：

CourseIndexService

至少提供：

- createCourseIndex
- addDocument
- updateDocument
- removeDocument
- searchCourseMaterials

不要把具体模型供应商的调用散落在业务代码中。

定义协议：

protocol DocumentIndexProvider

方便未来替换 OpenAI Vector Store、Pinecone、Supabase Vector 或其他实现。

==================================================
九、思维导图生成策略
==================================================

不要每次进入课程都重新生成整个知识图谱。

采用混合模式：

1. 课程顶层 1 到 2 层：
   在课件同步完成后预生成。

2. 更深层节点：
   用户点击节点时按需生成。

3. 已生成节点：
   保存到数据库并缓存。

首次顶层生成流程：

同步课程资料
→ 检索课程整体结构和章节信息
→ 生成课程前两层节点
→ 后端校验
→ 保存到数据库

节点展开流程：

用户点击“树”
→ App 发送 courseId 和 nodeId
→ 后端找到该节点
→ 只检索与“树”有关的课程课件
→ 生成“树”的下一层子节点
→ 保存并返回

接口建议：

GET /courses/{courseId}/mind-map

POST /courses/{courseId}/mind-map/expand

请求：

{
  "nodeId": "node-tree",
  "requestedDepth": 1
}

==================================================
十、大模型输出结构
==================================================

禁止让模型返回 Markdown 树状文本。

必须要求模型返回严格 JSON。

建议结构：

{
  "courseId": "data-structure",
  "title": "数据结构知识地图",
  "rootNodeId": "node-root",
  "nodes": [
    {
      "id": "node-root",
      "parentId": null,
      "title": "数据结构",
      "summary": "研究数据组织、存储和操作方式的课程。",
      "type": "course",
      "depth": 0,
      "importance": 1.0,
      "hasMoreChildren": true,
      "evidenceLevel": "strong",
      "sourceRefs": [
        {
          "documentId": "doc-001",
          "documentTitle": "第一章 绪论",
          "sourceUrl": "https://school.example.edu/files/chapter01.pdf",
          "page": 2,
          "chunkId": "chunk-001"
        }
      ]
    }
  ],
  "edges": [
    {
      "id": "edge-root-tree",
      "from": "node-root",
      "to": "node-tree",
      "relation": "contains"
    }
  ]
}

节点类型：

- course
- chapter
- concept
- definition
- theorem
- method
- example
- skill
- vocabulary
- grammar
- exercise

EvidenceLevel：

- strong
- partial
- insufficient

要求：

- 每个非根节点必须有 parentId
- 每个节点必须有来源
- 节点 ID 唯一
- sourceUrl 必须来自当前课程已登记的文档
- 不得生成课件中没有依据的知识点
- 材料不足时标记 insufficient
- 不得伪造页码
- 无法确定页码时允许 page 为 null
- 顶层每个父节点默认最多生成 4 到 8 个子节点
- 节点标题应简洁
- summary 控制在合理长度

使用结构化输出或 JSON Schema 约束模型返回格式。

==================================================
十一、模型提示词规则
==================================================

系统提示词必须明确要求：

你只能依据提供的课程资料生成思维导图。

不得使用课件以外的常识、教材知识或网络知识补全内容。

每个节点必须包含能够支持该节点的课程资料来源。

如果检索材料不足，不要猜测，应返回 evidenceLevel = insufficient。

生成的内容必须属于当前 courseId。

只生成指定 parentNode 的直接子节点，不要一次展开无限层级。

不要生成 UI 坐标。

不要生成 Swift 代码。

不要输出 Markdown。

只返回符合 JSON Schema 的数据。

==================================================
十二、后端校验
==================================================

实现 MindMapValidationService。

校验：

1. courseId 是否正确
2. 节点 ID 是否唯一
3. edge ID 是否唯一
4. from 和 to 是否指向已有节点
5. parentId 是否存在
6. 是否出现循环
7. 节点深度是否正确
8. 节点数量是否超过限制
9. 每个节点是否有来源
10. sourceUrl 是否属于当前课程文件
11. documentId 是否属于当前课程
12. sourceRefs 是否为空
13. 标题是否重复
14. summary 是否超长
15. importance 是否位于 0 到 1
16. 是否生成了其他课程内容
17. 展开请求是否只生成当前父节点的直接子节点

校验失败时：

第一次：
- 将错误信息发送给模型要求修复

第二次：
- 返回可识别错误
- 不保存错误结果
- 不返回未经验证的数据给 App

==================================================
十三、缓存和更新
==================================================

保存思维导图：

MindMap

- id
- courseId
- rootNodeId
- documentVersion
- generatedAt
- updatedAt

MindMapNode

- id
- courseId
- parentId
- title
- summary
- type
- depth
- importance
- hasMoreChildren
- evidenceLevel
- generationVersion

MindMapSourceReference

- nodeId
- documentId
- sourceUrl
- page
- chunkId

当课程资料没有变化时：

- 直接使用缓存
- 不重新生成顶层思维导图

当新增课件时：

- 更新课程索引
- 计算新的 documentVersion
- 标记顶层知识图谱可能过期
- 允许管理员或系统重新生成

不要在每次用户打开页面时重新生成整个思维导图。

==================================================
十四、后端接口
==================================================

请实现以下接口。

1. 创建课程

POST /courses

请求：

{
  "id": "data-structure",
  "name": "数据结构",
  "semester": "2026-spring",
  "sourcePages": [
    "https://school.example.edu/courses/ds/resources"
  ],
  "allowedDomains": [
    "school.example.edu",
    "cdn.school.example.edu"
  ],
  "accessType": "publicWeb"
}

2. 获取课程

GET /courses/{courseId}

3. 同步课程资料

POST /courses/{courseId}/sync-materials

4. 获取课程文档列表

GET /courses/{courseId}/documents

5. 获取课程顶层思维导图

GET /courses/{courseId}/mind-map

6. 展开节点

POST /courses/{courseId}/mind-map/expand

请求：

{
  "nodeId": "node-tree",
  "requestedDepth": 1
}

7. 获取节点详情

GET /courses/{courseId}/mind-map/nodes/{nodeId}

8. 获取节点来源

GET /courses/{courseId}/mind-map/nodes/{nodeId}/sources

9. 重新生成顶层结构

POST /courses/{courseId}/mind-map/regenerate

需要避免同一个节点被多个请求同时重复生成。

使用数据库锁、分布式锁或任务状态控制。

==================================================
十五、iOS 数据模型
==================================================

Swift 中定义：

struct Course: Codable, Identifiable {
    let id: String
    let name: String
}

struct MindMapResponse: Codable {
    let courseId: String
    let title: String
    let rootNodeId: String
    let nodes: [MindMapNode]
    let edges: [MindMapEdge]
}

struct MindMapNode: Codable, Identifiable, Hashable {
    let id: String
    let parentId: String?
    let title: String
    let summary: String
    let type: MindMapNodeType
    let depth: Int
    let importance: Double
    let hasMoreChildren: Bool
    let evidenceLevel: EvidenceLevel
    let sourceRefs: [MindMapSourceReference]
}

struct MindMapEdge: Codable, Identifiable, Hashable {
    let id: String
    let from: String
    let to: String
    let relation: String
}

struct MindMapSourceReference: Codable, Hashable {
    let documentId: String
    let documentTitle: String
    let sourceUrl: URL
    let page: Int?
    let chunkId: String?
}

enum EvidenceLevel: String, Codable {
    case strong
    case partial
    case insufficient
}

enum MindMapNodeType: String, Codable {
    case course
    case chapter
    case concept
    case definition
    case theorem
    case method
    case example
    case skill
    case vocabulary
    case grammar
    case exercise
}

==================================================
十六、iOS 网络服务
==================================================

定义：

protocol MindMapService {
    func fetchMindMap(courseId: String) async throws -> MindMapResponse

    func expandNode(
        courseId: String,
        nodeId: String
    ) async throws -> MindMapExpansionResponse
}

实现：

APIMindMapService

要求：

- 使用 async/await
- 正确处理 HTTP 状态码
- 设置超时
- 支持取消请求
- 解码失败时输出明确错误
- 不在 View 中直接写网络请求
- URL 和后端地址统一配置
- 不在客户端保存模型 API Key

==================================================
十七、iOS 页面流程
==================================================

课程列表页面：

点击课程时传递 courseId。

示例：

NavigationLink {
    CourseMindMapView(courseId: course.id)
} label: {
    CourseCard(course: course)
}

CourseMindMapView：

1. 根据 courseId 请求对应思维导图。
2. 显示加载状态。
3. 加载成功后显示 DynamicMindMapView。
4. 加载失败显示重试。
5. 不同 courseId 必须获取不同课程数据。
6. 页面中不能写死“数据结构”等具体节点。

用户点击节点：

- 如果 hasMoreChildren == true
- 且子节点尚未加载
- 调用 expandNode
- 显示节点加载动画
- 合并返回的新节点和连线
- 保存展开状态
- 展开失败时保留原图并允许重试

==================================================
十八、SwiftUI 动态思维导图
==================================================

API 只返回节点关系，不返回坐标。

Swift 本地负责布局。

实现：

MindMapLayoutEngine

输入：

- nodes
- edges
- rootNodeId
- containerSize
- focusedNodeId
- expandedNodeIds

输出：

[String: CGPoint]

支持：

- 树状布局或径向布局
- 点击节点聚焦到中心
- 拖动画布
- 双指缩放
- 展开和收起节点
- 连接线动态生长
- 深层节点按需显示
- 节点出现时使用弹簧动画
- 不同屏幕尺寸自适应
- 节点文字长度变化时不重叠
- 当前聚焦节点放大
- 未聚焦区域适当淡化

建议：

- Canvas 绘制连接线
- 普通 SwiftUI View 绘制节点
- DragGesture 平移
- MagnifyGesture 缩放
- spring 动画展开节点

不要让模型计算 x、y 坐标。

==================================================
十九、节点详情和资料来源
==================================================

点击节点后展示详情面板：

- 节点标题
- 简介
- 类型
- 证据等级
- 来源课件
- PDF 页码
- 打开原始课件

来源示例：

《第五章 树与二叉树》
第 16 页
查看原始课件

如果证据等级为 insufficient：

显示：

“当前课件对此内容介绍较少。”

不要把低证据内容表现为确定事实。

==================================================
二十、Mate 联动
==================================================

与现有 Mate 悬浮 Agent 联动。

进入课程知识地图时：

mateViewModel.handle(event: .mindMapLoadingStarted)

加载成功：

mateViewModel.handle(event: .mindMapLoaded)

点击节点并请求子节点：

mateViewModel.handle(event: .mindMapNodeExpanding)

展开完成：

mateViewModel.handle(event: .mindMapNodeExpanded)

加载时 Mate 显示 thinking 动画。

成功后显示轻量开心反馈。

失败时使用温和疑惑状态，不使用责备或警告式动作。

如果当前项目中没有这些事件，请以不破坏现有结构的方式扩展 MateEvent。

==================================================
二十一、安全要求
==================================================

必须处理：

- SSRF
- 私有 IP
- localhost
- 云服务元数据地址
- 恶意重定向
- 超大文件
- 非 PDF 内容
- 超时
- 过多并发下载
- 不可信 HTML
- 路径遍历
- SQL 注入
- API 滥用
- 模型调用限流
- 同步任务重复执行

不得：

- 自动抓取未配置的网站
- 绕过登录
- 破解验证码
- 保存学生账号密码
- 把登录 Cookie 发给模型
- 把 API Key 写进 App
- 抓取 allowedDomains 之外的文件

==================================================
二十二、建议代码结构
==================================================

Backend/
├── courses/
│   ├── models.py
│   ├── schemas.py
│   ├── repository.py
│   ├── service.py
│   └── routes.py
│
├── crawler/
│   ├── source_adapter.py
│   ├── static_html_adapter.py
│   ├── pdf_link_extractor.py
│   ├── url_normalizer.py
│   └── domain_validator.py
│
├── documents/
│   ├── models.py
│   ├── remote_fetcher.py
│   ├── metadata_service.py
│   ├── hash_service.py
│   └── temp_storage.py
│
├── indexing/
│   ├── provider.py
│   ├── course_index_service.py
│   └── material_sync_service.py
│
├── mindmap/
│   ├── models.py
│   ├── schemas.py
│   ├── generation_service.py
│   ├── validation_service.py
│   ├── prompt_builder.py
│   ├── repository.py
│   └── routes.py
│
└── tests/

iOS/
└── Features/
    └── MindMap/
        ├── Models/
        ├── Services/
        ├── ViewModels/
        ├── Views/
        ├── Layout/
        └── Components/

可以根据现有项目结构调整，但必须保持职责分离。

==================================================
二十三、测试要求
==================================================

后端测试：

1. HTML 中发现多个 PDF。
2. 相对 URL 转绝对 URL。
3. 重复 URL 去重。
4. 非允许域名被拒绝。
5. 重定向到非法域名被拒绝。
6. 非 PDF 文件被拒绝。
7. 文件未变化时不重新索引。
8. 文件更新时重新索引。
9. 不同课程的资料不会混用。
10. 思维导图节点 ID 唯一。
11. 无效边被拒绝。
12. 循环结构被拒绝。
13. 没有来源的节点被拒绝。
14. 同一节点的并发生成不会重复调用模型。

iOS 测试：

1. 不同 courseId 加载不同数据。
2. API 返回错误时显示重试。
3. 点击未加载节点会调用展开接口。
4. 已加载节点不会重复请求。
5. 新节点可以正确合并。
6. 布局结果不会产生 NaN。
7. 缩放和平移状态正确。
8. 网络请求取消后不会错误更新界面。

==================================================
二十四、MVP 范围
==================================================

第一版只需完整实现：

1. 配置两门课程：
   - 数据结构
   - 大学英语

2. 每门课程配置一个公开资源页面。

3. 后端从资源页中发现公开 PDF。

4. 后端临时获取 PDF 并建立课程独立索引。

5. 根据课件生成课程前两层知识结构。

6. iOS 根据 courseId 加载不同思维导图。

7. 点击节点后动态生成下一层。

8. 生成结果缓存。

9. 每个节点显示课件来源。

10. 课件发生变化后可以手动重新同步。

11. Mate 在生成过程中显示思考动画。

暂时不要求：

- 自动登录校园系统
- 绕过验证码
- 全网通用爬虫
- 实时多人协作
- 复杂知识图谱推理
- 一次性生成完整课程所有层级

==================================================
二十五、验收标准
==================================================

完成后必须满足：

- Swift 代码中没有写死具体知识节点。
- 点击“数据结构”会显示由数据结构课件生成的内容。
- 点击“大学英语”会显示由英语课件生成的内容。
- 课程资料来自配置的网站。
- 网站中存在多个 PDF 时可以全部发现。
- PDF 不需要下载到用户手机。
- 后端可以识别新增或更新的 PDF。
- 不同课程的课件不会混用。
- API 返回结构化节点和连线。
- SwiftUI 可以动态绘制节点。
- 用户点击节点后可以按需生成下一层。
- 已生成内容不会重复调用模型。
- 每个节点都可以查看资料来源。
- 模型生成结果经过后端校验。
- 非允许域名和危险地址不能被访问。
- 大模型 API Key 不存在于 iOS 客户端。
- 项目可以正常编译和运行。

==================================================
二十六、最终输出要求
==================================================

请直接修改项目并提供可运行实现，不要只输出伪代码。

完成后说明：

1. 创建和修改了哪些文件。
2. 如何配置数据库。
3. 如何配置模型 API Key。
4. 如何新增一门课程。
5. 如何配置课程资源页。
6. 如何手动同步远程课件。
7. 如何生成课程顶层思维导图。
8. iOS 如何通过 courseId 请求对应课程。
9. 如何测试节点动态展开。
10. 哪些部分属于 MVP 占位实现。
11. 如何替换文档索引供应商。
12. 如何支持未来的登录授权课程网站。
13. 当前安全限制和已知问题。

开始开发前先输出一份简短实施计划，然后按计划逐步完成代码。