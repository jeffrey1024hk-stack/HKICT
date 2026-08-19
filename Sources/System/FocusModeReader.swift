import Foundation

/// A Focus mode configured on this Mac.
struct FocusModeInfo: Identifiable, Equatable {
    let identifier: String
    let name: String
    var id: String { identifier }
}

/// Reads macOS Focus mode configuration.
///
/// NOTE: The user's Do Not Disturb database
/// (`~/Library/DoNotDisturb/DB/`) is owned by the Do Not Disturb system
/// service. Reading those files triggers the macOS "PostureAI would like to
/// access data from other apps" (App Management) consent prompt on launch, so
/// we deliberately do NOT read them. The public `INFocusStatusCenter` API is
/// used instead (see `FocusObserver`).
enum FocusModeReader {
    /// All Focus modes supported by this Mac, using the well-known system
    /// identifiers. Custom user modes are not listed because discovering them
    /// requires reading the Do Not Disturb database, which would trigger the
    /// App Management consent prompt.
    static func configuredModes() -> [FocusModeInfo] {
        defaultModes()
    }

    /// Well-known system Focus modes, used as a fallback when the
    /// configuration database cannot be read.
    static func defaultModes() -> [FocusModeInfo] {
        [
            FocusModeInfo(identifier: "com.apple.donotdisturb.mode.default", name: "Do Not Disturb"),
            FocusModeInfo(identifier: "com.apple.focus.work", name: "Work"),
            FocusModeInfo(identifier: "com.apple.focus.personal", name: "Personal"),
            FocusModeInfo(identifier: "com.apple.sleep.sleep-mode", name: "Sleep"),
            FocusModeInfo(identifier: "com.apple.focus.gaming", name: "Gaming"),
            FocusModeInfo(identifier: "com.apple.focus.fitness", name: "Fitness"),
            FocusModeInfo(identifier: "com.apple.focus.mindfulness", name: "Mindfulness"),
            FocusModeInfo(identifier: "com.apple.focus.reading", name: "Reading")
        ]
    }
}