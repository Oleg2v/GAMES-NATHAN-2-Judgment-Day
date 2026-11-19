# Anatomical character rebuild — review assets

This replaces the earlier disconnected primitive prototype. It is a work-in-progress likeness, not a claim of a finished professional character or a scanned reconstruction.

## Authoring and licensing

The continuous body, face, eyelid, nostril, lip, ear and finger topology comes from [MakeHuman Community MPFB2](https://github.com/makehumancommunity/mpfb2), commit `9de0707fdc88438d7c53a1a2ac7937d9221e2431`. `mpfb2/LICENSE.md` sections C/D explicitly license bundled graphical assets under CC0 and make no claim over generated output. The plugin source itself is GPLv3; it is an authoring dependency and is not included in the game runtime.

The official [MakeHuman system asset pack](https://static.makehumancommunity.org/asset_packs/makehuman_system_assets.html) provides `high-poly` eyes, `eyebrow001`, `eyelashes01`, `teeth_base`, `short01`, `male_casualsuit06`, and `shoes05`. Individual MHCLO/material headers explicitly state the CC0 release. Garments are fitted, tailored, recolored, and reweighted for these characters. The body keeps native MPFB morphs plus an editable smooth reference mass morph.

The face paint atlas and tattoo atlas are original ImageGen output based on the user's visual references. No original reference photograph is copied into a game asset. Face paint is aligned to anatomical eye, nose and mouth landmarks and baked to a new non-overlapping UV layout; it is not used as a face billboard. Tattoos retain the source alpha and occupy the forearms only. The tattoo design is an interpretation, not an exact tracing.

Animation retargeting is maintained in `animate_rig.py` by the animation task. Its report distinguishes CC0 Quaternius Universal Animation Library 2 motion from original authored skeletal curves. A clip being present does not imply that paired contact or parkour collision behavior has passed gameplay review.

## Files and workflow

- `build_character.py`: anatomy/morph construction, normalization, lighting, review renders.
- `dress_character.py`: fitted groom, strand geometry, costume prototype and original shoe stripe geometry.
- `official_assets.py`: licensed garment/eye/hair fitting, tailoring and prescribed glasses.
- `clothing_coverage.py`: conservative anatomy masks, matching garment underlay, fitted waistband weights and firm shoe soles.
- `paint_face.py`: generated albedo and forearm tattoo projection/baking.
- `animate_rig.py`: skeletal motion retargeting and authored action curves.
- `export_character.py`: keeps the editable high-detail source, removes render subdivisions for runtime, reduces fine beard strand density, normalizes four skin influences, and embeds materials/textures into GLB.
- `validate_gltf.py`: imports the actual exported GLB and measures evaluated skinned world geometry.

Run Blender 4.5.15 in background with `--factory-startup --python-exit-code 1 --python work/character-rebuild/build_character.py -- --dressed`. Add `--oz` or `--thug` for the other characters. `--no-render` skips only review images. Export using `--python work/character-rebuild/export_character.py -- nathan` (or `oz` / `thug`). Execute heavy Blender jobs sequentially on this machine.

Editable source and renders are under `checkpoint/`. Runtime paths are `game-godot/assets/characters/nathan.glb`, `oz.glb`, and `thug.glb`. Private references stay outside that runtime folder.

## Rig and scale contract

The standard MPFB game-engine rig has 53 bones, with `Root`, `pelvis`, `spine_01/02/03`, `neck_01`, `head`, `clavicle_l/r`, `upperarm_l/r`, `lowerarm_l/r`, `hand_l/r`, finger chains, `thigh_l/r`, `calf_l/r`, `foot_l/r`, and `ball_l/r`. Skin weights are smooth and normalized to a maximum of four influences in runtime exports.

Blender authoring is Z-up / -Y-forward. GLB and Godot are +Y-up / +Z-forward in meters. Nathan and Oz body stature is 1.95m; generic thug body stature is 1.80m. Hair/footwear can extend slightly beyond bare anatomical bounds. Do not infer skinned height solely from a MeshInstance's local unskinned AABB; measure evaluated skin or skeletal landmarks.

The Root bone and rig object have no animated world translation; Godot owns movement. Pelvis motion and limb pose remain skeletal. A reversible authoring mask hides skin under fitted clothing; it is eroded by a topology ring so the cut remains inside the garment. Matching fabric/footwear underlay covers intersections beneath the visible shell. The complete continuous anatomy remains in the editable source beneath that mask. Shoe meshes and the covered foot region follow the foot bone together to preserve a firm sole instead of bending through the upper.

Godot 4.7's importer preserved the beard's `COLOR_0` RGBA but left `vertex_color_use_as_albedo` disabled. `game-godot/scripts/character_materials.gd` copies only the relevant beard material, enables that flag and alpha hash. The native and fresh GLTFDocument paths were both checked: one surface changes, and authored vertex alpha remains 0–1. This is a renderer integration fix, not extra face geometry.

## Review limitations

Likeness, hairline/groom, facial expression, costume silhouette and exact tattoo placement still require visual art approval. Body mass is an artistic approximation, not a biomechanically measured 140kg body. Generated paint carries some baked shading. Fine beard transparency must be checked in the Godot renderer. Retargeted and authored motions require in-engine foot/contact validation. The editable source retains teeth, but the neutral closed-mouth runtime export currently excludes them to avoid a bright interior-mouth artifact.
