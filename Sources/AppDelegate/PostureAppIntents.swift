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
    static var description = IntentDescription("Returns true if PostureAI currently detects bad posture.")
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        return .result(value: PostureStateStore.shared.isSlouching)
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
    }
}
