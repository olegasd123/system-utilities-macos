import Foundation

@MainActor
final class MetricsSampler {
    private let worker: MetricsSamplingWorker
    private var samplingTask: Task<Void, Never>?

    init(collector: MetricsCollector = MetricsCollector()) {
        self.worker = MetricsSamplingWorker(collector: collector)
    }

    func start(onSample: @escaping @MainActor (Snapshot) -> Void) {
        stop()

        samplingTask = Task { [worker] in
            while !Task.isCancelled {
                let snapshot = await worker.sample()
                guard !Task.isCancelled else {
                    return
                }

                onSample(snapshot)

                do {
                    try await Task.sleep(for: .seconds(1))
                } catch {
                    return
                }
            }
        }
    }

    func stop() {
        samplingTask?.cancel()
        samplingTask = nil
    }
}

private actor MetricsSamplingWorker {
    private let collector: MetricsCollector

    init(collector: MetricsCollector) {
        self.collector = collector
    }

    func sample() -> Snapshot {
        collector.sample()
    }
}
