// SnapshotTool/SnapshotMac.swift
// chrome=view path for macOS. Hosts the SwiftUI graph in NSHostingView and
// snapshots via cacheDisplay. No NSWindow, no NSApplication touch.
//
// Captures: NavigationSplitView, in-content `.toolbar`, List, Picker,
// ProgressView, Form, approximated materials.
// Does NOT capture: real NSWindow titlebar, traffic lights, vibrancy,
// sheets/popovers/alerts. Use SnapshotMacWindow.swift for titlebar/toolbar.

#if canImport(AppKit)
import SwiftUI
import AppKit

@MainActor
func snapshotMac<V: View>(_ view: V, size: CGSize) -> Data? {
    let host = NSHostingView(rootView:
        view
            .frame(width: size.width, height: size.height)
    )
    host.frame = CGRect(origin: .zero, size: size)
    host.layoutSubtreeIfNeeded()

    guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return nil }
    rep.size = host.bounds.size
    host.cacheDisplay(in: host.bounds, to: rep)
    return rep.representation(using: .png, properties: [:])
}
#endif
