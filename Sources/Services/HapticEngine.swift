import Foundation
import UIKit

/// 触觉引擎：开售读秒不靠眼睛，靠手感。
/// 用 UIImpactFeedbackGenerator，比 Core Haptics 简单、耗电低，
/// iPhone 8 及之后的机型全覆盖；不支持的设备上调用会被系统静默忽略。
final class HapticEngine {

    static let shared = HapticEngine()

    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let soft = UIImpactFeedbackGenerator(style: .soft)
    private let notifier = UINotificationFeedbackGenerator()
    private var countdownTask: Task<Void, Never>?

    private var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "settings.hapticsEnabled") as? Bool ?? true
    }

    /// 提前唤醒 Taptic Engine，避免第一次触发的延迟。
    @MainActor
    func warmUp() {
        guard isEnabled else { return }
        heavy.prepare()
        rigid.prepare()
        soft.prepare()
        notifier.prepare()
    }

    @MainActor
    func tick() {
        guard isEnabled else { return }
        rigid.impactOccurred(intensity: 0.75)
        rigid.prepare()
    }

    @MainActor
    func tap() {
        guard isEnabled else { return }
        soft.impactOccurred(intensity: 0.6)
    }

    /// 开售瞬间：一记重击 + 成功提示，隔着裤兜都能感觉到。
    @MainActor
    func fire() {
        guard isEnabled else { return }
        heavy.impactOccurred(intensity: 1.0)
        notifier.notificationOccurred(.success)
    }

    @MainActor
    func warn() {
        guard isEnabled else { return }
        notifier.notificationOccurred(.warning)
    }

    /// 最后 3 秒读秒：T-3、T-2、T-1 各一记轻击，T-0 一记重击。
    @MainActor
    func startFinalCountdown(to date: Date) {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            for second in stride(from: 3, through: 1, by: -1) {
                let fireAt = date.addingTimeInterval(-Double(second))
                let delay = fireAt.timeIntervalSinceNow
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }
                guard !Task.isCancelled else { return }
                self.tick()
            }
            let remaining = date.timeIntervalSinceNow
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled else { return }
            self.fire()
        }
    }

    @MainActor
    func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }
}
