import Foundation
import Observation

/// 准备清单的本地状态。存 UserDefaults，键是 "checklist.done"。
@Observable
final class ChecklistStore {

    struct Item: Identifiable, Hashable {
        let id: String
        let title: String
        let detail: String
        let symbol: String
    }

    struct Section: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let items: [Item]
    }

    static let sections: [Section] = [
        Section(
            id: "account",
            title: "账号与支付",
            subtitle: "开售前最容易掉链子的地方",
            items: [
                Item(id: "login", title: "大麦账号已登录", detail: "别在开售后才想起来账号被登出", symbol: "person.crop.circle.badge.checkmark"),
                Item(id: "realname", title: "实名观影人已添加", detail: "需要填身份证的场次，提前录好", symbol: "person.text.rectangle"),
                Item(id: "payment", title: "支付方式可用", detail: "支付宝免密 / Apple Pay 至少留一条", symbol: "creditcard"),
                Item(id: "balance", title: "余额或额度充足", detail: "避免跳到支付页才发现余额不够", symbol: "yensign.circle")
            ]
        ),
        Section(
            id: "network",
            title: "网络与设备",
            subtitle: "先把路修通，再谈手速",
            items: [
                Item(id: "network", title: "网络通畅（延迟 < 120ms）", detail: "5G 或独享 WiFi，别用公共热点", symbol: "wifi"),
                Item(id: "vpn", title: "已关闭 VPN / 代理", detail: "跨境节点会直接把你挡在门外", symbol: "network.slash"),
                Item(id: "warmup", title: "大麦 App 已提前打开", detail: "冷启动要十几秒，别赌", symbol: "app.badge.checkmark"),
                Item(id: "backup", title: "备用设备已登录同一账号", detail: "主力机卡住时立刻换机继续", symbol: "iphone.gen3")
            ]
        ),
        Section(
            id: "info",
            title: "信息与选座",
            subtitle: "现场才想就来不及了",
            items: [
                Item(id: "session", title: "场次与影院已确认", detail: "顺手记下备选场次", symbol: "mappin.and.ellipse"),
                Item(id: "tier", title: "价格档已选定", detail: "犹豫的那一秒就是别人的了", symbol: "tag"),
                Item(id: "seat", title: "座位策略已想好", detail: "中间还是过道，先定唯一答案", symbol: "rectangle.center.inset.filled"),
                Item(id: "qty", title: "票数已确定", detail: "多选票会显著降低命中率", symbol: "person.2")
            ]
        ),
        Section(
            id: "final",
            title: "开抢前 5 分钟",
            subtitle: "把身体和设备都调到待命",
            items: [
                Item(id: "standby", title: "已停在购票页面", detail: "不要在首页等，直接进详情页", symbol: "hand.tap"),
                Item(id: "battery", title: "低电量模式已关闭", detail: "省电模式会拖慢后台与网络", symbol: "battery.100percent"),
                Item(id: "focus", title: "勿扰已开、提醒保留", detail: "别让一条微信把倒计时顶掉", symbol: "moon.zzz"),
                Item(id: "rhythm", title: "触觉读秒已开启", detail: "T-3 起用震动代替眼睛计时", symbol: "hand.tap.fill")
            ]
        )
    ]

    static let allItemIDs: [String] = sections.flatMap { $0.items.map(\.id) }

    private let defaults: UserDefaults
    private let storageKey = "checklist.done"
    private(set) var done: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.stringArray(forKey: storageKey) ?? []
        self.done = Set(stored)
    }

    var totalCount: Int { Self.allItemIDs.count }

    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(done.count) / Double(totalCount)
    }

    var isAllDone: Bool { done.count == totalCount }

    func isDone(_ id: String) -> Bool { done.contains(id) }

    func toggle(_ id: String) {
        if done.contains(id) { done.remove(id) } else { done.insert(id) }
        persist()
    }

    func reset() {
        done.removeAll()
        persist()
    }

    private func persist() {
        defaults.set(Array(done), forKey: storageKey)
    }
}
