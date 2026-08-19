import AppKit
import Intents
import os.log

/// Observes which macOS Focus (Do Not Disturb) mode is active and reports
/// whether it is one the user has selected to pause during.
///
/// Detection uses the public `INFocusStatusCenter` API, which reports whether
/// *any* Focus mode is active. Reading the Do Not Disturb database to identify
/// the exact active mode would trigger the macOS "access data from other apps"
/// (App Management) consent prompt, so it is deliberately avoided. Pausing
/// only matches the default Do Not Disturb mode, which is what this API
/// reports for.
private let log = OSLog(subsystem: "chill..PostureAI", category: "Focus")

@MainActor
final class FocusObserver {
    private(set) var isInFocus = false
    var onFocusStateChange: ((Bool) -> Void)?

    /// The Focus mode identifiers the user wants to pause during.
    /// An empty set means never pause (feature effectively off).
    var selectedModeIdentifiers: Set<String> = []

    private var timer: Timer?

    func startMonitoring() {
        guard timer == nil else { return }
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

    private func refresh() {
        let focused = currentFocusMatchesSelection()
        guard focused != isInFocus else { return }
        os_log(.info, log: log, "Focus state changed: %{public}@", focused ? "matching active" : "inactive")
        isInFocus = focused
        onFocusStateChange?(focused)
    }

    private func currentFocusMatchesSelection() -> Bool {
        guard !selectedModeIdentifiers.isEmpty else { return false }

        // Public API only says "some Focus is active". Pause only if the user
        // selected the default Do Not Disturb mode, which is what this reports
        // for.
        let anyFocusActive = INFocusStatusCenter.default.focusStatus.isFocused ?? false
        guard anyFocusActive else { return false }
        return selectedModeIdentifiers.contains("com.apple.donotdisturb.mode.default")
    }
}