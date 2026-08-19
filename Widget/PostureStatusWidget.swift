import SwiftUI
import WidgetKit

// MARK: - Shared App Group

/// Identifier for the app group shared between PostureAI and its widget.
/// Both write/read UserDefaults from this suite, which resolves to the
/// `~/Library/Group Containers/group.chill.PostureAI` container.
enum WidgetAppGroup {
    static let identifier = "group.chill.PostureAI"
    static let defaults = UserDefaults(suiteName: identifier)
}

// MARK: - Snapshot Keys

enum WidgetSnapshotKey {
    static let isMonitoring = "widget.isMonitoring"
    static let isSlouching = "widget.isSlouching"
    static let source = "widget.source"
    static let pauseReason = "widget.pauseReason"
    static let minutesToday = "widget.minutesToday"
    static let nextBreakMinutes = "widget.nextBreakMinutes"
    static let lastUpdated = "widget.lastUpdated"
}

// MARK: - Entry

struct PostureStatusEntry: TimelineEntry {
    let date: Date
    let isMonitoring: Bool
    let isSlouching: Bool
    let source: String
    let pauseReason: String
    let minutesToday: Int
    let nextBreakMinutes: Int
}

// MARK: - Provider

struct PostureStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> PostureStatusEntry {
        PostureStatusEntry(
            date: Date(),
            isMonitoring: true,
            isSlouching: false,
            source: "camera",
            pauseReason: "",
            minutesToday: 42,
            nextBreakMinutes: 12
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (PostureStatusEntry) -> Void) {
        completion(readEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PostureStatusEntry>) -> Void) {
        let entry = readEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }

    private func readEntry() -> PostureStatusEntry {
        if let entry = readFromContainer() { return entry }
        let defaults = WidgetAppGroup.defaults
        let now = Date()
        return PostureStatusEntry(
            date: now,
            isMonitoring: defaults?.bool(forKey: WidgetSnapshotKey.isMonitoring) ?? false,
            isSlouching: defaults?.bool(forKey: WidgetSnapshotKey.isSlouching) ?? false,
            source: defaults?.string(forKey: WidgetSnapshotKey.source) ?? "camera",
            pauseReason: defaults?.string(forKey: WidgetSnapshotKey.pauseReason) ?? "",
            minutesToday: defaults?.integer(forKey: WidgetSnapshotKey.minutesToday) ?? 0,
            nextBreakMinutes: defaults?.integer(forKey: WidgetSnapshotKey.nextBreakMinutes) ?? 0
        )
    }

    /// The host app writes a snapshot into this extension's own sandbox
    /// container (the "widgetContainer" transport), which always works with
    /// ad-hoc signing.
    private func readFromContainer() -> PostureStatusEntry? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = documents.appendingPathComponent("widget_snapshot.json")
        guard let data = try? Data(contentsOf: url),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let isMonitoring = (object["widget.isMonitoring"] as? Bool) ?? false
        return PostureStatusEntry(
            date: Date(),
            isMonitoring: isMonitoring,
            isSlouching: (object["widget.isSlouching"] as? Bool) ?? false,
            source: (object["widget.source"] as? String) ?? "camera",
            pauseReason: (object["widget.pauseReason"] as? String) ?? "",
            minutesToday: (object["widget.minutesToday"] as? Int) ?? 0,
            nextBreakMinutes: (object["widget.nextBreakMinutes"] as? Int) ?? 0
        )
    }
}

// MARK: - Widget

struct PostureStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: "PostureStatusWidget",
            provider: PostureStatusProvider()
        ) { entry in
            PostureStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Posture Status")
        .description("Live posture monitoring status")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - View

struct PostureStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PostureStatusEntry

    private var accentColor: Color {
        entry.isMonitoring
            ? (entry.isSlouching ? Color(red: 0.98, green: 0.45, blue: 0.35) : Color(red: 0.31, green: 0.82, blue: 0.77))
            : Color.white.opacity(0.55)
    }

    private var iconName: String {
        entry.isMonitoring
            ? (entry.isSlouching ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
            : "pause.fill"
    }

    private var title: String {
        if entry.isMonitoring {
            return entry.isSlouching ? "Slouching" : "Good posture"
        }
        return "Monitoring paused"
    }

    private var subtitle: String {
        if entry.isMonitoring {
            let source = entry.source == "airpods" ? "AirPods" : "Camera"
            let minutes = String(format: "%d min today", entry.minutesToday)
            return "\(source) · \(minutes)"
        }
        return entry.pauseReason.isEmpty ? "Tap to start" : entry.pauseReason
    }

    private var breakText: String? {
        guard entry.isMonitoring, entry.nextBreakMinutes > 0 else { return nil }
        return "Screen break in \(entry.nextBreakMinutes)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Image(systemName: iconName)
                    .font(.system(size: family == .systemSmall ? 18 : 20, weight: .bold))
                    .foregroundColor(accentColor)
                Spacer()
                if entry.isMonitoring {
                    Circle()
                        .fill(entry.isSlouching
                            ? Color(red: 0.98, green: 0.45, blue: 0.35)
                            : Color(red: 0.31, green: 0.82, blue: 0.77))
                        .frame(width: 8, height: 8)
                }
            }

            Text(title)
                .font(.system(size: family == .systemSmall ? 15 : 16, weight: .semibold))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.72))

            if let breakText {
                Text(breakText)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.15, blue: 0.27),
                    Color(red: 0.16, green: 0.24, blue: 0.42)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}