import SwiftUI
import SwiftData
import UIKit
import UserNotifications

struct SettingsView: View {

    var probe: NetworkProbe

    @Environment(\.modelContext) private var context
    @Query private var targets: [GrabTarget]

    @AppStorage("settings.hapticsEnabled") private var hapticsEnabled = true
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isConfirmingWipe = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("提醒权限") {
                        HStack(spacing: Theme.Spacing.s) {
                            Text(statusText)
                                .foregroundStyle(statusColor)
                            if notificationStatus != .authorized && notificationStatus != .provisional {
                                Button("开启") { requestPermission() }
                                    .buttonStyle(.borderless)
                            }
                        }
                    }
                    LabeledContent("网络延迟") {
                        HStack(spacing: Theme.Spacing.s) {
                            Text(probe.latencyDescription)
                                .foregroundStyle(probe.isHealthy ? Color.secondary : Color.orange)
                            if probe.isLowDataMode {
                                Text("低数据模式")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                } header: {
                    Text("状态")
                } footer: {
                    Text("网络延迟是对目标站点做的一次本地 HEAD 探测，只用来判断当下是否值得抢。")
                }

                Section("手感") {
                    Toggle(isOn: $hapticsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("触觉反馈")
                            Text("读秒、复制、开售瞬间的震动")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onChange(of: hapticsEnabled) { _, enabled in
                        if enabled {
                            HapticEngine.shared.warmUp()
                            HapticEngine.shared.tap()
                        }
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Label("数据全部留在本机", systemImage: "lock.shield")
                            .font(.subheadline.weight(.semibold))
                        Text("目标、清单、偏好都存在本机数据库和 UserDefaults 里，没有账号体系，没有服务端，没有埋点。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Label("不代你下单", systemImage: "hand.raised")
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, Theme.Spacing.xs)
                        Text("本应用不调用大麦的私有接口、不模拟点击、不接管登录。它只负责提醒你、帮你准备好、把你送到正确的位置。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                } header: {
                    Text("边界")
                }

                Section("数据") {
                    LabeledContent("已保存目标", value: "\(targets.count) 个")
                    Button(role: .destructive) {
                        isConfirmingWipe = true
                    } label: {
                        Label("清空全部目标与提醒", systemImage: "trash")
                            .minTouchTarget()
                    }
                }

                Section {
                    LabeledContent("版本", value: appVersion)
                    Link(destination: DamaiRouter.webFallback) {
                        Label("打开大麦网页版", systemImage: "safari")
                    }
                } header: {
                    Text("关于")
                } footer: {
                    Text("抢票作战台为非官方的个人辅助工具，与大麦网无关联。")
                }
            }
            .navigationTitle("设置")
            .task {
                notificationStatus = await NotificationScheduler.shared.authorizationStatus()
            }
            .confirmationDialog(
                "清空全部目标？",
                isPresented: $isConfirmingWipe,
                titleVisibility: .visible
            ) {
                Button("全部清空", role: .destructive) { wipe() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("目标、已排程的提醒会一并删除，且无法恢复。")
            }
        }
    }

    private var statusText: String {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return "已开启"
        case .denied: return "已关闭"
        case .notDetermined: return "未申请"
        @unknown default: return "未知"
        }
    }

    private var statusColor: Color {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: return Theme.accent
        case .denied: return .orange
        default: return .secondary
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func requestPermission() {
        Task { @MainActor in
            if notificationStatus == .denied {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    await UIApplication.shared.open(url)
                }
            } else {
                _ = await NotificationScheduler.shared.requestAuthorization()
            }
            notificationStatus = await NotificationScheduler.shared.authorizationStatus()
        }
    }

    private func wipe() {
        for target in targets {
            context.delete(target)
        }
        try? context.save()
        Task { await NotificationScheduler.shared.cancelAll() }
        HapticEngine.shared.warn()
    }
}

#Preview {
    SettingsView(probe: NetworkProbe())
        .modelContainer(for: GrabTarget.self, inMemory: true)
}
