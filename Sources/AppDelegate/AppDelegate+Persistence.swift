import AppKit
import Foundation
import ServiceManagement

extension AppDelegate {
    // MARK: - Global Keyboard Shortcut

    func updateGlobalKeyMonitor() {
        hotkeyManager.isEnabled = toggleShortcutEnabled
        hotkeyManager.shortcut = toggleShortcut
        menuBarManager.updateShortcut(enabled: toggleShortcutEnabled, shortcut: toggleShortcut)
    }

    // MARK: - Persistence

    func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(useCompatibilityMode, forKey: SettingsKeys.useCompatibilityMode)
        defaults.set(appAppearance.rawValue, forKey: SettingsKeys.appAppearance)
        defaults.set(blurWhenAway, forKey: SettingsKeys.blurWhenAway)
        defaults.set(pauseOnTheGo, forKey: SettingsKeys.pauseOnTheGo)
        defaults.set(pauseOnBattery, forKey: SettingsKeys.pauseOnBattery)
        defaults.set(useFullScreenOverlay, forKey: SettingsKeys.useFullScreenOverlay)
        defaults.set(toggleShortcutEnabled, forKey: SettingsKeys.toggleShortcutEnabled)
        defaults.set(SMAppService.mainApp.status == .enabled, forKey: SettingsKeys.launchAtLogin)
        defaults.set(postureAlertManager.showAlertEnabled, forKey: SettingsKeys.showAlert)
        defaults.set(postureAlertManager.soundMode.rawValue, forKey: SettingsKeys.alertSoundMode)
        defaults.set(postureAlertManager.voiceAnnouncementEnabled, forKey: SettingsKeys.voiceAnnouncementEnabled)
        defaults.set(breakReminderEnabled, forKey: SettingsKeys.breakReminderEnabled)
        defaults.set(breakReminderInterval, forKey: SettingsKeys.breakReminderInterval)
        defaults.set(dailyReminderEnabled, forKey: SettingsKeys.dailyReminderEnabled)
        defaults.set(focusPauseModes, forKey: SettingsKeys.focusPauseModes)
        defaults.set(meetingPauseEnabled, forKey: SettingsKeys.meetingPauseEnabled)
        defaults.set(focusPauseEnabled, forKey: SettingsKeys.focusPauseEnabled)
        defaults.set(dualSensorEnabled, forKey: SettingsKeys.dualSensorEnabled)
        if let cameraID = selectedCameraID {
            defaults.set(cameraID, forKey: SettingsKeys.lastCameraID)
        }
        defaults.set(trackingSource.rawValue, forKey: SettingsKeys.trackingSource)
        defaults.set(trackingStore.withState { $0.trackingMode.rawValue }, forKey: SettingsKeys.trackingMode)
        defaults.set(trackingStore.withState { $0.preferredSource.rawValue }, forKey: SettingsKeys.preferredSource)
        defaults.set(trackingStore.withState { $0.autoReturnEnabled }, forKey: SettingsKeys.autoReturnEnabled)
        if let airPodsCalibration = airPodsCalibration,
           let data = try? JSONEncoder().encode(airPodsCalibration) {
            defaults.set(data, forKey: SettingsKeys.airPodsCalibration)
        }
    }

    func loadSettings() {
        let defaults = UserDefaults.standard
        SettingsMigrations.migrateLegacyKeysIfNeeded(userDefaults: defaults)
        settingsProfileManager.loadProfiles()
        applyActiveSettingsProfile()

        // First-run defaults: everything on except pause-on-battery.
        defaults.register(defaults: [
            SettingsKeys.launchAtLogin: true,
            SettingsKeys.blurWhenAway: true,
            SettingsKeys.useFullScreenOverlay: true,
            SettingsKeys.toggleShortcutEnabled: true,
            SettingsKeys.showAlert: true,
            SettingsKeys.alertSoundMode: AlertSoundMode.on.rawValue,
            SettingsKeys.voiceAnnouncementEnabled: true,
            SettingsKeys.breakReminderEnabled: true,
            SettingsKeys.breakReminderInterval: 20.0,
            SettingsKeys.dailyReminderEnabled: true,
            SettingsKeys.meetingPauseEnabled: true,
            SettingsKeys.focusPauseEnabled: true,
            SettingsKeys.dualSensorEnabled: false
        ])

        // Keep the login item in sync with the persisted preference (default on).
        let shouldLaunchAtLogin = defaults.object(forKey: SettingsKeys.launchAtLogin) as? Bool ?? true
        if shouldLaunchAtLogin {
            if SMAppService.mainApp.status != .enabled {
                try? SMAppService.mainApp.register()
            }
        } else if SMAppService.mainApp.status == .enabled {
            try? SMAppService.mainApp.unregister()
        }

        useCompatibilityMode = defaults.bool(forKey: SettingsKeys.useCompatibilityMode)
        if let appearanceString = defaults.string(forKey: SettingsKeys.appAppearance),
           let appearance = AppAppearance(rawValue: appearanceString) {
            appAppearance = appearance
        }
        blurWhenAway = defaults.bool(forKey: SettingsKeys.blurWhenAway)
        pauseOnTheGo = defaults.bool(forKey: SettingsKeys.pauseOnTheGo)
        if defaults.object(forKey: SettingsKeys.pauseOnBattery) != nil {
            applyTrackingAction(.setPauseOnBatteryEnabled(defaults.bool(forKey: SettingsKeys.pauseOnBattery)))
        }
        useFullScreenOverlay = true
        cameraDetector.selectedCameraID = defaults.string(forKey: SettingsKeys.lastCameraID)
        if let sourceString = defaults.string(forKey: SettingsKeys.trackingSource),
           let source = TrackingSource(rawValue: sourceString) {
            trackingSource = source
        }
        if let modeString = defaults.string(forKey: SettingsKeys.trackingMode),
           let mode = TrackingMode(rawValue: modeString) {
            applyTrackingAction(.setTrackingMode(mode))
        }
        if let prefString = defaults.string(forKey: SettingsKeys.preferredSource),
           let pref = TrackingSource(rawValue: prefString) {
            applyTrackingAction(.setPreferredSource(pref))
        }
        if defaults.object(forKey: SettingsKeys.autoReturnEnabled) != nil {
            applyTrackingAction(.setAutoReturnEnabled(defaults.bool(forKey: SettingsKeys.autoReturnEnabled)))
        }
        if let data = defaults.data(forKey: SettingsKeys.airPodsCalibration),
           let calibration = try? JSONDecoder().decode(AirPodsCalibrationData.self, from: data) {
            airPodsCalibration = calibration
        }
        if defaults.object(forKey: SettingsKeys.toggleShortcutEnabled) != nil {
            toggleShortcutEnabled = defaults.bool(forKey: SettingsKeys.toggleShortcutEnabled)
        }
        // Shortcut is fixed to Ctrl+Option+P; the user cannot change it.
        toggleShortcut = .defaultShortcut

        postureAlertManager.showAlertEnabled = defaults.object(forKey: SettingsKeys.showAlert) as? Bool ?? true
        if let modeRaw = defaults.string(forKey: SettingsKeys.alertSoundMode),
           let mode = AlertSoundMode(rawValue: modeRaw) {
            postureAlertManager.soundMode = mode
        }
        postureAlertManager.voiceAnnouncementEnabled = defaults.object(forKey: SettingsKeys.voiceAnnouncementEnabled) as? Bool ?? true
        breakReminderEnabled = defaults.bool(forKey: SettingsKeys.breakReminderEnabled)
        breakReminderInterval = defaults.double(forKey: SettingsKeys.breakReminderInterval)
        if breakReminderInterval < 1 { breakReminderInterval = 20 }
        dailyReminderEnabled = defaults.bool(forKey: SettingsKeys.dailyReminderEnabled)
        if let savedModes = defaults.stringArray(forKey: SettingsKeys.focusPauseModes) {
            focusPauseModes = savedModes
        } else {
            focusPauseModes = FocusModeReader.configuredModes().map { $0.identifier }
        }
        if defaults.object(forKey: SettingsKeys.meetingPauseEnabled) != nil {
            applyTrackingAction(.setMeetingPauseEnabled(defaults.bool(forKey: SettingsKeys.meetingPauseEnabled)))
        }
        if defaults.object(forKey: SettingsKeys.focusPauseEnabled) != nil {
            applyTrackingAction(.setFocusPauseEnabled(defaults.bool(forKey: SettingsKeys.focusPauseEnabled)))
        }
        if defaults.object(forKey: SettingsKeys.dualSensorEnabled) != nil {
            applyTrackingAction(.setDualSensorEnabled(defaults.bool(forKey: SettingsKeys.dualSensorEnabled)))
        }
    }

    func saveProfile(forKey key: String, data: ProfileData) {
        let defaults = UserDefaults.standard
        var profiles = defaults.dictionary(forKey: SettingsKeys.profiles) as? [String: Data] ?? [:]

        if let encoded = try? JSONEncoder().encode(data) {
            profiles[key] = encoded
            defaults.set(profiles, forKey: SettingsKeys.profiles)
        }
    }

    func loadProfile(forKey key: String) -> ProfileData? {
        let defaults = UserDefaults.standard
        guard let profiles = defaults.dictionary(forKey: SettingsKeys.profiles) as? [String: Data],
              let data = profiles[key] else {
            return nil
        }

        return try? JSONDecoder().decode(ProfileData.self, from: data)
    }
}
