# Ashdod waterfront environment references

Research and visual inspection: 19 November 2026. This is a compressed, manually authored representation of the Lido–Oranim promenade and HaKshatot beach plaza. It is **not photogrammetry**, a surveyed digital twin, or a claim that every photographed shop still operates today. Photos document 2023–2024 appearances; the architecture, public furniture and coastal materials guide the scene.

The source photographs are stored only in the development workspace's `work/ashdod-references`, outside this Godot project. They are not shipped as texture billboards or backgrounds. The game environment contains authored geometry and separately licensed PBR materials.

## Photographs inspected

| Local reference ID | Documented appearance used | Source and license |
| --- | --- | --- |
| `lido-beach-day-2023` | Broad sandy beach, shallow surf, uninterrupted Mediterranean horizon | [Lido Beach, November 2023](https://commons.wikimedia.org/wiki/File:Lido_Beach,_Ashdod,_November_2023.jpg), מקף־עברי, CC0 |
| `lido-oranim-promenade-01-2024` | Gray square paving, fixed yellow/white octagonal parasols, thin metal poles, cafe furniture, orange and white restaurant frontages, multi-arm lamps | [Lido–Oranim promenade 01, January 2024](https://commons.wikimedia.org/wiki/File:טיילת_חופי_לידו–אורנים_באשדוד_בלילה,_ינואר_2024_01.jpg), מקף־עברי, CC0 |
| `lido-oranim-promenade-02-2024` | Circular splash plaza, broad wood-capped curved bench, parasols and sandy planting edge | [Lido–Oranim promenade 02, January 2024](https://commons.wikimedia.org/wiki/File:טיילת_חופי_לידו–אורנים_באשדוד_בלילה,_ינואר_2024_02.jpg), מקף־עברי, CC0 |
| `hatayelet-nightlife-01-2024` | Dense palm/cafe frontage, wood slat benches, outdoor dining, fairy lights, awnings, visible air-conditioning units | [HaTayelet nightlife 01, January 2024](https://commons.wikimedia.org/wiki/File:חיי_לילה_בטיילת_של_אשדוד,_ינואר_2024_01.jpg), מקף־עברי, CC0 |
| `hakshatot-plaza-night` | Cream masonry arch landmark: tall central openings, lower arched wings, restaurant terraces and palms | [HaKshatot beach plaza at night](https://commons.wikimedia.org/wiki/File:HaKshatot_beach_plaza_at_night,_Ashdod.jpg), מקף־עברי, CC0 |
| `ashdod-mall-2024` | Low white commercial plinth with blue ribbon glazing, residential blocks above/behind, green balcony rails, rooftop frames, parking and Y-arm lamps | [Ashdod Mall, September 2024](https://commons.wikimedia.org/wiki/File:קניון_אשדוד,_ספטמבר_2024.jpg), מקף־עברי, [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). Reference-only, no photographic pixels shipped. |
| `oranim-lifeguard-tower-2023` | White-clad two-level hut, turquoise external stairs/railings and structure, shallow red roof, beach furniture | [Oranim lifeguard tower 1, November 2023](https://commons.wikimedia.org/wiki/File:Oranim_Beach_lifeguard_tower,_Ashdod,_November_2023_1.jpg), מקף־עברי, CC0 |
| `hakshatot-panorama-2024` | Sea/land ordering, promenade and palms, beach, breakwater and yacht-mast horizon | [HaKshatot panorama 02, January 2024](https://commons.wikimedia.org/wiki/File:פנורמה_של_חוף_הקשתות_באשדוד,_שעת_שקיעה,_ינואר_2024_02.jpg), מקף־עברי, CC0 |

All page licenses were checked individually. The complete image URL, author, date, SHA-256 and license URL are retained in `work/ashdod-references/manifest.json` and the accompanying `.metadata.json` files. One additional older HaTayelet photo was not downloaded because Wikimedia returned HTTP 429; it was not used.

## Official location context

- [Ashdod municipality: tourism and leisure](https://ashdod.muni.il/en-us/אתר-העיר/general/tourism-and-leisure/) confirms the coastline, marina and promenade/public-space context.
- [Visit Ashdod: food trucks](https://visit.ashdod.muni.il/events/פודטראקים-באשדוד/) lists Moola Yam at Oranim Beach and food trucks by the HaKshatot restaurant frontage. This supports the outdoor-food setting. Our kiosks use generic food signs and are gameplay designs, not claims about a particular real business.

## Shipped material textures

The following 1K diffuse/albedo, OpenGL normal and roughness sets are [Poly Haven CC0](https://polyhaven.com/license):

- [coast_sand_02](https://polyhaven.com/a/coast_sand_02)
- [concrete_pavers_03](https://polyhaven.com/a/concrete_pavers_03)
- [white_plaster_rough_02](https://polyhaven.com/a/white_plaster_rough_02)
- [brown_planks_03](https://polyhaven.com/a/brown_planks_03)

Materials use world-space triplanar coordinates at metre-based scales, mipmaps and anisotropic filtering. Near-camera plaster uses clean cream/terracotta mineral-paint colors with only the plaster scan's subtle normal detail; its mossy diffuse map is intentionally not applied to the cafe walls. Individual photograph colors are not sampled as factual colorimetry: gently warm coastal daylight is an art-direction choice. Sea animation is an authored shader. Palm geometry, shop fittings, vehicles, building modules and benches are authored in `scripts/ashdod_environment.gd`.

`coastal-menu.png` is original artwork generated with the built-in imagegen tool on 19 November 2026 for this project. It depicts shawarma, coffee/pastry and lemonade with fictional generic Hebrew cafe text. It is not a photograph of an existing Ashdod business or its actual menu. The flat artwork is applied only to physical menu/sign objects within modeled shop interiors and pavement A-frames. Generation prompt is retained in the development workspace at `work/ashdod-menu-prompt.txt`.

## Layout and review scope

Sea lies to the west (negative X), then sand, the timber shore edge and tiled promenade. Cafes occupy the east frontage; the road, commercial plinth and balcony towers sit behind them. The HaKshatot arches form the northern review landmark and the Lido circular plaza the southern one. Their distances and relative placement are compressed for review and gameplay; this is not a navigational map.

The review scene is an environment inspection with a free camera and five saved views. It does not present a completed campaign or a substitute player character. Ground, masonry and building collision are on layer 1. The fictional fryer counter exposes `Approach` and `Contact` markers in the `environment_stations` group for later animation integration.

## Campaign chapters 2 and 3

`scripts/campaign_environment.gd` reuses the local material, geometry, lighting and filtering helpers of the waterfront scene without modifying its layout. It creates two authored game environments, selected by exported `chapter = 2` or `3`. Neither is a survey of a real route.

The **Mediterranean forest** uses the regional vegetation and terrain vocabulary documented by KKL-JNF: pines, cypress, shrub understory, exposed pale chalk/dolomite, picnic furniture and walking trails. References include [Gezer–Nahshon forests](https://www.kkl-jnf.org/tourism-and-recreation/forests-and-parks/gezer-nachshon-forests/), [Hakaf-Het forest](https://www.kkl-jnf.org/tourism-and-recreation/forests-and-parks/hakaf-het-forest/) and [Shoham community forest](https://www.kkl-jnf.org/tourism-and-recreation/forests-and-parks/shoham-park/). These pages informed the vegetation mix and limestone setting; their photographs are not shipped. All tree, needle-spray, shrub, rock, log and boardwalk geometry is authored. Three trees nearest the traversal route retain detailed needles; background pines and cypress use broader, reduced-density sprays. The validated forest scene contains approximately 562,000 triangles after this reduction, down from 1.38 million. This is an asset complexity count, not a frame-rate claim.

The **Ashdod port/factory** vocabulary comes from [Ashdod Port's official operational information](https://www.ashdodport.co.il/about/structure/Documents/adv/ashdod-port-eng.pdf) and its [official gantry-crane video](https://www.youtube.com/watch?v=MWFetAUjbtg). Corrugated containers, door locking bars, warehouse shutters and clerestory glazing, quayside gantry structures, pipe racks, bulk tanks, pallets and a forklift are independently modeled. The compressed layout and industrial contact station are fictional gameplay designs; this is not a map of current port operations. No port photographs are shipped.

Both chapters expose `Spawn`, `EncounterA`, `EncounterB` and `Exit` markers. The playable axis runs from approximately Z +29 to −47, with clearings before and after the traversal corridor. A low 0.28 m trunk/pipe supports an ordinary jump, followed by a 0.72 m vault, 1.10 m climb and 2.15 m ledge with usable tops and descending access. The vault was raised from the initial 0.65 m brief so it is reliably detected by the controller's 0.65 m chest ray. Ground and obstacle collision use layer 1. Headless checks verify these heights and a clear 0.36 m radius / 1.95 m height capsule at all spawn, encounter, exit, approach and landing markers. Industrial `Approach` and `Contact` markers follow the same station contract as the waterfront.
