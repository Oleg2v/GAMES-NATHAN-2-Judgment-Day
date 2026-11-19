# Godot verification record — 19 November 2026

This record concerns the Godot rebuild. Earlier Three.js checks, enemy counts and screenshots do not establish correctness of this runtime. The game is a compact independent prototype; neither a photorealistic reconstruction nor AAA visual quality is claimed.

## Confirmed source checks

- The recorded `full_campaign_test.gd` simulation completed all three actual game scenes, all 12 traversal milestones and 11 opponents including Oz, ending in victory. It used normal movement/key commands, inventory and real Next buttons with live enemy AI. It did not write actor transforms, health, collision flags or route milestones. Recorded vault-overlap frames: zero in every chapter. This automated input strategy is not a manual playthrough; dedicated boss tests cover patterns it can defeat before they occur.
- `campaign_routes_test.gd` traversed the city, forest and factory using the actual 0.36 m radius / 1.95 m standing capsule, physical Space key-down/key-up requests, jump/vault/climb/hang and exit approach. All three routes restored standing shape and completed with zero vault-overlap frames after the landing clearance fix.
- `menu_layout_test.gd`: **54 cases** cover 667×375, 844×390 and 1280×800 CSS dimensions in RU/EN/HE across six menu states. Native engine bounds confirm panels remain in the viewport, targets are at least 44 CSS px, card text stays inside its button and the final action is fully reachable through scrolling. These bounds checks do not substitute for rendered browser inspection.
- `menu_input_test.gd`: **13 checks** exercise real Godot ScreenTouch dispatch, independent movement/look/action contacts, a single action per tap, pause reset and exact victory/defeat/chapter-result restoration after rotation.
- `menu_hud_test.gd`: **90 checks** verify all gameplay HUD elements disappear in every menu state, held touch state is reset, the HUD returns to play, Nathan's name follows RU/EN/HE, and the HTML state is derived from the menu.
- `browser_state_test.mjs`: **22 checks** execute the actual embedded JavaScript bridge, including absent-DOM guards and playing/language updates. They do not launch a browser.
- `godot-packaging.test.mjs`: **11 Node tests** verify exact allowlist copying, removal of stale previous-site files, chunk SHA-256/size/reassembled-length checks, matching loader manifests, missing chunks, duplicate or unsafe paths, stale chunks, local HTML/PWA dependencies, the per-file hosting limit, and preservation of the previous build on corruption.

The additional native suites distinguish invisible physics fixtures (`controller_test.gd`), real skinned assets (`asset_integration_test.gd`, `contact_probe.gd`), fixture-driven chapter/retry behavior (`game_flow_test.gd`) and complete command-driven campaign simulation (`full_campaign_test.gd`). Do not describe fixture tests as a manual campaign run or numerical hand/head targets as approval of the visible choreography.

## Export and browser release checks

The final export is a separate release gate. Re-import updated source assets, smoke-test the actual exported PCK with `pack_smoke.gd`, package it, and verify `web-godot` before publishing. The PCK smoke test checks a scripted game root, live camera, main menu and encounter actors; simply starting the engine is insufficient.

During development, actual Godot Compatibility web renders were inspected for the waterfront/cafes and character presentation. Their appearance required multiple corrections to light, materials and foliage. This establishes observation of those inspected states, not a complete real-time browser playthrough of all three chapters.

Append the final export identifier and host-specific browser/offline outcome after the release freeze. In particular, confirm that reload with the server/network unavailable loads the same frozen runtime, the complete asset cache exists, and a waiting update does not replace an active fight. A passing mocked or source-only service-worker test must not be reported as that runtime check.

## Privacy and provenance

Sync admits only Godot project/scenes/scripts/assets/tests and reviewed text/import sidecars. It excludes `.godot`, workspace/tool caches and photo/reference folders. Before copying, exact SHA-256 values are compared with the private handoff reference index. The web build independently copies only `package-files.json` entries; it never copies the editable source tree or a directory wholesale into public output. This exact-file hash check is not a claim to identify every possible transformed derivative.

The Ashdod photographs guide manually authored geometry and are kept outside the shipped project. Poly Haven material scans are CC0. The café menu is generated artwork for a fictional business. See `godot/assets/environment/SOURCES.md` for sources and boundaries; the waterfront is not photogrammetry. Forest geometry was reduced from about 1.38 million to 562,000 triangles while retaining three detailed near-route trees. Geometry counts do not establish an FPS result.

## Remaining limits

- No physical iPhone or Android test was performed. Safari installation, safe-area behavior on hardware, real multitouch, sustained FPS, heat and battery use need device testing.
- Browser automation and headless simulation are not reliable mobile frame-rate benchmarks. No stable mobile FPS claim is made.
- Likeness, unseen character details, clothing and animation quality remain authored interpretations. Passing rig/contact tests does not establish user approval of their appearance.
- Environmental actions use stylized, non-graphic impact choreography. The tested contact geometry does not make them motion capture or realistic injury simulation.
- Final frozen-export browser/offline verification must remain distinct from the source checks above.

## Frozen release 0.2.0

Web PCK SHA-256: `e50942129482d9047eadeddc8f41f58cecfe4a805a65260fb4784c3b57c4ef64`.
Windows executable SHA-256: `2ccfa718776f85a44c7f7813654ebc323d896f20972d921861263f287b50df6b`.

The same frozen PCK completed the three-chapter automated campaign, with no
failed assertions and zero vault overlaps. Its test-process shutdown reported
four remaining ObjectDB instances; this shutdown warning is recorded separately
from the passing gameplay assertions and has not been classified as a runtime
memory-growth issue.

The exported PCK passed `pack_smoke.gd` with its actual scripted root, camera,
two initial opponents and main menu. The Windows executable started headlessly
and exited with status 0 after 60 frames. The packaged chunk transport loaded
the actual game in the local browser. RU/EN/HE main menus, waterfront gameplay,
item hand motion and both forest/factory review views were visually inspected.
The IAB viewport override did not visibly change the capture dimensions, so no
rendered phone-size verification is claimed from that attempt. Hardware mobile
and real network-offline checks remain unperformed.
