import Foundation

// MARK: - Localization (conflict-free)

private final class LocalizationToken {}

private let fallbackStrings: [String: String] = [
    // Menu Bar
    "menu.status.starting": "Status: Starting...",
    "menu.enable": "Enable",
    "menu.recalibrate": "Recalibrate",
    "menu.support": "Support",
    "menu.analytics": "Analytics",
    "menu.settings": "Settings",
    "menu.quit": "Quit",
    "menu.checkForUpdates": "Check for Updates…",

    // App Menu
    "appmenu.quit": "Quit PostureAI",
    "appmenu.closeWindow": "Close Window",
    "appmenu.file": "File",
    "appmenu.edit": "Edit",
    "appmenu.undo": "Undo",
    "appmenu.redo": "Redo",
    "appmenu.cut": "Cut",
    "appmenu.copy": "Copy",
    "appmenu.paste": "Paste",
    "appmenu.selectAll": "Select All",

    // Status Text
    "status.disabled": "Status: Disabled",
    "status.calibrating": "Status: Calibrating...",
    "status.starting": "Status: Starting...",
    "status.away": "Status: Away",
    "status.slouching": "Status: Slouching",
    "status.goodPosture": "Status: Good Posture",
    "status.calibrationNeeded": "Status: Calibration needed",
    "status.pausedOnTheGo": "Status: Paused (on the go - recalibrate)",
    "status.cameraDisconnected": "Status: Camera disconnected",
    "status.airPodsDisconnected": "Status: AirPods disconnected",
    "status.pausedScreenLocked": "Status: Paused (screen locked)",
    "status.pausedPutInAirPods": "Status: Paused (put in AirPods)",
    "status.pausedOnBattery": "Status: Paused (on battery)",
    "status.pausedInMeeting": "Status: Paused (in a meeting)",
    "status.pausedInFocus": "Status: Paused (Focus mode)",

    // Accessibility
    "accessibility.goodPosture": "Good Posture",
    "accessibility.badPosture": "Bad Posture",
    "accessibility.away": "Away",
    "accessibility.paused": "Paused",
    "accessibility.calibrating": "Calibrating",

    // Warning Mode
    "warningMode.blur": "Blur",
    "warningMode.glow": "Glow",
    "warningMode.border": "Border",
    "warningMode.solid": "Solid",
    "warningMode.none": "None",

    // Detection Mode
    "detectionMode.responsive": "Responsive",
    "detectionMode.balanced": "Balanced",
    "detectionMode.performance": "Performance",

    // Tracking Source
    "trackingSource.camera": "Camera",
    "trackingSource.airpods": "AirPods",
    "trackingSource.camera.description": "Uses your camera to track head position. Works with any Mac camera.",
    "trackingSource.airpods.description": "Uses motion sensors to detect head tilt. Requires AirPods Pro, Max, 3rd gen, or 4 with ANC.",
    "trackingSource.camera.requirement": "Requires camera access",
    "trackingSource.airpods.requirement": "Requires macOS 14+ and compatible AirPods",

    // AirPods
    "airpods.compatible": "Compatible",
    "airpods.noMotionSensors": "No motion sensors",
    "airpods.requiresMacOS14": "Requires macOS 14.0 or later",
    "airpods.noCompatibleConnected": "No compatible AirPods connected",
    "airpods.failedCreateManager": "Failed to create motion manager",
    "airpods.noCompatiblePaired": "No compatible AirPods paired. Please pair AirPods Pro, Max, 3rd gen, or 4 with ANC.",

    // Alerts
    "alert.permissionRequired": "Permission Required",
    "alert.permissionRequired.airpods": "Motion & Fitness Activity permission is required for AirPods tracking. Please enable it in System Settings > Privacy & Security > Motion & Fitness Activity.",
    "alert.permissionRequired.camera": "Camera permission is required. Please enable it in System Settings > Privacy & Security > Camera.",
    "alert.openSettings": "Open Settings",
    "alert.cameraNotAvailable": "Camera Not Available",
    "alert.cameraNotAvailable.message": "Please make sure your camera is connected and camera access is granted.",
    "alert.tryAgain": "Try Again",
    "support.title": "Support PostureAI",
    "support.message": "If PostureAI has helped you with your posture and you want to show some support, please buy us a coffee.",
    "support.button": "Buy us a Coffee",

    // Calibration
    "calibration.lookAtRing": "Look at the ring and tap Space",
    "calibration.stepOf": "Step %d of %d",
    "calibration.lookAtCorner": "Look at the %@ corner",
    "calibration.lookOtherScreen": "Look at the other screen",
    "calibration.corner.topLeft": "top-left",
    "calibration.corner.topRight": "top-right",
    "calibration.corner.bottomLeft": "bottom-left",
    "calibration.corner.bottomRight": "bottom-right",
    "calibration.hint.tapSpace": "Tap {Space} while looking at the ring",
    "calibration.hint.escToSkip": "{Esc} to skip calibration",
    "calibration.airpods.putIn": "Put in your AirPods",
    "calibration.airpods.autoBegin": "Calibration will begin automatically",
    "calibration.airpods.escToCancel": "Press {Esc} to cancel",

    // Settings
    "settings.title": "Settings",
    "settings.tracking": "Tracking",
    "settings.tracking.help": "Manual uses one source. Automatic switches between Camera and AirPods based on availability, using your preferred source when possible.",
    "settings.noCameras": "No cameras",
    "settings.connected": "Connected",
    "settings.notConnected": "Not connected",
    "settings.recalibrate": "Recalibrate",
    "settings.mode.manual": "Manual",
    "settings.mode.automatic": "Automatic",
    "settings.preferred": "Preferred",
    "settings.source": "Source",
    "settings.section.response": "Posture response",
    "settings.section.behavior": "Behavior",
    "settings.appearance": "Appearance",
    "settings.appearance.auto": "Auto",
    "settings.appearance.light": "Light",
    "settings.appearance.dark": "Dark",
    "settings.active": "Active",
    "settings.calibrated": "Calibrated",
    "settings.notCalibrated": "Not calibrated",
    "settings.preferredNeedsCalibration": "Preferred device needs calibration",
    "settings.calibratePreferred": "Calibrate",
    "settings.profile": "Profile",
    "settings.profile.help": "Save different configurations for different situations. Switch profiles to instantly apply all settings below.",
    "settings.profile.new": "New",
    "settings.profile.newTitle": "New Profile",
    "settings.profile.namePrompt": "Name your settings profile.",
    "settings.profile.namePlaceholder": "Profile name",
    "settings.profile.create": "Create",
    "settings.profile.deleteTitle": "Delete Profile",
    "settings.profile.deleteMessage": "Are you sure you want to delete this profile? This cannot be undone.",
    "settings.profile.delete": "Delete",
    "settings.warning": "Warning",
    "settings.warning.help": "Blur obscures the screen, Glow shows edge glow, Border shows colored borders, Solid fills screen. None disables visual warnings.",
    "settings.deadZone": "Dead Zone",
    "settings.deadZone.help": "How much you can move before warning starts. A relaxed dead zone allows more natural movement.",
    "settings.intensity": "Intensity",
    "settings.intensity.help": "How quickly the warning increases as you slouch past the dead zone.",
    "settings.delay": "Delay",
    "settings.delay.help": "Grace period before warning activates. Allows brief glances at keyboard without triggering.",
    "settings.detection": "Detection",
    "settings.detection.help": "Balance responsiveness vs battery. Responsive detects quickly, Performance saves battery.",
    "settings.launchAtLogin": "Launch at login",
    "settings.launchAtLogin.help": "Automatically start PostureAI when you log in",
    "settings.autoUpdates": "Automatic updates",
    "settings.autoUpdates.help": "Check for new versions in the background and offer to install them",
    "settings.blurWhenAway": "Blur when away",
    "settings.blurWhenAway.help.camera": "Apply full blur when you step away",
    "settings.blurWhenAway.help.airpods": "Apply full blur when you step away. Only available when using camera for detection.",
    "settings.pauseOnTheGo": "Pause on the go",
    "settings.pauseOnTheGo.help": "Auto-pause on laptop-only display",
    "settings.pauseOnBattery": "Pause on battery",
    "settings.pauseOnBattery.help": "Auto-pause to save power when on battery",
    "settings.pauseOnBattery.help.desktop": "Only available on Mac laptops",
    "settings.fullScreenOverlay": "Full screen overlay",
    "settings.fullScreenOverlay.help": "Extend effects over the dock and menu bar",
    "settings.shortcut": "Shortcut",
    "settings.shortcut.help": "Global keyboard shortcut to toggle PostureAI. Click the field and press your desired key combination.",
    "settings.shortcut.press": "Press...",
    "settings.language": "Language",
    "settings.language.system": "(System)",
    "settings.language.restartTitle": "Restart Required",
    "settings.language.restartMessage": "Changing the language will restart PostureAI to apply the new language. Continue?",
    "settings.language.restartConfirm": "Restart",
    "settings.permissions.title": "Permissions",
    "settings.permissions.camera": "Camera",
    "settings.permissions.bluetooth": "Bluetooth",
    "settings.permissions.notifications": "Notifications",
    "settings.permissions.focus": "Focus",
    "settings.permissions.allowed": "Allowed",
    "settings.permissions.denied": "Denied",
    "settings.permissions.restricted": "Restricted",
    "settings.permissions.notDetermined": "Not Requested",
    "settings.permissions.revoke": "Revoke",
    "settings.permissions.manage": "Manage",
    "settings.compatibilityMode": "Compatibility mode",
    "settings.compatibilityMode.help": "Enable if blur isn't appearing",
    "settings.viewOnGitHub": "View on GitHub",
    "settings.joinDiscord": "Join Discord",
    "settings.deadZone.strict": "Strict",
    "settings.deadZone.tight": "Tight",
    "settings.deadZone.medium": "Medium",
    "settings.deadZone.relaxed": "Relaxed",
    "settings.deadZone.loose": "Loose",
    "settings.intensity.gentle": "Gentle",
    "settings.intensity.easy": "Easy",
    "settings.intensity.medium": "Medium",
    "settings.intensity.firm": "Firm",
    "settings.intensity.aggressive": "Aggressive",
    "settings.section.tracking": "Monitoring",
    "settings.section.general": "General Preferences",
    "settings.section.calibration": "Calibration & Alerts",
    "settings.section.privacy": "Tracking & Privacy",
    "settings.section.reminders": "Reminders & Auto-Pause",

    "settings.tab.general": "General",
    "settings.tab.tracking": "Tracking",
    "settings.tab.response": "Response",
    "settings.tab.behavior": "Behavior",
    "settings.tab.autoPause": "Auto Pause",
    "settings.tab.reminders": "Reminders",
    "settings.resetAll": "Reset All Settings",
    "settings.resetAll.confirmTitle": "Reset All Settings?",
    "settings.resetAll.confirm": "This will erase all PostureAI settings and restore the app to its original state.",
    "settings.resetAll.confirmButton": "Reset",
    "settings.airpodsReady": "AirPods active — ready",
    "settings.airpodsNotConnected": "AirPods not connected",
    "settings.warningColor": "Warning Color",
    "settings.noCameras.title": "No cameras",
    "settings.source.camera": "Camera",
    "settings.source.airpods": "AirPods",
    "settings.preferredTag": "Preferred",
    "settings.activeTag": "Active",
    "settings.calibrate": "Calibrate",
    "settings.done": "Done",
    "settings.brightness": "Brightness",
    "settings.versionShort": "v%@",
    "settings.privacy.note": "Posture analysis happens on-device. Camera frames are processed locally and never leave your Mac.",
    "settings.delay.stepper": "Trigger alert after %d seconds of slouching",
    "settings.version": "Version %@ (Build %@)",

    // Analytics
    "analytics.title": "Analytics",
    "analytics.header": "PostureAI Analytics",
    "analytics.tagline": "SIT BETTER · WORK SMARTER",
    "analytics.todayScore": "Today's Score",
    "analytics.monitoringTime": "Monitoring Time",
    "analytics.slouchDuration": "Slouch Duration",
    "analytics.slouchEvents": "Slouch Events",
    "analytics.last7Days": "Last 7 Days",
    "analytics.currentStreak": "Current Streak",
    "analytics.days": "Days",
    "analytics.bestHour": "Best Hour Today",
    "analytics.worstHour": "Worst Hour Today",
    "analytics.insufficientData": "Not enough data collected yet to display analytics. Keep using PostureAI!",

    // Onboarding
    "onboarding.title": "Welcome to PostureAI",
    "onboarding.subtitle": "Choose how you want to track your posture",
    "onboarding.selectCamera": "Select Camera",
    "onboarding.pairedAirPods": "Paired AirPods",
    "onboarding.unavailable": "Unavailable",
    "onboarding.continue": "Continue",

    // Dashboard
    "dashboard.title": "PostureAI",
    "dashboard.status.paused": "Monitoring Paused",
    "dashboard.status.slouching": "Slouching Detected",
    "dashboard.status.good": "Good Posture",
    "dashboard.live.off": "OFF",
    "dashboard.live.on": "LIVE",
    "dashboard.inputSource": "Input Source",
    "dashboard.camera": "Camera",
    "dashboard.airpods": "AirPods",
    "dashboard.sensitivityTolerance": "Sensitivity & Tolerance",
    "dashboard.slouchSensitivity": "Slouch Sensitivity",
    "dashboard.deadZoneTolerance": "Dead Zone Tolerance",
    "dashboard.recalibrate": "Recalibrate Sitting Posture",

    "settings.status.disconnected": "Disconnected",
    "settings.status.needsCalibration": "Needs calibration",
    "settings.status.ready": "Ready",

    // Alerts
    "alert.section": "Alerts",
    "alert.showAlert": "Show notification",
    "alert.showAlert.help": "Show a notification when slouching is detected",
    "alert.spatialSoundSection": "Spatial Sound",
    "alert.spatialSound": "Sound alert",
    "alert.spatialSound.help": "Play a tone when you slouch",
    "alert.sound.off": "Off",
    "alert.sound.on": "On",
    "alert.sound.airpodsOnly": "AirPods only",
    "alert.sound.alwaysOn": "Always On",
    "alert.sound.autoAirPods": "Automatically when connected to AirPods",
    "alert.slouch.title": "Posture Alert",
    "alert.slouch.body": "Slouching detected. Sit up straight.",
    "alert.voiceAnnouncement": "Voice reminder",
    "alert.voiceAnnouncement.help": "Speak \"Sit up straight\" after 5 seconds of slouching (instead of the tone)",
    "alert.voiceAnnouncement.help.off": "Turn sound on to use the voice reminder",
    "alert.voiceAnnouncement.help.airpods": "Speak \"Sit up straight\" after 5 seconds of slouching — AirPods output only",
    "voice.sitUpStraight": "Sit up straight",

    // Screen Break Reminder
    "breakReminder.section": "Screen Break Reminder",
    "breakReminder.enabled": "Screen break (20/20/20)",
    "breakReminder.enabled.help": "Every 20 minutes, blurs the screen for 20 seconds so you look 20 feet away",
    "breakReminder.interval": "Work interval",
    "breakReminder.interval.minutes": "%d min",
    "breakReminder.startNow": "Start Screen Break Now",
    "breakReminder.start": "Start Screen Break",
    "breakReminder.duration": "Break length",
    "breakReminder.duration.seconds": "%d sec",
    "breakReminder.startIn": "Start in",
    "breakReminder.now": "Now",
    "screenBreak.title": "Look 20 feet away",
    "screenBreak.caption": "Blink a few times and relax your shoulders",

    // Daily Start Reminder
    "reminder.section": "Start Monitoring",
    "reminder.daily": "Daily start reminder",
    "reminder.daily.help": "Prompt to start monitoring when tracking isn't running",
    "reminder.startMonitoring.title": "PostureAI isn't monitoring",
    "reminder.startMonitoring.body": "Start monitoring?",

    // Auto-Pause
    "autoPause.section": "Auto-Pause",
    "autoPause.meeting": "Pause during meetings",
    "autoPause.meeting.help": "Auto-pause when a video call is active (Zoom, Teams, FaceTime, etc.) to avoid screen blurs",
    "autoPause.focus": "Pause during Focus",
    "autoPause.focus.help": "Pauses whenever a Focus mode is active. macOS only shows apps whether Focus is on, not which mode.",
        "autoPause.focus.modes": "Focus modes to pause during",

    // Dual Sensor Fusion
    "fusion.enabled": "Dual sensor fusion",
    "fusion.enabled.help": "Combine AirPods tilt and camera positioning simultaneously for better accuracy",
    "fusion.disabledNote": "Camera and AirPods are locked while fusion is on",

    // Single AirPod (auto-detected)
    "singleBud.badge": "Single bud — lower accuracy",

    // About
    "about.windowTitle": "About PostureAI",
    "about.title": "PostureAI",
    "about.tagline": "SIT BETTER · WORK SMARTER",
    "about.version": "Version %@ (Build %@)",
    "about.github": "GitHub",
    "about.license": "License",
    "about.privacy": "Privacy Policy",
    "about.copyright": "© 2026 PostureAI. All rights reserved.",

    // Common
    "common.cancel": "Cancel"
]

// MARK: - In-App Language Selection

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system = ""
    case english = "en"
    case german = "de"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case spanish = "es"
    case french = "fr"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .system: return L("settings.language.system")
        case .english: return "English"
        case .german: return "Deutsch"
        case .traditionalChinese: return "繁體中文"
        case .japanese: return "日本語"
        case .spanish: return "Español"
        case .french: return "Français"
        }
    }
}

private let appLanguageKey = "appLanguage"

public func currentAppLanguage() -> AppLanguage {
    guard let raw = UserDefaults.standard.string(forKey: appLanguageKey),
          let lang = AppLanguage(rawValue: raw) else { return .system }
    return lang
}

public func setAppLanguage(_ language: AppLanguage) {
    UserDefaults.standard.set(language.rawValue, forKey: appLanguageKey)
}

public func L(_ key: String) -> String {
    // In-app language selection overrides the system language.
    let language = currentAppLanguage()
    if language != .system,
       let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        let customVal = bundle.localizedString(forKey: key, value: nil, table: nil)
        if customVal != key { return customVal }
    }

    let mainVal = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    if mainVal != key { return mainVal }

    let classVal = Bundle(for: LocalizationToken.self).localizedString(forKey: key, value: nil, table: nil)
    if classVal != key { return classVal }

    if let fallback = fallbackStrings[key] {
        return fallback
    }

    #if SWIFT_PACKAGE
    let moduleVal = NSLocalizedString(key, bundle: .module, comment: "")
    if moduleVal != key { return moduleVal }
    #endif

    return key
}

public func L(_ key: String, _ args: CVarArg...) -> String {
    let format = L(key)
    return String(format: format, locale: Locale.current, arguments: args)
}
