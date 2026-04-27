// SnapshotTool/main.swift (excerpted)
// One Snap per inventory row. Dispatcher routes by (platform, chrome).
// Forbidden combinations are rejected at construction time.

import SwiftUI
#if canImport(AppKit)
import AppKit
#endif

enum Platform { case macOS, iOS, iPadOS }
enum Chrome { case view, window }

struct Snap {
    let name: String
    let platform: Platform
    let kind: String           // "window", "sheet", "screen", etc. (from inventory)
    let chrome: Chrome
    let size: CGSize
    let view: AnyView
    var title: String = ""
    #if canImport(AppKit)
    var toolbar: NSToolbar? = nil   // only meaningful when platform == .macOS && chrome == .window
    #endif

    init(name: String, platform: Platform, kind: String, chrome: Chrome,
         size: CGSize, view: AnyView, title: String = "") {
        precondition(!(chrome == .window && (platform == .iOS || platform == .iPadOS)),
                     "chrome=window is macOS-only — use chrome=view for iOS/iPadOS")
        precondition(!(chrome == .window && kind != "window"),
                     "chrome=window only applies to kind=window (not sheets/popovers/alerts)")
        self.name = name
        self.platform = platform
        self.kind = kind
        self.chrome = chrome
        self.size = size
        self.view = view
        self.title = title
    }
}

@MainActor
func main() throws {
    let outDir = URL(fileURLWithPath: "snapshots")
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    let snaps: [Snap] = Inventory.all   // built from docs/screens.md, one Snap per row

    for s in snaps {
        let data: Data?
        switch (s.platform, s.chrome) {
        case (.macOS, .view):
            data = snapshotMac(s.view, size: s.size)
        #if canImport(AppKit)
        case (.macOS, .window):
            data = snapshotMacWindow(s.view, size: s.size,
                                     title: s.title, toolbar: s.toolbar)
        #endif
        case (.iOS, .view), (.iPadOS, .view):
            data = snapshotIOS(s.view, size: s.size)
        case (.iOS, .window), (.iPadOS, .window):
            fatalError("unreachable — preconditions reject this combination")
        }
        guard let png = data else {
            print("✗ \(s.name) — render returned nil")
            continue
        }
        try png.write(to: outDir.appendingPathComponent("\(s.name).png"))
        print("✓ \(s.name)  [\(s.platform) / \(s.chrome)]")
    }
}
