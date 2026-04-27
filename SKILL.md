---
name: apple-ui-from-spec
description: Use when given an Apple-platform UI spec (macOS, iOS, or iPadOS) covering multiple screens or dialogs and the output must be (a) integration-ready SwiftUI views and (b) PNG snapshots of every screen rendered offscreen without launching the app. Triggers include "build the screens from this spec", "implement these mockups", "create the macOS/iOS UI", "SwiftUI views from spec", or specs listing windows/screens/sheets/states.
---

# Apple UI from Spec

## Overview

Given a UI spec covering multiple screens or dialogs on macOS, iOS, or iPadOS, produce:
1. **Pure SwiftUI views** that drop straight into a real app — no embedded fake stores, no fixture references inside view files.
2. **PNG snapshots of every screen-state** rendered offscreen via `NSHostingView` (macOS) or `UIHostingController` (iOS), with NO need to launch the app.
3. **At least one design-review iteration** using the `frontend-design` skill against the PNGs.

**Core principle:** the views must be honest production code. Fixtures and rendering harness live outside the view layer so the views can be lifted into the real app verbatim.

**Two render paths, both offscreen, neither runs the app:**
- **`chrome=view`** (default): `NSHostingView` / `UIHostingController` + `cacheDisplay` / `drawHierarchy`. Captures real SwiftUI content including `NavigationSplitView`, `NavigationStack`, in-content `.toolbar`, `List`, `Picker`, `ProgressView`, `TabView`, `Form`.
- **`chrome=window`** (opt-in, **macOS only**): headless `NSWindow` + `NSHostingController`. Captures the real window titlebar, traffic lights, and window-level `NSToolbar`. Touches `NSApplication.shared`; never calls `.run()`, no Dock icon, no visible window.

A few things remain uncapturable on either path (real `NSVisualEffectView` vibrancy, `.sheet` / `.popover` / `.alert` presentation, animations); substitution rules in step 5 cover those.

**REQUIRED SUB-SKILL:** Use `frontend-design` for the review pass in step 7.

## Quick Reference

**Inventory column values:**

| column | values |
|--------|--------|
| `platform` | `macOS` \| `iOS` \| `iPadOS` |
| `kind` (macOS) | `window`, `sheet`, `popover`, `inspector`, `menu` |
| `kind` (iOS / iPadOS) | `screen`, `sheet`, `popover`, `alert`, `tab`, `sidebar` |
| `chrome` | `view` (default, all platforms) \| `window` (macOS only, opt-in for real titlebar / `NSToolbar`) |
| `size` | macOS: 1280×800 \| 1440×900 \| 1680×1050 ; macOS sheet: 460×220 → 640×520 ; iPhone 16: 393×852 ; iPad Pro 11": 1024×1366 ; iOS sheet (`.medium`): 393×440 |

**State rubric — enumerate every state that applies (do not collapse):**

| axis | values |
|------|--------|
| Data | empty, loading, populated, error |
| Form | default (empty), filled, in-progress, validation error |
| Interaction | hover (macOS, via `forceHoverTarget`), focus, disabled, selected, pressed (iOS) |
| Window / screen | focused vs unfocused (macOS); landscape vs portrait (iOS / iPadOS, only if rotation is in spec) |

**Forbidden combinations** (rejected by `Snap` precondition):
- `chrome=window` on `iOS` or `iPadOS` — macOS-only
- `chrome=window` on `kind != "window"` — sheets/popovers/alerts must be `chrome=view`

**`chrome=window` opt-in triggers** (spec must use one of these): "titlebar", "traffic lights", "NSToolbar", "window chrome", or a mockup that explicitly shows them.

**Pipeline:** spec → `docs/screens.md` (inventory) → `Sources/AppleUIScreens/` (views) + `Sources/SnapshotTool/Fixtures.swift` (data) → `swift run SnapshotTool` → `snapshots/*.png` → `frontend-design` → `docs/review-round-N.md` → fix in `AppleUIScreens/` only → re-render → repeat.

## When to Use

- A spec lists multiple windows, screens, sheets, or states for macOS, iOS, or iPadOS
- View code is meant to be integrated into a real app, not thrown away after review
- Apple HIG aesthetic is requested or implied

When NOT to use:
- Single isolated component without screen-level context
- Web/React UI (this skill is SwiftUI-specific)
- Cross-platform apps that don't actually use SwiftUI

## The spec is an argument

The spec is whatever the user provided alongside this skill — pasted text, a file path, or a link. **Read it in full before doing anything else.** If the spec is missing, ask for it; do not invent screens.

If the platform isn't named, infer it from vocabulary:
- "window", "sidebar", "menu bar", "traffic lights" → macOS
- "tab bar", "navigation bar", "modal screen", iPhone size → iOS
- "split view on iPad", "popover from a bar button" → iPadOS
- Mixed signals → **ask** the user before continuing.

## Workflow

### 1. Decompose the spec FIRST — write `docs/screens.md`

Before any code, extract a flat **screen inventory**. One row per artifact-state combination:

| name | platform | kind | chrome | size | state |
|------|----------|------|--------|------|-------|
| main-three-pane-populated | macOS | window | view | 1280×800 | populated |
| main-three-pane-unfocused | macOS | window | view | 1280×800 | window unfocused |
| main-with-real-toolbar | macOS | window | window | 1440×900 | populated, real NSToolbar + traffic lights |
| new-folder-sheet-default | macOS | sheet | view | 460×220 | default |
| new-folder-sheet-error | macOS | sheet | view | 460×260 | validation error |
| onboarding-welcome | iOS | screen | view | 393×852 | iPhone 16 |
| settings-sheet-medium | iOS | sheet | view | 393×440 | `.medium` detent |
| document-split | iPadOS | screen | view | 1024×1366 | iPad Pro 11", landscape |

**Platform values:** `macOS` | `iOS` | `iPadOS`.

**Kind values:**
- macOS: `window`, `sheet`, `popover`, `inspector`, `menu`
- iOS / iPadOS: `screen` (full-screen content), `sheet` (`.sheet` body), `popover`, `alert`, `tab` (one tab's screen), `sidebar` (iPad sidebar)

**Chrome values:**
- `view` (default) — render via the **hosting-view harness** (step 6, primary path). Fast, simple. Captures content + nav containers + in-content `.toolbar` + lists + pickers + materials (approximated). Does NOT capture the real `NSWindow` titlebar, traffic lights, or `WindowGroup`-level `NSToolbar`.
- `window` — render via the **headless-window harness** (step 6, optional path, **macOS only**). Captures the real `NSWindow` titlebar + traffic lights + window-level `NSToolbar`. Touches `NSApplication.shared` — does NOT enter the run loop, no Dock icon, no visible window.

**iOS / iPadOS always use `chrome=view`.** `UIHostingController` already captures `NavigationStack` toolbars, status bars (via `safeAreaInset`), and tab bars from inside the SwiftUI graph; a `UIWindow` adds no real visible chrome that `chrome=view` misses. The dispatcher rejects `(iOS|iPadOS, .window)` rows.

**`chrome=window` does NOT capture sheets, popovers, alerts, vibrancy, or animations.** Those still require `chrome=view` rows rendering the body directly. Sheet+`chrome=window` is forbidden — the dispatcher must reject it.

Default is `view`. Only mark `window` when the spec uses one of these trigger words: **"titlebar", "traffic lights", "NSToolbar", "window chrome"**, or shows them explicitly in a mockup. Phrases like "macOS-native feel" or "looks like a real Mac app" do NOT trigger `chrome=window` — those are satisfied by `chrome=view` + good HIG fidelity.

**Size — pick from the spec or these defaults:**
- macOS windows: 1280×800 (compact), 1440×900 (typical), 1680×1050 (wide)
- macOS sheets: 460×220 → 640×520 (grow with content)
- iPhone 16: 393×852 / iPhone 16 Pro Max: 430×932
- iPad Pro 11": 1024×1366 / iPad Air: 820×1180
- iOS sheet at `.medium` detent: width × ~half-height (e.g. 393×440 on iPhone 16)

**State rubric — enumerate every state that applies, do not collapse them:**
- **Data:** empty, loading, populated, error
- **Form:** default (empty), filled, in-progress, validation error
- **Interaction:** hover (macOS only — render via `forceHoverTarget` input), focus, disabled, selected, pressed (iOS)
- **Window / screen:** focused vs unfocused (macOS only); landscape vs portrait (iOS / iPadOS, only if spec implies rotation)

**State combinations stack into one row.** A screen showing both "filled" and "validation error" is ONE row, not two.

**Cardinality cap.** If the inventory exceeds 30 rows, prune to states the user named or strongly implied — re-read the spec.

Each row's `name` is kebab-case and becomes the PNG filename. Do not skip this step.

### 2. Stack: Swift Package, hosting-view snapshot harness

Use a **Swift Package** with two targets:

- **Library target** `AppleUIScreens` — pure views, components, models, tokens. Imported by the real app verbatim.
- **Executable target** `SnapshotTool` — imports the library, wires fixtures, renders PNGs.

The app itself is **never built or launched**. `swift run SnapshotTool` produces every PNG.

`Package.swift` platforms: declare each target your spec covers. Typical:

```swift
platforms: [.macOS(.v13), .iOS(.v16)]
```

For an iOS-only spec running on a Mac dev machine, build the snapshot tool as a macOS executable that uses `import UIKit` via Mac Catalyst (`.macCatalyst(.v16)` in `Package.swift`), or run on the iOS simulator via `xcodebuild test`. Document which path you took.

**`AppleUIScreens` is a library, not an app.** No `@main`, no `App` conformance, no `Scene` types, no `WindowGroup`. The real app provides those.

**Why hosting views instead of `ImageRenderer`:** `ImageRenderer` rasterises the SwiftUI graph offscreen and cannot host AppKit / UIKit-backed components. `NSHostingView` / `UIHostingController` provides a real AppKit / UIKit view tree, so `NavigationSplitView`, `NavigationStack`, in-content `.toolbar`, `List`, `Picker`, `ProgressView`, etc. render correctly. The few things still uncapturable are listed in step 5.

**Production alternative:** teams already using `swift-snapshot-testing` (pointfreeco) get the same hosting-view rendering inside `XCTest` / `swift-testing`. Use that if you want test-bound snapshots; this skill's standalone harness is for "produce artifacts" workflows.

### 3. Clean architecture — views are integration-ready

```
Package.swift
Sources/
  AppleUIScreens/             # Library — drop into the real app verbatim
    Views/                    # One file per screen
    Components/               # Reusable primitives (Sidebar, ListRow, ToolbarChrome…)
    Models/                   # Plain structs — replaceable
    Tokens/                   # Spacing.swift, Palette.swift, Typography.swift
  SnapshotTool/               # Executable — never imported by the app
    main.swift
    Fixtures.swift            # ALL fake data lives here
    SnapshotMac.swift         # NSHostingView render fn (chrome=view, default)
    SnapshotIOS.swift         # UIHostingController render fn (chrome=view, default)
    SnapshotMacWindow.swift   # Headless NSWindow render fn (chrome=window, macOS only)
    LibraryToolbar.swift      # NSToolbar + NSToolbarDelegate, retained explicitly
docs/screens.md
snapshots/
```

**Integration contract — non-negotiable:**

- **Views are pure.** Each view is `struct ___View: View` whose inputs are init parameters and bindings. No `@StateObject` wrapping fake stores, no static fixture references, no `#Preview` blocks inside view files.
- **Models are plain structs**, replaceable by the real app's models (or used as-is).
- **Components consume tokens.** `Spacing.medium` not `12`; `Palette.accent` not `Color.blue`.
- **Each view renders standalone** given only its declared inputs.
- **Callbacks are closures** with no-op defaults so snapshots work without wiring.

**Verification greps (all must return zero hits):**

```bash
grep -rE 'Fixtures|SampleData|MockData|FakeData' Sources/AppleUIScreens/
grep -rE '@StateObject|@EnvironmentObject|#Preview' Sources/AppleUIScreens/
grep -rE '@main|: App \{|: Scene \{|WindowGroup' Sources/AppleUIScreens/
```

If any return hits, the contract is broken. Fix before moving on.

### 4. Realistic fixture data — in `SnapshotTool/Fixtures.swift` only

| Bad | Good |
|-----|------|
| `"Test Note 1"` | `"Q3 planning notes"` |
| `"user@test.com"` | `"hannah.k@theplant.jp"` |
| `["Item A", "Item B"]` | varied lengths, real-feeling content |

Mirror familiar Apple contexts: Mail, Notes, Finder, Reminders, Messages. Vary text lengths so layouts get stress-tested.

Fixtures live exclusively in `SnapshotTool/Fixtures.swift`. They are never visible to the library target.

### 5. Render-friendly composition — what the harness still cannot capture

Hosting views capture most SwiftUI content correctly, but a few things still don't reach the bitmap.

| Won't render offscreen | Why | Substitute in `AppleUIScreens/Views/` |
|---|---|---|
| **Window-level `.toolbar`** (Mac NSToolbar at `WindowGroup`, iOS UINavigationBar at the window root) | Bound to the window/scene, not the view tree | **Two options:** (a) default — build a `ToolbarChrome` `HStack` component as the top of the screen view; (b) mark the row `chrome=window` and render via the headless-window harness — captures a real `NSToolbar`. **In-content `.toolbar` attached to `NavigationStack` / `NavigationSplitView` DOES render via the default path — use it freely.** |
| **`.sheet(isPresented:) { … }`** | Presents in a separate window/controller; needs a run-loop turn | Render the sheet's body view directly at the inventory size. The real app calls `.sheet` at integration. **Even `chrome=window` cannot capture this** — sheet presentation needs the run loop. |
| **`Scene` modifiers** (`.windowStyle`, `.windowToolbarStyle`, `.defaultSize`) | Apply to `Scene`, not `View` | **Two options:** (a) default — hand-draw a `WindowChrome` `HStack` for traffic lights + titlebar; (b) mark the row `chrome=window` and use the headless-window harness — captures real titlebar and traffic lights. `.defaultSize` is a config hint, not a visual; the headless window's `contentRect` size replaces it. |
| **`.background(.regularMaterial)` / `.thinMaterial` vibrancy** | `NSVisualEffectView` blurs what's *behind* it; offscreen there's nothing behind (neither chrome path captures real vibrancy) | Approximate: `Color(nsColor: .controlBackgroundColor).opacity(0.85)` over a subtle gradient (macOS) or `Color(uiColor: .secondarySystemBackground)` (iOS). Real vibrancy returns at integration. |
| **macOS window-unfocused chrome** | AppKit-drawn at `NSWindow` level | `windowIsFocused: Bool` input on `WindowChrome`; desaturate / dim manually. |
| **`:hover`** | Snapshot is static | `forceHoverTarget: HoverTarget?` input; the view renders the hover style for that target. |
| **Animations / spring transitions** | Snapshot is one frame | Render the start or end state explicitly via input. |
| **Live `.popover` / `.alert` / `.fullScreenCover`** | Same window-presentation issue as `.sheet` | Render the body view directly. |

**What DOES render correctly under the hosting-view harness** — the `ImageRenderer`-era restrictions on these were too strict:
- `NavigationSplitView { sidebar } content: { … } detail: { … }`
- `NavigationStack { … }` (iOS / iPadOS)
- `.toolbar { ToolbarItemGroup(…) }` attached to a `NavigationStack` / `NavigationSplitView`
- `List`, `.listStyle(.sidebar)`, `.listStyle(.insetGrouped)`
- `Picker`, `ProgressView`, `Stepper`, `DatePicker`, `Slider`
- `TabView` (page and standard styles)
- `Form`, `Section`, `LabeledContent`

Use these freely inside `AppleUIScreens/Views/`.

**Compositional rule:** screen views compose with standard SwiftUI primitives + hosting-view-safe containers. The real app provides Scene-level chrome (`.windowStyle`, window-level `.toolbar`, `.sheet`, real vibrancy). Two clients (snapshot tool + real app) consume the same view structs.

### 6. Render every screen via hosting view — no app launch

`SnapshotTool` provides one render function per platform. Each is small (~20 lines); copy from `examples/` and adapt.

| chrome | platform | function | source |
|--------|----------|----------|--------|
| view | macOS | `snapshotMac(view:size:)` — `NSHostingView` + `cacheDisplay` | `examples/SnapshotMac.swift` |
| view | iOS / iPadOS | `snapshotIOS(view:size:)` — `UIHostingController` + `drawHierarchy` at 2× | `examples/SnapshotIOS.swift` |
| window | macOS only | `snapshotMacWindow(view:size:title:toolbar:)` — headless `NSWindow` + `NSHostingController`, snapshots the **window frame view** (titlebar + traffic lights + `NSToolbar`) | `examples/SnapshotMacWindow.swift` |

**`chrome=window` rules — read before copying `SnapshotMacWindow.swift`:**
- Touch only `NSApplication.shared` (singleton). The following are FORBIDDEN — they would activate the app or order a window onscreen: `NSApp.run()`, `NSApp.setActivationPolicy(.regular)`, `NSApp.activate(...)`, `window.makeKeyAndOrderFront(_:)`, `window.orderFront(_:)`.
- Snapshot `window.contentView?.superview` (the frame view), NOT `window.contentView` — the frame view is what contains the titlebar and toolbar.
- `titleVisibility = .visible` — the whole point of `chrome=window` is the real titlebar.
- Still cannot capture (run-loop / nothing-behind issues): real `NSVisualEffectView` vibrancy, `.sheet` / `.popover` / `.alert` presentation, animations. For these, render the body as a `chrome=view` row.

**`NSToolbar` retention — silent failure if forgotten.** `NSToolbar` holds its `delegate` weakly. If you write `tb.delegate = LibraryToolbarDelegate()`, the delegate deallocates immediately and the toolbar renders empty. Retain explicitly via `objc_setAssociatedObject(tb, "delegate-retain", delegate, .OBJC_ASSOCIATION_RETAIN)` (or store the delegate on a long-lived property). Build toolbars in `SnapshotTool/LibraryToolbar.swift` — NEVER inside `AppleUIScreens/`. See `examples/LibraryToolbar.swift`.

**Dispatcher — `SnapshotTool/main.swift`:** copy from `examples/SnapDispatcher.swift`. Defines `Platform`, `Chrome`, `Snap`, and the loop. The `Snap` initializer enforces forbidden combinations as preconditions:
- `chrome=window` × (`iOS` | `iPadOS`) → `precondition` fails. iOS chrome (status bar, nav bar) is captured by `chrome=view`.
- `chrome=window` × `kind != "window"` → `precondition` fails. Sheets/popovers/alerts cannot be captured by `chrome=window`; render the body as `chrome=view`.

**Rules — apply to every render call:**
- **One snap per inventory row.** No skipping, no batching.
- **Scale 2.0** on iOS for Retina output. PNG carries no DPI metadata; note "rendered at 2× DPR" in the review context.
- **Window-unfocused** is `windowIsFocused: false` on `WindowChrome`, not opacity hacks on the whole view.
- **Hover** is `forceHoverTarget`, not a real hover.
- **A `nil` result almost always means** a `Scene` modifier or window-level toolbar leaked into the view graph — re-read the substitution table.

**Inventory ↔ snapshot count check.** Copy `examples/inventory_check.py` to the user's project (e.g. as `scripts/inventory_check.py`) and run it from the project root after `swift run SnapshotTool`. It reads `docs/screens.md`, lists `snapshots/*.png`, and exits non-zero on mismatch. Missing PNG = work not done.

### 7. Review with `frontend-design`

For each PNG, invoke `frontend-design` with:
- **Primary input:** the PNG file path
- **Context:** screen name, platform, kind, state
- **Note for the reviewer:** "SwiftUI render at 2× DPR via hosting view. The real app supplies window-level toolbar, vibrancy, and sheet presentation — critique only what is visible. Do not propose web/CSS code."
- **Known deltas to flag, not penalise:** approximated materials, no real `NSVisualEffectView` blur, no live unfocused-window chrome, no live sheets/popovers/alerts.

Critique focus:
- HIG fidelity per platform (Mac vs iOS spacing, type sizes, control sizing, tap targets)
- Visual hierarchy and weight
- Color and contrast
- Generic-AI red flags (rounded-everything, gradient buttons, emoji-as-icons, lorem-ipsum content, generic SF Symbols)

**Persist every round to disk before fixing.** Write `docs/review-round-N.md` with one section per PNG and a bullet list of concrete issues. Do not write it after-the-fact.

### 8. Iterate

**Minimum two rounds.** Round 1 stop is allowed only if `docs/review-round-1.md` contains zero substantive issues — and the report MUST quote that file as proof.

Each round:
1. Read `docs/review-round-N.md`
2. Apply fixes inside `AppleUIScreens/` only — never inside `SnapshotTool/`
3. `swift run SnapshotTool` to re-render affected rows
4. New review → `docs/review-round-(N+1).md`
5. **Regression check:** if a round-N fix reintroduces an issue from round N-1, escalate
6. Stop when no new substantive issues appear

## HIG quick reference

**Shared (both platforms):**
- **Type:** `.system(.body, design: .default)` — never `.font(.custom("Inter"…))`
- **Spacing scale:** `enum Spacing { static let xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 20.0, xxl = 24.0, xxxl = 32.0 }`
- **Colors:** semantic — `Color.accentColor`, `Color(nsColor: .labelColor)` / `Color(uiColor: .label)`, `Color(nsColor: .separatorColor)` / `Color(uiColor: .separator)`.
- **SF Symbols:** specific symbols, not generic `star.fill`. Avoid `.hierarchical` / `.palette` rendering modes — they sometimes drop colors offscreen.

**macOS specifics (snapshot-safe):**
- `NavigationSplitView`, `List(.sidebar)`, `Picker`, `Form`, in-content `.toolbar` — all render
- Sidebar width 220–260pt; sheet width 480–560pt
- Buttons: `.controlSize(.regular)` ~24pt, `.large` ~32pt; primary = `.borderedProminent`
- Approximate window vibrancy with `Color(nsColor: .controlBackgroundColor).opacity(0.85)` over a subtle gradient
- Hand-draw `WindowChrome` for traffic lights and titlebar when needed

**macOS integration-only (real app, not in `Views/`):**
- `.windowStyle(.hiddenTitleBar)`, `.windowToolbarStyle(.unified)`
- `.background(.regularMaterial)` for true vibrancy at the window root
- Window-level `.toolbar` attached at `WindowGroup`

**iOS / iPadOS specifics (snapshot-safe):**
- `NavigationStack`, `TabView`, `Form`, `List(.insetGrouped)`, in-content `.toolbar` — all render
- Tap targets: 44×44pt minimum
- Standard sheet detents: render the sheet at the corresponding height (e.g., `.medium` ≈ half the screen)
- Use `.safeAreaInset(edge: .top)` to render a faux status bar (or include it in `WindowChrome`)
- Buttons: standard heights driven by `.controlSize`; primary = `.borderedProminent`

**iOS / iPadOS integration-only (real app):**
- `.sheet(item:) { … }`, `.popover(...)`, `.alert(...)`, `.fullScreenCover(...)`
- `.toolbar(...)` attached at the app root (window-level)
- `.tabBar` configuration at `Scene`

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Coding before writing inventory | Write `docs/screens.md` first, always |
| Treating in-content `.toolbar` as integration-only | It renders — only window-level toolbars don't |
| `.sheet(isPresented:)` in a snapshot view | Render the sheet body directly at sheet size |
| `.popover` / `.alert` / `.fullScreenCover` in a snapshot view | Same — render the body directly |
| `.background(.regularMaterial)` and expecting vibrancy in PNG | Approximate; real vibrancy returns at integration |
| `@StateObject` of a fake store inside a view | Move to inputs; views take data via init |
| Fixture imports in `AppleUIScreens/` | Move to `SnapshotTool/Fixtures.swift` |
| `@main` / `App` / `WindowGroup` in `AppleUIScreens` | Library only |
| Building/running the app for screenshots | `swift run SnapshotTool` only |
| Hardcoded `Color.blue`, magic padding `12` | `Palette` and `Spacing` tokens |
| `nil` snapshot result and you ignore it | Almost always a Scene modifier or window-level toolbar in the graph |
| Inventory states only `default` and `error` | Apply the full state rubric |
| Skipping the `frontend-design` pass | Required |
| One review round, declared "stable" | Minimum two rounds unless round 1 had zero substantive issues |
| Review notes only in chat, not on disk | `docs/review-round-N.md` BEFORE applying fixes |
| Custom font (Inter etc.) | `.system(...)` — SF is the point |
| iPhone-styled render of a Mac spec (or vice versa) | Inventory `platform` column drives the platform-correct hosting view |
| Forgetting iPad-specific sidebar sizing | iPad uses macOS-like sidebar widths (220–320pt), not iPhone's compact list |
| Marking every row `chrome=window` "to be safe" | Default is `chrome=view`. Only opt in when the spec uses "titlebar", "traffic lights", "NSToolbar", or "window chrome" |
| `chrome=window` on iOS or iPadOS | macOS-only — `Snap` precondition rejects it. iOS chrome (status bar, navigation bar from `NavigationStack`) is captured by `chrome=view` |
| `chrome=window` on a `kind=sheet` row | Sheets cannot be captured by `chrome=window` either. `Snap` precondition rejects this. Render the sheet body as `chrome=view` |
| `tb.delegate = LibraryToolbarDelegate()` without retaining | `NSToolbar` holds delegate weakly → renders empty. Use `objc_setAssociatedObject(...OBJC_ASSOCIATION_RETAIN)` to retain |
| Calling `NSApp.setActivationPolicy(.regular)` / `activate(...)` / `makeKeyAndOrderFront` "since we already touched `NSApp`" | Forbidden — those activate the app or order a window onscreen. Only `_ = NSApplication.shared` is sanctioned |
| `titleVisibility = .hidden` on `chrome=window` | Defeats the point. `chrome=window` exists for real titlebar; default `.visible` |

## Red Flags — STOP and check

- "I'll add the dialog later" → no, all inventory rows are first-class
- "I'll just use `.sheet` in the snapshot view" → no, render the sheet body directly
- "Materials look gray, that's a bug" → no, that's expected; real app restores vibrancy
- "Round 1 was good enough" → did `review-round-1.md` actually have zero issues?
- "Let me embed a fake store in the view for now" → no, breaks the integration contract
- "Let me build the app to check it visually" → no, `swift run SnapshotTool` only
- "Inventory is in my head" → write it down
- "I described fixtures realistically in chat" → check `Fixtures.swift`
- "I can't use `NavigationSplitView` because of `ImageRenderer`" → outdated; the new harness renders it
- "I named the file `SampleData.swift` instead of `Fixtures.swift`" → run all three greps from step 3

## Reporting completion

When done, report exactly:

1. Path to `docs/screens.md` and inventory row count
2. Output of the inventory↔snapshot Python check (must say `OK — N rows match N PNGs`)
3. Output of all three verification greps from step 3 (each must be empty)
4. Paths to every `docs/review-round-N.md` file produced
5. Number of review rounds, with one-sentence outcome per round
6. Path to `snapshots/` so the user can open it
7. Per-platform PNG counts (e.g., "macOS: 18, iOS: 8, iPadOS: 4")
8. Per-chrome PNG counts (e.g., "chrome=view: 24, chrome=window: 6"). For each `chrome=window` row, **quote the exact spec phrase that triggered the opt-in** (must contain "titlebar", "traffic lights", "NSToolbar", or "window chrome", or reference a mockup that shows them)
9. Confirmation: app never launched — only `swift run SnapshotTool`. For `chrome=window` rows, confirm `NSApplication.shared` was referenced but `NSApp.run()`, `.setActivationPolicy(.regular)`, `.activate(...)`, `makeKeyAndOrderFront`, and `orderFront` were NOT called
10. Known offscreen render deltas (vibrancy approximated; sheets rendered as bodies; window-level toolbars either `WindowChrome` components or real `NSToolbar` via headless-window path)

If anything is missing or fabricated after-the-fact, you are not done.
