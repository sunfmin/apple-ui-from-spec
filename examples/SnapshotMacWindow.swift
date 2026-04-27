// SnapshotTool/SnapshotMacWindow.swift
// chrome=window path for macOS only. Headless NSWindow + NSHostingController.
// Captures real NSWindow titlebar, traffic lights, and window-level NSToolbar.
//
// Touches NSApplication.shared (singleton) but DOES NOT enter the run loop.
// FORBIDDEN here (would activate app or order a window onscreen):
//   NSApp.setActivationPolicy(.regular)
//   NSApp.activate(ignoringOtherApps:)
//   window.makeKeyAndOrderFront(_:)
//   window.orderFront(_:)
//
// Still cannot capture (even via this path):
//   - Real NSVisualEffectView vibrancy (nothing behind to blur)
//   - .sheet / .popover / .alert (need run-loop turn — render body as chrome=view)
//   - Animations / transitions (one frame only)

#if canImport(AppKit)
import SwiftUI
import AppKit

@MainActor
func snapshotMacWindow<V: View>(_ view: V, size: CGSize,
                                title: String = "",
                                toolbar: NSToolbar? = nil) -> Data? {
    _ = NSApplication.shared

    let host = NSHostingController(rootView: view)
    let window = NSWindow(
        contentRect: CGRect(origin: .zero, size: size),
        styleMask: [.titled, .closable, .miniaturizable, .resizable,
                    .fullSizeContentView, .unifiedTitleAndToolbar],
        backing: .buffered, defer: false)
    window.contentViewController = host
    window.toolbar = toolbar
    window.title = title
    window.titleVisibility = .visible  // chrome=window exists for real titlebar look
    window.isReleasedWhenClosed = false
    window.layoutIfNeeded()

    // Snapshot the WINDOW FRAME (not contentView) — captures titlebar + traffic lights + toolbar.
    guard let frameView = window.contentView?.superview,
          let rep = frameView.bitmapImageRepForCachingDisplay(in: frameView.bounds) else { return nil }
    rep.size = frameView.bounds.size
    frameView.cacheDisplay(in: frameView.bounds, to: rep)
    return rep.representation(using: .png, properties: [:])
}
#endif
