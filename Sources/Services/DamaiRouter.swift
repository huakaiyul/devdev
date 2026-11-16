import Foundation
import UIKit

/// 跳转与剪贴板。只做“把人送到大麦 App”，下单动作永远由你自己完成。
enum DamaiRouter {

    /// 大麦 App 的 URL Scheme。
    static let appScheme = "damai"
    /// 兜底：没装 App 时打开移动端网页。
    static let webFallback = URL(string: "https://m.damai.cn")!

    /// 打开大麦。优先跳 App，失败回落到网页。
    /// 返回 true 表示成功唤起 App。
    @MainActor
    @discardableResult
    static func openApp() async -> Bool {
        if let schemeURL = URL(string: "\(appScheme)://"),
           UIApplication.shared.canOpenURL(schemeURL) {
            let opened = await UIApplication.shared.open(schemeURL)
            if opened { return true }
        }
        await UIApplication.shared.open(webFallback)
        return false
    }

    /// 打开用户自己填的链接（例如从大麦复制过来的活动页）。
    @MainActor
    @discardableResult
    static func open(url: URL) async -> Bool {
        guard UIApplication.shared.canOpenURL(url) else {
            await UIApplication.shared.open(webFallback)
            return false
        }
        return await UIApplication.shared.open(url)
    }

    /// 把片名／影院名塞进剪贴板，切到大麦后可以直接长按粘贴。
    static func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
    }

    /// 是否有装大麦（决定按钮文案是“打开大麦”还是“网页版大麦”）。
    @MainActor
    static var isAppInstalled: Bool {
        guard let url = URL(string: "\(appScheme)://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}
