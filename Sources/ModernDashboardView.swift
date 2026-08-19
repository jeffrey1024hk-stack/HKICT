import SwiftUI
import AppKit
import ServiceManagement

// MARK: - Content Height Preference

struct DashboardContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

extension Notification.Name {
    /// Posted by `AppDelegate.syncUIToState()` whenever the tracking UI state
    /// changes (enabled state, slouching, active source, profile settings).
    static let postureUIStateChanged = Notification.Name("PostureUIStateChanged")
}

// MARK: - Dashboard Sections

enum DashboardSection: String, CaseIterable, Identifiable {
    case general
    case tracking
    case response
    case behavior
    case autoPause
    case reminders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return L("settings.tab.general")
        case .tracking: return L("settings.tab.tracking")
        case .response: return L("settings.tab.response")
        case .behavior: return L("settings.tab.behavior")
        case .autoPause: return L("settings.tab.autoPause")
        case .reminders: return L("settings.tab.reminders")
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .tracking: return "scope"
        case .response: return "slider.horizontal.3"
        case .behavior: return "switch.2"
        case .autoPause: return "pause.circle"
        case .reminders: return "timer"
        }
    }
}

@MainActor
struct ModernDashboardView: View {
    let appDelegate: AppDelegate

    private let contentWidth: CGFloat = 440

    @State private var measuredContentHeight: CGFloat = 0

    // Live status
    @State private var intensity: Double
    @State private var deadZone: Double
    @State private var isActive: Bool = false
    @State private var isSlouching: Bool = false
    @State private var activeSource: TrackingSource = .camera

    @State private var selectedSection: DashboardSection = .general

    // Tracking
    @State private var selectedCameraID: String
    @State private var availableCameras: [(id: String, name: String)] = []
    @State private var airPodsAvailable: Bool = false
    @State private var airPodsConnected: Bool = false
    @State private var cameraCalibrated: Bool = false
    @State private var airPodsCalibrated: Bool = false
    @State private var dualSensor: Bool

    // Response
    @State private var warningMode: WarningMode
    @State private var warningOnsetDelay: Double
    @State private var detectionModeSlider: Double
    @State private var intensitySlider: Double
    @State private var deadZoneSlider: Double
    @State private var showAlert: Bool
    @State private var soundMode: AlertSoundMode
    @State private var soundAlertEnabled: Bool
    @State private var voiceAnnouncement: Bool

    // General & Behavior
    @State private var appAppearance: AppAppearance
    @State private var launchAtLogin: Bool
    @State private var selectedLanguage: AppLanguage
    @State private var confirmedLanguage: AppLanguage
    @State private var pauseOnBattery: Bool
    @State private var blurWhenAway: Bool
    @State private var toggleShortcutEnabled: Bool

    // Reminders
    @State private var breakReminderEnabled: Bool
    @State private var breakIntervalMinutes: Double
    @State private var breakDurationSeconds: Double = 20
    @State private var breakStartInMinutes: Double = 0
    @State private var dailyReminderEnabled: Bool
    @State private var meetingPauseEnabled: Bool
    @State private var focusPauseEnabled: Bool
    @State private var focusModes: [FocusModeInfo] = []
    @State private var selectedFocusModeIDs: Set<String> = []

    let detectionModes: [DetectionMode] = [.responsive, .balanced, .performance]

    let intensityValues: [Double] = [0.08, 0.15, 0.35, 0.65, 1.2]
    var intensityLabels: [String] { [L("settings.intensity.gentle"), L("settings.intensity.easy"), L("settings.intensity.medium"), L("settings.intensity.firm"), L("settings.intensity.aggressive")] }

    let deadZoneValues: [Double] = [0.0, 0.08, 0.15, 0.25, 0.40]
    var deadZoneLabels: [String] { [L("settings.deadZone.strict"), L("settings.deadZone.tight"), L("settings.deadZone.medium"), L("settings.deadZone.relaxed"), L("settings.deadZone.loose")] }

    let breakIntervalOptions: [Double] = [15, 20, 30, 45, 60]
    let breakDurationOptions: [Double] = [10, 20, 30, 60]
    let breakStartInOptions: [Double] = [0, 5, 10, 15, 30]

    /// Helper function to find closest index in an array of values
    static func closestIndex(for value: Double, in array: [Double]) -> Int {
        guard !array.isEmpty else { return 0 }
        var closestIdx = 0
        var minDiff = Double.greatestFiniteMagnitude
        for (index, item) in array.enumerated() {
            let diff = abs(item - value)
            if diff < minDiff {
                minDiff = diff
                closestIdx = index
            }
        }
        return closestIdx
    }

    private static func normalizedWarningMode(_ mode: WarningMode) -> WarningMode {
        (mode == .blur || mode == .border) ? mode : .blur
    }

    /// The language actually in use by macOS, mapped to one of our supported
    /// languages (falls back to English).
    private var resolvedSystemLanguage: AppLanguage {
        for localization in Bundle.main.preferredLocalizations {
            if let lang = AppLanguage(rawValue: localization), lang != .system {
                return lang
            }
        }
        return .english
    }

    /// The language the app is effectively displayed in.
    private var effectiveLanguage: AppLanguage {
        let current = currentAppLanguage()
        return current == .system ? resolvedSystemLanguage : current
    }

    /// Label shown in the language picker. When the selected language is the
    /// one used by the macOS system, append "(System)".
    private func languageOptionLabel(_ lang: AppLanguage) -> String {
        if lang == resolvedSystemLanguage && currentAppLanguage() == .system {
            return lang.displayName + " " + L("settings.language.system")
        }
        return lang.displayName
    }

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        _intensity = State(initialValue: Double(appDelegate.activeIntensity))
        _deadZone = State(initialValue: Double(appDelegate.activeDeadZone))

        let cameras = appDelegate.cameraDetector.getAvailableCameras()
        let cameraList = cameras.map { (id: $0.uniqueID, name: $0.localizedName) }

        _selectedCameraID = State(initialValue: appDelegate.selectedCameraID ?? cameras.first?.uniqueID ?? "")
        _availableCameras = State(initialValue: cameraList)
        _airPodsAvailable = State(initialValue: appDelegate.airPodsDetector.isAvailable)
        _airPodsConnected = State(initialValue: appDelegate.airPodsDetector.isBluetoothConnected)
        _cameraCalibrated = State(initialValue: appDelegate.cameraCalibration?.isValid ?? false)
        _airPodsCalibrated = State(initialValue: appDelegate.airPodsCalibration?.isValid ?? false)
        _dualSensor = State(initialValue: appDelegate.dualSensorEnabled)

        let profileIntensity = appDelegate.activeIntensity
        let profileDeadZone = appDelegate.activeDeadZone
        let profileWarningMode = appDelegate.activeWarningMode
        let profileWarningOnsetDelay = appDelegate.activeWarningOnsetDelay
        let profileDetectionMode = appDelegate.activeDetectionMode

        _intensitySlider = State(initialValue: Double(Self.closestIndex(for: Double(profileIntensity), in: intensityValues)))
        _deadZoneSlider = State(initialValue: Double(Self.closestIndex(for: Double(profileDeadZone), in: deadZoneValues)))
        _warningMode = State(initialValue: Self.normalizedWarningMode(profileWarningMode))
        _warningOnsetDelay = State(initialValue: profileWarningOnsetDelay)
        _detectionModeSlider = State(initialValue: Double(detectionModes.firstIndex(of: profileDetectionMode) ?? 0))
        _showAlert = State(initialValue: appDelegate.postureAlertManager.showAlertEnabled)
        let initialSoundMode = appDelegate.postureAlertManager.soundMode
        _soundMode = State(initialValue: initialSoundMode == .off ? .on : initialSoundMode)
        _soundAlertEnabled = State(initialValue: initialSoundMode != .off)
        _voiceAnnouncement = State(initialValue: appDelegate.postureAlertManager.voiceAnnouncementEnabled)

        _appAppearance = State(initialValue: appDelegate.appAppearance)
        _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
        _selectedLanguage = State(initialValue: currentAppLanguage() == .system
            ? AppLanguage(rawValue: Bundle.main.preferredLocalizations.first(where: { AppLanguage(rawValue: $0) != nil && AppLanguage(rawValue: $0) != .system }) ?? "en") ?? .english
            : currentAppLanguage())
        _confirmedLanguage = State(initialValue: currentAppLanguage() == .system
            ? AppLanguage(rawValue: Bundle.main.preferredLocalizations.first(where: { AppLanguage(rawValue: $0) != nil && AppLanguage(rawValue: $0) != .system }) ?? "en") ?? .english
            : currentAppLanguage())
        _pauseOnBattery = State(initialValue: appDelegate.pauseOnBattery && appDelegate.hasBattery)
        _blurWhenAway = State(initialValue: appDelegate.blurWhenAway)
        _toggleShortcutEnabled = State(initialValue: appDelegate.toggleShortcutEnabled)

        _breakReminderEnabled = State(initialValue: appDelegate.breakReminderEnabled)
        _breakIntervalMinutes = State(initialValue: appDelegate.breakReminderInterval)
        _dailyReminderEnabled = State(initialValue: appDelegate.dailyReminderEnabled)
        _meetingPauseEnabled = State(initialValue: appDelegate.meetingPauseEnabled)
        _focusPauseEnabled = State(initialValue: appDelegate.focusPauseEnabled)
        _focusModes = State(initialValue: FocusModeReader.configuredModes())
        _selectedFocusModeIDs = State(initialValue: Set(appDelegate.focusPauseModes))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                headerCard
                tabBar
                sectionCard.id(selectedSection)

                footer
                    .padding(.top, 10)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .frame(width: contentWidth)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: DashboardContentHeightKey.self, value: geo.size.height)
                }
            )
        }
        .frame(width: contentWidth + 40)
        .onPreferenceChange(DashboardContentHeightKey.self) { value in
            guard value > 120 else { return }
            measuredContentHeight = value
        }
        .onChange(of: measuredContentHeight) { _ in postHeight() }
        // Listen for live posture state changes
        .onReceive(NotificationCenter.default.publisher(for: .postureUIStateChanged)) { _ in
            refreshState()
        }
        .onAppear {
            refreshState()
            postHeight()
        }
    }

    private func postHeight() {
        appDelegate.fitDashboardWindow(toContentHeight: measuredContentHeight)
    }

    // MARK: - Header (always on top)

    private var headerCard: some View {
        NotabilityCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("dashboard.title"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))

                    Text(isActive ? (isSlouching ? L("dashboard.status.slouching") : L("dashboard.status.good")) : L("dashboard.status.paused"))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(statusColor)
                }

                Spacer()

                // Live Pill Indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)

                    Text(isActive ? L("dashboard.live.on") : L("dashboard.live.off"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())

                // Main Toggle Switch
                Toggle("", isOn: Binding(
                    get: { isActive },
                    set: { newValue in
                        guard newValue != appDelegate.state.isActive else { return }
                        Task { @MainActor in
                            await appDelegate.toggleEnabled()
                        }
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
        }
    }

    // MARK: - Section Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(DashboardSection.allCases) { section in
                Button(action: { selectedSection = section }) {
                    VStack(spacing: 3) {
                        Image(systemName: section.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(section.title)
                            .font(.system(size: 10, weight: selectedSection == section ? .semibold : .regular, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundColor(selectedSection == section ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(selectedSection == section ? NotabilityTheme.accentBlue : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .glassEffect(in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
    }

    // MARK: - Section Content

    @ViewBuilder
    private var sectionCard: some View {
        switch selectedSection {
        case .general: generalCard
        case .tracking: trackingCard
        case .response: responseCard
        case .behavior: behaviorCard
        case .autoPause: autoPauseCard
        case .reminders: remindersCard
        }
    }

    // General: appearance + launch at login
    private var generalCard: some View {
        NotabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(L("settings.language"))
                        .font(.system(size: 11))
                        .frame(width: 82, alignment: .leading)
                    Spacer()
                    Picker("", selection: $selectedLanguage) {
                        ForEach(AppLanguage.allCases.filter { $0 != .system }) { lang in
                            Text(languageOptionLabel(lang)).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 180, alignment: .trailing)
                    .onChange(of: selectedLanguage) { newValue in
                        guard newValue != confirmedLanguage else { return }
                        let alert = NSAlert()
                        alert.messageText = L("settings.language.restartTitle")
                        alert.informativeText = L("settings.language.restartMessage")
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: L("settings.language.restartConfirm"))
                        alert.addButton(withTitle: L("common.cancel"))
                        if alert.runModal() == .alertFirstButtonReturn {
                            confirmedLanguage = newValue
                            setAppLanguage(newValue)
                            appDelegate.relaunchApp()
                        } else {
                            selectedLanguage = confirmedLanguage
                        }
                    }
                }
                .frame(height: 26)

                HStack(spacing: 8) {
                    Text(L("settings.appearance"))
                        .font(.system(size: 11))
                    Spacer()
                    CompactSegmentedPicker(
                        selection: Binding(
                            get: { appAppearance },
                            set: { newValue in
                                appDelegate.appAppearance = newValue
                                appDelegate.saveSettings()
                                appDelegate.applyAppearance()
                                appAppearance = newValue
                            }
                        ),
                        options: AppAppearance.allCases.map { ($0, $0.displayName) }
                    )
                    .frame(width: 170)
                }
                .frame(height: 26)

                CompactToggle(
                    title: L("settings.launchAtLogin"),
                    helpText: L("settings.launchAtLogin.help"),
                    isOn: $launchAtLogin
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: launchAtLogin) { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }

                SubtleDivider()

                Button(action: {
                    let alert = NSAlert()
                    alert.messageText = L("settings.resetAll.confirmTitle")
                    alert.informativeText = L("settings.resetAll.confirm")
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: L("settings.resetAll.confirmButton"))
                    alert.addButton(withTitle: L("common.cancel"))
                    if alert.runModal() == .alertFirstButtonReturn {
                        let domain = Bundle.main.bundleIdentifier ?? "chill..PostureAI"
                        UserDefaults.standard.removePersistentDomain(forName: domain)
                        UserDefaults.standard.synchronize()
                        appDelegate.relaunchApp()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text(L("settings.resetAll"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(NotabilityTheme.dangerRed)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // Tracking: source, device status, dual-sensor fusion, recalibrate
    private var trackingCard: some View {
        NotabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(L("dashboard.inputSource"))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    MethodButton(
                        title: L("dashboard.camera"),
                        icon: "camera.fill",
                        isSelected: activeSource == .camera
                    ) {
                        guard activeSource != .camera else { return }
                        Task { @MainActor in
                            await appDelegate.switchTrackingSource(to: .camera)
                        }
                    }
                    .disabled(dualSensor)
                    .opacity(dualSensor ? 0.45 : 1)

                    MethodButton(
                        title: L("dashboard.airpods"),
                        icon: "airpodspro",
                        isSelected: activeSource == .airpods
                    ) {
                        guard activeSource != .airpods else { return }
                        Task { @MainActor in
                            await appDelegate.switchTrackingSource(to: .airpods)
                        }
                    }
                    .disabled(dualSensor)
                    .opacity(dualSensor ? 0.45 : 1)
                }

                DeviceStatusRow(
                    source: activeSource,
                    isCalibrated: activeSource == .camera ? cameraCalibrated : airPodsCalibrated,
                    isConnected: activeSource == .camera ? !availableCameras.isEmpty : airPodsConnected,
                    isActive: appDelegate.state.isActive,
                    cameraDropdown: activeSource == .camera && !availableCameras.isEmpty ? AnyView(
                        Picker("", selection: $selectedCameraID) {
                            ForEach(availableCameras, id: \.id) { camera in
                                Text(camera.name).tag(camera.id)
                            }
                        }
                            .labelsHidden()
                            .frame(minWidth: 110, maxWidth: 170)
                            .onChange(of: selectedCameraID) { newValue in
                                if newValue != appDelegate.selectedCameraID {
                                    appDelegate.selectedCameraID = newValue
                                    appDelegate.saveSettings()
                                    appDelegate.restartCamera()
                                }
                            }
                    ) : nil,
                    onCalibrate: nil
                )

                if dualSensor {
                    HStack(spacing: 6) {
                        Image(systemName: "airpodspro")
                            .font(.system(size: 10))
                            .foregroundColor(airPodsConnected ? NotabilityTheme.successGreen : .secondary)
                        Text(airPodsConnected ? L("settings.airpodsReady") : L("settings.airpodsNotConnected"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                }

                SubtleDivider()

                CompactToggle(
                    title: L("fusion.enabled"),
                    helpText: L("fusion.enabled.help"),
                    isOn: $dualSensor
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: dualSensor) { newValue in
                    appDelegate.dualSensorEnabled = newValue
                    appDelegate.saveSettings()
                }

                if dualSensor {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(NotabilityTheme.accentBlue)
                        Text(L("fusion.disabledNote"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(NotabilityTheme.accentBlue.opacity(0.08))
                    )
                }

                Button(action: {
                    appDelegate.startCalibration()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(L("dashboard.recalibrate"))
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(NotabilityTheme.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: NotabilityTheme.accentBlue.opacity(0.3), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // Posture Response: warning mode, dropdowns, alert toggles
    private var responseCard: some View {
        NotabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("settings.warning"))
                            .font(.system(size: 11))
                            .frame(width: 82, alignment: .leading)
                        warningModePills
                        SubtleDivider()
                    }

                    dropdownRow(
                        L("settings.intensity"),
                        help: L("settings.intensity.help"),
                        selection: $intensitySlider,
                        labels: intensityLabels
                    ) { index in
                        intensity = intensityValues[index]
                        appDelegate.settingsProfileManager.updateActiveProfile(intensity: intensity)
                        appDelegate.applyActiveSettingsProfile()
                    }

                    dropdownRow(
                        L("settings.deadZone"),
                        help: L("settings.deadZone.help"),
                        selection: $deadZoneSlider,
                        labels: deadZoneLabels
                    ) { index in
                        deadZone = deadZoneValues[index]
                        appDelegate.settingsProfileManager.updateActiveProfile(deadZone: deadZone)
                        appDelegate.applyActiveSettingsProfile()
                    }

                    dropdownRow(
                        L("settings.detection"),
                        help: L("settings.detection.help"),
                        selection: $detectionModeSlider,
                        labels: detectionModes.map { $0.displayName }
                    ) { index in
                        appDelegate.settingsProfileManager.updateActiveProfile(detectionMode: detectionModes[index])
                        appDelegate.applyActiveSettingsProfile()
                    }
                }

                SubtleDivider()

                VStack(alignment: .leading, spacing: 6) {
                    CompactToggle(
                        title: L("alert.showAlert"),
                        helpText: L("alert.showAlert.help"),
                        isOn: $showAlert
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: showAlert) { newValue in
                        appDelegate.postureAlertManager.showAlertEnabled = newValue
                        appDelegate.saveSettings()
                    }

                    SubtleDivider()

                    CompactToggle(
                        title: L("alert.voiceAnnouncement"),
                        helpText: L("alert.voiceAnnouncement.help"),
                        isOn: $voiceAnnouncement
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: voiceAnnouncement) { newValue in
                        appDelegate.postureAlertManager.voiceAnnouncementEnabled = newValue
                        appDelegate.saveSettings()
                    }

                    CompactToggle(
                        title: L("alert.spatialSound"),
                        helpText: L("alert.spatialSound.help"),
                        isOn: Binding(
                            get: { soundAlertEnabled },
                            set: { isOn in
                                soundAlertEnabled = isOn
                                pushSoundState()
                            }
                        )
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if voiceAnnouncement || soundAlertEnabled {
                        VStack(alignment: .leading, spacing: 2) {
                            Picker("", selection: $soundMode) {
                                Text(L("alert.sound.alwaysOn")).tag(AlertSoundMode.on)
                                Text(L("alert.sound.autoAirPods")).tag(AlertSoundMode.airpodsOnly)
                            }
                            .pickerStyle(.radioGroup)
                            .labelsHidden()
                            .font(.system(size: 11))
                            .onChange(of: soundMode) { newValue in
                                pushSoundState()
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
    }

    private func pushSoundState() {
        appDelegate.postureAlertManager.soundMode = soundAlertEnabled ? soundMode : .off
        appDelegate.saveSettings()
    }

    // Behavior: pause on battery + blur when away + shortcut info
    private var behaviorCard: some View {
        NotabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                CompactToggle(
                    title: L("settings.pauseOnBattery"),
                    helpText: appDelegate.hasBattery
                        ? L("settings.pauseOnBattery.help")
                        : L("settings.pauseOnBattery.help.desktop"),
                    isOn: $pauseOnBattery,
                    isDisabled: !appDelegate.hasBattery
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: pauseOnBattery) { newValue in
                    guard appDelegate.hasBattery else { return }
                    Task { @MainActor in
                        await appDelegate.setPauseOnBatteryEnabled(newValue)
                    }
                }

                CompactToggle(
                    title: L("settings.blurWhenAway"),
                    helpText: activeSource == .airpods
                        ? L("settings.blurWhenAway.help.airpods")
                        : L("settings.blurWhenAway.help.camera"),
                    isOn: $blurWhenAway,
                    isDisabled: activeSource == .airpods
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: blurWhenAway) { newValue in
                    appDelegate.blurWhenAway = newValue
                    appDelegate.saveSettings()
                }

                SubtleDivider()

                HStack(spacing: 6) {
                    BrandSwitch(isOn: $toggleShortcutEnabled)
                        .frame(width: 38, alignment: .leading)
                        .onChange(of: toggleShortcutEnabled) { newValue in
                            appDelegate.toggleShortcutEnabled = newValue
                            appDelegate.saveSettings()
                            appDelegate.updateGlobalKeyMonitor()
                        }

                    Text(L("settings.shortcut"))
                        .font(.system(size: 11))

                    Spacer()

                    Text(appDelegate.toggleShortcut.displayString)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background {
                            if #available(macOS 26.0, *) {
                                Capsule().fill(.ultraThinMaterial).glassEffect(in: Capsule())
                            } else {
                                Capsule().fill(NotabilityTheme.accentBlue.opacity(0.12))
                            }
                        }
                        .overlay(
                            Capsule().strokeBorder(NotabilityTheme.accentBlue.opacity(0.3), lineWidth: 1)
                        )
                }
                .frame(height: 24)
            }
        }
    }

    // Reminders: daily start reminder + screen break (20/20/20)
    private var remindersCard: some View {
        NotabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                CompactToggle(
                    title: L("reminder.daily"),
                    helpText: L("reminder.daily.help"),
                    isOn: $dailyReminderEnabled
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: dailyReminderEnabled) { newValue in
                    appDelegate.dailyReminderEnabled = newValue
                    appDelegate.saveSettings()
                }

                SubtleDivider()

                HStack(spacing: 0) {
                    CompactToggle(
                        title: L("breakReminder.enabled"),
                        helpText: L("breakReminder.enabled.help"),
                        isOn: $breakReminderEnabled
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: breakReminderEnabled) { newValue in
                        appDelegate.breakReminderEnabled = newValue
                        appDelegate.saveSettings()
                    }

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(L("breakReminder.interval"))
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Picker("", selection: $breakIntervalMinutes) {
                            ForEach(breakIntervalOptions, id: \.self) { minutes in
                                Text(L("breakReminder.interval.minutes", Int(minutes))).tag(minutes)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)
                        .onChange(of: breakIntervalMinutes) { newValue in
                            appDelegate.breakReminderInterval = newValue
                            appDelegate.saveSettings()
                        }
                    }
                    .disabled(!breakReminderEnabled)
                    .opacity(breakReminderEnabled ? 1.0 : 0.5)
                }

                HStack(spacing: 8) {
                    Text(L("breakReminder.duration"))
                        .font(.system(size: 11))
                        .frame(width: 82, alignment: .leading)
                    Picker("", selection: $breakDurationSeconds) {
                        ForEach(breakDurationOptions, id: \.self) { seconds in
                            Text(L("breakReminder.duration.seconds", Int(seconds))).tag(seconds)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120, alignment: .leading)
                }
                .frame(height: 22)

                HStack(spacing: 8) {
                    Text(L("breakReminder.startIn"))
                        .font(.system(size: 11))
                        .frame(width: 82, alignment: .leading)
                    Picker("", selection: $breakStartInMinutes) {
                        ForEach(breakStartInOptions, id: \.self) { minutes in
                            Text(minutes == 0 ? L("breakReminder.now") : L("breakReminder.interval.minutes", Int(minutes))).tag(minutes)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 120, alignment: .leading)
                }
                .frame(height: 22)

                Button(action: {
                    appDelegate.scheduleScreenBreak(
                        inMinutes: breakStartInMinutes,
                        durationSeconds: Int(breakDurationSeconds)
                    )
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(L("breakReminder.startNow"))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(NotabilityTheme.accentBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .shadow(color: NotabilityTheme.accentBlue.opacity(0.25), radius: 5, x: 0, y: 2)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // Auto Pause: pause tracking during meetings and macOS Focus modes
    private var autoPauseCard: some View {
        NotabilityCard {
            VStack(alignment: .leading, spacing: 10) {
                CompactToggle(
                    title: L("autoPause.meeting"),
                    helpText: L("autoPause.meeting.help"),
                    isOn: $meetingPauseEnabled
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: meetingPauseEnabled) { newValue in
                    appDelegate.meetingPauseEnabled = newValue
                    appDelegate.saveSettings()
                }

                CompactToggle(
                    title: L("autoPause.focus"),
                    helpText: L("autoPause.focus.help"),
                    isOn: $focusPauseEnabled
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: focusPauseEnabled) { newValue in
                    appDelegate.focusPauseEnabled = newValue
                    appDelegate.saveSettings()
                }

                if focusPauseEnabled {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("autoPause.focus.modes"))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)

                        ForEach(focusModes) { mode in
                            Toggle(isOn: Binding(
                                get: { selectedFocusModeIDs.contains(mode.identifier) },
                                set: { isOn in
                                    if isOn {
                                        selectedFocusModeIDs.insert(mode.identifier)
                                    } else {
                                        selectedFocusModeIDs.remove(mode.identifier)
                                    }
                                    appDelegate.focusPauseModes = Array(selectedFocusModeIDs)
                                    appDelegate.saveSettings()
                                }
                            )) {
                                Text(mode.name)
                                    .font(.system(size: 11))
                                    .lineLimit(1)
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(L("settings.privacy.note"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                Text(L("settings.version", version, build))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Warning Mode Pills (Blur / Border only)

    private var warningModePills: some View {
        HStack(spacing: 6) {
            ForEach([WarningMode.blur, .border], id: \.self) { mode in
                Button(action: {
                    guard warningMode != mode else { return }
                    warningMode = mode
                    appDelegate.settingsProfileManager.updateActiveProfile(warningMode: mode)
                    appDelegate.switchWarningMode()
                }) {
                    Text(mode.displayName)
                        .font(.system(size: 11, weight: warningMode == mode ? .semibold : .regular, design: .rounded))
                        .foregroundColor(warningMode == mode ? .white : .primary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 5)
                        .background {
                            if warningMode == mode {
                                Capsule().fill(NotabilityTheme.accentBlue)
                            } else if #available(macOS 26.0, *) {
                                Capsule().fill(.ultraThinMaterial).glassEffect(in: Capsule())
                            } else {
                                Capsule().fill(Color.primary.opacity(0.05))
                            }
                        }
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Dropdown Row

    private func dropdownRow(
        _ title: String,
        help: String,
        selection: Binding<Double>,
        labels: [String],
        onChange: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .frame(width: 82, alignment: .leading)
            Picker("", selection: selection) {
                ForEach(0..<labels.count, id: \.self) { index in
                    Text(labels[index]).tag(Double(index))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 200, alignment: .leading)
            .onChange(of: selection.wrappedValue) { newValue in
                onChange(Int(newValue))
            }
        }
        .frame(height: 24)
        .help(help)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        if !isActive { return .gray }
        return isSlouching ? NotabilityTheme.warningOrange : NotabilityTheme.successGreen
    }

    private func refreshState() {
        isActive = appDelegate.state.isActive
        isSlouching = appDelegate.isCurrentlySlouching
        activeSource = appDelegate.activeTrackingSource
        intensity = Double(appDelegate.activeIntensity)
        deadZone = Double(appDelegate.activeDeadZone)
        cameraCalibrated = appDelegate.cameraCalibration?.isValid ?? false
        airPodsCalibrated = appDelegate.airPodsCalibration?.isValid ?? false
        airPodsConnected = appDelegate.airPodsDetector.isBluetoothConnected
        dualSensor = appDelegate.dualSensorEnabled
        syncProfileStateToUI()
    }

    // MARK: - Profile Sync

    private func syncProfileStateToUI() {
        guard let activeProfile = appDelegate.settingsProfileManager.activeProfile else { return }
        intensity = activeProfile.intensity
        deadZone = activeProfile.deadZone
        intensitySlider = Double(Self.closestIndex(for: activeProfile.intensity, in: intensityValues))
        deadZoneSlider = Double(Self.closestIndex(for: activeProfile.deadZone, in: deadZoneValues))
        warningMode = Self.normalizedWarningMode(activeProfile.warningMode)
        warningOnsetDelay = activeProfile.warningOnsetDelay
        detectionModeSlider = Double(detectionModes.firstIndex(of: activeProfile.detectionMode) ?? 0)
    }
}