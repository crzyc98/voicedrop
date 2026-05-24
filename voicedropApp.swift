import SwiftUI
import AppKit

@main
struct voicedropApp: App {
    @StateObject private var statusBarManager = StatusBarManager()
    
    var body: some Scene {
        // We use Settings instead of WindowGroup to avoid showing a main window on launch.
        // The menu bar is managed by StatusBarManager.
        Settings {
            ContentView()
        }
    }
}

class StatusBarManager: NSObject, ObservableObject {
    private var statusItem: NSStatusItem!
    
    override init() {
        super.init()
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "VoiceDrop")
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "About VoiceDrop", action: #selector(aboutAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(settingsAction), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit VoiceDrop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc private func aboutAction() {
        NSApp.orderFrontStandardAboutPanel(nil)
    }
    
    @objc private func settingsAction() {
        // In SwiftUI, the Settings scene can be opened via the menu.
        // For now, we'll just print a placeholder.
        print("Settings opened")
    }
}
