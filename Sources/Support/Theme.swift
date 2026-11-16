import SwiftUI

/// 全局设计令牌：8pt 网格 + 语义色。
/// 尺寸统一走 8 的倍数；颜色优先使用系统语义色，自动适配深浅色与增强对比度。
enum Theme {

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 16
        static let control: CGFloat = 12
    }

    /// 品牌强调色。只做强调，不单独承载语义（配合图标与文字）。
    static let accent = Color(red: 0.95, green: 0.20, blue: 0.27)

    /// HIG 触控目标下限。
    static let minTouchTarget: CGFloat = 44
}

extension View {

    /// 卡片容器：材质底 + 连续圆角 + 统一内边距。
    func grabCard(isHighlighted: Bool = false) -> some View {
        self
            .padding(Theme.Spacing.m)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(isHighlighted ? Theme.accent.opacity(0.55) : Color.clear, lineWidth: 1.5)
            }
    }

    /// 保证最小可点击区域，避免 44pt 以下的“难点中”。
    func minTouchTarget() -> some View {
        frame(minHeight: Theme.minTouchTarget, alignment: .center)
    }
}
