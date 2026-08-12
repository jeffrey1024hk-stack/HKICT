import AppKit
import SwiftUI

extension AppDelegate {
    
    static var dashboardWindow: NSWindow?

    @MainActor
    @objc func showDashboardWindow() {
        if AppDelegate.dashboardWindow == nil {
            let dashboardView = ModernDashboardView()
            let hostingController = NSHostingController(rootView: dashboardView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 490),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.backgroundColor = .clear
            window.contentViewController = hostingController
            window.center()
            window.isReleasedWhenClosed = false
            
            AppDelegate.dashboardWindow = window
        }
        
        AppDelegate.dashboardWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}