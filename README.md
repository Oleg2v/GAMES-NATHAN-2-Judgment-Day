# NATHAN 2: Judgment Day

Standalone browser 3D arcade action game. Three compact playable chapters (city, forest, factory), third-person camera, skinned characters, paired throws, environmental finishers, parkour, Oz boss, Russian / English / Hebrew, touch controls and offline PWA.

## Run

Requires Node.js 20.19+.

```sh
npm ci
npm test
npm run build
npm run dev
```

Open `http://127.0.0.1:4182`. The server exposes only `dist`; personal reference photographs are never included. Build uses the pinned local Three.js dependency and no runtime CDN.

## Controls

WASD / arrows move relative to camera. Drag the scene to look. J punch, K kick, L throw, Shift dodge, C crouch, R rage, Space context parkour, E environmental finisher / pick up / throw item. While hanging: A/D shimmy, Space pull up, E or C release. B opens bag, 1–5 use items, Escape pauses.

On a landscape phone: floating analog joystick left, □/○/△/× combat right, separate parkour and environmental buttons. The scene fills the viewport. Portrait rotation pauses; only a rotation-triggered pause resumes through 3–2–1. Manual/background pauses require explicit resume.

Complete the four marked traversal tasks and defeat every enemy to unlock a chapter exit. Nearby environmental stations can be used against an enemy with E: city shawarma fryer, forest workbench, factory machine. These are non-graphic slapstick effects; the fryer uses steam and debris.

## Models and editable sources

- `src/characters.js`: procedural authored geometry, named 27-bone rigs, skinned mesh and animation poses. Uses an AI-painted face atlas; original reference photographs are excluded.
- `models/export.mjs`: regenerates glTF/GLB and editable Three.js scenes with baked animation clips: `node models/export.mjs`.
- `models/exports`: Nathan, Oz and enemy GLB + scene JSON exports.
- `models/preview.html`: standalone turntable workspace with body/face views and animation selection; see the optional workshop command below.
- `src/world.js`: editable environment geometry, props and collision/parkour definitions.
- `src/core.js`: deterministic render-independent simulation.

Rear views, unseen costume details and Oz body proportions are authored interpretations. Facial likeness is stylized and has not been approved by the user as a final reconstruction. This is an independent small browser game, not an AAA production.

### Optional model workshop

The integrated **Characters** screen works with `npm run dev`. To open the separate model workshop, run the following from the repository root (`game` in the development workspace) after `npm ci` (requires Python 3):

```sh
python -m http.server 4183 --bind 127.0.0.1 --directory .
```

Open `http://127.0.0.1:4183/models/preview.html`. The workshop imports the installed Three.js package and resolves the painted face atlas from `public/assets`. Its **В игру** link opens the standard game server on port 4182, which must be running separately. This local server exposes only the repository directory; keep the private `handoff` folder outside it. Stop this optional server with Ctrl+C when finished. The workshop is an editing tool and is not included in the published game build.

## PWA and hosting

Build generates a content-versioned service worker with the complete runtime asset list. It installs atomically, caches canonical `/`, and leaves an update waiting until older game tabs close. After initial installation completes, reload works offline. Safari in a normal tab keeps its browser chrome; on iPhone use Share → Add to Home Screen.

Target: a separate Cloudflare Pages project `games-nathan-2-judgment-day`, repository `Oleg2v/GAMES-NATHAN-2-Judgment-Day`, branch `main`, build command `npm run build`, output `dist`, framework preset None. Never point this build at the first game's Pages project or other existing domains.

## Verification

`npm test` exercises combat contacts, line of sight, paired throws and interruptions, environmental collisions, item expiry/pause, analog motion, parkour and a command-driven campaign through all three real maps and Oz. Browser/device evidence and remaining limits are tracked separately in `QA.md`; simulation tests do not establish physical iPhone performance.

Three.js is MIT licensed; its license is included in the runtime build. All generated game geometry and sound synthesis is editable in this repository. Working reference photos remain outside the repository and web root.
