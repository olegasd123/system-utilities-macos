import Foundation

@MainActor
final class MetricsSampler {
    private let collector = MetricsCollector()
    private var timer: Timer?

    func start(onSample: @escaping @MainActor (Snapshot) -> Void) {
        stop()
        sample(onSample: onSample)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sample(onSample: onSample)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample(onSample: @MainActor (Snapshot) -> Void) {
        onSample(collector.sample())
    }
}
