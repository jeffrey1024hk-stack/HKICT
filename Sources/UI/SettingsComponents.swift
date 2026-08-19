import AppKit
import SwiftUI
import Combine

// MARK: - Brand Colors

extension Color {
    static let brandCyan = Color(red: 0.0, green: 0.48, blue: 1.0)        // #007AFF accent blue
    static let brandNavy = Color(red: 0.10, green: 0.15, blue: 0.27)      // #1a2744
    static let sectionBackground = Color(NSColor.controlBackgroundColor).opacity(0.5)

    static let onBrandCyan = Color.white
}

// MARK: - Settings Card

struct SettingsCard<Trailing: View, Content: View>: View {
    let icon: String
    let title: String
    let helpText: String?
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let content: () -> Content

    init(
        icon: String,
        title: String,
        helpText: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.helpText = helpText
        self.trailing = trailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.brandCyan)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 8)
                trailing()
            }
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

extension SettingsCard where Trailing == EmptyView {
    init(
        icon: String,
        title: String,
        helpText: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(icon: icon, title: title, helpText: helpText, trailing: { EmptyView() }, content: content)
    }
}

// MARK: - Compact Slider

struct CompactSlider: View {
    let title: String
    let helpText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .frame(width: 82, alignment: .leading)

            SteppedSliderTrack(value: $value, range: range, step: step)
                .frame(maxWidth: .infinity)

            Text(valueLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.brandCyan)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.brandCyan.opacity(0.12)))
                .frame(width: 86, alignment: .trailing)
        }
        .frame(height: 22)
    }
}

// MARK: - Stepped Slider Track

struct SteppedSliderTrack: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    private let thumbRadius: CGFloat = 7

    private var fraction: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return CGFloat((value - range.lowerBound) / span)
    }

    private var stepCount: Int {
        max(1, Int(((range.upperBound - range.lowerBound) / step).rounded()))
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let usable = width - thumbRadius * 2
            let thumbX = thumbRadius + usable * fraction

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                    .frame(height: 4)
                Capsule()
                    .fill(Color.brandCyan.opacity(0.85))
                    .frame(width: max(0, thumbX), height: 4)

                if stepCount <= 8 {
                    ForEach(1..<stepCount, id: \.self) { i in
                        Circle()
                            .fill(Color.primary.opacity(0.15))
                            .frame(width: 3, height: 3)
                            .position(
                                x: thumbRadius + usable * CGFloat(i) / CGFloat(stepCount),
                                y: geo.size.height / 2
                            )
                    }
                }

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbRadius * 2, height: thumbRadius * 2)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.18), radius: 1.5, y: 0.5)
                    .position(x: thumbX, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let f = min(1, max(0, (gesture.location.x - thumbRadius) / usable))
                        let raw = range.lowerBound + Double(f) * (range.upperBound - range.lowerBound)
                        let stepped = (raw / step).rounded() * step
                        value = min(range.upperBound, max(range.lowerBound, stepped))
                    }
            )
        }
        .frame(height: 22)
    }
}

// MARK: - Brand Switch

struct BrandSwitch: View {
    @Binding var isOn: Bool
    var isDisabled: Bool = false

    var body: some View {
        Toggle("", isOn: $isOn)
            .toggleStyle(.switch)
            .labelsHidden()
            .controlSize(.mini)
            .tint(NotabilityTheme.accentBlue)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1.0)
    }
}

// MARK: - Compact Toggle

struct CompactToggle: View {
    let title: String
    let helpText: String
    @Binding var isOn: Bool
    var isDisabled: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            BrandSwitch(isOn: $isOn, isDisabled: isDisabled)
                .frame(width: 38, alignment: .leading)

            Text(title)
                .font(.system(size: 11))
                .lineLimit(1)
                .opacity(isDisabled ? 0.5 : 1.0)

            Spacer(minLength: 0)
        }
        .frame(height: 22)
    }
}

// MARK: - Compact Warning Style Picker

struct CompactWarningStylePicker: View {
    @Binding var selection: WarningMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach([WarningMode.blur, .glow, .border, .solid, .none], id: \.self) { mode in
                Button(action: { selection = mode }) {
                    Text(mode.shortName)
                        .font(.system(size: 10, weight: selection == mode ? .semibold : .regular))
                        .foregroundColor(selection == mode ? .onBrandCyan : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(selection == mode ? Color.brandCyan : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

// MARK: - Inline Color Picker

struct InlineColorPicker: View {
    @Binding var color: Color
    @State private var showPopover = false
    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1
    @State private var hexText: String = ""

    var body: some View {
        Button(action: { showPopover.toggle() }) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color)
                .frame(width: 28, height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            VStack(spacing: 12) {
                ColorWheelView(hue: $hue, saturation: $saturation)
                    .frame(width: 150, height: 150)
                    .onChange(of: hue) { _ in updateColorFromHSB() }
                    .onChange(of: saturation) { _ in updateColorFromHSB() }

                HStack {
                    Text(L("settings.brightness"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Slider(value: $brightness, in: 0...1)
                        .onChange(of: brightness) { _ in updateColorFromHSB() }
                }

                HStack(spacing: 6) {
                    Text("#")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)

                    TextField("", text: $hexText)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .textFieldStyle(.plain)
                        .frame(width: 70)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.primary.opacity(0.05))
                        )
                        .onSubmit { updateColorFromHex() }

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: 32, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        )
                }
            }
            .padding(16)
            .frame(width: 212)
            .onAppear { syncFromColor() }
        }
        .onAppear { syncFromColor() }
    }

    private func syncFromColor() {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
        hue = Double(nsColor.hueComponent)
        saturation = Double(nsColor.saturationComponent)
        brightness = Double(nsColor.brightnessComponent)
        updateHexText()
    }

    private func updateColorFromHSB() {
        color = Color(hue: hue, saturation: saturation, brightness: brightness)
        updateHexText()
    }

    private func updateHexText() {
        let nsColor = NSColor(color).usingColorSpace(.deviceRGB) ?? NSColor(color)
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        hexText = String(format: "%02X%02X%02X", r, g, b)
    }

    private func updateColorFromHex() {
        let hex = hexText.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return }

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0

        color = Color(red: r, green: g, blue: b)
        syncFromColor()
    }
}

struct ColorWheelView: View {
    @Binding var hue: Double
    @Binding var saturation: Double

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2

            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color(hue: 0.0, saturation: 1, brightness: 1),
                                Color(hue: 0.1, saturation: 1, brightness: 1),
                                Color(hue: 0.2, saturation: 1, brightness: 1),
                                Color(hue: 0.3, saturation: 1, brightness: 1),
                                Color(hue: 0.4, saturation: 1, brightness: 1),
                                Color(hue: 0.5, saturation: 1, brightness: 1),
                                Color(hue: 0.6, saturation: 1, brightness: 1),
                                Color(hue: 0.7, saturation: 1, brightness: 1),
                                Color(hue: 0.8, saturation: 1, brightness: 1),
                                Color(hue: 0.9, saturation: 1, brightness: 1),
                                Color(hue: 1.0, saturation: 1, brightness: 1),
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: size, height: size)

                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.white, .white.opacity(0)]),
                            center: .center,
                            startRadius: 0,
                            endRadius: radius
                        )
                    )
                    .frame(width: size, height: size)

                Circle()
                    .strokeBorder(Color.white, lineWidth: 2)
                    .background(Circle().fill(Color(hue: hue, saturation: saturation, brightness: 1)))
                    .frame(width: 20, height: 20)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .position(
                        x: center.x + cos(hue * 2 * .pi) * (radius - 10) * saturation,
                        y: center.y + sin(hue * 2 * .pi) * (radius - 10) * saturation
                    )
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - center.x
                        let dy = value.location.y - center.y

                        var angle = atan2(dy, dx)
                        if angle < 0 { angle += 2 * .pi }
                        hue = angle / (2 * .pi)

                        let distance = sqrt(dx * dx + dy * dy)
                        saturation = min(1, max(0, distance / (radius - 10)))
                    }
            )
        }
    }
}

// MARK: - Device Status Row

struct DeviceStatusRow: View {
    let source: TrackingSource
    let isCalibrated: Bool
    let isConnected: Bool
    let isPreferred: Bool
    let isActive: Bool
    let cameraDropdown: AnyView?
    let onCalibrate: (() -> Void)?

    init(
        source: TrackingSource,
        isCalibrated: Bool,
        isConnected: Bool,
        isPreferred: Bool = false,
        isActive: Bool = false,
        cameraDropdown: AnyView? = nil,
        onCalibrate: (() -> Void)? = nil
    ) {
        self.source = source
        self.isCalibrated = isCalibrated
        self.isConnected = isConnected
        self.isPreferred = isPreferred
        self.isActive = isActive
        self.cameraDropdown = cameraDropdown
        self.onCalibrate = onCalibrate
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: source == TrackingSource.camera ? "camera" : "airpodspro")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(source == TrackingSource.camera ? L("settings.source.camera") : L("settings.source.airpods"))
                        .font(.system(size: 12, weight: .medium))

                    if isPreferred {
                        Text(L("settings.preferredTag"))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.cyan.opacity(0.12)))
                    }

                    if isActive {
                        Text(L("settings.activeTag"))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.green)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.green.opacity(0.12)))
                    }
                }

                HStack(spacing: 6) {
                    Circle()
                        .fill(isConnected ? (isCalibrated ? Color.green : Color.orange) : Color.red)
                        .frame(width: 6, height: 6)

                    Text(statusText)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let cameraDropdown = cameraDropdown {
                cameraDropdown
            }

            if let onCalibrate = onCalibrate {
                Button(action: onCalibrate) {
                    Text(isCalibrated ? L("settings.recalibrate") : L("settings.calibrate"))
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 3)
    }

    private var statusText: String {
        if !isConnected {
            return L("settings.status.disconnected")
        } else if !isCalibrated {
            return L("settings.status.needsCalibration")
        } else {
            return L("settings.status.ready")
        }
    }
}

// MARK: - Compact Tracking Source Picker

struct CompactTrackingSourcePicker: View {
    @Binding var selection: TrackingSource
    let airPodsAvailable: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TrackingSource.allCases) { source in
                let isDisabled = source == TrackingSource.airpods && !airPodsAvailable
                Button(action: {
                    if !isDisabled { selection = source }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: source.icon)
                            .font(.system(size: 9))
                        Text(source.displayName)
                            .font(.system(size: 10, weight: selection == source ? .semibold : .regular))
                    }
                    .foregroundColor(selection == source ? .onBrandCyan : (isDisabled ? .secondary.opacity(0.5) : .primary))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(selection == source ? Color.brandCyan : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

// MARK: - Subtle Divider

struct SubtleDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
    }
}

extension WarningMode {
    var displayName: String {
        switch self {
        case .blur: return L("warningMode.blur")
        case .glow: return L("warningMode.glow")
        case .border: return L("warningMode.border")
        case .solid: return L("warningMode.solid")
        case .none: return L("warningMode.none")
        }
    }

    var shortName: String { displayName }
}

// MARK: - Social Icons

struct GitHubIcon: View {
    var color: Color = .secondary

    var body: some View {
        Image(systemName: "code.square.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 16, height: 16)
            .foregroundColor(color)
    }
}

// MARK: - Discord Icon

struct DiscordIcon: View {
    var color: Color = .secondary

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let scale = min(geometry.size.width, geometry.size.height) / 24

                path.move(to: CGPoint(x: 20.317 * scale, y: 4.3698 * scale))
                path.addCurve(to: CGPoint(x: 15.432 * scale, y: 2.8546 * scale),
                              control1: CGPoint(x: 18.7873 * scale, y: 3.6588 * scale),
                              control2: CGPoint(x: 17.1461 * scale, y: 3.1346 * scale))
                path.addCurve(to: CGPoint(x: 14.8237 * scale, y: 4.1041 * scale),
                              control1: CGPoint(x: 15.3535 * scale, y: 2.8917 * scale),
                              control2: CGPoint(x: 15.0347 * scale, y: 3.4793 * scale))
                path.addCurve(to: CGPoint(x: 9.3369 * scale, y: 4.1041 * scale),
                              control1: CGPoint(x: 12.979 * scale, y: 3.8279 * scale),
                              control2: CGPoint(x: 11.1437 * scale, y: 3.8279 * scale))
                path.addCurve(to: CGPoint(x: 8.7192 * scale, y: 2.8546 * scale),
                              control1: CGPoint(x: 9.1269 * scale, y: 3.4793 * scale),
                              control2: CGPoint(x: 8.7963 * scale, y: 2.8917 * scale))
                path.addCurve(to: CGPoint(x: 3.8341 * scale, y: 4.3698 * scale),
                              control1: CGPoint(x: 7.0042 * scale, y: 3.1346 * scale),
                              control2: CGPoint(x: 5.3643 * scale, y: 3.6588 * scale))
                path.addCurve(to: CGPoint(x: 0.5524 * scale, y: 18.0578 * scale),
                              control1: CGPoint(x: 0.5524 * scale, y: 9.0458 * scale),
                              control2: CGPoint(x: -0.3811 * scale, y: 13.5799 * scale))
                path.addCurve(to: CGPoint(x: 6.6052 * scale, y: 21.0872 * scale),
                              control1: CGPoint(x: 2.6052 * scale, y: 19.5654 * scale),
                              control2: CGPoint(x: 4.5939 * scale, y: 20.51 * scale))
                path.addCurve(to: CGPoint(x: 7.8312 * scale, y: 19.093 * scale),
                              control1: CGPoint(x: 7.0668 * scale, y: 20.4568 * scale),
                              control2: CGPoint(x: 7.4862 * scale, y: 19.7878 * scale))
                path.addCurve(to: CGPoint(x: 5.959 * scale, y: 18.2007 * scale),
                              control1: CGPoint(x: 7.179 * scale, y: 18.8454 * scale),
                              control2: CGPoint(x: 6.5569 * scale, y: 18.5483 * scale))
                path.addCurve(to: CGPoint(x: 6.3308 * scale, y: 17.9093 * scale),
                              control1: CGPoint(x: 6.0848 * scale, y: 18.1064 * scale),
                              control2: CGPoint(x: 6.2108 * scale, y: 18.008 * scale))
                path.addCurve(to: CGPoint(x: 12 * scale, y: 19.7026 * scale),
                              control1: CGPoint(x: 8.2586 * scale, y: 19.7026 * scale),
                              control2: CGPoint(x: 10.1508 * scale, y: 19.7026 * scale))
                path.addCurve(to: CGPoint(x: 17.6692 * scale, y: 17.9093 * scale),
                              control1: CGPoint(x: 13.8492 * scale, y: 19.7026 * scale),
                              control2: CGPoint(x: 15.7414 * scale, y: 19.7026 * scale))
                path.addCurve(to: CGPoint(x: 18.041 * scale, y: 18.2007 * scale),
                              control1: CGPoint(x: 17.7892 * scale, y: 18.008 * scale),
                              control2: CGPoint(x: 17.9152 * scale, y: 18.1064 * scale))
                path.addCurve(to: CGPoint(x: 16.1688 * scale, y: 19.093 * scale),
                              control1: CGPoint(x: 17.4431 * scale, y: 18.5483 * scale),
                              control2: CGPoint(x: 16.821 * scale, y: 18.8454 * scale))
                path.addCurve(to: CGPoint(x: 17.3948 * scale, y: 21.0872 * scale),
                              control1: CGPoint(x: 16.5138 * scale, y: 19.7878 * scale),
                              control2: CGPoint(x: 16.9332 * scale, y: 20.4568 * scale))
                path.addCurve(to: CGPoint(x: 23.4476 * scale, y: 18.0578 * scale),
                              control1: CGPoint(x: 19.4061 * scale, y: 20.51 * scale),
                              control2: CGPoint(x: 21.3948 * scale, y: 19.5654 * scale))
                path.addCurve(to: CGPoint(x: 20.317 * scale, y: 4.3698 * scale),
                              control1: CGPoint(x: 24.3811 * scale, y: 13.5799 * scale),
                              control2: CGPoint(x: 23.4476 * scale, y: 9.0458 * scale))
                path.closeSubpath()

                path.addEllipse(in: CGRect(x: 5.8631 * scale, y: 10.9122 * scale, width: 4.314 * scale, height: 4.838 * scale))
                path.addEllipse(in: CGRect(x: 13.8369 * scale, y: 10.9122 * scale, width: 4.314 * scale, height: 4.838 * scale))
            }
            .fill(color, style: FillStyle(eoFill: true))
        }
    }
}

// MARK: - Compact Mode Picker

struct CompactModePicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String)]

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.0) { option in
                Text(option.1).tag(option.0)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

// MARK: - Compact Segmented Picker

struct CompactSegmentedPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [(T, String)]

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(options, id: \.0) { option in
                Text(option.1).tag(option.0)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

// MARK: - Compact Shortcut Recorder

struct CompactShortcutRecorder: View {
    @Binding var shortcut: AppKeyboardShortcut
    @Binding var isEnabled: Bool
    var onShortcutChange: () -> Void

    @State private var isRecording = false
    @State private var localMonitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            BrandSwitch(isOn: $isEnabled)
                .frame(width: 38, alignment: .leading)
                .onChange(of: isEnabled) { _ in
                    onShortcutChange()
                }

            Text(L("settings.shortcut"))
                .font(.system(size: 11))

            Button(action: {
                isRecording.toggle()
                if isRecording {
                    startRecording()
                } else {
                    stopRecording()
                }
            }) {
                Text(isRecording ? L("settings.shortcut.press") : shortcut.displayString)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isRecording ? .secondary : (isEnabled ? .primary : .secondary))
                    .lineLimit(1)
                    .frame(width: 60)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(isRecording ? Color.brandCyan.opacity(0.15) : Color.primary.opacity(0.06))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(isRecording ? Color.brandCyan : Color.primary.opacity(0.1), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .frame(height: 22)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
            if modifierKeyCodes.contains(event.keyCode) {
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasModifier = modifiers.contains(.command) || modifiers.contains(.control) ||
                             modifiers.contains(.option) || modifiers.contains(.shift)

            if hasModifier {
                shortcut = AppKeyboardShortcut(keyCode: event.keyCode, modifiers: modifiers)
                stopRecording()
                onShortcutChange()
                return nil
            }

            return event
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}
