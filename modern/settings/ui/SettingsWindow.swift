import AppKit
import SwiftUI

/// Builds the SwiftUI settings window for the Objective-C app delegate.
@objc(JTSettingsWindowFactory)
public final class JTSettingsWindowFactory: NSObject {
    @MainActor
    @objc public static func makeWindow(store: JTSettingsStore, engine: JTEngineController) -> NSWindow {
        let model = SettingsModel(store: store, engine: engine)
        let controller = NSHostingController(rootView: SettingsRootView(model: model))
        if #available(macOS 14.0, *) {
            // Let SwiftUI own the toolbar buttons and search field.
            controller.sceneBridgingOptions = [.toolbars]
        }
        let window = NSWindow(contentViewController: controller)
        window.title = "Jitouch Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbarStyle = .unified
        window.setContentSize(NSSize(width: 780, height: 600))
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("JitouchSettingsWindow")
        window.center()
        return window
    }
}

/// Keeps the hosting window's title in sync with the selected settings page.
struct WindowTitle: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { nsView.window?.title = title }
    }
}
