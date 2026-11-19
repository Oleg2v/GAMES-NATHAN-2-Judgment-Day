# NATHAN 2: Judgment Day

A compact third-person action game built in Godot 4.7.2, using its Compatibility renderer. The campaign crosses an Ashdod waterfront, a Mediterranean forest and a port/factory, ending with Oz. It includes physical traversal, paired attacks, environmental interactions, Russian / English / Hebrew menus and landscape touch controls.

This is an independent game prototype, **not an AAA production**. The waterfront uses inspected photographs and official location references to guide authored geometry. It is a compressed interpretation, **not photogrammetry or a surveyed replica**. Character likeness and the choreography remain authored approximations; unseen details are interpretations.

## Build and run the browser release

Requires Node.js 20.19+; the checked-in web export does not require Godot to build the static site.

```sh
npm ci
npm run build
npm run dev
```

Open `http://127.0.0.1:4182`. The server exposes only `dist`. Build reads `web-godot/package-files.json`, verifies each split payload's SHA-256, byte length and loader manifest, then copies **only** those listed runtime files into a fresh `dist`. Unlisted stale exports, editable sources and development references are not published. An invalid package leaves the previous `dist` intact. No runtime CDN is required.

Run the standalone packaging checks with:

```sh
node --test tests/godot-packaging.test.mjs
```

## Repository layout

| Path | Purpose |
| --- | --- |
| `godot/` | Editable Godot project, scripts, scenes, textures, GLBs, import settings and native tests |
| `web-godot/` | Frozen browser export, split payload chunks, offline shell and package allowlist |
| `scripts/build-godot.mjs` | Validate the frozen export and produce the public `dist` |
| `scripts/package-web.mjs` | Split a fresh Godot export and generate its local transport/PWA shell |
| `build-godot/` | Ignored local export output; never copied into the published site wholesale |
| `godot/assets/environment/SOURCES.md` | Environment photographs, material licenses and generated menu artwork provenance |

Godot regenerates `godot/.godot/` locally. That cache is excluded; `.import` settings and `.uid` sidecars are kept so imports remain reproducible. Original personal reference photographs, research-photo folders and workspace/tool caches remain outside the repository and public runtime. Generated face artwork and shipped character textures are separate assets, not copies of those original files.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move relative to the camera; hold Shift to walk |
| Hold right mouse button and drag | Turn the camera |
| J / K | Punch / kick |
| L | Throw a nearby foe, or throw a held prop |
| Q / Ctrl / C | Counter / dodge / crouch |
| Space | Context jump, low vault, climb or ledge grab; pull up while hanging |
| A / D while hanging | Shimmy along the ledge |
| E or Ctrl while hanging | Release the ledge |
| E | Nearby item interaction or environmental action when a foe and station are in reach |
| R | Rage when the meter is full |
| B / 1–5 | Bag / use the five inventory slots |
| Escape | Pause or return from an ordinary pause menu |

On a landscape touch screen, use the floating joystick at left, drag the upper scene at right to look, and use the labeled combat/context buttons. The physical controls keep their positions in Hebrew; menu text uses RTL layout. Opening any menu hides the complete gameplay HUD and resets held touches. Portrait rotation pauses; only an orientation-triggered gameplay pause resumes through 3–2–1. Manual pauses and result screens retain their own state after rotation.

Defeat each chapter's encounters, complete jump/vault/climb/hang traversal and reach its exit. Environmental actions are non-graphic stylized impacts with steam and debris. Inventory effects are fictional game mechanics, not claims about real products or substances.

## Edit and re-export

Open `godot/project.godot` in **Godot 4.7.2** with matching export templates. The main scene is `scenes/boot.tscn`. Review routes are `?view=character`, `?view=oz`, `?view=environment`, `?view=forest` and `?view=factory`; native launches accept `-- --view=<name>`.

From the repository root, create `build-godot/raw` and then run:

```sh
godot --headless --editor --path godot --import
godot --headless --path godot --export-release "Web Review" ../build-godot/raw/index.html
node scripts/package-web.mjs --source build-godot/raw --target web-godot --icons public --notices godot/assets/licenses
node scripts/build-godot.mjs --verify web-godot
npm run build
```

The `Windows Desktop` export preset writes into `build-godot/native`; create that folder before exporting it. Static-site build intentionally does not launch Godot or regenerate art. Re-exporting and packaging are explicit release steps, followed by validation of the actual exported PCK and browser build. A source-only test run cannot detect every stale Godot export-cache issue.

Native tests can be run with commands such as:

```sh
godot --headless --fixed-fps 60 --path godot --script res://tests/controller_test.gd
godot --headless --fixed-fps 60 --path godot --script res://tests/campaign_routes_test.gd
godot --headless --path godot --script res://tests/menu_layout_test.gd
node godot/tests/browser_state_test.mjs
```

Campaign/reload tests write save data: use a disposable command-scoped user-data environment, as described in `godot/CONTROLLER_CONTRACT.md`, rather than a player's profile. See `QA.md` for test scope and known limits.

## Offline installation and hosting

The export includes a local web manifest and a versioned service worker. First installation requires a complete successful download; partial downloads do not establish offline readiness. Updates wait for existing controlled tabs to close and do not force a reload during a fight. Subsequent loading uses the installed runtime cache. Actual offline behavior must be checked on the final host, not inferred merely from the presence of `sw.js`.

On iPhone, installation uses Safari's **Share → Add to Home Screen**. Normal Safari tabs retain browser chrome. Physical iPhone/Android installation, sustained performance, heat, battery use and hardware multitouch remain **untested**; emulated layouts and input checks do not establish device performance.

For the separate second-game Cloudflare Pages project, use build command `npm run build`, output `dist`, framework preset None. Individual emitted files are capped at 20,000,000 bytes; large Godot PCK/WASM payloads are reconstructed from hash-verified local chunks. Do not deploy this release over the first game's project or domain.

Environment credits are in `godot/assets/environment/SOURCES.md`. Character asset licensing and animation provenance are in `godot/assets/characters/ASSET_PIPELINE.md`; not every third-party asset is original project artwork. Full engine and asset notices ship in `credits.txt`, linked from the browser menu. The generated pine texture and its exact generation prompt are in `godot/assets/environment/pine-spray.png` and `pine-spray.prompt.txt`.
