import AppIntents
import Foundation

// MARK: - Posture Status Enum

public enum PostureStatusEnum: String, AppEnum {
    case good
    case bad
    case inactive

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Posture Status"

    public static var caseDisplayRepresentations: [PostureStatusEnum: DisplayRepresentation] = [
        .good: "Good Posture",
        .bad: "Bad Posture",
        .inactive: "Inactive / Off"
    ]
}

// MARK: - App Intent: Get Posture Status

struct GetPostureStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Posture Status"
    static var description = IntentDescription("Returns current posture status from PostureAI.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PostureStatusEnum> {
        let statusString = PostureStateStore.shared.currentStatus
        let status = PostureStatusEnum(rawValue: statusString) ?? .inactive
        return .result(value: status)
    }
}

// MARK: - App Intent: Is Slouching

struct IsSlouchingIntent: AppIntent {
    static var title: LocalizedStringResource = "Is Slouching"
    static var description = IntentDescription("Returns true if PostureAI currently detects bad posture. Use with automations like 'If slouching, shut down Mac'.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        return .result(value: PostureStateStore.shared.isSlouching)
    }
}

// MARK: - App Intent: Set Posture Monitoring (Start / Stop / Toggle)

enum PostureMonitoringAction: String, AppEnum {
    case start
    case stop
    case toggle

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Action"

    static var caseDisplayRepresentations: [PostureMonitoringAction: DisplayRepresentation] = [
        .start: "Start",
        .stop: "Stop",
        .toggle: "Toggle"
    ]
}

struct PostureMonitoringIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Posture"
    static var description = IntentDescription("Starts, stops, or toggles posture monitoring.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Action")
    var action: PostureMonitoringAction?

    @MainActor
    func perform() async throws -> some IntentResult {
        switch action ?? .toggle {
        case .start:
            await PostureStateStore.shared.onStartMonitoring?()
        case .stop:
            await PostureStateStore.shared.onStopMonitoring?()
        case .toggle:
            await PostureStateStore.shared.onToggleMonitoring?()
        }
        return .result()
    }
}

// MARK: - App Entity: Today's Posture Analytics

struct PostureAnalytics: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Posture Analytics"
    static let defaultQuery = PostureAnalyticsQuery()

    let id: String
    let minutesTracked: Int
    let slouchCount: Int
    let streakDays: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(minutesTracked) min tracked · \(slouchCount) slouches · \(streakDays)-day streak"
        )
    }
}

struct PostureAnalyticsQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [PostureAnalytics] {
        let analytics = await PostureStateStore.shared.currentAnalytics()
        return identifiers.contains(analytics.id) ? [analytics] : []
    }

    func suggestedEntities() async throws -> [PostureAnalytics] {
        [await PostureStateStore.shared.currentAnalytics()]
    }
}

// MARK: - App Intent: Get Today's Posture Analytics

struct GetPostureAnalyticsIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Posture Analytics"
    static var description = IntentDescription("Returns minutes tracked, slouch count, and good-posture streak for today.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<PostureAnalytics> {
        return .result(value: PostureStateStore.shared.currentAnalytics())
    }
}

// MARK: - App Intent: Start Screen Break

enum ScreenBreakDelay: Int, AppEnum {
    case now = 0
    case fiveMinutes = 5
    case tenMinutes = 10
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case sixtyMinutes = 60

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Start In"

    static var caseDisplayRepresentations: [ScreenBreakDelay: DisplayRepresentation] = [
        .now: "Now",
        .fiveMinutes: "5 minutes",
        .tenMinutes: "10 minutes",
        .fifteenMinutes: "15 minutes",
        .thirtyMinutes: "30 minutes",
        .sixtyMinutes: "1 hour"
    ]
}

enum ScreenBreakDuration: Int, AppEnum {
    case seconds10 = 10
    case seconds20 = 20
    case seconds30 = 30
    case seconds60 = 60

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Duration"

    static var caseDisplayRepresentations: [ScreenBreakDuration: DisplayRepresentation] = [
        .seconds10: "10 seconds",
        .seconds20: "20 seconds",
        .seconds30: "30 seconds",
        .seconds60: "1 minute"
    ]
}

struct StartScreenBreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Screen Break"
    static var description = IntentDescription("Starts a screen break after a delay for a set duration.")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Start in")
    var delay: ScreenBreakDelay?

    @Parameter(title: "Duration")
    var duration: ScreenBreakDuration?

    @MainActor
    func perform() async throws -> some IntentResult {
        let delaySeconds = (delay?.rawValue ?? 0) * 60
        let durationSeconds = duration?.rawValue ?? 20
        if delaySeconds > 0 {
            try await Task.sleep(for: .seconds(delaySeconds))
        }
        PostureStateStore.shared.onStartScreenBreak?(durationSeconds)
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct PostureShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: GetPostureStatusIntent(),
            phrases: [
                "Get posture status in \(.applicationName)"
            ],
            shortTitle: "Get Posture Status",
            systemImageName: "figure.walk"
        )
        AppShortcut(
            intent: IsSlouchingIntent(),
            phrases: [
                "Check if I'm slouching in \(.applicationName)"
            ],
            shortTitle: "Is Slouching",
            systemImageName: "figure.fall"
        )
        AppShortcut(
            intent: PostureMonitoringIntent(),
            phrases: [
                "Start, stop, or toggle posture in \(.applicationName)"
            ],
            shortTitle: "Set Posture",
            systemImageName: "power"
        )
        AppShortcut(
            intent: GetPostureAnalyticsIntent(),
            phrases: [
                "Get today's posture analytics in \(.applicationName)"
            ],
            shortTitle: "Get Today's Analytics",
            systemImageName: "chart.bar.fill"
        )
        AppShortcut(
            intent: StartScreenBreakIntent(),
            phrases: [
                "Start a screen break in \(.applicationName)"
            ],
            shortTitle: "Start Screen Break",
            systemImageName: "eye"
        )
    }
}