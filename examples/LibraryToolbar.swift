// SnapshotTool/LibraryToolbar.swift
// Build NSToolbar in the snapshot tool, NEVER in AppleUIScreens/.
//
// Silent failure to avoid: NSToolbar holds its delegate WEAKLY. If you write
//   tb.delegate = LibraryToolbarDelegate()
// the delegate deallocates immediately and the toolbar renders empty.
// Fix: retain the delegate via objc_setAssociatedObject, or store it on a
// property whose lifetime exceeds the snapshot call.

#if canImport(AppKit)
import AppKit

final class LibraryToolbarDelegate: NSObject, NSToolbarDelegate {
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        // ... return identifiers for default items
        []
    }
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        // ... return identifiers for all allowed items
        []
    }
    func toolbar(_ toolbar: NSToolbar,
                 itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        // ... vend NSToolbarItem instances
        nil
    }
}

let libraryToolbar: NSToolbar = {
    let tb = NSToolbar(identifier: "LibraryToolbar")
    let delegate = LibraryToolbarDelegate()
    tb.delegate = delegate
    objc_setAssociatedObject(tb, "delegate-retain", delegate, .OBJC_ASSOCIATION_RETAIN)
    tb.displayMode = .iconAndLabel
    return tb
}()
#endif
