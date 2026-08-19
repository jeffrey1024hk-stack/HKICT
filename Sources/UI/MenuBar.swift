import AppKit
import SwiftUI

@MainActor
public class MenuBarManager: NSObject, NSMenuDelegate {
    
    // MARK: - Public Properties
    
    /// Public statusItem for popup window anchoring in AppDelegate
    public var statusItem: NSStatusItem!
    
    /// Provides seconds until the next screen break, or nil when none is
    /// scheduled. Wired up by AppDelegate.
    public var nextBreakSecondsProvider: (() -> TimeInterval?)?
    
    // Callback closures expected by AppDelegate
    public var onToggleEnabled: (() -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var onShowAbout: (() -> Void)?
    public var onShowAnalytics: (() -> Void)?
    public var onRecalibrate: (() -> Void)?
    public var onCheckForUpdates: (() -> Void)?
    public var onOpenHelp: (() -> Void)?
    public var onQuit: (() -> Void)?
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupMenuBar()
    }
    
    /// Setup hook called explicitly by AppDelegate
    public func setup() {
        if statusItem == nil {
            setupMenuBar()
        }
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "PostureAI")
            image?.isTemplate = true
            button.image = image
        }
        
        rebuildMenu()
    }
    
    /// Builds the status menu. Exposed separately from `rebuildMenu()` so
    /// headless tests can inspect the structure without a window server.
    public func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        // 0. About PostureAI
        let aboutItem = NSMenuItem(
            title: "About PostureAI",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About PostureAI")
        aboutItem.image?.isTemplate = true
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        // 1. Settings ⌘,
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // 2. Analytics (primary feature — no shortcut clutter)
        let analyticsItem = NSMenuItem(
            title: "Analytics...",
            action: #selector(openAnalytics),
            keyEquivalent: ""
        )
        analyticsItem.image = NSImage(systemSymbolName: "chart.bar", accessibilityDescription: "Analytics")
        analyticsItem.image?.isTemplate = true
        analyticsItem.target = self
        menu.addItem(analyticsItem)

        menu.addItem(NSMenuItem.separator())

        // 3. Check for Updates (GitHub releases page)
        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(handleCheckForUpdates),
            keyEquivalent: ""
        )
        updateItem.image = NSImage(systemSymbolName: "arrow.clockwise.circle", accessibilityDescription: "Check for Updates")
        updateItem.image?.isTemplate = true
        updateItem.target = self
        menu.addItem(updateItem)

        // 4. Help (GitHub issues)
        let helpItem = NSMenuItem(
            title: "Help...",
            action: #selector(handleHelp),
            keyEquivalent: ""
        )
        helpItem.image = NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: "Help")
        helpItem.image?.isTemplate = true
        helpItem.target = self
        menu.addItem(helpItem)

        menu.addItem(NSMenuItem.separator())

        // 5. Quit ⌘Q
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Quit")
        quitItem.image?.isTemplate = true
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    public func rebuildMenu() {
        statusItem?.menu = makeMenu()
    }
    
    // MARK: - Actions
    
    /// Opens the modern SwiftUI Settings window
    @objc public func openSettings() {
        if let onOpenSettings = onOpenSettings {
            onOpenSettings()
            return
        }

        // No delegate wired (headless/fallback): nothing to show.
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Opens the About PostureAI window
    @objc public func showAbout() {
        if let onShowAbout = onShowAbout {
            onShowAbout()
        }
    }

    /// Opens the Analytics window
    @objc public func openAnalytics() {
        if let onShowAnalytics = onShowAnalytics {
            onShowAnalytics()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    @objc private func handleRecalibrate() {
        if let onRecalibrate = onRecalibrate {
            onRecalibrate()
        } else {
            NotificationCenter.default.post(name: NSNotification.Name("RecalibratePosture"), object: nil)
        }
    }
    
    @objc private func handleCheckForUpdates() {
        if let onCheckForUpdates = onCheckForUpdates {
            onCheckForUpdates()
        } else if let url = URL(string: "https://github.com/jeffrey1024hk-stack/HKICT/releases") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func handleHelp() {
        if let onOpenHelp = onOpenHelp {
            onOpenHelp()
        } else if let url = URL(string: "https://github.com/jeffrey1024hk-stack/HKICT/issues") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func handleQuit() {
        if let onQuit = onQuit {
            onQuit()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
    
    // MARK: - NSMenuDelegate
    
    public func menuWillOpen(_ menu: NSMenu) {
        refreshNextBreak()
    }
    
    // MARK: - Status & UI Updates
    
    /// Refreshes the status button countdown when a screen break is imminent.
    public func refreshNextBreak() {
        let seconds = nextBreakSecondsProvider?()

        // Show a short countdown next to the menu bar icon when the break is
        // imminent (under 5 minutes); otherwise keep the icon clean.
        if let seconds, seconds > 0, seconds < 300 {
            statusItem?.button?.title = "\(max(1, Int(ceil(seconds / 60))))m"
        } else {
            statusItem?.button?.title = ""
        }
    }

    func updateShortcut(enabled: Bool, shortcut: AppKeyboardShortcut?) {}
    func updateEnabledState(_ isEnabled: Bool) {}
    func updateRecalibrateEnabled(_ canRecalibrate: Bool) {}
    
    func updateStatus(text: String? = nil, icon: MenuBarIcon? = nil) {
        guard let button = statusItem?.button else { return }
        
        if let icon {
            button.image = icon.image
        }
        
        if let text {
            button.title = text
        }
    }
    
    func updateStatus(isSlouching: Bool = false) {
        updateStatus(icon: isSlouching ? .bad : .good)
    }
    
    func updateStatus(isSlouching: Bool = false, isPaused: Bool = false) {
        if isPaused {
            updateStatus(icon: .paused)
        } else {
            updateStatus(isSlouching: isSlouching)
        }
    }
}