import SwiftUI
import SwiftData

@main
struct GrabDeskApp: App {

    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: GrabTarget.self)
        } catch {
            // 本地库建不起来说明磁盘或沙盒异常，直接用内存库兜底，保证能进 App。
            container = try! ModelContainer(
                for: GrabTarget.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
        }
        .modelContainer(container)
    }
}
