import AppKit
import WidgetKit

/// Writes a compact posture snapshot that the desktop widget reads, and asks
/// WidgetKit to refresh its timeline.
///
/// The widget is sandboxed, so with ad-hoc signing (no team ID) it cannot read
/// the app-group container that the unsandboxed host writes to. To keep the
/// widget working without a developer account, the host also writes a JSON
/// snapshot into the widget's own sandbox container, which the widget always
/// can read. The app-group defaults remain as a fallback for properly signed
/// builds.
enum WidgetSnapshot {
    static let suiteName = "group.chill.PostureAI"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    /// Path inside the widget extension's sandbox container
    /// (`~/Library/Containers/chill.PostureAI.widget/Data/Documents`).
    private static var widgetContainerSnapshotURL: URL? {
        let path = ("~/Library/Containers/chill.PostureAI.widget/Data/Documents/widget_snapshot.json" as NSString)
            .expandingTildeInPath
        return URL(fileURLWithPath: path)
    }

    private static var lastReload: Date?
    private static let reloadInterval: TimeInterval = 5

    static func update(
        isMonitoring: Bool,
        isSlouching: Bool,
        source: TrackingSource,
        pauseReason: PauseReason?,
        minutesToday: Int,
        nextBreakMinutes: Int
    ) {
        let pauseText = pauseReason.map(pauseReasonText) ?? ""
        defaults?.set(isMonitoring, forKey: "widget.isMonitoring")
        defaults?.set(isSlouching, forKey: "widget.isSlouching")
        defaults?.set(source.rawValue, forKey: "widget.source")
        defaults?.set(pauseText, forKey: "widget.pauseReason")
        defaults?.set(minutesToday, forKey: "widget.minutesToday")
        defaults?.set(nextBreakMinutes, forKey: "widget.nextBreakMinutes")
        defaults?.set(Date(), forKey: "widget.lastUpdated")

        writeContainerSnapshot(
            isMonitoring: isMonitoring,
            isSlouching: isSlouching,
            source: source.rawValue,
            pauseReason: pauseText,
            minutesToday: minutesToday,
            nextBreakMinutes: nextBreakMinutes
        )

        let now = Date()
        if let lastReload, now.timeIntervalSince(lastReload) < reloadInterval { return }
        lastReload = now
        WidgetCenter.shared.reloadTimelines(ofKind: "PostureStatusWidget")
    }

    private static func writeContainerSnapshot(
        isMonitoring: Bool,
        isSlouching: Bool,
        source: String,
        pauseReason: String,
        minutesToday: Int,
        nextBreakMinutes: Int
    ) {
        guard let url = widgetContainerSnapshotURL else { return }
        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let payload: [String: Any] = [
                "widget.isMonitoring": isMonitoring,
                "widget.isSlouching": isSlouching,
                "widget.source": source,
                "widget.pauseReason": pauseReason,
                "widget.minutesToday": minutesToday,
                "widget.nextBreakMinutes": nextBreakMinutes,
                "widget.lastUpdated": Date().timeIntervalSince1970
            ]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
            try data.write(to: url, options: [.atomic])
        } catch {
            // Not fatal: the app-group path may still work on signed builds.
        }
    }

    /// Today's monitored minutes (for the widget subtitle).
    static func todayMinutes() -> Int {
        let dayKey = DailyStats.dayKey(for: Date())
        let seconds = AnalyticsManager.shared.getLast7Days()
            .first(where: { $0.dayKey == dayKey })?.totalSeconds ?? 0
        return Int((seconds / 60).rounded())
    }

    private static func pauseReasonText(_ reason: PauseReason) -> String {
        switch reason {
        case .noProfile: return "Waiting for setup"
        case .onTheGo: return "Paused — on the go"
        case .cameraDisconnected: return "Paused — camera disconnected"
        case .screenLocked: return "Paused — screen locked"
        case .airPodsRemoved: return "Paused — AirPods removed"
        case .onBattery: return "Paused — on battery"
        case .inMeeting: return "Paused — in a meeting"
        case .inFocus: return "Paused — Focus active"
        }
    }
}