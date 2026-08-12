import AppKit
import SwiftUI

@MainActor
public class MenuBarManager: NSObject {
    // Public statusItem for popup window anchoring in AppDelegate
    public var statusItem: NSStatusItem!
    
    // Window reference to keep ModernDashboardView alive
    private var dashboardWindow: NSWindow?
    
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
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "Dorso")
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
        
        menu.addItem(NSMenuItem.separator())
        
        // 2. Recalibrate Action
        let recalibrateItem = NSMenuItem(
            title: "Recalibrate Posture",
            action: #selector(handleRecalibrate),
            keyEquivalent: "r"
        )
        recalibrateItem.target = self
        menu.addItem(recalibrateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Check for Updates
        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(handleCheckForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Quit Action
        let quitItem = NSMenuItem(
            title: "Quit Dorso",
            action: #selector(handleQuit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    /// Opens the modern SwiftUI Dashboard window
    @objc public func openDashboard() {
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
            window.title = "Dorso Dashboard"
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.isMovableByWindowBackground = true
            
            self.dashboardWindow = window
        }
        
        dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func handleRecalibrate() {
        if let onRecalibrate = onRecalibrate {
            onRecalibrate()
        } else {
            NotificationCenter.default.post(name: NSNotification.Name("RecalibratePosture"), object: nil)
        }
    }
    
    @objc private func handleCheckForUpdates() {
        onCheckForUpdates?()
    }
    
    @objc private func handleQuit() {
        if let onQuit = onQuit {
            onQuit()
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
    
    // Helper hooks called by AppDelegate
    public func updateShortcut(enabled: Bool, shortcut: Any? = nil) {}
    public func updateEnabledState(_ isEnabled: Bool) {}
    public func updateRecalibrateEnabled(_ canRecalibrate: Bool) {}
    public func updateStatus(text: String? = nil, icon: Any? = nil) {}
    public func updateStatus(isSlouching: Bool = false) {}
    public func updateStatus(isSlouching: Bool = false, isPaused: Bool = false) {}
}