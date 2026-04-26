# apple-ui-from-spec

Claude Code skill: turn an Apple-platform UI spec (macOS, iOS, or iPadOS) into **integration-ready SwiftUI views** plus **PNG snapshots of every screen** — without launching the app.

## What it does

Given a multi-screen UI spec, this skill drives Claude through:

1. **Decomposing the spec** into a flat screen inventory (one row per screen × state × theme), persisted to `docs/screens.md`
2. **Generating a Swift Package** with two targets:
    - `AppleUIScreens` — pure SwiftUI views, models, components, tokens. Drop-in for the real app
    - `SnapshotTool` — executable that wires fixtures and renders PNGs
3. **Rendering every screen offscreen**:
    - `chrome=view` (default) — `NSHostingView` (macOS) or `UIHostingController` (iOS) + `cacheDisplay` / `drawHierarchy`. Captures `NavigationSplitView`, `NavigationStack`, in-content `.toolbar`, lists, pickers, forms.
    - `chrome=window` (macOS only, opt-in) — headless `NSWindow` + `NSHostingController`. Captures real titlebar, traffic lights, and `NSToolbar`. No app launch, no Dock icon.
4. **Reviewing** every PNG with the `frontend-design` skill, persisted to `docs/review-round-N.md`
5. **Iterating** at least two rounds until reviews stabilise

## Why it exists

The default LLM failure modes when given "build these Mac/iOS screens":
- Picks SwiftUI but launches the app to "verify" — slow, brittle, can't run in CI
- Picks `ImageRenderer` and produces blank PNGs because `NavigationSplitView` / materials / sheets need an AppKit/UIKit host
- Embeds mock stores inside views, making them un-shippable
- Forgets dark mode, hover states, empty states, validation errors
- Skips the design-review pass

This skill closes every one of those gaps, with explicit substitution rules for the things that still don't render offscreen (real vibrancy, sheets, popovers, animations).

## Integration contract

Views in `AppleUIScreens/` must be honest production code — no fixture imports, no `@StateObject` wrapping fakes, no `#Preview` blocks, no `@main` / `App` / `WindowGroup`. The skill includes three `grep` checks that verify this; the real app imports the library verbatim.

## Install

```bash
git clone https://github.com/sunfmin/apple-ui-from-spec.git ~/.claude/skills/apple-ui-from-spec
```

Then invoke from Claude Code with the spec as your message:

```
/apple-ui-from-spec <paste spec or attach file>
```

## How rendering works (the part most people get wrong)

`ImageRenderer` is the obvious choice but it can't host AppKit/UIKit-backed components. This skill uses `NSHostingView` / `UIHostingController` + `cacheDisplay` / `drawHierarchy` instead — the same approach `swift-snapshot-testing` uses internally. That single change unlocks `NavigationSplitView`, `NavigationStack`, in-content toolbars, lists, pickers, forms, and SF Symbols rendering.

For specs that need real `NSWindow` titlebar or `NSToolbar` (with the actual Mac chrome), there's an opt-in headless-window path: programmatically create an `NSWindow`, attach `NSHostingController` as content, configure `NSToolbar` with a retained delegate, force layout, and snapshot the window's frame view. Touches `NSApplication.shared` (singleton) but never calls `.run()`, never sets activation policy, never orders a window onscreen.

## What still can't be captured

- Real `NSVisualEffectView` vibrancy (offscreen has nothing to blur — approximate with semi-transparent colors over a gradient)
- `.sheet` / `.popover` / `.alert` presentation (needs run-loop; render the body as a `chrome=view` row at the inventory size)
- Live animations and transitions (single frame; render start or end state explicitly)
- Window-level `.toolbar` attached at `WindowGroup` on `chrome=view` rows (only `chrome=window` captures it)

## Output

When the skill finishes, you have:

- `Sources/AppleUIScreens/` — drop-in SwiftUI library
- `Sources/SnapshotTool/` — render harness with `Fixtures.swift`
- `docs/screens.md` — the inventory
- `docs/review-round-1.md` … `review-round-N.md` — the design-review trail
- `snapshots/*.png` — one PNG per inventory row, both light + dark modes

## License

MIT
