import Foundation

/// 倒计时格式化。分三档精度：
/// 1 天以上 → "3天02:15"
/// 1 小时以上 → "02:15:30"
/// 1 小时以内 → "15:30"
/// 最后 60 秒 → "00:09.42"（百分秒）
enum CountdownFormatter {

    static func coarse(_ remaining: TimeInterval) -> String {
        guard remaining > 0 else { return "已开售" }
        let total = Int(remaining)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if days > 0 { return String(format: "%d天%02d:%02d", days, hours, minutes) }
        if hours > 0 { return String(format: "%02d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// 精确到百分秒，仅用于开售前 60 秒。
    static func precise(_ remaining: TimeInterval) -> String {
        let clamped = max(0, remaining)
        let whole = clamped.rounded(.down)
        let minutes = Int(whole) / 60
        let seconds = Int(whole) % 60
        let hundredths = Int((clamped - whole) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }

    /// 给 VoiceOver 读的口语化文本。
    static func spoken(_ remaining: TimeInterval) -> String {
        guard remaining > 0 else { return "已经开售" }
        let total = Int(remaining)
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        var parts: [String] = []
        if days > 0 { parts.append("\(days) 天") }
        if hours > 0 { parts.append("\(hours) 小时") }
        if minutes > 0 { parts.append("\(minutes) 分") }
        if days == 0, hours == 0 { parts.append("\(seconds) 秒") }
        return parts.joined()
    }

    /// 提醒档位的短标签，例如 600 → "10 分钟"。
    static func offsetLabel(_ offset: Int) -> String {
        if offset % 3600 == 0 { return "\(offset / 3600) 小时" }
        if offset % 60 == 0 { return "\(offset / 60) 分钟" }
        return "\(offset) 秒"
    }

    /// 提醒档位的简短前缀，例如 600 → "T-10m"。
    static func offsetBadge(_ offset: Int) -> String {
        if offset % 3600 == 0 { return "T-\(offset / 3600)h" }
        if offset % 60 == 0 { return "T-\(offset / 60)m" }
        return "T-\(offset)s"
    }
}
