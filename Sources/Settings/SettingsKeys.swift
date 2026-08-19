import Foundation

// MARK: - Settings Keys

enum SettingsKeys {
    static let intensity = "intensity"
    static let deadZone = "deadZone"
    static let useCompatibilityMode = "useCompatibilityMode"
    static let appAppearance = "appAppearance"
    static let blurWhenAway = "blurWhenAway"
    static let pauseOnTheGo = "pauseOnTheGo"
    static let pauseOnBattery = "pauseOnBattery"
    static let useFullScreenOverlay = "useFullScreenOverlay"
    static let launchAtLogin = "launchAtLogin"
    static let lastCameraID = "lastCameraID"
    static let profiles = "profiles"
    static let settingsProfiles = "settingsProfiles"
    static let currentSettingsProfileID = "currentSettingsProfileID"
    static let warningMode = "warningMode"
    static let warningColor = "warningColor"
    static let warningOnsetDelay = "blurOnsetDelay"  // Keep key for backward compatibility
    static let toggleShortcutEnabled = "toggleShortcutEnabled"
    static let toggleShortcutKeyCode = "toggleShortcutKeyCode"
    static let toggleShortcutModifiers = "toggleShortcutModifiers"
    static let showAlert = "showAlert"
    static let alertSoundMode = "alertSoundMode"
    static let voiceAnnouncementEnabled = "voiceAnnouncementEnabled"
    static let breakReminderEnabled = "breakReminderEnabled"
    static let breakReminderInterval = "breakReminderInterval"
    static let dailyReminderEnabled = "dailyReminderEnabled"
    static let lastStartReminderDate = "lastStartReminderDate"
    static let meetingPauseEnabled = "meetingPauseEnabled"
    static let focusPauseEnabled = "focusPauseEnabled"
    static let focusPauseModes = "focusPauseModes"
    static let dualSensorEnabled = "dualSensorEnabled"
    static let detectionMode = "detectionMode"
    static let trackingSource = "trackingSource"
    static let trackingMode = "trackingMode"
    static let preferredSource = "preferredSource"
    static let autoReturnEnabled = "autoReturnEnabled"
    static let airPodsCalibration = "airPodsCalibration"

    // Legacy keys (migrated on load)
    static let legacyAirPodsProfile = "airPodsProfile"
}
