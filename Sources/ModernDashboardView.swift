import SwiftUI
import AppKit

struct ModernDashboardView: View {
    // AppStorage hooks
    @AppStorage("sensitivity") private var sensitivity: Double = 0.5
    @AppStorage("deadZone") private var deadZone: Double = 0.2
    @AppStorage("isTrackingPaused") private var isPaused: Bool = false
    @AppStorage("trackingMethod") private var trackingMethod: String = "camera"
    
    @State private var isSlouching: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            
            // 1. Header & Live Status Card
            NotabilityCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("dashboard.title"))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        
                        Text(isPaused ? L("dashboard.status.paused") : (isSlouching ? L("dashboard.status.slouching") : L("dashboard.status.good")))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(statusColor)
                    }
                    
                    Spacer()
                    
                    // Live Pill Indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(isPaused ? L("dashboard.live.off") : L("dashboard.live.on"))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
                    
                    // Main Toggle Switch
                    Toggle("", isOn: Binding(
                        get: { !isPaused },
                        set: { newValue in
                            isPaused = !newValue
                            notifyStateChange(name: "TogglePause", object: isPaused)
                            notifyStateChange(name: "TrackingStateChanged", object: !isPaused)
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
                            isSelected: trackingMethod == "camera"
                        ) {
                            trackingMethod = "camera"
                            notifyStateChange(name: "TrackingMethodChanged", object: "camera")
                        }
                        
                        MethodButton(
                            title: L("dashboard.airpods"),
                            icon: "airpodspro",
                            isSelected: trackingMethod == "airpods"
                        ) {
                            trackingMethod = "airpods"
                            notifyStateChange(name: "TrackingMethodChanged", object: "airpods")
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
                        Slider(value: $sensitivity, in: 0.1...1.0)
                            .tint(NotabilityTheme.accentBlue)
                            .onChange(of: sensitivity) { newValue in
                                notifyStateChange(name: "SensitivityChanged", object: newValue)
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
                        Slider(value: $deadZone, in: 0.0...1.0)
                            .tint(NotabilityTheme.accentBlue)
                            .onChange(of: deadZone) { newValue in
                                notifyStateChange(name: "DeadZoneChanged", object: newValue)
                            }
                    }
                }
            }
            
            // 4. Recalibrate Action Button
            Button(action: triggerRecalibration) {
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
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PostureStatusChanged"))) { notification in
            if let slouching = notification.object as? Bool {
                isSlouching = slouching
            }
        }
    }
    
    private var statusColor: Color {
        if isPaused { return .gray }
        return isSlouching ? NotabilityTheme.warningOrange : NotabilityTheme.successGreen
    }
    
    private func triggerRecalibration() {
        notifyStateChange(name: "RecalibratePosture", object: nil)
        notifyStateChange(name: "recalibrate", object: nil)
        notifyStateChange(name: "StartCalibration", object: nil)
    }
    
    private func notifyStateChange(name: String, object: Any?) {
        NotificationCenter.default.post(name: NSNotification.Name(name), object: object)
    }
}

