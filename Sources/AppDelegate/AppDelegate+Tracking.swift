import AppKit
import os.log

private let log = OSLog(subsystem: "chill..PostureAI", category: "Tracking")

/// Context gathered at startup to decide between monitoring and onboarding.
struct InitialSetupContext {
    let profile: ProfileData?
    let profileCameraAvailable: Bool
    let hasValidAirPodsCalibration: Bool
}

// MARK: - Associated Property Box

private final class PostureUIStateBox {
    let value: PostureUIState
    init(_ value: PostureUIState) { self.value = value }
}

private struct AssociatedKeys {
    static var lastRenderedUIStateKey: UInt8 = 0
}

extension AppDelegate {

    // MARK: - Associated Storage

    @MainActor
    private var lastRenderedUIState: PostureUIState? {
        get {
            (objc_getAssociatedObject(self, &AssociatedKeys.lastRenderedUIStateKey) as? PostureUIStateBox)?.value
        }
        set {
            let box = newValue.map { PostureUIStateBox($0) }
            objc_setAssociatedObject(
                self,
                &AssociatedKeys.lastRenderedUIStateKey,
                box,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    // MARK: - Store Transition Application

    /// Applies the observable consequences of a tracking-store state change:
    /// state-machine transitions, detector start/stop, and UI refresh.
    func applyTrackingStoreTransition(
        from oldTrackingState: TrackingFeature.State,
        to newTrackingState: TrackingFeature.State,
        applyStateTransition: Bool = true
    ) {
        if applyStateTransition, oldTrackingState.appState != newTrackingState.appState {
            handleStateTransition(from: oldTrackingState.appState, to: newTrackingState.appState)
        } else if oldTrackingState.activeSource != newTrackingState.activeSource {
            syncDetectorToState()
            syncUIToState()
        } else if oldTrackingState.manualSource != newTrackingState.manualSource {
            syncDetectorToState()
        }
        if oldTrackingState.activeSource != newTrackingState.activeSource {
            onActiveSourceChanged?()
        }
    }

    private func handleStateTransition(from oldState: AppState, to newState: AppState) {
        os_log(.info, log: log, "State transition: %{public}@ -> %{public}@", String(describing: oldState), String(describing: newState))
        syncDetectorToState()
        if !newState.isActive {
            clearBlur()
            warningOverlayManager.targetIntensity = 0
            warningOverlayManager.updateWarning()
        }
        if newState == .monitoring {
            applyActiveSettingsProfile()
        }
        syncUIToState()
    }

    // MARK: - Detector and UI Sync

    func syncDetectorToState() {
        if let syncDetectorToStateOverride {
            syncDetectorToStateOverride()
            return
        }

        let activeSource = activeTrackingSource
        let shouldRun = PostureEngine.shouldDetectorRun(for: state, trackingSource: activeSource)
        let usingFusion = dualSensorEnabled

        // Always stop the other detector so in-flight starts are cancelled
        // even if that detector has not flipped isActive=true yet.
        // But don't stop a detector that's currently being calibrated.
        let calSource = calibratingSource
        let isAutomatic = trackingMode == .automatic
        if activeSource == .camera {
            if calSource != .airpods && !usingFusion {
                airPodsDetector.stop()
                // In automatic mode, keep AirPods connection monitoring alive
                // so we can detect when they're put back in for auto-return.
                if isAutomatic {
                    airPodsDetector.startConnectionMonitoring()
                }
            }
        } else {
            if calSource != .camera && !usingFusion { cameraDetector.stop() }
            if !usingFusion {
                // Stop connection-only monitoring since AirPods detector is now active
                airPodsDetector.stopConnectionMonitoring()
            }
        }

        // Start/stop the active detector
        if shouldRun {
            if !activeDetector.isActive {
                activeDetector.start { [weak self] success, error in
                    if !success, let error = error {
                        os_log(.error, log: log, "Failed to start detector: %{public}@", error)
                        Task { @MainActor in
                            guard let self else { return }
                            await self.sendTrackingAction(
                                .runtimeDetectorStartFailed(trackingSource: self.trackingSource)
                            )
                        }
                    }
                }
            }

            // Dual-sensor fusion: also run the secondary detector (when it is
            // calibrated) so AirPods tilt + camera positioning combine.
            if usingFusion {
                let secondary = dualSensorDetector
                let secondaryCalibration: CalibrationData? = dualSensorSource == .camera
                    ? cameraCalibration
                    : airPodsCalibration
                let secondaryReady = isMarketingMode || (secondaryCalibration?.isValid ?? false)
                if secondaryReady && !secondary.isActive {
                    secondary.start { success, error in
                        if !success, let error = error {
                            os_log(.error, log: log, "Failed to start secondary detector: %{public}@", error)
                        }
                    }
                }
                // Ensure the secondary detector evaluates readings (beginMonitoring
                // is idempotent, so this is safe to call on every sync).
                if let secondaryCalibration, secondaryCalibration.isValid {
                    secondary.beginMonitoring(
                        with: secondaryCalibration,
                        intensity: activeIntensity,
                        deadZone: activeDeadZone
                    )
                }
            }
        } else {
            // Always call stop() so in-flight starts are cancelled even if
            // the detector has not yet flipped isActive=true.
            activeDetector.stop()
            if usingFusion {
                dualSensorDetector.stop()
            }
        }
    }

    /// The secondary detector used in dual-sensor fusion mode.
    var dualSensorSource: TrackingSource {
        activeTrackingSource == .camera ? .airpods : .camera
    }

    var dualSensorDetector: PostureDetector {
        detector(for: dualSensorSource)
    }

    @MainActor
    func syncUIToState() {
        let uiState = PostureUIState.derive(
            from: state,
            isCalibrated: isCalibrated,
            isCurrentlyAway: isCurrentlyAway,
            isCurrentlySlouching: isCurrentlySlouching,
            trackingSource: activeTrackingSource,
            isOnFallback: trackingStore.withState { $0.isOnFallback }
        )

        // Notify observers (e.g. the Dashboard) of the latest UI state, even
        // when nothing menu-related changed, so they can refresh live status.
        NotificationCenter.default.post(name: .postureUIStateChanged, object: uiState)

        // Drive slouch alerts (notification + spatial sound).
        updateSlouchAlerts()

        // Drive the 20/20/20 break reminder countdown.
        breakReminderManager.update(isMonitoring: state == .monitoring)

        // Publish a compact snapshot for the desktop widget.
        let pauseReason: PauseReason? = {
            if case .paused(let reason) = state { return reason }
            return nil
        }()
        WidgetSnapshot.update(
            isMonitoring: state == .monitoring,
            isSlouching: isCurrentlySlouching,
            source: activeTrackingSource,
            pauseReason: pauseReason,
            minutesToday: WidgetSnapshot.todayMinutes(),
            nextBreakMinutes: breakReminderManager.nextBreakMinutesForWidget()
        )

        // DIFF CHECK: Only hit AppKit if the state actually changed!
        guard uiState != lastRenderedUIState else { return }
        lastRenderedUIState = uiState

        menuBarManager.updateStatus(text: uiState.statusText, icon: uiState.icon.menuBarIcon)
        menuBarManager.refreshNextBreak()
        menuBarManager.updateEnabledState(uiState.isEnabled)
        menuBarManager.updateRecalibrateEnabled(uiState.canRecalibrate)
    }

    /// Re-evaluates slouch alerts (notification + spatial sound) against the
    /// current slouch state and whether AirPods are the audio output. Alerts
    /// are suppressed while a screen break blur is on screen.
    @MainActor
    func updateSlouchAlerts() {
        guard !isScreenBreakActive else { return }
        postureAlertManager.update(
            isSlouching: isCurrentlySlouching,
            isAirPodsOutput: AudioOutput.isAirPodsOutput
        )
    }

    // MARK: - Screen Break (20/20/20 blur)

    /// Begins the screen break blur for the 20/20/20 reminder: the screen is
    /// blurred for the break duration while the user looks 20 feet away.
    func beginScreenBreak() {
        guard breakReminderEnabled, !isScreenBreakActive else { return }
        isScreenBreakActive = true
        screenBreakOverlayManager.show(duration: 20) { [weak self] in
            Task { @MainActor in
                self?.endScreenBreak()
            }
        }
    }

    /// Begins the screen break blur regardless of the 20/20/20 reminder
    /// setting, for explicit requests (e.g. a Shortcut action).
    func beginScreenBreakNow(durationSeconds: Int = 20) {
        guard !isScreenBreakActive else { return }
        isScreenBreakActive = true
        screenBreakOverlayManager.show(duration: durationSeconds) { [weak self] in
            Task { @MainActor in
                self?.endScreenBreak()
            }
        }
    }

    /// Schedules a screen break to begin after the given number of minutes,
    /// or starts it immediately when `inMinutes` is zero.
    func scheduleScreenBreak(inMinutes: Double, durationSeconds: Int) {
        breakScheduledTimer?.invalidate()
        breakScheduledTimer = nil
        guard inMinutes > 0 else {
            beginScreenBreakNow(durationSeconds: durationSeconds)
            return
        }
        breakScheduledTimer = Timer.scheduledTimer(withTimeInterval: inMinutes * 60, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.beginScreenBreakNow(durationSeconds: durationSeconds)
            }
        }
    }

    private func endScreenBreak() {
        isScreenBreakActive = false
        updateSlouchAlerts()
    }

    // MARK: - Single AirPod Detection

    /// Polls Bluetooth to detect when only one AirPod is in use (macOS does
    /// not expose which bud is worn, only the connection count). The Bluetooth
    /// query runs off the main thread (IOBluetooth can block), so this reads
    /// the cached result from the previous poll.
    func refreshSingleBudState() {
        airPodsDetector.refreshBluetoothState()
        let single = airPodsDetector.connectedAirPodsDeviceCount == 1
        guard single != isSingleBudInUse else { return }
        isSingleBudInUse = single
        NotificationCenter.default.post(name: .postureUIStateChanged, object: nil)
    }

    func updateSourceReadiness() {
        let cameraReadiness = TrackingSourceReadiness(
            permissionGranted: true,
            connected: !cameraDetector.getAvailableCameras().isEmpty,
            calibrated: cameraCalibration?.isValid ?? false,
            available: true
        )
        let airPodsReadiness = TrackingSourceReadiness(
            permissionGranted: true,
            connected: airPodsDetector.isConnected,
            calibrated: airPodsCalibration?.isValid ?? false,
            available: airPodsDetector.isAvailable
        )
        applyTrackingAction(.sourceReadinessChanged(source: .camera, readiness: cameraReadiness))
        applyTrackingAction(.sourceReadinessChanged(source: .airpods, readiness: airPodsReadiness))
    }

    // MARK: - Detector Setup

    func setupDetectors() {
        // Configure camera detector
        cameraDetector.blurWhenAway = blurWhenAway
        cameraDetector.baseFrameInterval = 1.0 / activeDetectionMode.frameRate

        cameraDetector.onPostureReading = { [weak self] reading in
            Task { @MainActor in
                await self?.handlePostureReading(reading)
            }
        }

        cameraDetector.onAwayStateChange = { [weak self] isAway in
            Task { @MainActor in
                await self?.handleAwayStateChange(isAway)
            }
        }

        // Configure AirPods detector
        airPodsDetector.onPostureReading = { [weak self] reading in
            Task { @MainActor in
                await self?.handlePostureReading(reading)
            }
        }

        airPodsDetector.onConnectionStateChange = { [weak self] isConnected in
            Task { @MainActor in
                await self?.handleConnectionStateChange(isConnected)
            }
        }
    }

    // MARK: - Detector Events

    private func handleConnectionStateChange(_ isConnected: Bool) async {
        let transition = await sendTrackingAction(.airPodsConnectionChanged(isConnected))

        if isConnected,
           transition.oldState.appState == .paused(.airPodsRemoved),
           transition.newState.appState == .monitoring {
            os_log(.info, log: log, "AirPods back in ears - resuming monitoring")
        } else if !isConnected,
                  transition.oldState.appState == .monitoring,
                  transition.newState.appState == .paused(.airPodsRemoved) {
            os_log(.info, log: log, "AirPods removed - pausing monitoring")
        }
    }

    private func handlePostureReading(_ reading: PostureReading) async {
        await sendTrackingAction(
            .postureReadingReceived(reading, isMarketingMode: isMarketingMode),
            applyStateTransition: false
        )
    }

    func handleAwayStateChange(_ isAway: Bool) async {
        await sendTrackingAction(
            .awayStateChanged(isAway, isMarketingMode: isMarketingMode),
            applyStateTransition: false
        )
    }

    // MARK: - Auto-Pause Events

    func handleMeetingStateChange(_ isInMeeting: Bool) async {
        applyTrackingAction(.meetingStateChanged(isInMeeting))
        syncUIToState()
    }

    func handleFocusStateChange(_ isInFocus: Bool) async {
        applyTrackingAction(.focusStateChanged(isInFocus))
        syncUIToState()
    }

    // MARK: - Enable/Disable

    func toggleEnabled() async {
        await sendTrackingAction(
            .toggleEnabled(
                trackingSource: trackingSource,
                isCalibrated: isCalibrated,
                detectorAvailable: activeDetector.isAvailable
            )
        )
        saveSettings()
    }

    // MARK: - Initial Setup Flow

    func initialSetupFlow() async {
        guard !setupComplete else { return }
        setupComplete = true

        updateSourceReadiness()
        let context = makeInitialSetupContext()
        await sendTrackingAction(
            .initialSetupEvaluated(
                isMarketingMode: isMarketingMode,
                hasCameraProfile: context.profile != nil,
                profileCameraAvailable: context.profileCameraAvailable,
                hasValidAirPodsCalibration: context.hasValidAirPodsCalibration,
                cameraProfile: context.profile
            )
        )

        // Seed the current power source so launching on battery honors
        // pause-on-battery without waiting for the first power transition.
        await sendTrackingAction(.powerSourceChanged(isOnBattery: powerSourceObserver.isOnBattery))
    }

    private func makeInitialSetupContext() -> InitialSetupContext {
        if let initialSetupContextOverride {
            return initialSetupContextOverride()
        }

        let configKey = DisplayMonitor.getCurrentConfigKey()
        let profile = loadProfile(forKey: configKey)
        let cameras = cameraDetector.getAvailableCameras()
        let profileCameraAvailable = profile.map { profile in
            cameras.contains(where: { $0.uniqueID == profile.cameraID })
        } ?? false

        return InitialSetupContext(
            profile: profile,
            profileCameraAvailable: profileCameraAvailable,
            hasValidAirPodsCalibration: airPodsCalibration?.isValid ?? false
        )
    }

    func showOnboarding() {
        onboardingWindowController = OnboardingWindowController()
        onboardingWindowController?.show(
            appDelegate: self,
            cameraDetector: cameraDetector,
            airPodsDetector: airPodsDetector
        ) { [weak self] source, cameraID in
            Task { @MainActor in
                guard let self else { return }

                await self.switchTrackingSource(to: source)
                if let cameraID = cameraID {
                    self.cameraDetector.selectedCameraID = cameraID
                }
                self.saveSettings()

                // Start calibration
                self.startCalibration()
            }
        }
    }

    // MARK: - Tracking Source Management

    func switchTrackingSource(to source: TrackingSource) async {
        let isNewSourceCalibrated: Bool
        switch source {
        case .camera:
            isNewSourceCalibrated = isMarketingMode || (cameraCalibration?.isValid ?? false)
        case .airpods:
            isNewSourceCalibrated = isMarketingMode || (airPodsCalibration?.isValid ?? false)
        }

        await sendTrackingAction(
            .switchTrackingSource(
                source,
                isNewSourceCalibrated: isNewSourceCalibrated
            )
        )
    }

    func setTrackingMode(_ mode: TrackingMode) async {
        updateSourceReadiness()
        await sendTrackingAction(.setTrackingMode(mode))
        saveSettings()
    }

    func setPreferredSource(_ source: TrackingSource) async {
        updateSourceReadiness()
        await sendTrackingAction(.setPreferredSource(source))
        saveSettings()
    }

    func setPauseOnTheGoEnabled(_ isEnabled: Bool) async {
        pauseOnTheGo = isEnabled
        saveSettings()
        await sendTrackingAction(.pauseOnTheGoSettingChanged(isEnabled: isEnabled))
    }

    func setPauseOnBatteryEnabled(_ isEnabled: Bool) async {
        await sendTrackingAction(.setPauseOnBatteryEnabled(isEnabled))
        saveSettings()
    }

    // MARK: - Monitoring

    func startMonitoring() async {
        let transition = await sendTrackingAction(
            .startMonitoringRequested(
                isMarketingMode: isMarketingMode,
                trackingSource: trackingSource,
                isCalibrated: isCalibrated,
                isConnected: activeDetector.isConnected
            )
        )

        // If a meeting/Focus is already active, pause immediately so the user
        // doesn't get a blur while presenting.
        if meetingPauseEnabled, videoCallDetector.isInMeeting,
           transition.newState.appState == .monitoring {
            applyTrackingAction(.meetingStateChanged(true))
        }
        if focusPauseEnabled, focusObserver.isInFocus,
           transition.newState.appState == .monitoring {
            applyTrackingAction(.focusStateChanged(true))
        }

        if transition.newState.appState == .paused(.airPodsRemoved) {
            os_log(.info, log: log, "AirPods not in ears - pausing instead of monitoring")
        }
    }

    // MARK: - Settings Profile

    func applyActiveSettingsProfile() {
        applyTrackingAction(
            .setPostureConfiguration(
                intensity: Double(activeIntensity),
                warningOnsetDelay: activeWarningOnsetDelay
            )
        )
        activeDetector.updateParameters(intensity: activeIntensity, deadZone: activeDeadZone)
        if dualSensorEnabled {
            dualSensorDetector.updateParameters(intensity: activeIntensity, deadZone: activeDeadZone)
        }
        applyDetectionMode()

        guard setupComplete else { return }

        if warningOverlayManager.mode != activeWarningMode {
            switchWarningMode()
        }

        let desiredColorData = activeSettingsProfile?.warningColorData
        if desiredColorData != appliedWarningColorData {
            appliedWarningColorData = desiredColorData
            updateWarningColor(activeWarningColor)
        }
    }
}
