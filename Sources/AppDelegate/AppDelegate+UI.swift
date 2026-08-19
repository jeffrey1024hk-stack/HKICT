import AppKit
import SwiftUI

extension AppDelegate {
    
    static var dashboardWindow: NSWindow?

    @MainActor
    @objc func showDashboardWindow() {
        if AppDelegate.dashboardWindow == nil {
            let dashboardView = ModernDashboardView(appDelegate: self)
            let hostingController = NSHostingController(rootView: dashboardView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 660),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            window.isMovableByWindowBackground = true
            window.title = "PostureAI Settings"
            window.contentViewController = hostingController
            window.setContentSize(NSSize(width: 560, height: 660))
            window.center()
            window.isReleasedWhenClosed = false
            
            AppDelegate.dashboardWindow = window
        }
        
        AppDelegate.dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}