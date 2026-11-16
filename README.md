# 抢票作战台 · GrabDesk

一个只给自己用的 iOS 抢票辅助 App：**倒计时 + 提醒 + 触觉读秒 + 准备清单 + 网络自检 + 一键跳转**。

它不代你下单。它做的事是把你送到「点下去就能买」的那个状态，剩下的按钮由你的手指完成。

---

## 它做什么

| 能力 | 说明 |
| --- | --- |
| 开售倒计时 | 最近一个目标占主卡，最后 60 秒切到百分秒精度 + 环形进度 |
| 三档本地提醒 | 默认 提前 10 分钟 / 1 分钟 / 10 秒，走 `UNCalendarNotificationTrigger`，专注模式可透出 |
| 触觉读秒 | T-3 / T-2 / T-1 轻击，T-0 重击 + 成功提示，不用盯屏 |
| 目标管理 | 片名 / 影院 / 场次 / 价格档 / 张数 / 座位偏好全本地持久化（SwiftData） |
| 准备清单 | 16 项分四组：账号支付、网络设备、信息选座、开抢前 5 分钟 |
| 网络自检 | 对目标站点做 HEAD 探测，4 秒一轮，给出延迟分档 |
| 一键跳转 | `damai://` 唤起 App，装不上则回落网页版；可填自定义活动链接 |
| 剪贴板 | 一键复制片名，切过去长按粘贴 |

## 它不做什么（边界）

- 不调用大麦任何私有/非公开接口
- 不模拟点击、不做自动化下单、不接管登录与支付
- 不存储账号密码、不接第三方服务器、无埋点
- 不绕过风控、不做多设备并发抢购

原因很简单：这些行为违反平台用户协议，账号风险远大于收益；而且真被封号，谁也救不回来。

---

## 构建

要求：macOS + Xcode 15 以上，iOS 17.0+（用到 SwiftData 与 `@Observable`）。

### 方式一：XcodeGen（推荐）

```bash
brew install xcodegen
cd GrabDesk
xcodegen generate
open GrabDesk.xcodeproj
```

在 Xcode 里把 Signing Team 选成你自己的 Apple ID，连真机 ⌘R。

### 方式二：手动建工程

1. Xcode → New Project → iOS App，名字 `GrabDesk`，Interface 选 **SwiftUI**，Language **Swift**，最低版本 **iOS 17**。
2. 删掉模板自带的 `ContentView.swift` 与 `XxxApp.swift`。
3. 把本目录 `Sources/` 下所有 `.swift` 拖进工程（勾选 *Create groups* + *Copy items if needed*）。
4. Target → Info → 新增 `LSApplicationQueriesSchemes` 数组，加一项 `damai`（不加就检测不到大麦 App，按钮会永远显示「网页版」）。

---

## 目录结构

```
Sources/
├── App/
│   ├── GrabDeskApp.swift        # 入口，注入 ModelContainer
│   └── RootView.swift           # 三 Tab：作战台 / 准备清单 / 设置
├── Models/
│   ├── GrabTarget.swift         # SwiftData 目标 + Sendable 快照
│   └── ChecklistStore.swift     # 清单定义与 UserDefaults 状态
├── Services/
│   ├── NotificationScheduler.swift  # actor，本地通知排程（幂等）
│   ├── HapticEngine.swift           # 触觉读秒
│   ├── NetworkProbe.swift           # 延迟探测 + NWPathMonitor
│   └── DamaiRouter.swift            # Scheme 跳转 / 剪贴板
├── Support/
│   ├── Theme.swift              # 8pt 网格 + 语义色 + 卡片样式
│   └── CountdownFormatter.swift # 三档倒计时格式
└── Views/
    ├── MissionView.swift        # 作战台
    ├── CountdownCard.swift      # 主倒计时卡
    ├── TargetEditorView.swift   # 新建/编辑表单
    ├── ChecklistView.swift      # 准备清单
    └── SettingsView.swift       # 设置与边界说明
```

## 设计约定

- 所有间距走 **8pt 网格**，卡片圆角 16，可点区域不小于 **44pt**
- 只用系统语义色 + 一处品牌强调色，深色模式自动跟随
- 数字统一 `.monospacedDigit()` + `@ScaledMetric`，Dynamic Type 拉到最大不塌
- 每个交互元素都有 `accessibilityLabel`；倒计时标 `updatesFrequently` 并按秒给口语化朗读
- 权限不在冷启动要，第一次保存目标时才申请；被拒后在作战台顶部给可点的补救横幅
- 触觉/动效尊重 `accessibilityReduceMotion`

## 后续可以加的

1. **Live Activity**：锁屏 + 灵动岛倒计时（ActivityKit + Widget Extension，需在 project.yml 加第二个 target）
2. **通知点按直达**：`UNUserNotificationCenterDelegate` 解析 `targetUID`，点提醒直接落到对应目标卡
3. **CSV 导入**：从大麦复制的场次表批量建目标
4. **多设备同步**：CloudKit private database，两台手机各自提醒
5. **开售历史统计**：记录每次实际抢到/没抢到，回看自己的命中率与最佳提前量
