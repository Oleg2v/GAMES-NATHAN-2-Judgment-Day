# Character controller integration

`scripts/character_controller.gd` extends `CharacterBody3D`. It creates an invisible collision capsule only. The actual character must be an imported GLB child; call `bind_model(model)` after adding it, or set `model_path` before the controller enters the tree. The review scene stays empty until a GLB is imported.

Use meters, +Y up, feet at local Y=0, and visual forward +Z. Keep the physics body's scale uniform at 1. Set `actor_height` and `ledge_hand_height` to the model's dimensions before adding the actor; Nathan uses 1.95 m and 2.12 m. The reviewer's framing scale is for inspection only. Put physics geometry on collision layer 1 and actors on layer 2.

## Input and events

- `set_move_input(Vector2(right, forward), running = true)` uses positive Y for camera-forward. Set `camera_yaw` to the gameplay camera's public yaw; yaw 0 faces world -Z. Keyboard support is opt-in via `keyboard_enabled`.
- `request_action(&"punch" | &"kick" | &"fury" | &"crouch" | &"counter" | &"dodge" | &"grab" | &"throw" | &"parkour" | &"jump" | &"interact" | &"drop")` returns whether an action started or entered the combo buffer.
- `receive_hit(amount, source, kind)` and `launch(impulse)` support enemies using the same collision and action states. Set actor `team`; target selection excludes teammates. This controller does not implement enemy decision-making or campaign progression.
- Signals expose state changes, health, hits, knockouts, completed parkour, environment impact, rejected actions and missing clips. UI labels and localization belong to the containing game scene.
- Held objects must be `RigidBody3D` nodes in `improvised_props`; an optional `receive_damage(amount, source)` handles breakage. Throwing uses actual rigid-body velocity and a single-hit ledger. Picked-up objects use the rig's right hand when identified.
- Melee damage is `(base + damage_bonus) * damage_multiplier`. `ai_time_scale` scales action clocks, animation playback and movement; the owning game must also scale its enemy decision clock. Buff timers and inventory belong to the game.
- Crouch uses the real idle/walk skeleton with pelvis lowering, torso flexion and planted-foot IK; it is not a separate imported clip. Standing is rejected under low ceilings. Fury uses the actual hook/recovery motion and a radial hit test with world line of sight.

## Animation contract

Provide in-place clips in the imported `AnimationPlayer`. `animation_aliases` can map these keys to different names. No missing action is synthesized. Locomotion uses an `AnimationTree` 1D blend; action clips crossfade and their playback speed is adjusted to the gameplay duration.

| Clip | Duration / impact |
| --- | --- |
| `idle`, `walk`, `run` | Loop; authored Nathan gait targets walk 2.0 m/s, run 3.55 m/s (generic controller defaults are configurable) |
| `punch_1` | 0.48 s / impact 0.20 s |
| `punch_2` | 0.50 s / impact 0.22 s |
| `punch_3` | 0.66 s / impact 0.30 s |
| `kick` | 0.76 s / impact 0.33 s |
| `fury` | 1.10 s / impact 0.40 s; hook/recovery clip |
| `counter`, `dodge` | 0.44 / 0.38 s; counter window first 0.28 s |
| `grab`, `throw_prop` | 0.45 / 0.62 s; prop releases at 0.24 s |
| `throw`, `held` | Paired 1.12 s; victim releases at 64% |
| `env_attacker`, `env_victim` | Paired 1.65 s; contact at 62% |
| `jump`, `fall`, `hang`, `shimmy` | State-dependent, suitable hold/loop poses |
| `land`, `hit`, `getup`, `recover` | 0.22 / 0.43 / 0.75 / 0.35 s |
| `knockdown` | Dynamic airborne body motion, then floor recovery |
| `vault`, `climb`, `ledge_grab` | 0.85 / 1.05–1.10 / 0.58 s |

Animation tracks must not displace the actor root. Imported idle/walk/run/fall/hang/shimmy loops are explicitly enabled because glTF does not store a loop flag. UAL2 source motions and authored curves are recorded separately in `work/character-rebuild/checkpoint/animation-retarget-report.json`; review-prefixed source clips are not substitutes for gameplay clips.

`character_contact.gd` runs after the AnimationTree on the 53-bone MPFB game-engine rig. Two-bone arm/leg IK preserves segment lengths, while torso/head adjustments reach station contacts. Its supported names include `pelvis`, `spine_01` through `spine_03`, `neck_01`, `head`, `upperarm_l/r`, `lowerarm_l/r`, `hand_l/r`, `thigh_l/r`, `calf_l/r` and `foot_l/r`. The general hand socket also recognizes `hand`/`wrist` combined with `right`, `.r` or `_r`. Other rigs require a bone mapping before contact IK can be claimed.

Vaulting uses a 0.16 m root arc with a raised compact collision capsule, validated against the same profile used during movement. Hands hold the real obstacle edge during the support phase and release before the body passes beyond reach. Hang height follows `ledge_hand_height`. Canceled or completed traversal restores the standing capsule only where it fits.

## Environment stations

Use a `Node3D` in `environment_stations` with direct `Marker3D` children `Approach` and `Contact`. `Approach` is a feet-level front-side point with local +Z pointing away from the counter. The victim advances 0.24–0.72 m from Approach toward the counter, selecting the closest collision-free position; the attacker stands 0.74 m along Approach's +X beside the victim. Provide enough unobstructed space for both capsules and the sampled alignment arc. World collisions remain active; only the paired actors ignore one another during the validated transition, with root separation checked explicitly.

`Contact` marks the actual basin/impact surface. The city fryer uses local Approach=(-0.4,0,1.4) and Contact=(-0.4,1.08,0). The victim's forehead and attacker's head/shoulder hand targets converge through the contact modifier. Optional `break_station()` handles visible debris/counter collapse. The controller sets metadata `broken=true`, applies damage once at62% of the pair duration and emits `environment_hit`.

## Verification

Run Godot 4.7.2 headless with `--fixed-fps 60 --path game-godot --script res://tests/controller_test.gd`. The suite checks actual physics frames and includes an invisible transform-only animation fixture. `tests/viewer_test.gd` separately round-trips an explicitly named cuboid test fixture through GLB to check import, framing, metadata and invalid-file handling. These fixtures are not delivered art and do not validate human anatomy or final choreography.

`tests/contact_probe.gd` loads the actual Nathan GLB and checks sustained head/hand contact, paired-root separation, vault contact, obstacle overlap, root trajectory and capsule restoration. Optional user arguments select attacker and victim GLBs. It writes a captured skeletal pose to `user://godot_contact_pose.json` for inspection. Numerical contact checks validate target placement; final visual review must still inspect the actual current skinned assets in Godot.

`tests/asset_integration_test.gd` checks the delivered Nathan/Oz/thug skin bindings, real idle/run articulation, clip loops, buff damage/time scaling, and skeletal/collision crouch behavior. `tests/game_flow_test.gd` checks pause, inventory and chapter reload paths using isolated damage/position fixtures; it is not a full player campaign walkthrough. Run that suite with a separate command-scoped `APPDATA` directory because it writes test campaign progress. `tests/menu_input_test.gd` dispatches real ScreenTouch events through the viewport to verify independent movement/look/action fingers, one action per tap, and result-screen restoration after phone rotation.

`tests/full_campaign_test.gd` is an automated simulation through all three actual game scenes, delivered actors and live enemy AI. It drives normal key commands, movement inputs, available inventory items and the real Next buttons. The driver never sets actor transforms/health, collision masks or route milestones. It follows physical jump/vault/climb/hang routes, steers around fallen actors and enters the forest boardwalk through its open end. It uses the game's reduced-motion setting for deterministic timing and writes `user://full_campaign_report.json`; use a separate command-scoped `APPDATA` directory. A successful run proves campaign progression with that input strategy, while the dedicated boss tests cover attacks this strategy may defeat before they occur. It does not replace manual visual/device testing.

After every asset update, run the Godot editor import pass before export. Validate the actual exported PCK with the absolute path to `tests/pack_smoke.gd` and `--main-pack <export.pck> --headless --fixed-fps 60`. Merely starting the engine without errors is insufficient: an earlier stale converted waterfront scene had no root script and rendered an empty canvas. The smoke test asserts the packed root's script plus a live camera, main menu and real encounter actors after boot. If this precise failure recurs, back up and invalidate only the affected `.godot/exported/.../waterfront_game.scn` cache entry, then re-export and repeat the smoke check.
