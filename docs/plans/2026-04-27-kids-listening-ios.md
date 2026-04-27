# 儿童英语听力 iOS App — 实施计划

> 创建日期：2026-04-27

## 目标

给一个 12 岁、刚考过 PET（≈B1）的孩子，在**吃饭**和**睡前**两个碎片时间，自己拿 iPad / iPhone 听合适难度的英语内容。第一版只接一个内容源：[practisingenglish.com](https://www.practisingenglish.com/)。

## 用户与场景

- **唯一用户**：自家 12 岁孩子，独立操作，不用家长干预
- **设备**：iPhone + iPad（同一个 Apple ID，进度需要跨设备）
- **吃饭场景**：屏幕在面前，半看半听，10–15 分钟一集，可看字幕、可点词查义
- **睡前场景**：屏幕调暗放一边或锁屏，闭眼听，需要后台播放、锁屏控制、睡眠定时

## 关键架构决策

### 决策 1：iOS 原生 SwiftUI，不做 web / 不做跨平台

**理由**：
- 后台播放 + 锁屏控制 + 离线下载 + CarPlay/AirPods 控制，原生免费拿到，PWA / RN 都要绕
- 只两台设备、自家用，不需要走 App Store，TestFlight 装就行
- 12 岁孩子习惯点 app icon，不会去开浏览器输网址
- iCloud + SwiftData 跨设备同步进度，几乎零代码

**取舍**：未来想加 Android / Web 要全部重写。可以接受 —— 这是个家用工具，不是产品。

### 决策 2：无后端，内容源直接在 app 里抓

**理由**：
- practisingenglish 已经有公开 RSS（podcast 分发到了 Apple/Spotify）
- iOS app 用 URLSession 直接抓 RSS + episode 网页，没有 CORS 限制
- 不引入 server = 不维护、不付费、不出故障

**风险**：
- 网站改版会让 transcript 抓取失效 → 用 fallback：抓不到就只显示 RSS description
- RSS 拉取要做缓存和重试

**伸缩位**：未来如果加更多源、要做内容审核或 LLM 摘要，再起一个 Cloudflare Worker。这件事不在 V1。

### 决策 3：第一版字幕只做"纯文本可读"，不做逐句高亮同步

**理由**：
- practisingenglish 的 transcript 是纯 HTML 文本，**没有时间戳**
- 要做逐句同步只有两条路：(a) Whisper 本地转录拿时间戳（重）；(b) 强制对齐工具（更重）
- 吃饭场景下，孩子能"翻字幕"已经够用；睡前场景根本不看屏幕

**V2 再考虑**：本地 Whisper 转录 + 句级时间戳 + 卡拉OK高亮。

### 决策 4：iCloud 跨设备同步进度

**理由**：吃饭可能用 iPad，睡前用 iPhone，"上次听到哪"必须跟着走。SwiftData + CloudKit 几乎免费拿到。**已确认走付费 Apple Developer 账号**，CloudKit container 直接启用，TestFlight 也走这个账号。

### 决策 5：UI 文案中英双语，跟随系统语言

**理由**：12 岁孩子刚过 PET，英文 UI 能看懂、沉浸感更好；但部分功能性文案（设置项、错误提示、操作确认）中文更不易产生歧义。最简单的做法是**所有**静态 UI 文案都做中英两份，用 iOS 17+ 的 String Catalog 维护，运行时跟随系统语言。

**范围**：episode 标题、字幕等内容本身是英文，不翻译。第一版不做 in-app 独立切换语言，需要时去 iOS 系统设置切。

## 技术栈

- **Swift 5.10+，SwiftUI，iOS 17+**（SwiftData 要求）
- **AVFoundation / AVPlayer**：音频播放、后台、锁屏控制
- **SwiftData + CloudKit**：本地持久化 + iCloud 同步
- **URLSession + 后台下载会话**：离线下载 mp3
- **XMLParser**：解析 RSS（Foundation 自带）
- **SwiftSoup**（唯一外部依赖）：解析 episode 网页拿 transcript
- **String Catalog（.xcstrings, iOS 17+）**：UI 文案中英双语
- **Universal app**：一份代码，iPhone / iPad 自适应

## V1 范围（要做）

1. 启动后自动从 practisingenglish RSS 拉最新 30 集
2. 列表页：按发布时间倒序，显示标题 / 时长 / 难度标签 / 已听标记
3. 筛选：按难度（A2 / B1 / B2 / C1）、按时长（短 ≤10min / 中 10–20min / 长 >20min）
4. 播放页：大封面、播放控制、进度条、跳前/后 15 秒、变速 0.8x / 1.0x / 1.2x
5. 字幕：抓到 transcript 就以"阅读模式"展示（大字号、暗色背景）
6. 点词查义：长按英文单词 → 弹 iOS 系统词典
7. 离线下载：单集下载、批量下载、下载列表
8. 后台播放 + 锁屏 / 控制中心 / AirPods 控制
9. 睡眠定时：10 / 20 / 30 / 45 分钟，到时淡出停止
10. 进度记忆 + iCloud 同步
11. 收藏 / 已听历史
12. **吃饭模式 / 睡前模式** 一键切换：
    - 吃饭模式：默认筛选 ≤15min，亮屏，字幕大
    - 睡前模式：默认筛选 ≥15min，自动开睡眠定时器（默认 30min），屏幕暗色 + 暖色调
13. UI 文案中英双语，跟随系统语言切换；所有用户可见文案走 String Catalog

## V1 不做

- 多内容源聚合（先把 practisingenglish 跑顺）
- 用户账号 / 登录
- 家长报表 / 学习数据可视化
- 字幕逐句高亮同步
- 单词本 / 复习系统
- 推送通知
- App Store 上架（TestFlight 自家装即可）
- App 内独立切换 UI 语言（跟随系统）

## 数据模型

```swift
@Model
class Episode {
    @Attribute(.unique) var id: String          // sourceID + guid
    var sourceID: String                         // "practising-english"
    var title: String
    var summary: String?
    var audioURL: URL
    var pageURL: URL                             // 用来抓 transcript
    var publishedAt: Date
    var durationSeconds: Int?
    var levelRaw: String?                        // "A2" / "B1" / "B2" / "C1"
    var transcriptText: String?                  // 抓到才有
    var localAudioPath: String?                  // 下载后
    var playProgressSeconds: Double = 0
    var isFavorite: Bool = false
    var lastPlayedAt: Date?
}

enum Mode { case meal, bedtime }   // 仅 UI 状态，不持久化
```

## 模块拆分

```
ListenKids/
├── App/                        # @main、AppDelegate、SwiftData 容器
├── Models/                     # Episode、Level 枚举
├── Sources/                    # 内容源协议 + practising-english 实现
│   ├── ContentSource.swift     # protocol
│   └── PractisingEnglish.swift # RSS + transcript 抓取
├── Player/                     # AVPlayer 包装、后台播放、控制中心
├── Persistence/                # SwiftData container + iCloud 配置
├── Downloads/                  # URLSession 后台下载管理
├── Views/
│   ├── Home/                   # 今天推荐、继续听
│   ├── Library/                # 列表 + 筛选
│   ├── Player/                 # 播放页 + 字幕
│   ├── Downloads/              # 离线管理
│   └── Settings/               # 模式默认值、字号
├── DesignSystem/               # 字号、颜色、圆角 token
└── Resources/
    └── Localizable.xcstrings   # 中英双语文案
```

## 任务里程碑

### M1 — 基础能播（目标：能从列表点开任何一集，后台听完）

1. 新建 Xcode 项目：SwiftUI lifecycle，iOS 17+，Universal；signing 走付费 Apple Developer 账号
2. 配置 Info.plist：`UIBackgroundModes = audio`，Localizations 加 `en` + `zh-Hans`
3. 新建 String Catalog（`Localizable.xcstrings`），约定全部 UI 文案走 `LocalizedStringKey`
4. SwiftData 容器 + Episode 模型 + 启用 CloudKit container
5. `ContentSource` protocol + `PractisingEnglish.fetchEpisodes()` 解析 RSS
6. 拉到的 Episode 写 SwiftData，去重
7. 列表页：按 publishedAt DESC 显示
8. 播放页：AVPlayer + 标准控件，进度写回 SwiftData
9. AVAudioSession 配置后台播放 + 锁屏控制（MPNowPlayingInfoCenter / MPRemoteCommandCenter）

### M2 — 难度过滤 + 离线（目标：孩子能选 B1/B2 + 离线带出门）

1. 从 episode title / description 解析 level（regex：`A2|B1|B2|C1`），存到 `levelRaw`
2. 列表页加 level / 时长 筛选 chip
3. 单集下载按钮 → URLSession 后台下载到 `Documents/audio/`
4. 下载完更新 `localAudioPath`，播放优先用本地
5. 下载列表页 + 删除离线
6. 首页加"继续听"卡片（按 lastPlayedAt 排序，progress > 0 且未播完）

### M3 — 字幕 + 体验（目标：吃饭场景能用得舒服）

1. SwiftSoup 抓 episode 页面 transcript，存 `transcriptText`
2. 阅读视图：大字号、暗色、可调字号（设置页）
3. 点词查义：UIReferenceLibraryViewController（系统词典）
4. 睡眠定时器：底部抽屉 10/20/30/45min，到时 AVPlayer 1 秒淡出
5. 播放速度切换：0.8x / 1.0x / 1.2x

### M4 — 给孩子的细节（目标：两个场景一键切换、无脑用）

1. 顶部模式切换：吃饭 / 睡前
2. 吃饭模式：筛选 ≤15min、字幕字号大、屏幕保持唤醒（`UIApplication.isIdleTimerDisabled`）
3. 睡前模式：筛选 ≥15min、自动开 30min 定时、UI 切到暖色暗色
4. 收藏按钮 + 收藏页
5. 已听历史页

### M5 — 验证与交付

1. 把 app 装到孩子的 iPad 和 iPhone（TestFlight 或 ad-hoc）
2. 跟孩子一起用三天，记录卡点
3. 修一轮卡点
4. 写一个简短 README 描述怎么自己重装

## 横切原则

- **i18n**：每次新增 UI 文案，立刻补到 String Catalog 的 `en` + `zh-Hans`，不留 hardcoded 字符串。任何 PR 含 hardcoded 用户可见字符串都视为未完成。
- **设备验证**：每个里程碑结束至少装到孩子的 iPad 和 iPhone 各试一次，再决定下一步是否调。

## 风险与待办

- **RSS 里没 level 标签**：要看实际 feed 长什么样，可能 level 在 title 开头（"B1 - Story about ..."），也可能在 description 里。M1 第一步先 dump 一份真实 feed 看清楚。
- **transcript 抓取规则**：不同 episode 页面 DOM 可能略有差异，需要写得宽容（找 `<article>` / `.transcript` / `.entry-content` 等）。
- **后台下载**：iOS 后台下载有自己的会话语义，不能用普通 URLSession，要用 `URLSessionConfiguration.background`。
- **音频内容版权**：仅自家用，不再分发，问题不大。但下载到本地的 mp3 不要导出 / 分享。

## 待你确认的开关

1. **下一个内容源**：M5 之后第一个要加的源是哪个？BBC 6 Minute English / ESL Pod / 其他？我会在 `ContentSource` protocol 里预留好接口，但具体哪个先做，会影响 protocol 形状。

—

回头读这份 plan 的人请从 M1 开始按顺序做；每个里程碑结束跟一次孩子真实使用，再决定下一步要不要调。
