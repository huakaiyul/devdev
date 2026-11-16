import SwiftUI

struct ChecklistView: View {

    @Bindable var store: ChecklistStore
    @State private var isConfirmingReset = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    progressHeader
                        .listRowInsets(EdgeInsets(top: Theme.Spacing.m, leading: Theme.Spacing.m, bottom: Theme.Spacing.m, trailing: Theme.Spacing.m))
                        .listRowBackground(Color.clear)
                }

                ForEach(ChecklistStore.sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            ChecklistRow(
                                item: item,
                                isDone: store.isDone(item.id)
                            ) {
                                withAnimation(.snappy(duration: 0.18)) {
                                    store.toggle(item.id)
                                }
                                HapticEngine.shared.tap()
                            }
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(section.title)
                            Text(section.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        isConfirmingReset = true
                    } label: {
                        Label("重置全部勾选", systemImage: "arrow.counterclockwise")
                            .minTouchTarget()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("准备清单")
            .confirmationDialog(
                "重置全部勾选？",
                isPresented: $isConfirmingReset,
                titleVisibility: .visible
            ) {
                Button("重置", role: .destructive) {
                    store.reset()
                    HapticEngine.shared.warn()
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("只清空勾选状态，不会影响你的抢票目标。")
            }
        }
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(store.done.count) / \(store.totalCount)")
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                Spacer()
                Text(store.isAllDone ? "全部就绪" : "还有 \(store.totalCount - store.done.count) 项")
                    .font(.subheadline)
                    .foregroundStyle(store.isAllDone ? Theme.accent : Color.secondary)
            }
            ProgressView(value: store.progress)
                .tint(Theme.accent)
                .accessibilityLabel("准备进度")
                .accessibilityValue("\(Int(store.progress * 100))%")
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 清单行

private struct ChecklistRow: View {

    var item: ChecklistStore.Item
    var isDone: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isDone ? Theme.accent : Color.secondary.opacity(0.6))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body)
                        .foregroundStyle(isDone ? Color.secondary : Color.primary)
                        .strikethrough(isDone, color: .secondary)
                        .multilineTextAlignment(.leading)
                    Text(item.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                Image(systemName: item.symbol)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .minTouchTarget()
            .padding(.vertical, Theme.Spacing.xs)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title)。\(item.detail)")
        .accessibilityValue(isDone ? "已完成" : "未完成")
        .accessibilityAddTraits(isDone ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    ChecklistView(store: ChecklistStore())
        .preferredColorScheme(.dark)
}
