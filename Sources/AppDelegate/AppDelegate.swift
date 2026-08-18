import AppKit
import AVFoundation
import Vision
import os.log
import ComposableArchitecture
import SwiftUI

extension String {
    /// Uses shared L() helper (bundle lookup + English fallbacks)
    var localized: String {
        L(self)
    }
}

extension LocalizedStringKey {
    /// Helper for SwiftUI views using SPM Bundle.module
    static func module(_ key: String) -> LocalizedStringKey {
        LocalizedStringKey(key)
    }
}

// MARK: - Posture State Store for Shortcuts

@MainActor
public final class PostureStateStore {
    public static let shared = PostureStateStore()
    
    public var currentStatus: String = "inactive"
    public var isSlouching: Bool = false
    
    private init() {}
    
    public func update(isSlouching: Bool, isActive: Bool) {
        self.isSlouching = isSlouching
        if !isActive {
            self.currentStatus = "inactive"
        } else {
            self.currentStatus = isSlouching ? "bad" : "good"
        }
    }
}

// MARK: - MenuBarIconType Conversion

extension MenuBarIconType {
    var menuBarIcon: MenuBarIcon {
        switch self {
        case .good: return .good
        case .bad: return .bad
        case .away: return .away
        case .paused: return .paused
        case .calibrating: return .calibrating
        }
    }
}

// MARK: - App Delegate

@MainActor
public class AppDelegate: NSObject, NSApplicationDelegate {
    public override init() {
        super.init()
    }

    // UI Components
    let menuBarManager = MenuBarManager()

    // Overlay windows and blur
    var windows: [NSWindow] = []
    var blurViews: [NSVisualEffectView] = []
    var currentBlurRadius: Int32 = 0
    var targetBlurRadius: Int32 = 0
    private var blurAnimationTimer: Timer?

    // Warning overlay (alternative to blur)
    var warningOverlayManager = WarningOverlayManager()
    let settingsProfileManager = SettingsProfileManager()
    var appliedWarningColorData: Data?

    // MARK: - Posture Detectors

    let cameraDetector = CameraPostureDetector()
    let airPodsDetector = AirPodsPostureDetector()

    func detector(for source: TrackingSource) -> PostureDetector {
        source == .camera ? cameraDetector : airPodsDetector
    }

    var activeDetector: PostureDetector {
        detector(for: activeTrackingSource)
    }

    var activeTrackingSource: TrackingSource {
        trackingStore.withState { $0.activeSource }
    }

    var trackingSource: TrackingSource {
        get { trackingStore.withState { $0.manualSource } }
        set {
            guard trackingStore.withState({ $0.manualSource }) != newValue else { return }
            applyTrackingAction(.setManualSource(newValue))
        }
    }

    var trackingMode: TrackingMode {
        get { trackingStore.withState { $0.trackingMode } }
        set { applyTrackingAction(.setTrackingMode(newValue)) }
    }

    // Calibration data storage
    var cameraCalibration: CameraCalibrationData?
    var airPodsCalibration: AirPodsCalibrationData?
    /// Which source is currently being calibrated (nil when not calibrating)
    var calibratingSource: TrackingSource?
    /// Called when calibration completes successfully (for UI refresh)
    var onCalibrationComplete: (() -> Void)?
    /// Called when active source changes (for UI refresh)
    var onActiveSourceChanged: (() -> Void)?

    var currentCalibration: CalibrationData? {
        activeTrackingSource == .camera ? cameraCalibration : airPodsCalibration
    }

    // Legacy camera ID accessor for settings
    var selectedCameraID: String? {
        get { cameraDetector.selectedCameraID }
        set { cameraDetector.selectedCameraID = newValue }
    }

    // Calibration
    var calibrationController: CalibrationWindowController?
    var isCalibrated: Bool {
        isMarketingMode || (currentCalibration?.isValid ?? false)
    }

    // Settings
    var useCompatibilityMode = false
    var blurWhenAway = false {
        didSet {
            cameraDetector.blurWhenAway = blurWhenAway
            if !blurWhenAway {
                Task { @MainActor in
                    await self.handleAwayStateChange(false)
                }
            }
        }
    }
    var showInDock = false
    var appAppearance = AppAppearance.auto
    var pauseOnTheGo = false
    var pauseOnBattery: Bool {
        trackingStore.withState { $0.pauseOnBatteryEnabled }
    }
    var useFullScreenOverlay = false
    var settingsWindowController = SettingsWindowController()
    var supportWindowController = SupportWindowController()
    var analyticsWindowController: AnalyticsWindowController?
    var onboardingWindowController: OnboardingWindowController?
    var dashboardWindow: NSWindow?

    // Observers and monitors
    let displayMonitor = DisplayMonitor()
    let cameraObserver = CameraObserver()
    let screenLockObserver = ScreenLockObserver()
    let powerSourceObserver = PowerSourceObserver()
    let hotkeyManager = HotkeyManager()

    lazy var trackingStore: StoreOf<TrackingFeature> = {
        Store(initialState: TrackingFeature.State()) {
            TrackingFeature()
        } withDependencies: { [weak self] dependencies in
            dependencies.trackingRuntime.perform = { [weak self] intent in
                await self?.performTrackingEffect(intent)
            }
        }
    }()

    // MARK: - Test Seams

    var trackingEffectIntentObserver: ((TrackingFeature.EffectIntent) -> Void)?
    var calibrationPermissionDeniedAlertDecision: ((TrackingSource) -> Bool)?
    var cameraCalibrationRetryAlertDecision: ((String?) -> Bool)?
    var openPrivacySettingsHandler: (() -> Void)?
    var openSupportURLHandler: ((URL) -> Void)?
    var retryCalibrationHandler: (() -> Void)?
    var beginMonitoringSessionHandler: (() -> Void)?
    var showOnboardingHandler: (() -> Void)?
    var initialSetupContextOverride: (() -> InitialSetupContext)?
    var syncDetectorToStateOverride: (() -> Void)?

    // Convenience accessors into tracking store
    var isCurrentlySlouching: Bool {
        trackingStore.withState { $0.monitoringState.isCurrentlySlouching }
    }
    var isCurrentlyAway: Bool {
        trackingStore.withState { $0.monitoringState.isCurrentlyAway }
    }
    var postureWarningIntensity: CGFloat {
        trackingStore.withState { $0.monitoringState.postureWarningIntensity }
    }

    // Global keyboard shortcut
    var toggleShortcutEnabled = true
    var toggleShortcut: AppKeyboardShortcut = .defaultShortcut

    // Frame throttling
    var frameInterval: TimeInterval {
        isCurrentlySlouching ? 0.1 : (1.0 / activeDetectionMode.frameRate)
    }

    var activeSettingsProfile: SettingsProfile? {
        settingsProfileManager.activeProfile
    }

    var activeWarningMode: WarningMode {
        activeSettingsProfile?.warningMode ?? .blur
    }

    var activeWarningColor: NSColor {
        activeSettingsProfile?.warningColor ?? WarningDefaults.color
    }

    var activeDeadZone: CGFloat {
        CGFloat(activeSettingsProfile?.deadZone ?? 0.03)
    }

    var activeIntensity: CGFloat {
        CGFloat(activeSettingsProfile?.intensity ?? 1.0)
    }

    var activeWarningOnsetDelay: Double {
        activeSettingsProfile?.warningOnsetDelay ?? 0.0
    }

    var activeDetectionMode: DetectionMode {
        activeSettingsProfile?.detectionMode ?? .balanced
    }

    var setupComplete = false
    var marketingModeOverride: Bool?

    var isMarketingMode: Bool {
        if let marketingModeOverride {
            return marketingModeOverride
        }
        return UserDefaults.standard.bool(forKey: "MarketingMode")
            || CommandLine.arguments.contains("--marketing-mode")
    }

    // MARK: - State Machine

    var state: AppState {
        get { trackingStore.withState { $0.appState } }
        set {
            guard trackingStore.withState({ $0.appState }) != newValue else { return }
            applyTrackingAction(.setAppState(newValue))
        }
    }

    // MARK: - Tracking Store Dispatch

    @discardableResult
    func applyTrackingAction(
        _ action: TrackingFeature.Action,
        applyStateTransition: Bool = true
    ) -> (oldState: TrackingFeature.State, newState: TrackingFeature.State) {
        let oldState = trackingStore.withState { $0 }
        trackingStore.send(action)
        let newState = trackingStore.withState { $0 }
        applyTrackingStoreTransition(
            from: oldState,
            to: newState,
            applyStateTransition: applyStateTransition
        )
        return (oldState, newState)
    }

    @discardableResult
    func sendTrackingAction(
        _ action: TrackingFeature.Action,
        applyStateTransition: Bool = true
    ) async -> (oldState: TrackingFeature.State, newState: TrackingFeature.State) {
        let oldState = trackingStore.withState { $0 }
        let storeTask = trackingStore.send(action)
        await storeTask.finish()
        let newState = trackingStore.withState { $0 }
        applyTrackingStoreTransition(
            from: oldState,
            to: newState,
            applyStateTransition: applyStateTransition
        )
        return (oldState, newState)
    }

    // MARK: - Reducer Effect Execution

    func performTrackingEffect(_ intent: TrackingFeature.EffectIntent) async {
        trackingEffectIntentObserver?(intent)

        switch intent {
        case .startMonitoring:
            await startMonitoring()

        case .beginMonitoringSession:
            if let beginMonitoringSessionHandler {
                beginMonitoringSessionHandler()
                return
            }
            guard let calibration = currentCalibration else { return }
            activeDetector.beginMonitoring(
                with: calibration,
                intensity: activeIntensity,
                deadZone: activeDeadZone
            )

        case .applyStartupCameraProfile(let profile):
            guard let profile else { return }
            cameraDetector.selectedCameraID = profile.cameraID
            applyCameraCalibration(from: profile)

        case .showOnboarding:
            if let showOnboardingHandler {
                showOnboardingHandler()
            } else {
                showOnboarding()
            }

        case .switchCamera(.matchingProfile(let profile)):
            guard let profile else { return }
            cameraDetector.selectedCameraID = profile.cameraID
            applyCameraCalibration(from: profile)
            cameraDetector.switchCamera(to: profile.cameraID)

        case .switchCamera(.fallback(let cameraID, let profile)):
            guard let cameraID else { return }
            cameraDetector.selectedCameraID = cameraID
            if let profile, profile.cameraID == cameraID {
                applyCameraCalibration(from: profile)
            }
            cameraDetector.switchCamera(to: cameraID)

        case .switchCamera(.selectedCamera):
            guard let selectedCameraID else { return }
            cameraDetector.switchCamera(to: selectedCameraID)

        case .syncUI:
            syncUIToState()
            updateShortcutsState()

        case .updateBlur:
            updateBlur()
            updateShortcutsState()

        case .trackAnalytics(let interval, let isSlouching):
            AnalyticsManager.shared.trackTime(interval: interval, isSlouching: isSlouching)

        case .recordSlouchEvent:
            AnalyticsManager.shared.recordSlouchEvent()

        case .stopDetector(let source):
            detector(for: source).stop()

        case .persistTrackingSource:
            saveSettings()

        case .showCalibrationPermissionDeniedAlert:
            await showCalibrationPermissionDeniedAlert()

        case .openPrivacySettings:
            openPrivacySettings()

        case .showCameraCalibrationRetryAlert(let message):
            await showCameraCalibrationRetryAlert(message: message)

        case .retryCalibration:
            if let retryCalibrationHandler {
                retryCalibrationHandler()
            } else {
                startCalibration()
            }
        }
    }

    func applyCameraCalibration(from profile: ProfileData) {
        cameraCalibration = CameraCalibrationData(
            goodPostureY: profile.goodPostureY,
            badPostureY: profile.badPostureY,
            neutralY: profile.neutralY,
            postureRange: profile.postureRange,
            cameraID: profile.cameraID
        )
    }

    // MARK: - Appearance

    func applyAppearance() {
        NSApp.appearance = appAppearance.nsAppearance
    }

    // MARK: - App Lifecycle

    public func applicationDidFinishLaunching(_ notification: Notification) {
        _ = AnalyticsManager.shared

        UserDefaults.standard.register(defaults: ["NSInitialToolTipDelay": 250])

        loadSettings()
        applyAppearance()

        if showInDock {
            NSApp.setActivationPolicy(.regular)
        }

        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let icon = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = applyMacOSIconMask(to: icon)
        }

        setupDetectors()
        setupMenuBar()
        withAccessoryActivationPolicy {
            setupOverlayWindows()
            syncWarningOverlaySettings()
            appliedWarningColorData = activeSettingsProfile?.warningColorData
            if activeWarningMode.usesWarningOverlay {
                warningOverlayManager.setupOverlayWindows()
            }
        }

        setupObservers()
        startBlurDisplayLink()

        // Sync default posture state for Shortcuts on launch
        updateShortcutsState()

        if isMarketingMode {
            AnalyticsManager.shared.injectMarketingData()
        }

        if CommandLine.arguments.contains("--open-settings") {
            if CommandLine.arguments.contains("--appearance-dark") {
                NSApp.appearance = NSAppearance(named: .darkAqua)
            } else if CommandLine.arguments.contains("--appearance-light") {
                NSApp.appearance = NSAppearance(named: .aqua)
            }
            openSettings()
            return
        }

        Task { @MainActor in
            await self.initialSetupFlow()
        }
    }

    @objc public func openDashboard() {
        if dashboardWindow == nil {
            let dashboardView = ModernDashboardView(appDelegate: self)
            let hostingController = NSHostingController(rootView: dashboardView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 850, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            window.center()
            window.contentViewController = hostingController
            window.title = "PostureAI Dashboard"
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            
            dashboardWindow = window
        }
        
        NSApp.setActivationPolicy(.regular)
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menuBarManager.statusItem.button?.performClick(nil)
        return false
    }

    deinit {
        blurAnimationTimer?.invalidate()
    }

    private func startBlurDisplayLink() {
        blurAnimationTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.currentBlurRadius != self.targetBlurRadius else { return }
                self.updateBlur()
            }
        }
    }

    // MARK: - Observers Setup

    private func setupObservers() {
        displayMonitor.onDisplayConfigurationChange = { [weak self] in
            Task { @MainActor in
                await self?.handleDisplayConfigurationChange()
            }
        }
        displayMonitor.startMonitoring()

        cameraObserver.onCameraConnected = { [weak self] device in
            Task { @MainActor in
                await self?.handleCameraConnected(device)
            }
        }
        cameraObserver.onCameraDisconnected = { [weak self] device in
            Task { @MainActor in
                await self?.handleCameraDisconnected(device)
            }
        }
        cameraObserver.startObserving()

        screenLockObserver.onScreenLocked = { [weak self] in
            Task { @MainActor in
                await self?.handleScreenLocked()
            }
        }
        screenLockObserver.onScreenUnlocked = { [weak self] in
            Task { @MainActor in
                await self?.handleScreenUnlocked()
            }
        }
        screenLockObserver.startObserving()

        powerSourceObserver.onPowerSourceChanged = { [weak self] isOnBattery in
            Task { @MainActor in
                await self?.handlePowerSourceChanged(isOnBattery)
            }
        }
        powerSourceObserver.startObserving()

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

    // MARK: - Menu Bar Setup

    private func setupMenuBar() {
        menuBarManager.setup()
        menuBarManager.updateShortcut(enabled: toggleShortcutEnabled, shortcut: toggleShortcut)

        menuBarManager.onToggleEnabled = { [weak self] in
            Task { @MainActor in await self?.toggleEnabled() }
        }

        menuBarManager.onOpenSettings = { [weak self] in
            self?.openDashboard()
        }

        menuBarManager.onShowAnalytics = { [weak self] in
            self?.showAnalytics()
        }

        menuBarManager.onRecalibrate = { [weak self] in
            self?.startCalibration()
        }

        menuBarManager.onQuit = { [weak self] in
            NSApp.terminate(nil)
        }
    }

    // MARK: - Window Management

    private func showAnalytics() {
        if analyticsWindowController == nil {
            analyticsWindowController = AnalyticsWindowController()
        }
        analyticsWindowController?.appDelegate = self
        analyticsWindowController?.showWindow(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc public func openSettings() {
        openDashboard()
    }
}

// MARK: - Helpers & Extension Methods

extension AppDelegate {

    @objc func quit() {
        blurAnimationTimer?.invalidate()
        blurAnimationTimer = nil
        cameraDetector.stop()
        airPodsDetector.stop()
        NSApplication.shared.terminate(nil)
    }

    @objc func showSupport() {
        supportWindowController.showSupport(appDelegate: self, fromStatusItem: menuBarManager.statusItem)
    }

    func openSupportPage() {
        guard let url = URL(string: "https://github.com/jeffrey1024hk-stack/HKICT") else { return }

        if let openSupportURLHandler = self.openSupportURLHandler {
            openSupportURLHandler(url)
            return
        }

        NSWorkspace.shared.open(url)
    }

    func updateShortcutsState() {
        PostureStateStore.shared.update(
            isSlouching: isCurrentlySlouching,
            isActive: state.isActive
        )
    }

    // MARK: - Activation Policy

    func restoreAccessoryActivationPolicyIfNeeded(excluding windowToIgnore: NSWindow? = nil) {
        guard !showInDock else { return }

        let hasOtherVisibleTitledWindows = NSApp.windows.contains { window in
            guard window != windowToIgnore else { return false }
            return window.isVisible && !window.isMiniaturized && window.styleMask.contains(.titled)
        }

        if !hasOtherVisibleTitledWindows {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func withAccessoryActivationPolicy(_ block: () -> Void) {
        let current = NSApp.activationPolicy()
        if current != .accessory {
            let previousKeyWindow = NSApp.keyWindow
            NSApp.setActivationPolicy(.accessory)
            block()
            NSApp.setActivationPolicy(current)
            if let previousKeyWindow {
                NSApp.activate(ignoringOtherApps: true)
                previousKeyWindow.makeKeyAndOrderFront(nil)
            }
        } else {
            block()
        }
    }

    // MARK: - Camera Management

    func getAvailableCameras() -> [AVCaptureDevice] {
        return cameraDetector.getAvailableCameras()
    }

    func restartCamera() {
        guard activeTrackingSource == .camera, selectedCameraID != nil else { return }

        Task { @MainActor in
            await self.applyCameraSelectionTransition()
        }
    }

    func applyDetectionMode() {
        cameraDetector.baseFrameInterval = 1.0 / activeDetectionMode.frameRate
    }
}
