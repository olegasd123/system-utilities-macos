import Foundation

@MainActor
final class MetricsSampler {
    private let worker: MetricsSamplingWorker
    private var samplingTask: Task<Void, Never>?
    private var request: MetricSampleRequest = .all

    init(collector: MetricsCollector = MetricsCollector()) {
        self.worker = MetricsSamplingWorker(collector: collector)
    }

    func start(
        request: MetricSampleRequest,
        onSample: @escaping @MainActor (Snapshot, MetricSampleRequest) -> Void
    ) {
        stop()
        self.request = request

        samplingTask = Task { @MainActor [weak self, worker] in
            while !Task.isCancelled {
                guard let self else {
                    return
                }

                let request = self.request
                let snapshot = await worker.sample(request: request)
                guard !Task.isCancelled else {
                    return
                }

                onSample(snapshot, request)

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

    func updateRequest(_ request: MetricSampleRequest) {
        self.request = request
    }
}

private actor MetricsSamplingWorker {
    private let collector: MetricsCollector

    init(collector: MetricsCollector) {
        self.collector = collector
    }

    func sample(request: MetricSampleRequest) -> Snapshot {
        collector.sample(request: request)
    }
}
