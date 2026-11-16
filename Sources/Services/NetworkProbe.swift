import Foundation
import Network
import Observation

/// 网络自检：只测“到目标站点的往返耗时”，用来判断当下是否值得下手。
/// 注意：这是一次本机 HEAD 请求，不读写任何账号数据、不调用任何非公开接口。
@Observable
final class NetworkProbe {

    enum Status: Equatable {
        case idle
        case probing
        case online(latencyMS: Int)
        case offline
    }

    private(set) var status: Status = .idle
    private(set) var isExpensive = false
    private(set) var isLowDataMode = false
    private(set) var lastChecked: Date?

    private var monitor: NWPathMonitor?
    private var loop: Task<Void, Never>?
    private let session: URLSession
    private var host: String = "https://m.damai.cn"

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 4
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        session = URLSession(configuration: config)
    }

    // MARK: - 生命周期

    @MainActor
    func start(host: String? = nil) {
        if let host, !host.isEmpty { self.host = host }
        guard loop == nil else { return }

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                self.isExpensive = path.isExpensive
                self.isLowDataMode = path.isConstrained
                if path.status != .satisfied { self.status = .offline }
            }
        }
        monitor.start(queue: .global(qos: .utility))
        self.monitor = monitor

        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.measure()
                // 4 秒一轮：够用，也不至于给对端添麻烦。
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    @MainActor
    func stop() {
        loop?.cancel()
        loop = nil
        monitor?.cancel()
        monitor = nil
        status = .idle
    }

    // MARK: - 探测

    @MainActor
    private func measure() async {
        guard let url = URL(string: host) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        if case .idle = status { status = .probing }

        let started = CFAbsoluteTimeGetCurrent()
        do {
            let (_, response) = try await session.data(for: request)
            let elapsed = Int((CFAbsoluteTimeGetCurrent() - started) * 1_000)
            guard let http = response as? HTTPURLResponse, (200..<500).contains(http.statusCode) else {
                status = .offline
                lastChecked = Date()
                return
            }
            status = .online(latencyMS: elapsed)
        } catch {
            status = .offline
        }
        lastChecked = Date()
    }

    // MARK: - 展示

    var latencyDescription: String {
        switch status {
        case .idle: return "未检测"
        case .probing: return "检测中"
        case .offline: return "不可达"
        case .online(let ms):
            if ms < 120 { return "\(ms) ms · 通畅" }
            if ms < 350 { return "\(ms) ms · 一般" }
            return "\(ms) ms · 偏慢"
        }
    }

    var qualitySymbol: String {
        switch status {
        case .offline: return "wifi.exclamationmark"
        case .online(let ms): return ms < 350 ? "wifi" : "wifi.exclamationmark"
        default: return "wifi"
        }
    }

    var isHealthy: Bool {
        if case .online(let ms) = status { return ms < 350 }
        return false
    }
}
