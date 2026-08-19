import AppKit
#if SWIFT_PACKAGE
import PostureAICore
#endif

@main
@MainActor
struct PostureAIMain {
    
    // 1. MOVE DELEGATE HERE: This makes it a permanent static property
    // so Swift's memory manager never deletes it.
    static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        
        // 2. Assign the static delegate
        app.delegate = delegate
        app.setActivationPolicy(.accessory)

        // Set up main menu for standard keyboard shortcuts (Cmd+W, Cmd+Q, etc.)
        let mainMenu = NSMenu()

        // Application menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(AppDelegate.openSettings), keyEquivalent: ",")
        settingsItem.target = delegate
        appMenu.addItem(settingsItem)

        appMenu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit PostureAI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenu.addItem(quitItem)

        // File menu (for Cmd+W)
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenuItem.submenu = fileMenu

        let closeItem = NSMenuItem(title: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileMenu.addItem(closeItem)

        // Edit menu (for standard text editing shortcuts)
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenuItem.submenu = editMenu

        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"))
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        app.mainMenu = mainMenu
        app.run()
    }
}
