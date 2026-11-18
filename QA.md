# Verification record — 18 November 2026

This is a compact independently built browser game. The campaign is playable; artistic likeness and choreography remain subjective and are not represented as a photorealistic reconstruction or large-studio quality.

## Automated checks

- 25 deterministic mechanics tests pass, including a command-driven completion of all three actual maps, all 12 parkour milestones and all 12 enemies including Oz. That campaign test changes no HP, positions or completed milestones directly.
- 8 build/PWA tests pass: manifest and actual PNG dimensions, local imports, complete offline inventory, content fingerprint, offline fetch behavior using a mocked Cache API, waiting update policy and cache isolation.
- All 12 original photos plus the approved concept reference are checked against public payload bytes; none is published.
- GLB round-trip validation: three models, 27 bones, 26 animation clips each; all poses sampled across 11 phases with finite values and preserved object root transforms.

## Browser checks

Chrome and the Codex in-app browser loaded the actual WebGL scene without JavaScript errors in the inspected states. Desktop camera, menu, turntable, close face view, keyboard movement/attack, bag item use and pause were exercised.

The command-driven campaign also ran against the live browser application: 12 enemies defeated, 12 route milestones, both normal chapter transitions and the visible final victory screen. This accelerated integration check used normal game commands without changing actor HP, positions or milestones; it is not a real-time performance benchmark.

At 667×375 and 844×390 with emulated touch, the arena fills the viewport. Main buttons measured 56–58 CSS px, auxiliary buttons at least 44 px, bottom combat-button gap 28 px. No horizontal page overflow was measured. Hero remains centered clear of combat controls in the observed starting frame.

Chrome native CDP touch injection confirmed simultaneous independent joystick and punch contacts: nonzero analog motion remained active while state became `punch`; ending contacts reset both axes to zero. This is emulated browser input, not a physical phone test.

Portrait 375×667 displayed the rotate screen and paused the game. Returning to landscape resumed the orientation pause through countdown. A manually paused game remained paused through rotation. Bag selection consumed exactly one item and resumed with the correct 120-second buff.

Offline was verified with the development HTTP server actually stopped: browser reload still opened the WebGL game, the required face atlas returned HTTP 200 from Cache Storage, and an uncached probe failed with TypeError. The original active cache and a waiting update coexisted without forcing a reload during gameplay.

## Limits

- No physical iPhone/Android device session was available. Safari install behavior, thermal performance, battery use and native multitouch on hardware need device testing.
- Browser automation throttles rendering, so its displayed FPS is not a reliable device benchmark. No stable mobile FPS claim is made. Render complexity and pixel ratio are bounded and quality adapts downward.
- The skinned character generator is editable and the exports are real 3D models. Hidden views and Oz body proportions are authored interpretations; user approval of likeness is still pending.
- Environmental actions are non-graphic slapstick. Collision, release and the curved approach around the victim are tested on all three stations. Two-bone inverse kinematics targets the head and upper back without stretching the arms; the choreography remains stylized rather than motion capture.

Keep this distinction between simulation checks, emulated browser checks and physical-device checks in future release notes.
