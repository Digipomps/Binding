import Foundation

public actor SessionSupervisor {
    private var heartbeatTask: Task<Void, Never>?

    public init() {}

    public func start(intervalSeconds: Int, onHeartbeat: @escaping @Sendable (Date) async -> Void) {
        stop()
        heartbeatTask = Task {
            while !Task.isCancelled {
                await onHeartbeat(Date())
                let duration = UInt64(max(intervalSeconds, 1)) * 1_000_000_000
                try? await Task.sleep(nanoseconds: duration)
            }
        }
    }

    public func stop() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }
}
