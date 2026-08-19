import Foundation

/// A Focus mode the user can pause during.
struct FocusModeInfo: Identifiable, Equatable {
    let identifier: String
    let name: String
    var id: String { identifier }
}

/// The standard set of macOS Focus modes and their identifiers.
///
/// The app deliberately does NOT read Apple's Do Not Disturb database
/// (`~/Library/DoNotDisturb/DB/`) — that would require the App Data Management
/// / App Management privacy permission and trigger the "access data from other
/// apps" consent prompt, which makes users feel the app is unsafe. Instead it
/// relies only on the Focus privacy permission: `FocusObserver` reads the
/// currently active mode identifier via `INFocusStatusCenter` (public API) and
/// matches it against the identifiers the user selects from this list.
enum FocusModeReader {
    /// The modes offered in the Auto Pause tab. The user selects which ones to
    /// pause during; the app matches the active mode identifier (from
    /// `INFocusStatusCenter`) against the selection.
    static func configuredModes() -> [FocusModeInfo] {
        defaultModes()
    }

    /// Well-known system Focus modes with their stable identifiers.
    static func defaultModes() -> [FocusModeInfo] {
        [
            FocusModeInfo(identifier: "com.apple.donotdisturb.mode.default", name: "Do Not Disturb"),
            FocusModeInfo(identifier: "com.apple.focus.reduce-interruptions", name: "Reduce Interruptions"),
            FocusModeInfo(identifier: "com.apple.sleep.sleep-mode", name: "Sleep"),
            FocusModeInfo(identifier: "com.apple.focus.work", name: "Work"),
            FocusModeInfo(identifier: "com.apple.focus.personal-time", name: "Personal"),
            FocusModeInfo(identifier: "com.apple.focus.reading", name: "Reading"),
            FocusModeInfo(identifier: "com.apple.focus.gaming", name: "Gaming"),
            FocusModeInfo(identifier: "com.apple.donotdisturb.mode.workout", name: "Fitness"),
            FocusModeInfo(identifier: "com.apple.focus.mindfulness", name: "Mindfulness"),
            FocusModeInfo(identifier: "com.apple.donotdisturb.mode.driving", name: "Driving")
        ]
    }
}