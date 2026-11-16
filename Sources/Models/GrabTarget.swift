import Foundation
import SwiftData

/// 座位偏好。用枚举而不是自由文本，方便以后做筛选与排序。
enum SeatPreference: String, Codable, CaseIterable, Identifiable {
    case any = "不限"
    case front = "前排"
    case middle = "中间"
    case back = "靠后"
    case aisle = "通道旁"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .any: return "questionmark.circle"
        case .front: return "arrow.up.to.line"
        case .middle: return "rectangle.center.inset.filled"
        case .back: return "arrow.down.to.line"
        case .aisle: return "arrow.left.and.right"
        }
    }
}

/// 一场“要抢的目标”。全部数据只落本地 SQLite，不上传任何服务器。
@Model
final class GrabTarget {

    /// 用 uid 而不是 id，避免和 PersistentModel 自带的 Identifiable 语义混淆。
    @Attribute(.unique) var uid: UUID
    var title: String
    var venue: String
    var sessionNote: String
    var saleStart: Date
    var priceTier: String
    var seatPreferenceRaw: String
    var quantity: Int
    var reminderOffsets: [Int]
    /// 用户自己从大麦复制过来的链接（可选）。有则直接跳转，没有则打开大麦首页。
    var launchURLString: String
    var isArchived: Bool
    var createdAt: Date

    init(
        uid: UUID = UUID(),
        title: String = "",
        venue: String = "",
        sessionNote: String = "",
        saleStart: Date = Date().addingTimeInterval(3_600),
        priceTier: String = "",
        seatPreference: SeatPreference = .any,
        quantity: Int = 2,
        reminderOffsets: [Int] = [600, 60, 10],
        launchURLString: String = "",
        isArchived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.uid = uid
        self.title = title
        self.venue = venue
        self.sessionNote = sessionNote
        self.saleStart = saleStart
        self.priceTier = priceTier
        self.seatPreferenceRaw = seatPreference.rawValue
        self.quantity = quantity
        self.reminderOffsets = reminderOffsets
        self.launchURLString = launchURLString
        self.isArchived = isArchived
        self.createdAt = createdAt
    }

    // MARK: - 派生状态

    var seatPreference: SeatPreference {
        get { SeatPreference(rawValue: seatPreferenceRaw) ?? .any }
        set { seatPreferenceRaw = newValue.rawValue }
    }

    var remaining: TimeInterval { saleStart.timeIntervalSinceNow }

    var hasPassed: Bool { remaining <= 0 }

    /// 10 分钟内视为“临战”，卡片高亮。
    var isImminent: Bool { remaining > 0 && remaining <= 600 }

    /// 场次描述兜底：没有手填内容时用开售时间。
    var displaySession: String {
        let trimmed = sessionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return saleStart.formatted(date: .abbreviated, time: .shortened)
    }

    var displayVenue: String {
        let trimmed = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未填写影院" : trimmed
    }

    var launchURL: URL? {
        let trimmed = launchURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), url.scheme != nil else { return nil }
        return url
    }

    /// 传给跨 actor / 通知层的值类型快照。
    /// SwiftData 的 @Model 不是 Sendable，不能直接跨 actor 传。
    var snapshot: GrabTargetSnapshot {
        GrabTargetSnapshot(
            uid: uid,
            title: title,
            venue: displayVenue,
            sessionNote: displaySession,
            saleStart: saleStart,
            reminderOffsets: reminderOffsets
        )
    }
}

struct GrabTargetSnapshot: Sendable, Equatable {
    let uid: UUID
    let title: String
    let venue: String
    let sessionNote: String
    let saleStart: Date
    let reminderOffsets: [Int]

    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名目标" : trimmed
    }
}

// MARK: - 示例数据（仅 Debug 预览用）

extension GrabTarget {
    static func sample() -> GrabTarget {
        GrabTarget(
            title: "流浪地球 3",
            venue: "万达影城 · 保利广场店",
            sessionNote: "10月24日 19:30 · IMAX 2 号厅",
            saleStart: Date().addingTimeInterval(180),
            priceTier: "68 元档",
            seatPreference: .middle,
            quantity: 2
        )
    }
}
