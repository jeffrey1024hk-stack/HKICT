import AppKit
import Intents
import os.log

/// Observes whether macOS Focus (Do Not Disturb) is active and reports the
/// on/off state.
///
/// Detection uses the public `INFocusStatusCenter` API. The app only requests
/// the Focus privacy permission (listed under Privacy & Security → Focus) —
/// it never reads the Do Not Disturb database, so no App Management permission
/// is involved.
///
/// macOS exposes only `isFocused` (whether any Focus mode is active), never
/// which mode. The Auto Pause setting is therefore a single "pause while a
/// Focus mode is active" toggle rather than a per-mode selection.
private let log = OSLog(subsystem: "chill..PostureAI", category: "Focus")

@MainActor
final class FocusObserver {
    private(set) var isInFocus = false
    var onFocusStateChange: ((Bool) -> Void)?

    private var timer: Timer?
    private var didRequestAuthorization = false

    func startMonitoring() {
        guard timer == nil else { return }
        requestAuthorizationIfNeeded()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Re-checks the Focus state immediately (e.g. after enabling the setting).
    func reevaluate() {
        refresh()
    }

    /// Requests the Focus privacy permission the first time. The app only
    /// shows up under Privacy & Security → Focus once it has requested access,
    /// and unauthorized apps don't receive a Focus status value at all.
    private func requestAuthorizationIfNeeded() {
        let center = INFocusStatusCenter.default
        guard center.authorizationStatus == .notDetermined, !didRequestAuthorization else { return }
        didRequestAuthorization = true
        os_log(.info, log: log, "Requesting Focus Status authorization")
        center.requestAuthorization { [weak self] status in
            os_log(.info, log: log, "Focus Status authorization: %{public}@", String(describing: status))
            Task { @MainActor in
                self?.refresh()
            }
        }
    }

    private func refresh() {
        let focused = INFocusStatusCenter.default.focusStatus.isFocused == true
        guard focused != isInFocus else { return }
        os_log(.info, log: log, "Focus state changed: %{public}@", focused ? "active" : "inactive")
        isInFocus = focused
        onFocusStateChange?(focused)
    }
}
