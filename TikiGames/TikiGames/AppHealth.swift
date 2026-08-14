import Foundation
import MetricKit

/// Crash, hang and launch-time reporting via MetricKit.
///
/// Tiki Lounge shipped with **no crash reporting of any kind** — GameAnalytics
/// is an analytics SDK, not a crash reporter, and it was the only package in
/// the project. A crash loop hitting a tenth of players would have been
/// invisible until the reviews arrived (ANALYTICS_PLAN §5.6, D-17).
///
/// MetricKit rather than Crashlytics/Sentry because it is Apple-native: no
/// third-party SDK, no extra privacy surface to declare, and nothing new in
/// the nutrition labels. The trade is latency and granularity — iOS delivers
/// payloads roughly once every 24h, aggregated, and only while the app is
/// running. That is fine for "is the app stable", which is the actual
/// question; it is not a live crash console.
///
/// With no backend to receive payloads, the summary values are forwarded into
/// GA so there is one dashboard rather than two.
///
/// `@unchecked Sendable` is honest here: the type holds no stored state at
/// all, and MetricKit delivers its callbacks off the main thread.
final class AppHealth: NSObject, MXMetricManagerSubscriber, @unchecked Sendable {
    static let shared = AppHealth()

    func start() {
        MXMetricManager.shared.add(self)
    }

    // MARK: - MXMetricManagerSubscriber

    /// Daily performance rollup. Launch time is the one players feel.
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            let launch = payload.applicationLaunchMetrics
                .map { Self.averageMilliseconds($0.histogrammedTimeToFirstDraw) } ?? nil
            let hang = payload.applicationResponsivenessMetrics
                .map { Self.averageMilliseconds($0.histogrammedApplicationHangTime) } ?? nil
            Task { @MainActor in
                if let launch { Analytics.design("perf:launch", value: launch) }
                if let hang { Analytics.design("perf:hang", value: hang) }
            }
        }
    }

    /// Crashes, hangs and watchdog terminations. One error event per
    /// diagnostic, tagged by kind so the dashboard groups them.
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        var messages: [String] = []
        for payload in payloads {
            for crash in payload.crashDiagnostics ?? [] {
                messages.append("crash: \(crash.terminationReason ?? "unknown")")
            }
            for hang in payload.hangDiagnostics ?? [] {
                messages.append("hang: \(Int(hang.hangDuration.value))s")
            }
            for _ in payload.appLaunchDiagnostics ?? [] {
                messages.append("launch:watchdog")
            }
        }
        guard !messages.isEmpty else { return }
        Task { @MainActor in
            for m in messages { Analytics.error(m) }
        }
    }

    /// Bucket-weighted mean in whole milliseconds. MetricKit hands back a
    /// histogram rather than a scalar; without weighting by bucket count a
    /// single outlier bucket would read the same as the common case.
    ///
    /// A free function rather than an extension — Swift cannot extend a
    /// generic Objective-C class and reach its generic parameters at runtime.
    private static func averageMilliseconds(_ histogram: MXHistogram<UnitDuration>) -> Int? {
        var totalCount = 0
        var weighted = 0.0
        for case let bucket as MXHistogramBucket<UnitDuration> in histogram.bucketEnumerator {
            let start = bucket.bucketStart.converted(to: .milliseconds).value
            let end = bucket.bucketEnd.converted(to: .milliseconds).value
            weighted += ((start + end) / 2) * Double(bucket.bucketCount)
            totalCount += bucket.bucketCount
        }
        guard totalCount > 0 else { return nil }
        return Int((weighted / Double(totalCount)).rounded())
    }
}
