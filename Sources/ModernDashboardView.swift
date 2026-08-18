import SwiftUI
import AppKit

extension Notification.Name {
    /// Posted by `AppDelegate.syncUIToState()` whenever the tracking UI state
    /// changes (enabled state, slouching, active source, profile settings).
    static let postureUIStateChanged = Notification.Name("PostureUIStateChanged")
}

@MainActor
struct ModernDashboardView: View {
    let appDelegate: AppDelegate

    @State private var sensitivity: Double
    @State private var deadZone: Double
    @State private var isActive: Bool = false
    @State private var isSlouching: Bool = false
    @State private var activeSource: TrackingSource = .camera

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        _sensitivity = State(initialValue: Double(appDelegate.activeIntensity))
        _deadZone = State(initialValue: Double(appDelegate.activeDeadZone))
    }

    var body: some View {
        VStack(spacing: 16) {

            // 1. Header & Live Status Card
            NotabilityCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("dashboard.title"))
                            .font(.system(size: 22, weight: .bold, design: .rounded))

                        Text(isActive ? (isSlouching ? L("dashboard.status.slouching") : L("dashboard.status.good")) : L("dashboard.status.paused"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(statusColor)
                    }

                    Spacer()

                    // Live Pill Indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)

                        Text(isActive ? L("dashboard.live.on") : L("dashboard.live.off"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())

                    // Main Toggle Switch
                    Toggle("", isOn: Binding(
                        get: { isActive },
                        set: { newValue in
                            guard newValue != appDelegate.state.isActive else { return }
                            Task { @MainActor in
                                await appDelegate.toggleEnabled()
                            }
                        }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            }

            // 2. Input Source Selector
            NotabilityCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("dashboard.inputSource"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        MethodButton(
                            title: L("dashboard.camera"),
                            icon: "camera.fill",
                            isSelected: activeSource == .camera
                        ) {
                            guard activeSource != .camera else { return }
                            Task { @MainActor in
                                await appDelegate.switchTrackingSource(to: .camera)
                            }
                        }

                        MethodButton(
                            title: L("dashboard.airpods"),
                            icon: "airpodspro",
                            isSelected: activeSource == .airpods
                        ) {
                            guard activeSource != .airpods else { return }
                            Task { @MainActor in
                                await appDelegate.switchTrackingSource(to: .airpods)
                            }
                        }
                    }
                }
            }

            // 3. Sensitivity Controls
            NotabilityCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text(L("dashboard.sensitivityTolerance"))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L("dashboard.slouchSensitivity"))
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text("\(Int(sensitivity * 100))%")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $sensitivity, in: 0.08...1.2)
                            .tint(NotabilityTheme.accentBlue)
                            .onChange(of: sensitivity) { newValue in
                                appDelegate.settingsProfileManager.updateActiveProfile(intensity: newValue)
                                appDelegate.applyActiveSettingsProfile()
                            }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(L("dashboard.deadZoneTolerance"))
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text("\(Int(deadZone * 100))%")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $deadZone, in: 0.0...0.5)
                            .tint(NotabilityTheme.accentBlue)
                            .onChange(of: deadZone) { newValue in
                                appDelegate.settingsProfileManager.updateActiveProfile(deadZone: newValue)
                                appDelegate.applyActiveSettingsProfile()
                            }
                    }
                }
            }

            // 4. Recalibrate Action Button
            Button(action: {
                appDelegate.startCalibration()
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text(L("dashboard.recalibrate"))
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(NotabilityTheme.accentBlue)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: NotabilityTheme.accentBlue.opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)

        }
        .padding(20)
        .frame(width: 360)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.3))
        // Listen for live posture state changes
        .onReceive(NotificationCenter.default.publisher(for: .postureUIStateChanged)) { _ in
            refreshState()
        }
        .onAppear {
            refreshState()
        }
    }

    private var statusColor: Color {
        if !isActive { return .gray }
        return isSlouching ? NotabilityTheme.warningOrange : NotabilityTheme.successGreen
    }

    private func refreshState() {
        isActive = appDelegate.state.isActive
        isSlouching = appDelegate.isCurrentlySlouching
        activeSource = appDelegate.activeTrackingSource
        sensitivity = Double(appDelegate.activeIntensity)
        deadZone = Double(appDelegate.activeDeadZone)
    }
}