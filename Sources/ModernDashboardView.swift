import SwiftUI
import AppKit
import ServiceManagement
import AVFoundation
import CoreBluetooth
import CoreMotion
import UserNotifications
import Intents

extension Notification.Name {
    /// Posted by `AppDelegate.syncUIToState()` whenever the tracking UI state
    /// changes (enabled state, slouching, active source, profile settings).
    static let postureUIStateChanged = Notification.Name("PostureUIStateChanged")
}

// MARK: - Section Height Preference

struct DashboardSectionHeightKey: PreferenceKey {
    static var defaultValue: [DashboardSection: CGFloat] = [:]
    static func reduce(value: inout [DashboardSection: CGFloat], nextValue: () -> [DashboardSection: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Sum of the fixed-height elements around the section card (header, tab bar,
/// footer). Reported by background GeometryReaders on each of them.
struct DashboardFixedHeightsKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
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

    // Live status
    @State private var intensity: Double
    @State private var deadZone: Double
    @State private var isActive: Bool = false
    @State private var isSlouching: Bool = false
    @State private var activeSource: TrackingSource = .camera

    @State private var selectedSection: DashboardSection = .general
    @State private var sectionHeights: [DashboardSection: CGFloat] = [:]

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
    @State private var notificationPermissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var permissionTick = 0

    // Reminders
    @State private var breakReminderEnabled: Bool
    @State private var breakIntervalMinutes: Double
    @State private var breakDurationSeconds: Double = 20
    @State private var breakStartInMinutes: Double = 0
    @State private var dailyReminderEnabled: Bool
    @State private var meetingPauseEnabled: Bool
    @State private var focusPauseEnabled: Bool

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
    }

    var body: some View {
        VStack(spacing: 14) {
            headerCard
            tabBar

            // The section card is top-aligned inside a flexible container that
            // fills the space between the tab bar and the footer. The card
            // keeps its full intrinsic height (fixedSize) and is clipped by the
            // container, so when the window grows the card's lower part is
            // revealed smoothly while the header and tab bar stay put and the
            // footer stays pinned to the bottom edge.
            sectionContainer

            footer
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(width: contentWidth)
        .frame(width: contentWidth + 40)
        .frame(maxHeight: .infinity)
        .background(heightMeasurementProbe)
        .onPreferenceChange(DashboardSectionHeightKey.self) { heights in
            sectionHeights.merge(heights) { _, new in new }
        }
        .onPreferenceChange(DashboardFixedHeightsKey.self) { fixed in
            guard fixed > 0 else { return }
            // header + tab bar + footer + 3 inter-element spacings (3 * 14) +
            // top/bottom padding (20 + 16).
            appDelegate.dashboardFixedContentHeight = fixed + 78
        }
        // Listen for live posture state changes
        .onReceive(NotificationCenter.default.publisher(for: .postureUIStateChanged)) { _ in
            refreshState()
        }
        .onAppear {
            refreshState()
            loadNotificationPermissionStatus()
        }
    }

    /// The section card plus a height probe. The GeometryReader is a
    /// background sibling so it measures the section card's laid-out height
    /// (an overlay/preference probe reports 0 in this layout). It reports the
    /// height once on appear and again whenever the layout height changes,
    /// which drives `fitDashboardWindow`.
    private var sectionContainer: some View {
        ZStack(alignment: .top) {
            sectionCard
                .id(selectedSection)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: contentWidth, alignment: .top)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { reportSectionHeight(geo.size.height) }
                            .onChange(of: geo.size.height) { reportSectionHeight($0) }
                    }
                )
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
        .clipped()
    }

    private func reportSectionHeight(_ height: CGFloat) {
        guard height > 60 else { return }
        // Ignore intermediate heights reported while the content is animating
        // between section heights; the tab switch already pre-targets the
        // window to the final height. Only the settled height may refit.
        if let cached = sectionHeights[selectedSection], abs(cached - height) > 2 { return }
        DispatchQueue.main.async { appDelegate.fitDashboardWindow(sectionHeight: height) }
    }

    /// Background probe that reports a fixed-height element's laid-out height
    /// into `DashboardFixedHeightsKey` (summed by the preference reducer).
    private func fixedHeightProbe() -> some View {
        GeometryReader { geo in
            Color.clear.preference(key: DashboardFixedHeightsKey.self, value: geo.size.height)
        }
    }

    /// Renders every section card hidden (opacity 0, no hit testing) so their
    /// laid-out heights are known up front. A tab switch can then start the
    /// window animation toward the exact target height at the same moment the
    /// content transitions, keeping the two in sync so the taller content is
    /// never clipped while the window is still the old (smaller) size.
    private var heightMeasurementProbe: some View {
        ZStack {
            ForEach(DashboardSection.allCases) { section in
                sectionCard(for: section)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .frame(width: contentWidth)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: DashboardSectionHeightKey.self,
                                value: [section: geo.size.height]
                            )
                        }
                    )
            }
        }
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
        .background(fixedHeightProbe())
    }

    // MARK: - Section Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(DashboardSection.allCases) { section in
                Button(action: {
                    if let targetHeight = sectionHeights[section] {
                        appDelegate.fitDashboardWindow(sectionHeight: targetHeight)
                    }
                    selectedSection = section
                }) {
                    VStack(spacing: 3) {
                        Image(systemName: section.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .frame(width: 18, height: 16)
                        Text(section.title)
                            .font(.system(size: 10, weight: selectedSection == section ? .semibold : .regular, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(height: 12)
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
        .background(fixedHeightProbe())
    }

    // MARK: - Section Content

    @ViewBuilder
    private var sectionCard: some View {
        sectionCard(for: selectedSection)
    }

    @ViewBuilder
    private func sectionCard(for section: DashboardSection) -> some View {
        switch section {
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
                    AppearancePicker(
                        selection: Binding(
                            get: { appAppearance },
                            set: { newValue in
                                guard newValue != appAppearance else { return }
                                appDelegate.appAppearance = newValue
                                appDelegate.saveSettings()
                                appDelegate.applyAppearance()
                                appAppearance = newValue
                            }
                        )
                    )
                }

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

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 11))
                            .foregroundColor(NotabilityTheme.accentBlue)
                        Text(L("settings.permissions.title"))
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                    }
                    permissionRow(
                        icon: "camera.fill",
                        name: L("settings.permissions.camera"),
                        detail: L("settings.permissions.camera.reason"),
                        status: cameraPermissionStatus,
                        actionTitle: cameraPermissionStatus == .notDetermined ? L("settings.permissions.request") : L("settings.permissions.revoke"),
                        action: {
                            if cameraPermissionStatus == .notDetermined {
                                requestCameraPermission()
                            } else {
                                revokeCameraPermission()
                            }
                        }
                    )
                    permissionRow(
                        icon: "figure.walk.motion",
                        name: L("settings.permissions.motion"),
                        detail: L("settings.permissions.motion.reason"),
                        status: motionPermissionStatus,
                        actionTitle: L("settings.permissions.manage"),
                        action: { openSystemSettings("com.apple.preference.security?Privacy_Motion") }
                    )
                    permissionRow(
                        icon: "airpodspro",
                        name: L("settings.permissions.bluetooth"),
                        detail: L("settings.permissions.bluetooth.reason"),
                        status: bluetoothPermissionStatus,
                        actionTitle: L("settings.permissions.manage"),
                        action: { openSystemSettings("com.apple.preference.security?Privacy_Bluetooth") }
                    )
                    permissionRow(
                        icon: "bell.fill",
                        name: L("settings.permissions.notifications"),
                        detail: L("settings.permissions.notifications.reason"),
                        status: PermissionStatus(notificationPermissionStatus),
                        actionTitle: L("settings.permissions.manage"),
                        action: { openSystemSettings("com.apple.Notifications-Settings.extension") }
                    )
                    permissionRow(
                        icon: "moon.fill",
                        name: L("settings.permissions.focus"),
                        detail: L("settings.permissions.focus.reason"),
                        status: focusPermissionStatus,
                        actionTitle: L("settings.permissions.manage"),
                        action: {
                            if focusPermissionStatus == .notDetermined {
                                requestFocusPermission()
                            } else {
                                openSystemSettings("com.apple.preference.security?Privacy_Focus")
                            }
                        }
                    )
                }
                .id(permissionTick)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )

                SubtleDivider()

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("settings.resetAll"))
                            .font(.system(size: 12, weight: .medium))
                        Text(L("settings.resetAll.description"))
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(L("settings.resetAll.button")) {
                        let alert = NSAlert()
                        alert.messageText = L("settings.resetAll.confirmTitle")
                        alert.informativeText = L("settings.resetAll.confirm")
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: L("settings.resetAll.confirmButton")).hasDestructiveAction = true
                        alert.addButton(withTitle: L("common.cancel"))
                        if alert.runModal() == .alertFirstButtonReturn {
                            let domain = Bundle.main.bundleIdentifier ?? "chill.PostureAI"
                            UserDefaults.standard.removePersistentDomain(forName: domain)
                            UserDefaults.standard.synchronize()
                            appDelegate.relaunchApp()
                        }
                    }
                }
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
                        Text(L("breakReminder.start"))
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
                    appDelegate.focusObserver.reevaluate()
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
        .background(fixedHeightProbe())
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

    // MARK: - Permissions

    private enum PermissionStatus {
        case granted, denied, restricted, notDetermined

        var label: String {
            switch self {
            case .granted: return L("settings.permissions.allowed")
            case .denied: return L("settings.permissions.denied")
            case .restricted: return L("settings.permissions.restricted")
            case .notDetermined: return L("settings.permissions.notDetermined")
            }
        }

        var symbol: String? {
            switch self {
            case .granted: return "checkmark.circle.fill"
            case .denied: return "xmark.circle.fill"
            case .restricted: return "exclamationmark.triangle.fill"
            case .notDetermined: return nil
            }
        }

        var color: Color {
            switch self {
            case .granted: return NotabilityTheme.successGreen
            case .denied: return NotabilityTheme.dangerRed
            case .restricted: return .orange
            case .notDetermined: return .secondary
            }
        }

        init(_ status: UNAuthorizationStatus) {
            switch status {
            case .authorized, .provisional: self = .granted
            case .denied: self = .denied
            case .notDetermined: self = .notDetermined
            @unknown default: self = .notDetermined
            }
        }

        init(_ status: INFocusStatusAuthorizationStatus) {
            switch status {
            case .authorized: self = .granted
            case .denied: self = .denied
            case .restricted: self = .restricted
            case .notDetermined: self = .notDetermined
            @unknown default: self = .notDetermined
            }
        }
    }

    private var cameraPermissionStatus: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    private var bluetoothPermissionStatus: PermissionStatus {
        switch CBManager.authorization {
        case .allowedAlways: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    private var motionPermissionStatus: PermissionStatus {
        guard #available(macOS 14.0, *) else { return .notDetermined }
        switch CMHeadphoneMotionManager.authorizationStatus() {
        case .authorized: return .granted
        case .denied: return .denied
        case .restricted: return .restricted
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }

    private func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [self] _ in
            Task { @MainActor in
                permissionTick += 1
            }
        }
    }

    private var focusPermissionStatus: PermissionStatus {
        PermissionStatus(INFocusStatusCenter.default.authorizationStatus)
    }

    private func requestFocusPermission() {
        INFocusStatusCenter.default.requestAuthorization { [self] _ in
            Task { @MainActor in
                permissionTick += 1
            }
        }
    }

    private func loadNotificationPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                notificationPermissionStatus = settings.authorizationStatus
            }
        }
    }

    private func revokeCameraPermission() {
        let bundleID = Bundle.main.bundleIdentifier ?? "chill..PostureAI"
        let process = Process()
        process.launchPath = "/usr/bin/tccutil"
        process.arguments = ["reset", "Camera", bundleID]
        try? process.run()
        process.waitUntilExit()
        permissionTick += 1
    }

    private func openSystemSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    private func permissionRow(
        icon: String,
        name: String,
        detail: String,
        status: PermissionStatus,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(width: 16)

                Text(name)
                    .font(.system(size: 11))

                Spacer()

                HStack(spacing: 4) {
                    if let statusSymbol = status.symbol {
                        Image(systemName: statusSymbol)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(status.color)
                    }
                    Text(status.label)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(status.color)
                }

                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(NotabilityTheme.accentBlue)
                }
                .buttonStyle(.plain)
            }
            .frame(height: 24)

            Text(detail)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
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