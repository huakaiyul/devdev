import SwiftUI
import SwiftData
import UIKit
import UserNotifications

struct MissionView: View {

    var probe: NetworkProbe

    @Environment(\.modelContext) private var context
    @Query(sort: \GrabTarget.saleStart) private var targets: [GrabTarget]

    @State private var isCreating = false
    @State private var editingTarget: GrabTarget?
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var activeTargets: [GrabTarget] { targets.filter { !$0.isArchived } }

    /// 焦点目标：最近一个还没开售的；都开售过了就取最后一个。
    private var focusTarget: GrabTarget? {
        activeTargets.first { $0.saleStart > Date().addingTimeInterval(-600) } ?? activeTargets.last
    }

    private var otherTargets: [GrabTarget] {
        guard let focus = focusTarget else { return activeTargets }
        return activeTargets.filter { $0.uid != focus.uid }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.m) {
                    permissionBanner

                    if let focus = focusTarget {
                        CountdownCard(target: focus, probe: probe)
                    } else {
                        emptyState
                    }

                    if !otherTargets.isEmpty {
                        otherList
                    }

                    footnote
                }
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.m)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("作战台")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreating = true
                    } label: {
                        Label("新建目标", systemImage: "plus")
                    }
                    .accessibilityLabel("新建抢票目标")
                }
            }
            .sheet(isPresented: $isCreating) {
                TargetEditorView(target: nil)
            }
            .sheet(item: $editingTarget) { target in
                TargetEditorView(target: target)
            }
            .task {
                notificationStatus = await NotificationScheduler.shared.authorizationStatus()
            }
            .onChange(of: isCreating) { _, presenting in
                if !presenting { refreshPermission() }
            }
        }
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.m) {
            Image(systemName: "ticket")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("还没有目标")
                .font(.headline)
            Text("把想看的电影、影院、场次和开售时间记下来，开售前我会叫醒你。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                isCreating = true
            } label: {
                Text("新建第一个目标")
                    .minTouchTarget()
                    .padding(.horizontal, Theme.Spacing.m)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .grabCard()
    }

    // MARK: - 目标列表

    private var otherList: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("其他目标")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, Theme.Spacing.xs)

            VStack(spacing: Theme.Spacing.s) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: Theme.Spacing.s) {
                        ForEach(otherTargets) { target in
                            Button {
                                editingTarget = target
                            } label: {
                                TargetRow(target: target, now: context.date)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("编辑", systemImage: "pencil") { editingTarget = target }
                                Button("复制片名", systemImage: "doc.on.doc") {
                                    DamaiRouter.copyToPasteboard(target.title)
                                    HapticEngine.shared.tap()
                                }
                                Button("归档", systemImage: "archivebox") { archive(target) }
                                Button("删除", systemImage: "trash", role: .destructive) { delete(target) }
                            }
                        }
                    }
                }
            }
            .grabCard()
        }
    }

    // MARK: - 权限横幅

    @ViewBuilder
    private var permissionBanner: some View {
        if notificationStatus == .denied || notificationStatus == .notDetermined {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                Image(systemName: "bell.slash")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(notificationStatus == .denied ? "提醒已被关闭" : "还没开启提醒")
                        .font(.subheadline.weight(.semibold))
                    Text(
                        notificationStatus == .denied
                        ? "去系统设置打开通知，否则开售前收不到提示。"
                        : "开启后，开售前 10 分钟 / 1 分钟 / 10 秒会分三次提醒你。"
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(notificationStatus == .denied ? "去设置" : "开启") {
                    handlePermissionTap()
                }
                .buttonStyle(.bordered)
                .minTouchTarget()
            }
            .grabCard()
        }
    }

    // MARK: - 脚注

    private var footnote: some View {
        Label {
            Text("这里只做提醒、清单和跳转。下单与支付始终由你在官方 App 内手动完成。")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "checkmark.shield")
        }
        .foregroundStyle(.secondary)
        .padding(.top, Theme.Spacing.s)
        .accessibilityElement(children: .combine)
    }

    // MARK: - 动作

    private func handlePermissionTap() {
        if notificationStatus == .denied {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            Task { @MainActor in
                await UIApplication.shared.open(url)
            }
        } else {
            Task {
                let granted = await NotificationScheduler.shared.requestAuthorization()
                if granted { await MainActor.run { HapticEngine.shared.tap() } }
                let latest = await NotificationScheduler.shared.authorizationStatus()
                await MainActor.run { notificationStatus = latest }
            }
        }
    }

    private func refreshPermission() {
        Task {
            let latest = await NotificationScheduler.shared.authorizationStatus()
            await MainActor.run { notificationStatus = latest }
        }
    }

    private func archive(_ target: GrabTarget) {
        target.isArchived = true
        try? context.save()
        Task { await NotificationScheduler.shared.cancel(for: target.uid) }
    }

    private func delete(_ target: GrabTarget) {
        let uid = target.uid
        context.delete(target)
        try? context.save()
        Task { await NotificationScheduler.shared.cancel(for: uid) }
    }
}

// MARK: - 列表行

private struct TargetRow: View {

    var target: GrabTarget
    var now: Date

    private var remaining: TimeInterval {
        target.saleStart.timeIntervalSince(now)
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(target.title.isEmpty ? "未命名目标" : target.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text("\(target.displayVenue) · \(target.displaySession)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Spacing.s)
            VStack(alignment: .trailing, spacing: Theme.Spacing.xs) {
                Text(CountdownFormatter.coarse(remaining))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(remaining <= 0 ? Color.secondary : Color.primary)
                Text("\(target.quantity) 张")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(target.title)，\(target.displayVenue)，\(CountdownFormatter.spoken(remaining))后开售"
        )
        .accessibilityHint("轻点编辑")
    }
}

#Preview {
    MissionView(probe: NetworkProbe())
        .modelContainer(for: GrabTarget.self, inMemory: true)
}
