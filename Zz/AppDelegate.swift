import SwiftUI
import AppKit

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingPanel?
    var statusItem: NSStatusItem?
    var onboardingWindow: NSWindow?
    private let hotkeyManager = HotkeyManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set as accessory app (no Dock icon)
        NSApp.setActivationPolicy(.accessory)

        // Create status bar item
        setupStatusBar()

        // Create floating panel
        setupPanel()

        // Check if we need onboarding
        if !AppSettings.shared.hasCompletedOnboarding {
            showOnboarding()
        }

        // Request accessibility permission proactively
        requestAccessibilityPermission()

        // Setup hotkey (will work once permission is granted)
        setupHotkey()
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            let image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: "Zz")
            image?.isTemplate = true  // Follows system appearance
            button.image = image
            button.image?.size = NSSize(width: 16, height: 16)
        }

        // Menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle (⌘⇧Space)", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let permItem = NSMenuItem(title: "Grant Permissions...", action: #selector(showPermissions), keyEquivalent: "")
        menu.addItem(permItem)

        menu.addItem(NSMenuItem(title: "Setup...", action: #selector(showOnboardingFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc func togglePanel() {
        panel?.toggleVisibility()
    }

    @objc private func showPermissions() {
        // Open Accessibility settings
        requestAccessibilityPermission()
    }

    @objc private func showOnboardingFromMenu() {
        showOnboarding()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Floating Panel

    private func setupPanel() {
        let chatView = ChatView()
        let hostingView = NSHostingView(rootView: chatView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 380, height: 500)

        panel = FloatingPanel(contentView: hostingView)
    }

    // MARK: - Onboarding

    func showOnboarding() {
        // Close existing
        onboardingWindow?.close()

        let onboardingView = OnboardingView {
            DispatchQueue.main.async { [weak self] in
                self?.onboardingWindow?.close()
                self?.onboardingWindow = nil
                self?.setupHotkey()
                self?.panel?.showWithAnimation()
            }
        }

        let hostingView = NSHostingView(rootView: onboardingView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 460),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.center()
        window.level = .floating
        window.makeKeyAndOrderFront(nil)

        // When window closes, clean up reference
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification,
                                                object: window, queue: .main) { [weak self] _ in
            self?.onboardingWindow = nil
        }
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        hotkeyManager.onToggle = { [weak self] in
            self?.togglePanel()
        }
        hotkeyManager.start()
    }

    // MARK: - Permissions

    private func requestAccessibilityPermission() {
        if !AccessibilityReader.shared.hasPermission {
            // This will show the system permission dialog
            let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
