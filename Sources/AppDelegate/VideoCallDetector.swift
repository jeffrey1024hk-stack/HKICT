import AppKit
import CoreMediaIO
import CoreFoundation
import os.log

/// Detects when a video call is active so monitoring can auto-pause during
/// meetings/presentations (prevents screen blurs while presenting).
///
/// A meeting is considered active when:
/// - A known native video-call app (Zoom, Teams, FaceTime, Slack, Discord,
///   Webex, Skype) is the frontmost application, OR
/// - A browser (Chrome, Safari, Edge, Firefox) is frontmost AND the camera is
///   currently in use by another app (Google Meet, Teams on the web). This is
///   only detected while PostureAI's own camera detector is idle, so it works
///   when tracking with AirPods.
private let log = OSLog(subsystem: "chill..PostureAI", category: "VideoCall")

@MainActor
final class VideoCallDetector {
    private(set) var isInMeeting = false
    var onMeetingStateChange: ((Bool) -> Void)?
    /// Reports whether PostureAI's own camera detector is actively running.
    var isOurCameraActive: (() -> Bool)?

    private var timer: Timer?

    private let nativeMeetingIdentifiers: [String] = [
        "zoom", "microsoft teams", "teams", "facetime", "slack", "discord", "webex", "skype"
    ]
    private let browserIdentifiers: [String] = [
        "google chrome", "safari", "microsoft edge", "firefox", "arc", "brave"
    ]

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

    /// Re-checks the meeting state immediately (e.g. after enabling the setting).
    func reevaluate() {
        refresh()
    }

    // MARK: - Detection

    private func refresh() {
        var inMeeting = false
        if let front = NSWorkspace.shared.frontmostApplication {
            let name = (front.localizedName ?? "").lowercased()
            let bundle = (front.bundleIdentifier ?? "").lowercased()

            if nativeMeetingIdentifiers.contains(where: { name.contains($0) || bundle.contains($0) }) {
                inMeeting = true
            } else if browserIdentifiers.contains(where: { name.contains($0) || bundle.contains($0) }) {
                let ourCameraActive = isOurCameraActive?() ?? false
                if !ourCameraActive, Self.isAnyCameraRunningSomewhere() {
                    inMeeting = true
                }
            }
        }
        updateIfNeeded(inMeeting)
    }

    private func updateIfNeeded(_ inMeeting: Bool) {
        guard inMeeting != isInMeeting else { return }
        isInMeeting = inMeeting
        os_log(.info, log: log, "Meeting state changed: %{public}@", inMeeting ? "in meeting" : "not in meeting")
        onMeetingStateChange?(inMeeting)
    }

    // MARK: - Camera In Use (public CoreMediaIO API)

    private static func isAnyCameraRunningSomewhere() -> Bool {
        for device in cameraDeviceIDs() {
            var running: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            var address = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
            )
            let status = CMIOObjectGetPropertyData(device, &address, 0, nil, size, &size, &running)
            if status == kCMIOHardwareNoError, running == 1 {
                return true
            }
        }
        return false
    }

    private static func cameraDeviceIDs() -> [CMIOObjectID] {
        var size: UInt32 = 0
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        guard CMIOObjectGetPropertyDataSize(
            CMIOObjectID(kCMIOObjectSystemObject),
            &address,
            0,
            nil,
            &size
        ) == kCMIOHardwareNoError else { return [] }

        let count = Int(size) / MemoryLayout<CMIOObjectID>.size
        guard count > 0 else { return [] }
        var devices = [CMIOObjectID](repeating: 0, count: count)
        CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &address,
            0,
            nil,
            size,
            &size,
            &devices
        )
        return devices
    }
}