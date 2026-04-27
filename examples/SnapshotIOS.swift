// SnapshotTool/SnapshotIOS.swift
// chrome=view path for iOS / iPadOS. UIHostingController + drawHierarchy at 2× scale.
// Captures: NavigationStack, TabView, in-content `.toolbar`, status bar via
// safeAreaInset, Form, List(.insetGrouped).

#if canImport(UIKit)
import SwiftUI
import UIKit

@MainActor
func snapshotIOS<V: View>(_ view: V, size: CGSize) -> Data? {
    let controller = UIHostingController(rootView:
        view
            .frame(width: size.width, height: size.height)
    )
    controller.view.bounds = CGRect(origin: .zero, size: size)
    controller.view.backgroundColor = .clear
    controller.overrideUserInterfaceStyle = .light
    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()

    let format = UIGraphicsImageRendererFormat()
    format.scale = 2.0
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    let image = renderer.image { _ in
        controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
    }
    return image.pngData()
}
#endif
