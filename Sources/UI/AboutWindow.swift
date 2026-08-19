import AppKit
import SwiftUI

// MARK: - About Window Controller

@MainActor
final class AboutWindowController: NSObject, NSWindowDelegate {
    var window: NSWindow?

    func showAbout() {
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: AboutView())

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L("about.windowTitle")
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.backgroundColor = NSColor.windowBackgroundColor
        window.centerOnActiveScreen()

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        window?.close()
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Hero Section
            VStack(spacing: 14) {
                if let appIcon = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                }

                VStack(spacing: 4) {
                    Text(L("about.title"))
                        .font(.system(size: 22, weight: .bold))
                    Text(versionText)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.top, 30)

            Spacer()

            // Tagline Section
            Text(L("about.tagline"))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .tracking(1.5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Spacer()

            // Action Buttons Section
            HStack(spacing: 10) {
                AboutLinkButton(icon: "curlybraces.square", title: L("about.github")) {
                    openURL(Constants.repoURL)
                }
                AboutLinkButton(icon: "doc.text", title: L("about.license")) {
                    openURL(Constants.repoURL + "/blob/main/LICENSE")
                }
                AboutLinkButton(icon: "hand.raised", title: L("about.privacy")) {
                    openURL(Constants.repoURL + "/blob/main/PRIVACY.md")
                }
            }
            .padding(.horizontal, 24)

            // Footer Section
            Text(L("about.copyright"))
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.top, 22)
                .padding(.bottom, 18)
        }
        .frame(width: 320, height: 360)
    }

    private enum Constants {
        static let repoURL = "https://github.com/jeffrey1024hk-stack/HKICT"
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "24"
        return L("about.version", version, build)
    }

    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

// MARK: - About Link Button

struct AboutLinkButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundColor(.primary)
            .frame(height: 30)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }
}