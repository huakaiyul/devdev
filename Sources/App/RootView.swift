import SwiftUI
import SwiftData

struct RootView: View {

    @Environment(\.scenePhase) private var scenePhase
    @State private var probe = NetworkProbe()
    @State private var checklist = ChecklistStore()

    var body: some View {
        TabView {
            MissionView(probe: probe)
                .tabItem { Label("作战台", systemImage: "stopwatch") }

            ChecklistView(store: checklist)
                .tabItem { Label("准备清单", systemImage: "checklist") }

            SettingsView(probe: probe)
                .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
        .task {
            // 只预热触觉引擎。通知权限在用户第一次创建目标时才申请（上下文驱动）。
            HapticEngine.shared.warmUp()
            probe.start()
        }
        .onChange(of: scenePhase) { _, phase in
            // 回到前台时重新点亮 Taptic Engine，并刷新一次网络快照。
            if phase == .active {
                HapticEngine.shared.warmUp()
                probe.start()
            } else {
                probe.stop()
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: GrabTarget.self, inMemory: true)
        .preferredColorScheme(.dark)
}
