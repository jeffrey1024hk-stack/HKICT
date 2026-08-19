import AppKit
import SwiftUI

/// Fullscreen blur overlay used for the 20/20/20 screen break reminder.
/// Blurs every screen for `duration` seconds and shows a countdown prompting
/// the user to look about 20 feet away.
@MainActor
final class ScreenBreakOverlayManager {
    private var windows: [NSWindow] = []
    private var labels: [NSTextField] = []
    private var countdownTimer: Timer?
    private var remainingSeconds = 0
    private var onComplete: (() -> Void)?

    func show(duration: Int, onComplete: (() -> Void)? = nil) {
        hide()
        self.onComplete = onComplete
        remainingSeconds = max(1, duration)

        for screen in NSScreen.screens {
            let frame = screen.overlayFrame(fullScreen: true)
            let window = NSWindow(
                contentRect: frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .belowNotifications
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.ignoresMouseEvents = true
            window.hasShadow = false

            let content = NSVisualEffectView(frame: NSRect(origin: .zero, size: frame.size))
            content.material = .hudWindow
            content.blendingMode = .behindWindow
            content.state = .active

            // Dim layer so the blur is clearly a "break" and text is readable
            let dim = NSVisualEffectView(frame: content.bounds)
            dim.material = .underWindowBackground
            dim.blendingMode = .withinWindow
            dim.state = .active
            dim.wantsLayer = true
            dim.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.45).cgColor
            content.addSubview(dim)

            // Centered instruction + countdown
            let stack = NSStackView()
            stack.orientation = .vertical
            stack.alignment = .centerX
            stack.spacing = 8
            stack.translatesAutoresizingMaskIntoConstraints = false

            let title = NSTextField(labelWithString: L("screenBreak.title"))
            title.font = .systemFont(ofSize: 42, weight: .bold)
            title.textColor = .white
            title.alignment = .center

            let countdown = NSTextField(labelWithString: "\(remainingSeconds)")
            countdown.font = .monospacedDigitSystemFont(ofSize: 88, weight: .black)
            countdown.textColor = .white
            countdown.alignment = .center

            let caption = NSTextField(labelWithString: L("screenBreak.caption"))
            caption.font = .systemFont(ofSize: 17, weight: .medium)
            caption.textColor = .white.withAlphaComponent(0.85)
            caption.alignment = .center

            stack.addArrangedSubview(title)
            stack.addArrangedSubview(countdown)
            stack.addArrangedSubview(caption)

            content.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: content.centerYAnchor)
            ])

            window.contentView = content
            window.orderFrontRegardless()

            windows.append(window)
            labels.append(countdown)
        }

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func hide() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
        labels.removeAll()
    }

    var isVisible: Bool {
        !windows.isEmpty
    }

    private func tick() {
        remainingSeconds -= 1
        if remainingSeconds <= 0 {
            hide()
            onComplete?()
            onComplete = nil
            return
        }
        for label in labels {
            label.stringValue = "\(remainingSeconds)"
        }
    }
}