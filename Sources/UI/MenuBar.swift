import AppKit
import SwiftUI

@MainActor
public class MenuBarManager: NSObject, NSWindowDelegate {
    
    // MARK: - Public Properties
    
    /// Public statusItem for popup window anchoring in AppDelegate
    public var statusItem: NSStatusItem!
    
    // Callback closures expected by AppDelegate
    public var onToggleEnabled: (() -> Void)?
    public var onOpenSettings: (() -> Void)?
    public var onOpenSupport: (() -> Void)?
    public var onShowAnalytics: (() -> Void)?
    public var onShowSettings: (() -> Void)?
    public var onShowSupport: (() -> Void)?
    public var onRecalibrate: (() -> Void)?
    public var onTogglePause: (() -> Void)?
    public var onCheckForUpdates: (() -> Void)?
    public var onQuit: (() -> Void)?
    
    // MARK: - Private Window References
    
    private var dashboardWindow: NSWindow?
    private var analyticsWindowController: AnalyticsWindowController?
    
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
            button.image = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "PostureAI")
        }
        
        rebuildMenu()
    }
    
    public func rebuildMenu() {
        let menu = NSMenu()
        
        // 1. Dashboard & Settings
        let dashboardItem = NSMenuItem(
            title: "Dashboard & Settings...",
            action: #selector(openDashboard),
            keyEquivalent: "d"
        )
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        // 2. Analytics Menu Item
        let analyticsItem = NSMenuItem(
            title: "Analytics...",
            action: #selector(openAnalytics),
            keyEquivalent: "a"
        )
        analyticsItem.target = self
        menu.addItem(analyticsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Recalibrate Action
        let recalibrateItem = NSMenuItem(
            title: "Recalibrate Posture",
            action: #selector(handleRecalibrate),
            keyEquivalent: "r"
        )
        recalibrateItem.target = self
        menu.addItem(recalibrateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Check for Updates
        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(handleCheckForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. Quit Action
        let quitItem = NSMenuItem(
            title: "Quit PostureAI",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    // MARK: - Actions
    
    /// Opens the modern SwiftUI Dashboard window
    @objc public func openDashboard() {
        if let onOpenSettings = onOpenSettings {
            onOpenSettings()
            return
        }
        
        if dashboardWindow == nil {
            let dashboardView = ModernDashboardView()
            let hostingController = NSHostingController(rootView: dashboardView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 850, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            window.center()
            window.contentViewController = hostingController
            window.title = "PostureAI Dashboard"
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            window.delegate = self
            
            self.dashboardWindow = window
        }
        
        NSApp.setActivationPolicy(.regular)
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Opens the Analytics window
    @objc public func openAnalytics() {
        if let onShowAnalytics = onShowAnalytics {
            onShowAnalytics()
        } else {
            if analyticsWindowController == nil {
                analyticsWindowController = AnalyticsWindowController()
            }
            analyticsWindowController?.showWindow(nil)
            analyticsWindowController?.window?.makeKeyAndOrderFront(nil)
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
    
    @objc private func handleQuit() {
        if let onQuit = onQuit {
            onQuit()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
    
    // MARK: - NSWindowDelegate
    
    public func windowWillClose(_ notification: Notification) {
        if let closingWindow = notification.object as? NSWindow, closingWindow == dashboardWindow {
            dashboardWindow = nil
            
            // Check if any other visible titled windows exist before hiding from dock
            let hasOtherVisibleWindows = NSApp.windows.contains { window in
                window != closingWindow && window.isVisible && !window.isMiniaturized && window.styleMask.contains(.titled)
            }
            
            if !hasOtherVisibleWindows {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
    
    // MARK: - Status & UI Updates
    
    public func updateShortcut(enabled: Bool, shortcut: Any? = nil) {}
    public func updateEnabledState(_ isEnabled: Bool) {}
    public func updateRecalibrateEnabled(_ canRecalibrate: Bool) {}
    
    public func updateStatus(text: String? = nil, icon: Any? = nil) {
        guard let button = statusItem?.button else { return }
        
        if let iconName = icon as? String {
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: "PostureAI")
        } else if let image = icon as? NSImage {
            button.image = image
        }
        
        if let text = text {
            button.title = text
        }
    }
    
    public func updateStatus(isSlouching: Bool = false) {
        let iconName = isSlouching ? "figure.fall" : "figure.walk"
        updateStatus(icon: iconName)
    }
    
    public func updateStatus(isSlouching: Bool = false, isPaused: Bool = false) {
        if isPaused {
            updateStatus(icon: "pause.circle")
        } else {
            updateStatus(isSlouching: isSlouching)
        }
    }
}
