import AppKit
import SwiftUI
import ServiceManagement

// MARK: - Settings View

@MainActor
struct SettingsView: View {
    let appDelegate: AppDelegate
    let settingsProfileManager: SettingsProfileManager

    // Local state that syncs with AppDelegate - initialized from appDelegate in init()
    @State private var intensity: Double
    @State private var deadZone: Double
    @State private var intensitySlider: Double
    @State private var deadZoneSlider: Double
    @State private var blurWhenAway: Bool
    @State private var showInDock: Bool
    @State private var pauseOnTheGo: Bool
    @State private var pauseOnBattery: Bool
    @State private var useCompatibilityMode: Bool
    @State private var useFullScreenOverlay: Bool
    @State private var selectedCameraID: String
    @State private var availableCameras: [(id: String, name: String)]
    @State private var warningMode: WarningMode
    @State private var warningColor: Color
    @State private var warningOnsetDelay: Double
    @State private var launchAtLogin: Bool
    @State private var appAppearance: AppAppearance

    @State private var toggleShortcutEnabled: Bool
    @State private var toggleShortcut: AppKeyboardShortcut
    @State private var detectionModeSlider: Double
    @State private var trackingSource: TrackingSource
    @State private var trackingModeSelection: TrackingMode
    @State private var preferredSource: TrackingSource
    @State private var airPodsAvailable: Bool
    @State private var airPodsConnected: Bool
    @State private var cameraCalibrated: Bool
    @State private var airPodsCalibrated: Bool
    @State private var activeSource: TrackingSource
    @State private var settingsProfiles: [SettingsProfile]
    @State private var selectedSettingsProfileID: String
    @State private var lastSelectedSettingsProfileID: String
    @State private var isApplyingProfileSelection = false
    @State private var showingNewProfilePrompt = false
    @State private var showingDeleteConfirmation = false
    @State private var newProfileName = ""

    var canDeleteCurrentProfile: Bool {
        settingsProfileManager.canDeleteProfile(id: selectedSettingsProfileID)
    }

    let detectionModes: [DetectionMode] = [.responsive, .balanced, .performance]

    let intensityValues: [Double] = [0.08, 0.15, 0.35, 0.65, 1.2]
    var intensityLabels: [String] { [L("settings.intensity.gentle"), L("settings.intensity.easy"), L("settings.intensity.medium"), L("settings.intensity.firm"), L("settings.intensity.aggressive")] }

    let deadZoneValues: [Double] = [0.0, 0.08, 0.15, 0.25, 0.40]
    var deadZoneLabels: [String] { [L("settings.deadZone.strict"), L("settings.deadZone.tight"), L("settings.deadZone.medium"), L("settings.deadZone.relaxed"), L("settings.deadZone.loose")] }

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

    init(appDelegate: AppDelegate) {
        self.init(appDelegate: appDelegate, settingsProfileManager: appDelegate.settingsProfileManager)
    }

    init(appDelegate: AppDelegate, settingsProfileManager: SettingsProfileManager) {
        self.appDelegate = appDelegate
        self.settingsProfileManager = settingsProfileManager

        let cameras = appDelegate.cameraDetector.getAvailableCameras()
        let cameraList = cameras.map { (id: $0.uniqueID, name: $0.localizedName) }

        let profileIntensity = appDelegate.activeIntensity
        let profileDeadZone = appDelegate.activeDeadZone
        let profileWarningMode = appDelegate.activeWarningMode
        let profileWarningColor = appDelegate.activeWarningColor
        let profileWarningOnsetDelay = appDelegate.activeWarningOnsetDelay
        let profileDetectionMode = appDelegate.activeDetectionMode

        _intensity = State(initialValue: profileIntensity)
        _deadZone = State(initialValue: profileDeadZone)
        _intensitySlider = State(initialValue: Double(Self.closestIndex(for: Double(profileIntensity), in: intensityValues)))
        _deadZoneSlider = State(initialValue: Double(Self.closestIndex(for: Double(profileDeadZone), in: deadZoneValues)))
        _blurWhenAway = State(initialValue: appDelegate.blurWhenAway)
        _showInDock = State(initialValue: appDelegate.showInDock)
        _pauseOnTheGo = State(initialValue: appDelegate.pauseOnTheGo)
        _pauseOnBattery = State(initialValue: appDelegate.pauseOnBattery)
        _useCompatibilityMode = State(initialValue: appDelegate.useCompatibilityMode)
        _useFullScreenOverlay = State(initialValue: appDelegate.useFullScreenOverlay)
        _selectedCameraID = State(initialValue: appDelegate.selectedCameraID ?? cameras.first?.uniqueID ?? "")
        _availableCameras = State(initialValue: cameraList)
        _warningMode = State(initialValue: profileWarningMode)
        _warningColor = State(initialValue: Color(profileWarningColor))
        _warningOnsetDelay = State(initialValue: profileWarningOnsetDelay)
        _launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
        _appAppearance = State(initialValue: appDelegate.appAppearance)

        _toggleShortcutEnabled = State(initialValue: appDelegate.toggleShortcutEnabled)
        _toggleShortcut = State(initialValue: appDelegate.toggleShortcut)
        _detectionModeSlider = State(initialValue: Double(detectionModes.firstIndex(of: profileDetectionMode) ?? 0))
        _trackingSource = State(initialValue: appDelegate.trackingSource)
        _trackingModeSelection = State(initialValue: appDelegate.trackingStore.withState { $0.trackingMode })
        _preferredSource = State(initialValue: appDelegate.trackingStore.withState { $0.preferredSource })
        _airPodsAvailable = State(initialValue: appDelegate.airPodsDetector.isAvailable)
        let needsAirPods = appDelegate.trackingStore.withState { $0.trackingMode } == .automatic ||
        appDelegate.trackingSource == .airpods
        _airPodsConnected = State(initialValue: needsAirPods ? appDelegate.airPodsDetector.isBluetoothConnected : false)
        _cameraCalibrated = State(initialValue: appDelegate.cameraCalibration?.isValid ?? false)
        _airPodsCalibrated = State(initialValue: appDelegate.airPodsCalibration?.isValid ?? false)
        _activeSource = State(initialValue: appDelegate.activeTrackingSource)

        settingsProfileManager.ensureProfilesLoaded()
        let snapshot = settingsProfileManager.profilesState()
        let profiles = snapshot.profiles
        let initialProfileID = snapshot.selectedID ?? profiles.first?.id ?? ""
        _settingsProfiles = State(initialValue: profiles)
        _selectedSettingsProfileID = State(initialValue: initialProfileID)
        _lastSelectedSettingsProfileID = State(initialValue: initialProfileID)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            VStack(spacing: 10) {
                trackingCardView
                responseCardView
                behaviorCardView
            }
        }
        .padding(16)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .alert(L("settings.profile.newTitle"), isPresented: $showingNewProfilePrompt) {
            TextField(L("settings.profile.namePlaceholder"), text: $newProfileName)
            Button(L("common.cancel"), role: .cancel) { newProfileName = "" }
            Button(L("common.create")) { createNewProfile() }
                .disabled(newProfileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .alert(L("settings.profile.deleteTitle"), isPresented: $showingDeleteConfirmation) {
            Button(L("common.cancel"), role: .cancel) {}
            Button(L("common.delete"), role: .destructive) { deleteCurrentProfile() }
        } message: {
            Text(L("settings.profile.deleteMessage"))
        }
    }

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 8) {
            if let appIcon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 28, height: 28)
            }
            Text("PostureAI")
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            HStack(spacing: 4) {
                Link(destination: URL(string: "https://github.com/jeffrey1024hk-stack/HKICT")!) {
                    GitHubIcon(color: Color.secondary.opacity(0.6))
                        .frame(width: 14, height: 14)
                        .padding(3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .help(L("settings.viewOnGitHub"))

                Link(destination: URL(string: "https://discord.gg/6Ufy2SnXDW")!) {
                    DiscordIcon(color: Color.secondary.opacity(0.6))
                        .frame(width: 14, height: 14)
                        .padding(3)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .help(L("settings.joinDiscord"))
            }

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("v\(version)")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.primary.opacity(0.05)))
            }
        }
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var trackingCardView: some View {
        SettingsCard(icon: "scope", title: L("settings.tracking"), helpText: L("settings.tracking.help")) {
            CompactModePicker(selection: $trackingModeSelection)
                .frame(width: 170)
                .onChange(of: trackingModeSelection) { newValue in
                    Task { @MainActor in
                        await appDelegate.setTrackingMode(newValue)
                        activeSource = appDelegate.activeTrackingSource
                    }
                }
        } content: {
            VStack(spacing: 6) {
                if trackingModeSelection == .manual {
                    manualTrackingContent
                } else {
                    automaticTrackingContent
                }
            }
        }
    }

    @ViewBuilder
    private var manualTrackingContent: some View {
        HStack(spacing: 8) {
            Text(L("settings.source"))
                .font(.system(size: 11))

            Spacer()

            CompactTrackingSourcePicker(
                selection: $trackingSource,
                airPodsAvailable: airPodsAvailable
            )
            .frame(width: 170)
            .onChange(of: trackingSource) { newValue in
                if newValue != appDelegate.trackingSource {
                    Task { @MainActor in
                        await appDelegate.switchTrackingSource(to: newValue)
                    }
                }
            }
        }
        .frame(height: 26)

        DeviceStatusRow(
            source: trackingSource,
            isCalibrated: trackingSource == .camera ? cameraCalibrated : airPodsCalibrated,
            isConnected: trackingSource == .camera ? !availableCameras.isEmpty : airPodsConnected,
            isPreferred: false,
            isActive: appDelegate.state.isActive,
            cameraDropdown: trackingSource == .camera && !availableCameras.isEmpty ? AnyView(
                Picker("", selection: $selectedCameraID) {
                    ForEach(availableCameras, id: \.id) { camera in
                        Text(camera.name).tag(camera.id)
                    }
                }
                    .labelsHidden()
                    .frame(minWidth: 130, maxWidth: 220)
                    .onChange(of: selectedCameraID) { newValue in
                        if newValue != appDelegate.selectedCameraID {
                            appDelegate.selectedCameraID = newValue
                            appDelegate.saveSettings()
                            appDelegate.restartCamera()
                        }
                    }
            ) : nil,
            onCalibrate: {
                appDelegate.startCalibration()
            }
        )
    }

    @ViewBuilder
    private var automaticTrackingContent: some View {
        HStack(spacing: 8) {
            Text(L("settings.preferred"))
                .font(.system(size: 11))

            Spacer()

            CompactTrackingSourcePicker(
                selection: $preferredSource,
                airPodsAvailable: true
            )
            .frame(width: 170)
            .onChange(of: preferredSource) { newValue in
                Task { @MainActor in
                    await appDelegate.setPreferredSource(newValue)
                    activeSource = appDelegate.activeTrackingSource
                }
            }
        }
        .frame(height: 26)

        DeviceStatusRow(
            source: .camera,
            isCalibrated: cameraCalibrated,
            isConnected: !availableCameras.isEmpty,
            isPreferred: preferredSource == .camera,
            isActive: activeSource == .camera && appDelegate.state.isActive,
            cameraDropdown: availableCameras.isEmpty ? nil : AnyView(
                Picker("", selection: $selectedCameraID) {
                    ForEach(availableCameras, id: \.id) { camera in
                        Text(camera.name).tag(camera.id)
                    }
                }
                    .labelsHidden()
                    .frame(minWidth: 130, maxWidth: 220)
                    .onChange(of: selectedCameraID) { newValue in
                        if newValue != appDelegate.selectedCameraID {
                            appDelegate.selectedCameraID = newValue
                            appDelegate.saveSettings()
                            appDelegate.restartCamera()
                        }
                    }
            ),
            onCalibrate: {
                appDelegate.startCalibration(for: .camera)
            }
        )

        DeviceStatusRow(
            source: .airpods,
            isCalibrated: airPodsCalibrated,
            isConnected: airPodsConnected,
            isPreferred: preferredSource == .airpods,
            isActive: activeSource == .airpods && appDelegate.state.isActive,
            onCalibrate: {
                appDelegate.startCalibration(for: .airpods)
            }
        )

        if (preferredSource == .camera && !cameraCalibrated) || (preferredSource == .airpods && !airPodsCalibrated) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.orange)
                Text(L("settings.preferredNeedsCalibration"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.orange.opacity(0.08))
            )
        }
    }

    @ViewBuilder
    private var responseCardView: some View {
        SettingsCard(icon: "slider.horizontal.3", title: L("settings.section.response"), helpText: L("settings.profile.help")) {
            HStack(spacing: 4) {
                Picker("", selection: $selectedSettingsProfileID) {
                    ForEach(settingsProfiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .labelsHidden()
                .frame(width: 100)
                .onChange(of: selectedSettingsProfileID) { newValue in
                    handleProfileSelectionChange(newValue)
                }

                Button(action: {
                    newProfileName = ""
                    showingNewProfilePrompt = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.brandCyan)
                        .frame(width: 24, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.brandCyan.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(Color.brandCyan.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .help(L("settings.profile.new"))

                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(canDeleteCurrentProfile ? .red.opacity(0.8) : .secondary.opacity(0.4))
                        .frame(width: 24, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(canDeleteCurrentProfile ? Color.red.opacity(0.08) : Color.primary.opacity(0.04))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .strokeBorder(canDeleteCurrentProfile ? Color.red.opacity(0.25) : Color.primary.opacity(0.06), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!canDeleteCurrentProfile)
                .help(L("settings.profile.deleteTitle"))
            }
        } content: {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Text(L("settings.warning"))
                            .font(.system(size: 11))
                            .frame(width: 82, alignment: .leading)
                        HelpButton(text: L("settings.warning.help"))
                    }

                    CompactWarningStylePicker(selection: $warningMode)
                        .frame(maxWidth: .infinity)
                        .onChange(of: warningMode) { newValue in
                            settingsProfileManager.updateActiveProfile(warningMode: newValue)
                            appDelegate.switchWarningMode()
                        }

                    if warningMode.usesWarningOverlay {
                        InlineColorPicker(color: $warningColor)
                            .onChange(of: warningColor) { newValue in
                                let nsColor = NSColor(newValue)
                                settingsProfileManager.updateActiveProfile(warningColor: nsColor)
                                appDelegate.updateWarningColor(nsColor)
                            }
                    }
                }
                .frame(height: 26)

                CompactSlider(
                    title: L("settings.deadZone"),
                    helpText: L("settings.deadZone.help"),
                    value: $deadZoneSlider,
                    range: 0...4,
                    step: 1,
                    valueLabel: deadZoneLabels[Int(deadZoneSlider)]
                )
                .onChange(of: deadZoneSlider) { newValue in
                    let index = Int(newValue)
                    deadZone = deadZoneValues[index]
                    settingsProfileManager.updateActiveProfile(deadZone: deadZone)
                    appDelegate.applyActiveSettingsProfile()
                }

                CompactSlider(
                    title: L("settings.intensity"),
                    helpText: L("settings.intensity.help"),
                    value: $intensitySlider,
                    range: 0...4,
                    step: 1,
                    valueLabel: intensityLabels[Int(intensitySlider)]
                )
                .onChange(of: intensitySlider) { newValue in
                    let index = Int(newValue)
                    intensity = intensityValues[index]
                    settingsProfileManager.updateActiveProfile(intensity: intensity)
                    appDelegate.applyActiveSettingsProfile()
                }

                CompactSlider(
                    title: L("settings.delay"),
                    helpText: L("settings.delay.help"),
                    value: $warningOnsetDelay,
                    range: 0...30,
                    step: 1,
                    valueLabel: "\(Int(warningOnsetDelay))s"
                )
                .onChange(of: warningOnsetDelay) { newValue in
                    settingsProfileManager.updateActiveProfile(warningOnsetDelay: newValue)
                    appDelegate.applyActiveSettingsProfile()
                }

                CompactSlider(
                    title: L("settings.detection"),
                    helpText: L("settings.detection.help"),
                    value: $detectionModeSlider,
                    range: 0...2,
                    step: 1,
                    valueLabel: detectionModes[Int(detectionModeSlider)].displayName
                )
                .onChange(of: detectionModeSlider) { newValue in
                    let index = Int(newValue)
                    settingsProfileManager.updateActiveProfile(detectionMode: detectionModes[index])
                    appDelegate.applyActiveSettingsProfile()
                }
            }
        }
    }

    @ViewBuilder
    private var behaviorCardView: some View {
        SettingsCard(icon: "switch.2", title: L("settings.section.behavior")) {
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
            .help(L("settings.appearance"))
        } content: {
            VStack(spacing: 6) {
                HStack(spacing: 0) {
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

                    CompactToggle(
                        title: L("settings.showInDock"),
                        helpText: L("settings.showInDock.help"),
                        isOn: $showInDock
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: showInDock) { newValue in
                        appDelegate.showInDock = newValue
                        appDelegate.saveSettings()
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                        DispatchQueue.main.async {
                            appDelegate.settingsWindowController.window?.makeKeyAndOrderFront(nil)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                }

#if !APP_STORE
                HStack(spacing: 0) {
                    CompactToggle(
                        title: L("settings.compatibilityMode"),
                        helpText: L("settings.compatibilityMode.help"),
                        isOn: $useCompatibilityMode
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: useCompatibilityMode) { newValue in
                        appDelegate.useCompatibilityMode = newValue
                        appDelegate.saveSettings()
                        appDelegate.clearBlur()
                    }

                    Spacer()
                        .frame(maxWidth: .infinity)
                }
#endif

                HStack(spacing: 0) {
                    CompactToggle(
                        title: L("settings.pauseOnTheGo"),
                        helpText: L("settings.pauseOnTheGo.help"),
                        isOn: $pauseOnTheGo
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: pauseOnTheGo) { newValue in
                        Task { @MainActor in
                            await appDelegate.setPauseOnTheGoEnabled(newValue)
                        }
                    }

                    CompactToggle(
                        title: L("settings.pauseOnBattery"),
                        helpText: L("settings.pauseOnBattery.help"),
                        isOn: $pauseOnBattery
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: pauseOnBattery) { newValue in
                        Task { @MainActor in
                            await appDelegate.setPauseOnBatteryEnabled(newValue)
                        }
                    }
                }

                HStack(spacing: 0) {
                    CompactToggle(
                        title: L("settings.blurWhenAway"),
                        helpText: trackingSource == .airpods
                        ? L("settings.blurWhenAway.help.airpods")
                        : L("settings.blurWhenAway.help.camera"),
                        isOn: $blurWhenAway,
                        isDisabled: trackingSource == .airpods
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: blurWhenAway) { newValue in
                        appDelegate.blurWhenAway = newValue
                        appDelegate.saveSettings()
                    }

                    CompactToggle(
                        title: L("settings.fullScreenOverlay"),
                        helpText: L("settings.fullScreenOverlay.help"),
                        isOn: $useFullScreenOverlay
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: useFullScreenOverlay) { newValue in
                        appDelegate.useFullScreenOverlay = newValue
                        appDelegate.saveSettings()
                        appDelegate.rebuildOverlayWindows()
                    }
                }

                HStack(spacing: 0) {
                    CompactShortcutRecorder(
                        shortcut: $toggleShortcut,
                        isEnabled: $toggleShortcutEnabled,
                        onShortcutChange: {
                            appDelegate.toggleShortcutEnabled = toggleShortcutEnabled
                            appDelegate.toggleShortcut = toggleShortcut
                            appDelegate.saveSettings()
                            appDelegate.updateGlobalKeyMonitor()
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func handleProfileSelectionChange(_ newID: String) {
        guard !isApplyingProfileSelection, newID != lastSelectedSettingsProfileID else { return }
        isApplyingProfileSelection = true

        settingsProfileManager.selectProfile(id: newID)
        lastSelectedSettingsProfileID = newID
        appDelegate.applyActiveSettingsProfile()
        syncProfileStateToUI()

        isApplyingProfileSelection = false
    }

    private func createNewProfile() {
        let trimmedName = newProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newProfile = settingsProfileManager.createProfile(
            named: trimmedName,
            warningMode: warningMode,
            warningColor: NSColor(warningColor),
            deadZone: deadZone,
            intensity: intensity,
            warningOnsetDelay: warningOnsetDelay,
            detectionMode: detectionModes[Int(detectionModeSlider)]
        )

        refreshProfilesState(selectID: newProfile.id)
        newProfileName = ""
    }

    private func deleteCurrentProfile() {
        settingsProfileManager.deleteProfile(id: selectedSettingsProfileID)
        refreshProfilesState()
    }

    private func refreshProfilesState(selectID: String? = nil) {
        let snapshot = settingsProfileManager.profilesState()
        settingsProfiles = snapshot.profiles
        let targetID = selectID ?? snapshot.selectedID ?? settingsProfiles.first?.id ?? ""
        selectedSettingsProfileID = targetID
        lastSelectedSettingsProfileID = targetID
        syncProfileStateToUI()
    }

    private func syncProfileStateToUI() {
        guard let activeProfile = settingsProfileManager.activeProfile else { return }
        intensity = activeProfile.intensity
        deadZone = activeProfile.deadZone
        intensitySlider = Double(Self.closestIndex(for: activeProfile.intensity, in: intensityValues))
        deadZoneSlider = Double(Self.closestIndex(for: activeProfile.deadZone, in: deadZoneValues))
        warningMode = activeProfile.warningMode
        warningColor = Color(activeProfile.warningColor)
        warningOnsetDelay = activeProfile.warningOnsetDelay
        detectionModeSlider = Double(detectionModes.firstIndex(of: activeProfile.detectionMode) ?? 0)
    }
}

// MARK: - Settings Window Controller

public final class SettingsWindowController: NSWindowController {
    public convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.isReleasedWhenClosed = false
        window.title = "Settings"
        self.init(window: window)
    }

    public func showSettings(appDelegate: AppDelegate) {
        let settingsView = SettingsView(appDelegate: appDelegate)
        let hostingController = NSHostingController(rootView: settingsView)
        window?.contentViewController = hostingController
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Supporting Settings UI Controls

struct SettingsCard<HeaderExtra: View, Content: View>: View {
    let icon: String
    let title: String
    let helpText: String?
    let headerExtra: HeaderExtra
    let content: Content

    init(
        icon: String,
        title: String,
        helpText: String? = nil,
        @ViewBuilder headerExtra: () -> HeaderExtra,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.helpText = helpText
        self.headerExtra = headerExtra()
        self.content = content()
    }

    init(
        icon: String,
        title: String,
        helpText: String? = nil,
        @ViewBuilder content: () -> Content
    ) where HeaderExtra == EmptyView {
        self.icon = icon
        self.title = title
        self.helpText = helpText
        self.headerExtra = EmptyView()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.brandCyan)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))

                if let helpText {
                    HelpButton(text: helpText)
                }

                Spacer()
                headerExtra
            }

            content
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct CompactModePicker: View {
    @Binding var selection: TrackingMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach([TrackingMode.automatic, .manual], id: \.self) { mode in
                Button(action: { selection = mode }) {
                    Text(modeTitle(for: mode))
                        .font(.system(size: 10, weight: selection == mode ? .semibold : .regular))
                        .foregroundColor(selection == mode ? .onBrandCyan : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(selection == mode ? Color.brandCyan : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private func modeTitle(for mode: TrackingMode) -> String {
        switch mode {
        case .automatic:
            return L("settings.tracking.auto")
        case .manual:
            return L("settings.tracking.manual")
        }
    }
}

struct CompactTrackingSourcePicker: View {
    @Binding var selection: TrackingSource
    let airPodsAvailable: Bool

    var body: some View {
        Picker("", selection: $selection) {
            Text(L("source.camera")).tag(TrackingSource.camera)
            Text(L("source.airpods")).tag(TrackingSource.airpods)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

struct DeviceStatusRow: View {
    let source: TrackingSource
    let isCalibrated: Bool
    let isConnected: Bool
    let isPreferred: Bool
    let isActive: Bool
    var cameraDropdown: AnyView? = nil
    let onCalibrate: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: source == .camera ? "camera" : "airpodspro")
                .font(.system(size: 12))
                .foregroundColor(isActive ? .brandCyan : .secondary)

            Text(source == .camera ? L("source.camera") : L("source.airpods"))
                .font(.system(size: 11, weight: .medium))

            if isActive {
                Text(L("status.active"))
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.brandCyan)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.brandCyan.opacity(0.12)))
            }

            Spacer()

            if let cameraDropdown {
                cameraDropdown
            }

            Button(action: onCalibrate) {
                Text(isCalibrated ? L("common.recalibrate") : L("common.calibrate"))
                    .font(.system(size: 10, weight: .medium))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }
}

struct CompactWarningStylePicker: View {
    @Binding var selection: WarningMode

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(WarningMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .labelsHidden()
    }
}

struct InlineColorPicker: View {
    @Binding var color: Color

    var body: some View {
        ColorPicker("", selection: $color, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 24, height: 20)
    }
}

struct CompactSlider: View {
    let title: String
    let helpText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueLabel: String

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 11))
                    .frame(width: 82, alignment: .leading)
                HelpButton(text: helpText)
            }

            Slider(value: $value, in: range, step: step)

            Text(valueLabel)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .frame(height: 22)
    }
}

struct CompactSegmentedPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String)]

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.0) { option in
                Text(option.1).tag(option.0)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

struct CompactToggle: View {
    let title: String
    let helpText: String
    @Binding var isOn: Bool
    var isDisabled: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Toggle(isOn: $isOn) {
                Text(title)
                    .font(.system(size: 11))
            }
            .toggleStyle(.checkbox)
            .disabled(isDisabled)

            HelpButton(text: helpText)
        }
        .frame(height: 22)
    }
}

struct CompactShortcutRecorder: View {
    @Binding var shortcut: AppKeyboardShortcut
    @Binding var isEnabled: Bool
    let onShortcutChange: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Toggle(isOn: $isEnabled) {
                Text(L("settings.toggleShortcut"))
                    .font(.system(size: 11))
            }
            .toggleStyle(.checkbox)
            .onChange(of: isEnabled) { _ in onShortcutChange() }

            Spacer()

            Text(shortcut.displayString)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
        }
        .frame(height: 22)
    }
}

struct HelpButton: View {
    let text: String
    @State private var showingHelp = false

    var body: some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .help(text)
    }
}

struct GitHubIcon: View {
    let color: Color
    var body: some View {
        Image(systemName: "code")
            .font(.system(size: 11))
            .foregroundColor(color)
    }
}

struct DiscordIcon: View {
    let color: Color
    var body: some View {
        Image(systemName: "bubble.left.and.bubble.right")
            .font(.system(size: 11))
            .foregroundColor(color)
    }
}

// MARK: - App Delegate Extensions for Settings Integration

extension AppDelegate {
    func applyActiveSettingsProfile() {
        if activeWarningMode.usesWarningOverlay {
            syncWarningOverlaySettings()
        }
        applyDetectionMode()
    }

    func switchWarningMode() {
        if activeWarningMode.usesWarningOverlay {
            warningOverlayManager.setupOverlayWindows()
        }
        applyActiveSettingsProfile()
    }

    func updateWarningColor(_ color: NSColor) {
        warningOverlayManager.updateWarningColor(color)
    }

    func clearBlur() {
        targetBlurRadius = 0
        updateBlur()
    }

    func rebuildOverlayWindows() {
        setupOverlayWindows()
    }

    func setPauseOnTheGoEnabled(_ enabled: Bool) async {
        pauseOnTheGo = enabled
        saveSettings()
    }

    func setPauseOnBatteryEnabled(_ enabled: Bool) async {
        applyTrackingAction(.setPauseOnBatteryEnabled(enabled))
        saveSettings()
    }

    func updateGlobalKeyMonitor() {
        hotkeyManager.configure(
            enabled: toggleShortcutEnabled,
            shortcut: toggleShortcut,
            onToggle: { [weak self] in
                Task { @MainActor in
                    await self?.toggleEnabled()
                }
            }
        )
    }

    func setTrackingMode(_ mode: TrackingMode) async {
        trackingMode = mode
        saveSettings()
    }

    func switchTrackingSource(to source: TrackingSource) async {
        trackingSource = source
        saveSettings()
    }

    func setPreferredSource(_ source: TrackingSource) async {
        applyTrackingAction(.setPreferredSource(source))
        saveSettings()
    }

    func startCalibration(for source: TrackingSource? = nil) {
        calibratingSource = source ?? activeTrackingSource
        if calibrationController == nil {
            calibrationController = CalibrationWindowController()
        }
        calibrationController?.showWindow(nil)
    }

    func toggleEnabled() async {
        let newState = !state.isActive
        state = newState ? .active : .inactive
    }

    func syncWarningOverlaySettings() {
        warningOverlayManager.updateSettings(
            color: activeWarningColor,
            mode: activeWarningMode
        )
    }
}

// MARK: - SettingsProfileManager Extension

extension SettingsProfileManager {
    func createProfile(named name: String) -> SettingsProfile {
        let newProfile = SettingsProfile(
            name: name,
            warningMode: WarningDefaults.mode,
            warningColor: WarningDefaults.color,
            deadZone: 0.03,
            intensity: 1.0,
            warningOnsetDelay: 0.0,
            detectionMode: .balanced
        )
        addProfile(newProfile)
        return newProfile
    }
}
