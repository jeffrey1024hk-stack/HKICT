import AppKit
import os.log

/// Gentle screen break reminder (20/20/20): every `intervalMinutes` of active
/// monitoring, blur the screen for a short break and prompt the user to look
/// 20 feet away for 20 seconds.
@MainActor
final class BreakReminderManager {
    /// Whether the break reminder is enabled.
    var enabled = true
    /// Interval in minutes between reminders. Default 20 (20/20/20 rule).
    var intervalMinutes: Double = 20
    /// Called when a break should start (the AppDelegate shows the blur).
    var onBreakStart: (() -> Void)?

    private var timer: Timer?
    private var isMonitoring = false
    private let log = OSLog(subsystem: "chill..PostureAI", category: "BreakReminder")

    /// Called on every UI sync with the current monitoring state.
    /// Starts a fresh countdown when monitoring begins, stops when it ends.
    func update(isMonitoring: Bool) {
        guard isMonitoring != self.isMonitoring else { return }
        self.isMonitoring = isMonitoring
        restart()
    }

    /// Restarts the countdown (used after enabling or changing the interval).
    func restart() {
        timer?.invalidate()
        timer = nil
        guard enabled, isMonitoring else { return }
        scheduleNext()
    }

    /// Seconds until the next break fires, or nil when no break is scheduled.
    var secondsUntilNextBreak: TimeInterval? {
        guard let fireDate = timer?.fireDate else { return nil }
        return max(0, fireDate.timeIntervalSinceNow)
    }

    /// Whole minutes until the next break (for the widget), or 0 when no
    /// break is scheduled.
    func nextBreakMinutesForWidget() -> Int {
        guard let seconds = secondsUntilNextBreak else { return 0 }
        return max(1, Int(ceil(seconds / 60)))
    }

    private func scheduleNext() {
        let interval = max(1, intervalMinutes) * 60
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.enabled, self.isMonitoring else { return }
                self.onBreakStart?()
                self.scheduleNext()
            }
        }
    }
}