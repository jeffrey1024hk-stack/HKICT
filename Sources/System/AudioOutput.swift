import CoreAudio

// MARK: - Audio Output Device

enum AudioOutput {
    /// Whether the current default audio output device is an AirPods device.
    /// Used by the "AirPods only" spatial sound mode, regardless of the
    /// active posture tracking source.
    static var isAirPodsOutput: Bool {
        var defaultDeviceID = AudioDeviceID(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &defaultDeviceID
        )
        guard status == noErr, defaultDeviceID != 0 else { return false }

        var nameAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var name: Unmanaged<CFString>?
        var nameSize = UInt32(MemoryLayout<CFString?>.size)
        let nameStatus = AudioObjectGetPropertyData(
            defaultDeviceID,
            &nameAddress,
            0,
            nil,
            &nameSize,
            &name
        )
        guard nameStatus == noErr, let cfName = name?.takeRetainedValue() else { return false }

        let deviceName = cfName as String
        return deviceName.localizedCaseInsensitiveContains("AirPods")
    }
}
