# Editable environment sources

`../../src/world.js` is the complete editable procedural source for the three original environments. All visible geometry and materials are generated locally; the environments use no photographs, downloaded textures, or external assets.

Coordinates are metres, with Y up. Each location starts at `(0, 0, 14)` and ends at `(0, 0, -27)`. The floor is continuous, and the route uses a jump marker followed by low vault, 1.2 m platform, and 2.3 m hanging ledge. The front grip edge of every approved obstacle is mint; decorative surfaces outside the playable bounds are not marked as climbable.

The returned `colliders` array contains rectangular collision volumes with `x`, `z`, `w`, `d`, `y`, and `h`. The top is `y + h`. Destructible props are the same objects in both `props` and `colliders`; set `solid = false` on destruction or pickup. Prop meshes use feet-at-zero group origins, so they can be moved or animated by the game without altering the environment's batched geometry.

Immutable ornament is instanced by geometry and material. Editable source covers the city buildings, forest trees and cliffs, industrial tanks and crane, route structures, props, lighting, exit arch and ambient particles. No personal reference images are included.

Each map also returns `stations`: city `fryer`, forest `bench`, and factory `machine`. A station exposes its contact point, a safe front approach point, an interaction radius and an idempotent `break()` method. The city kiosk has a skewer, open fryer basin and basket, a geometric shawarma sign and striped canopy. Breaking a station disables its collision, collapses the canopy/fixtures, and exposes deterministic debris; no uncontrolled rigid-body pile is created. The game is responsible for synchronized actor animation and steam/spark effects. Call `break()` rather than manually moving its packed child meshes.

Two small `stool` props per map supplement crates, barrels, benches and carts as improvised weapons. All eight prop roots can be picked up and thrown by the controller.

Geometry inspection with Three.js 0.180.0 counted 20,800 triangles / 101 mesh draw groups for the city, 20,268 / 87 for the forest, and 10,536 / 89 for the factory, before characters and effects. These are scene-graph counts, not device FPS measurements; shadow rendering adds passes.
