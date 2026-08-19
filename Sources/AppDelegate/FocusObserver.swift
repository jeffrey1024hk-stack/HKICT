import AppKit
import Intents
import os.log

/// Observes which macOS Focus (Do Not Disturb) mode is active and reports
/// whether it is one the user has selected to pause during.
///
/// Detection uses the public `INFocusStatusCenter` API, which reports whether
/// any Focus mode is active and the identifier of the active mode. The app
/// only requests the Focus privacy permission (listed under Privacy & Security
/// → Focus) — it never reads the Do Not Disturb database, so no App Management
/// permission is involved.
private let log = OSLog(subsystem: "chill..PostureAI", category: "Focus")

@MainActor
final class FocusObserver {
    private(set) var isInFocus = false
    var onFocusStateChange: ((Bool) -> Void)?

    /// The Focus mode identifiers the user wants to pause during.
    /// An empty set means never pause (feature effectively off).
    var selectedModeIdentifiers: Set<String> = []

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
        let focused = currentFocusMatchesSelection()
        guard focused != isInFocus else { return }
        os_log(.info, log: log, "Focus state changed: %{public}@", focused ? "matching active" : "inactive")
        isInFocus = focused
        onFocusStateChange?(focused)
    }

    private func currentFocusMatchesSelection() -> Bool {
        guard !selectedModeIdentifiers.isEmpty else { return false }

        // The public API only reports whether *any* Focus mode is active, not
        // which one, so pause whenever Focus is on and the user selected at
        // least one mode to pause during.
        let status = INFocusStatusCenter.default.focusStatus
        return status.isFocused == true
    }
}