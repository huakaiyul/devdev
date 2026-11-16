import SwiftUI
import SwiftData

struct TargetEditorView: View {

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let target: GrabTarget?

    @State private var title: String
    @State private var venue: String
    @State private var sessionNote: String
    @State private var saleStart: Date
    @State private var priceTier: String
    @State private var seat: SeatPreference
    @State private var quantity: Int
    @State private var reminders: Set<Int>
    @State private var launchURLString: String

    private let reminderOptions: [(seconds: Int, label: String)] = [
        (3_600, "1 小时"),
        (600, "10 分钟"),
        (60, "1 分钟"),
        (10, "10 秒")
    ]

    init(target: GrabTarget?) {
        self.target = target
        _title = State(initialValue: target?.title ?? "")
        _venue = State(initialValue: target?.venue ?? "")
        _sessionNote = State(initialValue: target?.sessionNote ?? "")
        _saleStart = State(initialValue: target?.saleStart ?? Date().addingTimeInterval(3_600))
        _priceTier = State(initialValue: target?.priceTier ?? "")
        _seat = State(initialValue: target?.seatPreference ?? .any)
        _quantity = State(initialValue: target?.quantity ?? 2)
        _reminders = State(initialValue: Set(target?.reminderOffsets ?? [600, 60, 10]))
        _launchURLString = State(initialValue: target?.launchURLString ?? "")
    }

    private var isEditing: Bool { target != nil }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("影片与场次") {
                    TextField("片名，例如 流浪地球 3", text: $title)
                        .textInputAutocapitalization(.never)
                    TextField("影院，例如 万达影城 · 保利广场店", text: $venue)
                    TextField("场次备注，例如 10月24日 19:30 · IMAX", text: $sessionNote)
                }

                Section {
                    DatePicker(
                        "开售时间",
                        selection: $saleStart,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    if saleStart <= Date() {
                        Label("这个时间已经过去了，提醒不会触发。", systemImage: "exclamationmark.triangle")
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("开售时间")
                } footer: {
                    Text("以大麦页面显示的开售时间为准，建议提前 1 分钟进来待命。")
                }

                Section("票务偏好") {
                    TextField("价格档，例如 68 元档", text: $priceTier)
                    Stepper(value: $quantity, in: 1...6) {
                        HStack {
                            Text("数量")
                            Spacer()
                            Text("\(quantity) 张").foregroundStyle(.secondary)
                        }
                    }
                    Picker("座位偏好", selection: $seat) {
                        ForEach(SeatPreference.allCases) { preference in
                            Label(preference.rawValue, systemImage: preference.symbolName)
                                .tag(preference)
                        }
                    }
                }

                Section {
                    ForEach(reminderOptions, id: \.seconds) { option in
                        Toggle(isOn: binding(for: option.seconds)) {
                            Text("提前 \(option.label)")
                        }
                    }
                } header: {
                    Text("提醒")
                } footer: {
                    Text("选择多个档位会分别提醒，全部走系统本地通知。")
                }

                Section {
                    TextField("可选：从大麦复制的活动链接", text: $launchURLString)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("直达链接")
                } footer: {
                    Text("填了就直接跳到这个活动页，留空则打开大麦首页。")
                }
            }
            .navigationTitle(isEditing ? "编辑目标" : "新建目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func binding(for seconds: Int) -> Binding<Bool> {
        Binding(
            get: { reminders.contains(seconds) },
            set: { isOn in
                if isOn { reminders.insert(seconds) } else { reminders.remove(seconds) }
            }
        )
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let model = target ?? GrabTarget()
        model.title = trimmedTitle
        model.venue = venue.trimmingCharacters(in: .whitespacesAndNewlines)
        model.sessionNote = sessionNote.trimmingCharacters(in: .whitespacesAndNewlines)
        model.saleStart = saleStart
        model.priceTier = priceTier.trimmingCharacters(in: .whitespacesAndNewlines)
        model.seatPreference = seat
        model.quantity = quantity
        model.reminderOffsets = Array(reminders).sorted(by: >)
        model.launchURLString = launchURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        model.isArchived = false

        if target == nil { context.insert(model) }
        try? context.save()

        let snapshot = model.snapshot
        Task {
            // 权限申请放在“用户第一次保存目标”这个上下文里，而不是冷启动。
            let status = await NotificationScheduler.shared.authorizationStatus()
            if status == .notDetermined {
                _ = await NotificationScheduler.shared.requestAuthorization()
            }
            await NotificationScheduler.shared.reschedule(for: snapshot)
        }

        HapticEngine.shared.tap()
        dismiss()
    }
}

#Preview {
    TargetEditorView(target: GrabTarget.sample())
        .modelContainer(for: GrabTarget.self, inMemory: true)
}
