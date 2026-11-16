import SwiftUI

struct CountdownCard: View {

    var target: GrabTarget
    var probe: NetworkProbe

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var digitSize: CGFloat = 52

    @State private var didCopy = false
    @State private var isCountingDown = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            header
            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: target.hasPassed)) { context in
                countdownRow(now: context.date)
            }
            Divider()
            statusRow
            actionRow
        }
        .grabCard(isHighlighted: target.isImminent)
        .onDisappear {
            HapticEngine.shared.cancelCountdown()
            isCountingDown = false
        }
    }

    // MARK: - 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                Text(target.title.isEmpty ? "未命名目标" : target.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: Theme.Spacing.s)
                badge
            }
            Label {
                Text("\(target.displayVenue) · \(target.displaySession)")
                    .lineLimit(2)
            } icon: {
                Image(systemName: "mappin.and.ellipse")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
    }

    private var badge: some View {
        let passed = target.hasPassed
        return Text(passed ? "已开售" : "待开售")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, Theme.Spacing.s)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                (passed ? Color.secondary : Theme.accent).opacity(0.15),
                in: Capsule()
            )
            .foregroundStyle(passed ? Color.secondary : Theme.accent)
    }

    // MARK: - 倒计时

    private func countdownRow(now: Date) -> some View {
        let remaining = max(0, target.saleStart.timeIntervalSince(now))
        let inFinalMinute = remaining > 0 && remaining <= 60
        return HStack(alignment: .center, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(inFinalMinute ? CountdownFormatter.precise(remaining) : CountdownFormatter.coarse(remaining))
                    .font(.system(size: digitSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(remaining == 0 ? Theme.accent : Color.primary)
                Text(inFinalMinute ? "最后冲刺，准备点" : "距离开售")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            ProgressRing(progress: ringProgress(remaining: remaining), animate: !reduceMotion)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            remaining == 0 ? "已开售" : "距离开售还有 \(CountdownFormatter.spoken(remaining))"
        )
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// 最后 60 秒环形进度从 0 填到 1；超过 60 秒时按剩余时长做一个“临近感”渐变。
    private func ringProgress(remaining: TimeInterval) -> Double {
        if remaining <= 0 { return 1 }
        if remaining <= 60 { return 1 - remaining / 60 }
        return min(0.25, 60 / max(remaining, 1))
    }

    // MARK: - 状态

    private var statusRow: some View {
        HStack(spacing: Theme.Spacing.m) {
            Label(probe.latencyDescription, systemImage: probe.qualitySymbol)
                .font(.footnote)
                .foregroundStyle(probe.isHealthy ? Color.secondary : Color.orange)
                .accessibilityLabel("网络延迟 \(probe.latencyDescription)")

            if let last = target.reminderOffsets.max() {
                Label("提前 \(CountdownFormatter.offsetLabel(last)) 提醒", systemImage: "bell.badge")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - 操作

    private var actionRow: some View {
        VStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                Button {
                    copyTitle()
                } label: {
                    Label(didCopy ? "已复制" : "复制片名", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                        .minTouchTarget()
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(didCopy ? "已复制片名" : "复制片名到剪贴板")

                Button {
                    Task { await DamaiRouter.openApp() }
                } label: {
                    Label(DamaiRouter.isAppInstalled ? "去大麦" : "网页版", systemImage: "arrow.up.forward.app")
                        .frame(maxWidth: .infinity)
                        .minTouchTarget()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("打开大麦 App 手动下单")
            }

            Button {
                toggleCountdown()
            } label: {
                Label(
                    isCountingDown ? "正在读秒 · 点按停止" : "开启触觉读秒（T-3 起）",
                    systemImage: isCountingDown ? "hand.tap.fill" : "hand.tap"
                )
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .minTouchTarget()
            }
            .buttonStyle(.bordered)
            .tint(isCountingDown ? Theme.accent : .secondary)
            .accessibilityHint("开售前 3 秒开始震动提示，不用盯着屏幕")
        }
    }

    // MARK: - 动作

    private func copyTitle() {
        DamaiRouter.copyToPasteboard(target.title)
        HapticEngine.shared.tap()
        withAnimation(.snappy) { didCopy = true }
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.snappy) { didCopy = false }
        }
    }

    private func toggleCountdown() {
        if isCountingDown {
            HapticEngine.shared.cancelCountdown()
            isCountingDown = false
            return
        }
        guard !target.hasPassed else {
            HapticEngine.shared.warn()
            return
        }
        HapticEngine.shared.warmUp()
        HapticEngine.shared.startFinalCountdown(to: target.saleStart)
        isCountingDown = true
    }
}

// MARK: - 环形进度

private struct ProgressRing: View {

    var progress: Double
    var animate: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.18), lineWidth: 5)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(
                    Theme.accent,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(animate ? .linear(duration: 0.2) : nil, value: progress)
        }
    }
}

#Preview {
    CountdownCard(target: GrabTarget.sample(), probe: NetworkProbe())
        .padding()
        .background(Color(uiColor: .systemGroupedBackground))
}
