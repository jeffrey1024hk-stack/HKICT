import SwiftUI

struct ModernDashboardView: View {
    // Hooks directly into Dorso's persistence layer
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
                        Text("Dorso")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        
                        Text(isPaused ? "Monitoring Paused" : (isSlouching ? "Slouching Detected" : "Good Posture"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(statusColor)
                    }
                    
                    Spacer()
                    
                    // Live Pill Indicator
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(isPaused ? "OFF" : "LIVE")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(statusColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
                    
                    // Main Toggle
                    Toggle("", isOn: Binding(
                        get: { !isPaused },
                        set: { isPaused = !$0 }
                    ))
                    .toggleStyle(.switch)
                    .labelsHidden()
                }
            }
            
            // 2. Input Source Selector
            NotabilityCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("INPUT SOURCE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        MethodButton(
                            title: "Camera",
                            icon: "camera.fill",
                            isSelected: trackingMethod == "camera"
                        ) {
                            trackingMethod = "camera"
                        }
                        
                        MethodButton(
                            title: "AirPods",
                            icon: "airpodspro",
                            isSelected: trackingMethod == "airpods"
                        ) {
                            trackingMethod = "airpods"
                        }
                    }
                }
            }
            
            // 3. Sensitivity Controls
            NotabilityCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("SENSITIVITY & TOLERANCE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Slouch Sensitivity")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text("\(Int(sensitivity * 100))%")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $sensitivity, in: 0.1...1.0)
                            .tint(NotabilityTheme.accentBlue)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Dead Zone Tolerance")
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text("\(Int(deadZone * 100))%")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $deadZone, in: 0.0...1.0)
                            .tint(NotabilityTheme.accentBlue)
                    }
                }
            }
            
            // 4. Action Button
            Button(action: triggerRecalibration) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Recalibrate Sitting Posture")
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
    }
    
    private var statusColor: Color {
        if isPaused { return .gray }
        return isSlouching ? NotabilityTheme.warningOrange : NotabilityTheme.successGreen
    }
    
    private func triggerRecalibration() {
        NotificationCenter.default.post(name: NSNotification.Name("RecalibratePosture"), object: nil)
    }
}