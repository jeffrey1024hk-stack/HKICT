import Foundation

<<<<<<< HEAD
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

    // AirPods Detector
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
    "settings.showInDock": "Show in dock",
    "settings.showInDock.help": "Keep PostureAI in Dock and Cmd+Tab",
    "settings.blurWhenAway": "Blur when away",
    "settings.blurWhenAway.help.camera": "Apply full blur when you step away",
    "settings.blurWhenAway.help.airpods": "Apply full blur when you step away. Only available when using camera for detection.",
    "settings.pauseOnTheGo": "Pause on the go",
    "settings.pauseOnTheGo.help": "Auto-pause on laptop-only display",
    "settings.pauseOnBattery": "Pause on battery",
    "settings.pauseOnBattery.help": "Auto-pause to save power when on battery",
    "settings.fullScreenOverlay": "Full screen overlay",
    "settings.fullScreenOverlay.help": "Extend effects over the dock and menu bar",
    "settings.shortcut": "Shortcut",
    "settings.shortcut.help": "Global keyboard shortcut to toggle PostureAI. Click the field and press your desired key combination.",
    "settings.shortcut.press": "Press...",
    "settings.compatibilityMode": "Compatibility mode",
    "settings.compatibilityMode.help": "Enable if blur isn't appearing",
    "settings.viewOnGitHub": "View on GitHub",
    "settings.joinDiscord": "Join Discord",

    // Settings Sliders
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

    // Analytics
    "analytics.title": "Analytics",
    "analytics.header": "Posture Analytics",
    "analytics.tagline": "Track your habits and improvement over time",
    "analytics.todayScore": "Today's Score",
    "analytics.monitoringTime": "Monitoring Time",
    "analytics.slouchDuration": "Slouch Duration",
    "analytics.slouchEvents": "Slouch Events",
    "analytics.last7Days": "Last 7 Days",
    "analytics.currentStreak": "Current Streak",
    "analytics.days": "Days",
    "analytics.bestHour": "Best Hour Today",
    "analytics.worstHour": "Worst Hour Today",

    // Onboarding
    "onboarding.title": "Welcome to PostureAI",
    "onboarding.subtitle": "Choose how you want to track your posture",
    "onboarding.selectCamera": "Select Camera",
    "onboarding.pairedAirPods": "Paired AirPods",
    "onboarding.unavailable": "Unavailable",
    "onboarding.continue": "Continue",

    // Analytics Fallbacks
        "analytics.insufficientData": "Not enough data collected yet to display analytics. Keep using PostureAI!",

        // Dashboard Localizations
        "dashboard.title": "PostureAI",
        "dashboard.status.paused": "Monitoring Paused",
        "dashboard.status.slouching": "Slouching Detected",
        "dashboard.status.good": "Good Posture",
        "dashboard.live.off": "OFF",
        "dashboard.live.on": "LIVE",
        "dashboard.inputSource": "INPUT SOURCE",
        "dashboard.camera": "Camera",
        "dashboard.airpods": "AirPods",
        "dashboard.sensitivityTolerance": "SENSITIVITY & TOLERANCE",
        "dashboard.slouchSensitivity": "Slouch Sensitivity",
        "dashboard.deadZoneTolerance": "Dead Zone Tolerance",
        "dashboard.recalibrate": "Recalibrate Sitting Posture",
    // Common
    "common.cancel": "Cancel"
]

public func L(_ key: String) -> String {
    // 1. Try standard system bundles
    let mainVal = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    if mainVal != key { return mainVal }

    let classVal = Bundle(for: LocalizationToken.self).localizedString(forKey: key, value: nil, table: nil)
    if classVal != key { return classVal }

    // 2. Hardcoded English fallback dictionary
    if let fallback = fallbackStrings[key] {
        return fallback
    }

    // 3. Last-resort key string
    return key
=======
private var localizationBundle: Bundle {
    // In an app bundle, .lproj files live in Contents/Resources/ (Bundle.main).
    // SwiftPM's Bundle.module only works when the .build directory exists (dev/test).
    if Bundle.main.bundlePath.hasSuffix(".app") {
        return Bundle.main
    }
    return Bundle.module
}

private func localizedString(_ key: String) -> String {
    let value = NSLocalizedString(key, bundle: localizationBundle, comment: "")
    #if DEBUG
    if value == key {
        NSLog("Missing localization for key: %@", key)
    }
    #endif
    return value
}

public func L(_ key: String) -> String {
    localizedString(key)
>>>>>>> parent of 20dfe83 (Fix localization lookup, build script signing, and DMG creation)
}

public func L(_ key: String, _ args: CVarArg...) -> String {
    let format = localizedString(key)
    return String(format: format, locale: Locale.current, arguments: args)
}
