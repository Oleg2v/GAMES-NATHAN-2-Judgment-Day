# Character source assets

`src/characters.js` is the editable, deterministic mesh, rig and animation source. It creates genuine three-dimensional geometry, a named `THREE.Bone` hierarchy and a skinned character. The face atlas is newly painted with ImageGen; original reference photographs are excluded.

The character art is a stylized interpretation of the supplied references. Nathan's head, beard, broad build and tattoos were studied from all ten photographs; Oz's broad face, open forehead and clear metal-frame glasses use the primary portrait, with the second portrait as a supplementary reference. Rear views, Oz's body and the costumes are designed details. This is not a claim of photogrammetric reconstruction or approved final likeness.

Nathan's working dimensions are 1.95 m and 140 kg. Oz uses comparable *gameplay* stature; his real measurements are unknown. Ordinary enemies use a narrower, lighter rig. The entire model faces +Z and the foot sole rests at Y=0 in the neutral pose.

The runtime animation source contains named, editable animation poses, continuous interpolation and body motion. Root movement, collisions, paired participant alignment, damage and release timing remain the responsibility of the gameplay controller. Model animation alone never applies damage or changes world position.

Use `node models/export.mjs` after installing dependencies to regenerate the glTF/GLB and Three.js scene exports. The exports contain the same geometry, named skeleton, materials and sampled animation tracks used by the runtime. Private photo references live outside this repository.

Run `node models/validate.mjs` after exporting. It checks finite transforms over all 26 poses, preservation of the gameplay-owned root transform, planted support soles for the grounded animation states, and successful re-import of all three GLB rigs/geometries and their 27-bone rigs and animation clips. Embedded PNG bytes and material bindings are checked separately because Node does not have a DOM image decoder. These checks do not replace visual evaluation of likeness, contact timing or artistic quality.

Hand sockets are recorded in `metadata.sockets`: use the corresponding hand bone's `localToWorld(new Vector3(0, -.06, .025))` to get the palm contact point. `carry` holds an object at chest height and retains a walking cycle when `speed > 0`. `envVictim` braces the victim without adding a hidden fall offset; the paired-action controller must align and rotate the victim root.

Current budgets are recorded in `exports/manifest.json`. Exported GLBs contain full animation tracks and the generated face atlas; the runtime constructs the same models from the compact editable source. See `FACE-TEXTURE.md` for the image-generation prompt and source attribution. `preview.html` is an additional turntable and pose viewer using the workshop command in the repository README; the integrated game showroom is the primary in-game preview.
