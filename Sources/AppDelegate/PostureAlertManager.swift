import AppKit
import UserNotifications

// MARK: - Alert Sound Mode

enum AlertSoundMode: String {
    case off = "off"
    case on = "on"
    case airpodsOnly = "airpodsOnly"
}

// MARK: - Notification Presentation

private final class PostureNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    /// Show the banner even when PostureAI is the frontmost/active app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

// MARK: - Posture Alert Manager

/// Handles the two optional slouch alerts:
/// 1. A macOS notification shown while slouching (removed on good posture).
/// 2. A soft, repeating tone played while slouching.
@MainActor
final class PostureAlertManager {
    var showAlertEnabled = true
    var soundMode: AlertSoundMode = .on
    /// When enabled, speaks "Sit up straight" after 5s of slouching instead of
    /// playing the repeating tone.
    var voiceAnnouncementEnabled = false

    private let alertIdentifier = "PostureAI.SlouchAlert"
    private let notificationDelegate = PostureNotificationDelegate()
    private var hasActiveAlert = false
    private var soundPlayer: NSSound?

    // Voice announcement (only after 5 continuous seconds of slouching)
    private let voiceDelay: TimeInterval = 5
    private var isSlouchingNow = false
    private var hasAnnouncedForSlouch = false
    private var voiceTimer: Timer?
    private let speechSynthesizer = NSSpeechSynthesizer()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    /// Requests notification permission up front (called at launch) so the
    /// first slouch alert can be delivered without waiting for a prompt.
    func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
    }

    /// Fully re-evaluates both alerts against the current slouch state.
    /// Idempotent, so it is safe to call on every UI-state sync and after
    /// settings changes.
    func update(isSlouching: Bool, isAirPodsOutput: Bool) {
        isSlouchingNow = isSlouching
        if isSlouching {
            if showAlertEnabled {
                presentAlertIfNeeded()
            } else {
                dismissAlertIfNeeded()
            }
            if voiceAnnouncementEnabled && shouldPlayVoice(isAirPodsOutput: isAirPodsOutput) {
                stopSound()
                scheduleVoiceAnnouncementIfNeeded()
            } else {
                updateSound(isAirPodsOutput: isAirPodsOutput)
                cancelVoiceAnnouncement()
            }
        } else {
            dismissAlertIfNeeded()
            stopSound()
            cancelVoiceAnnouncement()
        }
    }

    // MARK: - Voice Announcement

    /// Voice announcements respect the same Off / On / AirPods-only routing as
    /// the spatial sound tone.
    private func shouldPlayVoice(isAirPodsOutput: Bool) -> Bool {
        switch soundMode {
        case .off: return false
        case .on: return true
        case .airpodsOnly: return isAirPodsOutput
        }
    }

    private func scheduleVoiceAnnouncementIfNeeded() {
        guard !hasAnnouncedForSlouch, voiceTimer == nil else { return }
        voiceTimer = Timer.scheduledTimer(withTimeInterval: voiceDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.voiceAnnouncementEnabled, self.isSlouchingNow else { return }
                self.speakSitUp()
                self.hasAnnouncedForSlouch = true
                self.voiceTimer = nil
            }
        }
    }

    private func speakSitUp() {
        speechSynthesizer.stopSpeaking()
        speechSynthesizer.startSpeaking(L("voice.sitUpStraight"))
    }

    private func cancelVoiceAnnouncement() {
        voiceTimer?.invalidate()
        voiceTimer = nil
        hasAnnouncedForSlouch = false
    }

    // MARK: - Daily Start-Monitoring Reminder

    /// Posts a "Start monitoring?" prompt notification. Only delivers when
    /// notification permission has been granted.
    func postStartMonitoringReminder() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = L("reminder.startMonitoring.title")
            content.body = L("reminder.startMonitoring.body")
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: "PostureAI.StartMonitoringReminder",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    // MARK: - Notification

    private func presentAlertIfNeeded() {
        guard !hasActiveAlert else { return }
        hasActiveAlert = true
        addAlertNotification()
    }

    private func addAlertNotification() {
        let content = UNMutableNotificationContent()
        content.title = L("alert.slouch.title")
        content.body = L("alert.slouch.body")
        content.sound = nil
        let request = UNNotificationRequest(identifier: alertIdentifier, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    private func dismissAlertIfNeeded() {
        guard hasActiveAlert else { return }
        hasActiveAlert = false
        let center = UNUserNotificationCenter.current()
        center.removeDeliveredNotifications(withIdentifiers: [alertIdentifier])
        center.removePendingNotificationRequests(withIdentifiers: [alertIdentifier])
    }

    // MARK: - Spatial Sound

    private func updateSound(isAirPodsOutput: Bool) {
        if shouldPlaySound(isAirPodsOutput: isAirPodsOutput) {
            startToneIfNeeded()
        } else {
            stopSound()
        }
    }

    private func shouldPlaySound(isAirPodsOutput: Bool) -> Bool {
        switch soundMode {
        case .off: return false
        case .on: return true
        case .airpodsOnly: return isAirPodsOutput
        }
    }

    private func startToneIfNeeded() {
        if let soundPlayer, soundPlayer.isPlaying { return }
        guard let data = makeSoftToneWav() else { return }
        let sound = NSSound(data: data)
        sound?.loops = true
        sound?.volume = 0.5
        sound?.play()
        soundPlayer = sound
    }

    private func stopSound() {
        soundPlayer?.stop()
        soundPlayer = nil
    }

    // MARK: - Soft Tone Generation

    /// Generates a soft 440Hz sine pulse (with fade in/out) as a WAV file so
    /// it loops gently until good posture is restored.
    private func makeSoftToneWav() -> Data? {
        let sampleRate = 44100
        let duration = 1.0
        let frequency = 440.0
        let amplitude = 0.15
        let count = Int(duration * Double(sampleRate))

        var samples: [Int16] = []
        samples.reserveCapacity(count)
        for i in 0..<count {
            let t = Double(i) / Double(sampleRate)
            let attack = min(1.0, t / 0.06)
            let release = min(1.0, (duration - t) / 0.06)
            let envelope = min(attack, release)
            let value = sin(2.0 * .pi * frequency * t) * amplitude * envelope
            samples.append(Int16(value * Double(Int16.max)))
        }

        return makeWavData(samples: samples, sampleRate: sampleRate)
    }

    private func makeWavData(samples: [Int16], sampleRate: Int) -> Data? {
        var data = Data()

        func appendString(_ string: String) {
            guard let stringData = string.data(using: .ascii) else { return }
            data.append(stringData)
        }
        func appendUInt16(_ value: UInt16) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        func appendUInt32(_ value: UInt32) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }

        let byteRate = sampleRate * 2
        let dataSize = samples.count * 2

        appendString("RIFF")
        appendUInt32(UInt32(36 + dataSize))
        appendString("WAVE")
        appendString("fmt ")
        appendUInt32(16)
        appendUInt16(1)
        appendUInt16(1)
        appendUInt32(UInt32(sampleRate))
        appendUInt32(UInt32(byteRate))
        appendUInt16(2)
        appendUInt16(16)
        appendString("data")
        appendUInt32(UInt32(dataSize))
        for sample in samples {
            appendUInt16(UInt16(bitPattern: sample))
        }

        return data
    }
}