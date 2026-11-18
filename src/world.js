import * as THREE from 'three';

/** Original, editable environments. Distances are metres, +Y is up. */
export const LEVELS = [
  { key: 'city', name: { ru: 'Город', en: 'City', he: 'העיר' }, color: 0xf5b66c },
  { key: 'forest', name: { ru: 'Лес', en: 'Forest', he: 'היער' }, color: 0xb8d39a },
  { key: 'factory', name: { ru: 'Завод', en: 'Factory', he: 'המפעל' }, color: 0xf38b66 },
];

const PALETTES = [
  { sky: 0x263d52, fog: 0x344c60, ground: 0x384856, stone: 0x71808b, edge: 0x566573, dark: 0x253541, light: 0xa9a29b, wood: 0x9c7554, metal: 0x506878, warm: 0xffb66d, accent: 0x86e6ce, sun: 0xffc490 },
  { sky: 0x647e81, fog: 0x6a8583, ground: 0x52665a, stone: 0x6a7b75, edge: 0x3e554d, dark: 0x31443d, light: 0xa8b39b, wood: 0x977c55, metal: 0x5d7066, warm: 0xf0c77c, accent: 0xb8efd0, sun: 0xffdfad },
  { sky: 0x172d3c, fog: 0x243e4c, ground: 0x3b515c, stone: 0x677d86, edge: 0x435962, dark: 0x243b47, light: 0x97a5a4, wood: 0x99734a, metal: 0x567985, warm: 0xff9b65, accent: 0x70e4d1, sun: 0xaacfe0 },
];

function seeded(seed) {
  let state = seed >>> 0;
  return () => { state = (Math.imul(state, 1664525) + 1013904223) >>> 0; return state / 4294967296; };
}

export function createWorld(scene, index = 0) {
  index = Math.max(0, Math.min(2, index | 0));
  const palette = PALETTES[index];
  const random = seeded(4181 + index * 777);
  const group = new THREE.Group();
  group.name = `environment-${LEVELS[index].key}`;
  const colliders = [], props = [], route = [], animated = [], stations = [];
  const ownedGeometries = new Set(), ownedMaterials = new Set();
  const batches = new Map();
  const geometries = {};
  const mat = (color, extra = {}) => {
    const m = new THREE.MeshStandardMaterial({ color, roughness: 0.86, metalness: 0.04, ...extra });
    ownedMaterials.add(m);
    return m;
  };
  const materials = {
    ground: mat(palette.ground), stone: mat(palette.stone), edge: mat(palette.edge),
    dark: mat(palette.dark), light: mat(palette.light), wood: mat(palette.wood),
    metal: mat(palette.metal, { metalness: 0.5, roughness: 0.52 }),
    black: mat(0x202d33), yellow: mat(0xe8b963), pink: mat(0xce6d87),
    mint: mat(palette.accent, { emissive: palette.accent, emissiveIntensity: 0.22 }),
    glow: mat(palette.warm, { emissive: palette.warm, emissiveIntensity: 1.5 }),
    window: mat(0x9db4bd, { emissive: 0x63838d, emissiveIntensity: 0.18, metalness: 0.5, roughness: 0.3 }),
  };
  function geometry(kind) {
    if (geometries[kind]) return geometries[kind];
    let g;
    if (kind === 'box') g = new THREE.BoxGeometry(1, 1, 1);
    else if (kind === 'cylinder') g = new THREE.CylinderGeometry(1, 1, 1, 10);
    else if (kind === 'cone') g = new THREE.ConeGeometry(1, 1, 8);
    else if (kind === 'rock') g = new THREE.IcosahedronGeometry(1, 0);
    else if (kind === 'leaf') g = new THREE.IcosahedronGeometry(1, 1);
    else if (kind === 'ring') g = new THREE.TorusGeometry(1, 0.035, 4, 24);
    else throw new Error(`Unknown primitive ${kind}`);
    ownedGeometries.add(g);
    geometries[kind] = g;
    return g;
  }
  const matrix = new THREE.Matrix4(), quaternion = new THREE.Quaternion(), euler = new THREE.Euler();
  const position = new THREE.Vector3(), scale = new THREE.Vector3();
  function instance(kind, material, p, s, r = [0, 0, 0]) {
    const key = `${kind}:${material.uuid}`;
    if (!batches.has(key)) batches.set(key, { kind, material, matrices: [] });
    position.set(...p); scale.set(...s); euler.set(...r); quaternion.setFromEuler(euler);
    batches.get(key).matrices.push(matrix.compose(position, quaternion, scale).clone());
  }
  const box = (m, p, s, r) => instance('box', m, p, s, r);
  const cyl = (m, p, s, r) => instance('cylinder', m, p, s, r);
  function mesh(kind, material, p, s, parent = group, r = [0, 0, 0]) {
    const object = new THREE.Mesh(geometry(kind), material);
    object.position.set(...p); object.scale.set(...s); object.rotation.set(...r);
    object.castShadow = true; object.receiveShadow = true;
    parent.add(object); return object;
  }
  // Local batches stay attached to their prop/station, so moving a prop costs no rebuild.
  // For collapsible stations the source transforms are retained and refreshed once on break.
  function packChildren(parent, exclude = []) {
    const local = new Map(), packs = [];
    for (const object of [...parent.children]) {
      if (!object.isMesh || object.isInstancedMesh || exclude.includes(object)) continue;
      const key = `${object.geometry.uuid}:${object.material.uuid}`;
      if (!local.has(key)) local.set(key, []);
      local.get(key).push(object);
    }
    const zero = new THREE.Matrix4().makeScale(0, 0, 0);
    for (const sources of local.values()) {
      if (sources.length < 2) continue;
      const instanced = new THREE.InstancedMesh(sources[0].geometry, sources[0].material, sources.length);
      instanced.castShadow = true; instanced.receiveShadow = true;
      sources.forEach(object => parent.remove(object)); parent.add(instanced);
      packs.push({ sources, instanced });
    }
    const refresh = () => {
      for (const { sources, instanced } of packs) {
        sources.forEach((object, i) => {
          object.updateMatrix();
          instanced.setMatrixAt(i, object.visible ? object.matrix : zero);
        });
        instanced.instanceMatrix.needsUpdate = true;
        instanced.computeBoundingSphere();
      }
    };
    refresh(); return { refresh, meshes: packs.map(p => p.instanced) };
  }
  function collider(id, x, z, w, d, h, material = materials.stone, parkour = null, y = 0) {
    const object = mesh('box', material, [x, y + h / 2, z], [w, h, d]);
    object.name = id;
    const c = { id, x, z, w, d, h, y, parkour, mesh: object, solid: true };
    object.userData.colliderId = id;
    colliders.push(c); return c;
  }
  function lineBetween(a, b, radius, material, parent = null) {
    const av = new THREE.Vector3(...a), bv = new THREE.Vector3(...b), delta = bv.clone().sub(av);
    const q = new THREE.Quaternion().setFromUnitVectors(new THREE.Vector3(0, 1, 0), delta.clone().normalize());
    if (parent) {
      const rod = mesh('cylinder', material, av.clone().add(bv).multiplyScalar(0.5).toArray(), [radius, delta.length(), radius], parent);
      rod.quaternion.copy(q); return rod;
    }
    position.copy(av).add(bv).multiplyScalar(0.5); scale.set(radius, delta.length(), radius);
    const key = `cylinder:${material.uuid}`;
    if (!batches.has(key)) batches.set(key, { kind: 'cylinder', material, matrices: [] });
    batches.get(key).matrices.push(matrix.compose(position, q, scale).clone());
  }
  function stripes(x, y, z, width, depth, vertical = false) {
    const count = Math.max(2, Math.floor(width / 0.42));
    for (let i = 0; i < count; i++) {
      box(i % 2 ? materials.black : materials.yellow,
        [x - width / 2 + (i + 0.5) * width / count, y, z],
        vertical ? [width / count - 0.02, depth, 0.035] : [width / count - 0.02, 0.027, depth]);
    }
  }

  // One continuous navigable floor; decorative surface details have no collision.
  mesh('box', materials.ground, [0, -0.18, -5], [25, 0.36, 52]);
  const wallMaterial = index === 1 ? materials.edge : materials.dark;
  collider('boundary-west', -12.6, -5, 1.2, 52, 3.7, wallMaterial);
  collider('boundary-east', 12.6, -5, 1.2, 52, 3.7, wallMaterial);
  collider('boundary-north', 0, -30.6, 26.4, 1.2, 5, wallMaterial);
  collider('boundary-south', 0, 20.6, 26.4, 1.2, 3.7, wallMaterial);

  function routeMarker(type, x, z, ordinal, target = null) {
    const marker = new THREE.Group(); marker.position.set(x, 0.03, z); marker.name = `route-${type}`;
    const markerMaterial = mat(palette.accent, { emissive: palette.accent, emissiveIntensity: 0.55 });
    mesh('ring', markerMaterial, [0, 0, 0], [0.65, 0.65, 0.65], marker, [-Math.PI / 2, 0, 0]);
    // Arrow direction is toward -Z, the campaign's direction of travel.
    mesh('box', markerMaterial, [-0.13, 0.015, -0.08], [0.34, 0.035, 0.075], marker, [0, -0.65, 0]);
    mesh('box', markerMaterial, [0.13, 0.015, -0.08], [0.34, 0.035, 0.075], marker, [0, 0.65, 0]);
    for (let n = 0; n < ordinal; n++) mesh('box', markerMaterial, [(n - (ordinal - 1) / 2) * 0.13, 0.015, 0.27], [0.065, 0.03, 0.08], marker);
    group.add(marker); animated.push({ kind: 'marker', material: markerMaterial, phase: ordinal });
    const entry = { id: `level${index}-${type}`, type, x, z, mesh: marker, colliderId: target?.id ?? null, target: target ?? null };
    route.push(entry); return entry;
  }

  const obstacleMat = index === 1 ? materials.wood : materials.stone;
  const vault = collider(`level${index}-vault-block`, -3, 0, 4, 0.75, 0.7, obstacleMat, 'vault');
  const climb = collider(`level${index}-climb-platform`, 3, -8, 4, 3, 1.2, obstacleMat, 'climb');
  const hang = collider(`level${index}-hang-platform`, -3, -17, 5, 3, 2.3, obstacleMat, 'hang');
  routeMarker('jump', 0, 7, 1);
  routeMarker('vault', -3, 1.1, 2, vault);
  routeMarker('climb', 3, -5.6, 3, climb);
  routeMarker('hang', -3, -14.6, 4, hang);
  // Bright continuous grip rails and clear standing space make valid surfaces legible.
  for (const c of [vault, climb, hang]) {
    box(materials.mint, [c.x, c.h + 0.025, c.z + c.d / 2 - 0.025], [c.w, 0.05, 0.09]);
    box(materials.edge, [c.x, c.h + 0.012, c.z], [c.w - 0.12, 0.024, c.d - 0.16]);
    for (const side of [-1, 1]) box(materials.metal, [c.x + side * (c.w / 2 - 0.12), c.h / 2, c.z + c.d / 2 + 0.018], [0.1, c.h, 0.05]);
  }
  for (const z of [12, 10, 4, 2, -3, -5, -11, -13, -21, -24]) {
    box(materials.light, [0, 0.012, z], [0.12, 0.02, 0.42], [0, 0.17 * Math.sin(z), 0]);
  }

  function prop(kind, x, z, rotation = 0) {
    const g = new THREE.Group(); g.position.set(x, 0, z); g.rotation.y = rotation; g.name = `prop-${kind}-${props.length}`;
    const dimensions = { crate: [1.05, 1.05, 1], bench: [2.6, 0.78, 0.9], barrel: [0.82, 1.08, 0.82], cart: [1.45, 0.92, 1.05], stool: [0.62, 0.62, 0.62] };
    let [w, h, d] = dimensions[kind];
    if (kind === 'crate') {
      mesh('box', materials.wood, [0, h / 2, 0], [w, h, d], g);
      for (const sign of [-1, 1]) {
        mesh('box', materials.edge, [0, h / 2, sign * (d / 2 + 0.012)], [w * 0.9, 0.085, 0.025], g, [0, 0, sign * 0.65]);
        for (const xSide of [-1, 1]) mesh('box', materials.light, [xSide * (w / 2 - 0.09), h / 2, sign * (d / 2 + 0.02)], [0.08, h - 0.03, 0.04], g);
      }
      for (const offset of [-0.3, 0, 0.3]) mesh('box', materials.edge, [offset, h + 0.012, 0], [0.025, 0.025, d], g);
    } else if (kind === 'bench') {
      for (const zOffset of [-0.22, 0, 0.22]) mesh('box', materials.wood, [0, 0.47, zOffset], [2.6, 0.12, 0.18], g);
      for (const side of [-1, 1]) {
        mesh('box', materials.metal, [side * 0.95, 0.25, 0], [0.13, 0.5, 0.72], g);
        mesh('box', materials.metal, [side * 0.95, 0.64, -0.3], [0.11, 0.52, 0.12], g, [-0.13, 0, 0]);
      }
      mesh('box', materials.wood, [0, 0.75, -0.34], [2.6, 0.24, 0.12], g);
    } else if (kind === 'barrel') {
      mesh('cylinder', index === 2 ? materials.pink : materials.wood, [0, h / 2, 0], [w / 2, h, d / 2], g);
      for (const y of [0.1, 0.53, 0.98]) mesh('cylinder', materials.metal, [0, y, 0], [0.425, 0.07, 0.425], g);
      mesh('cylinder', materials.dark, [0, h + 0.01, 0], [0.35, 0.025, 0.35], g);
    } else if (kind === 'stool') {
      mesh('cylinder', index === 2 ? materials.metal : materials.wood, [0, 0.57, 0], [0.34, 0.1, 0.34], g);
      for (const dx of [-1, 1]) for (const dz of [-1, 1]) {
        mesh('box', materials.metal, [dx * 0.22, 0.28, dz * 0.22], [0.055, 0.56, 0.055], g, [dz * 0.13, 0, -dx * 0.13]);
      }
      for (const side of [-1, 1]) mesh('box', materials.metal, [0, 0.2, side * 0.24], [0.5, 0.045, 0.045], g);
    } else {
      mesh('box', materials.metal, [0, 0.36, 0], [1.4, 0.16, 1], g);
      for (const xSide of [-1, 1]) {
        for (const zSide of [-1, 1]) mesh('cylinder', materials.black, [xSide * 0.55, 0.17, zSide * 0.35], [0.17, 0.12, 0.17], g, [0, 0, Math.PI / 2]);
        mesh('box', materials.metal, [xSide * 0.66, 0.65, -0.45], [0.06, 0.7, 0.06], g);
      }
      mesh('box', materials.metal, [0, 0.98, -0.45], [1.4, 0.07, 0.07], g);
      mesh('box', materials.wood, [0.1, 0.64, 0.08], [0.8, 0.42, 0.63], g);
    }
    packChildren(g);
    group.add(g);
    if (Math.abs(Math.sin(rotation)) > 0.7) [w, d] = [d, w];
    const p = { id: `level${index}-prop-${props.length}`, kind, x, z, y: 0, w, d, h, hp: kind === 'cart' ? 55 : kind === 'stool' ? 18 : 38, mesh: g, state: 'intact', solid: true, parkour: null, destructible: true, takeable: true };
    g.userData.propId = p.id; props.push(p); colliders.push(p); return p;
  }
  prop(index === 2 ? 'cart' : 'bench', -6.5, 7, Math.PI / 2);
  prop('crate', 5.3, 4.5);
  prop('barrel', 5.4, -1.5);
  prop('crate', -7.8, -9.2);
  prop(index === 1 ? 'bench' : 'cart', 5.6, -19, Math.PI / 2);
  prop('barrel', -6.8, -24);
  prop('stool', index === 0 ? 4.5 : -5.8, index === 0 ? 11 : 9.5);
  prop('stool', index === 0 ? 8.7 : 7, index === 0 ? 7.6 : -15);

  function interactionStation(kind, x, z) {
    const stationGroup = new THREE.Group(); stationGroup.name = `station-${kind}`; stationGroup.position.set(x, 0, z);
    group.add(stationGroup);
    const parts = [], debris = [], falling = [];
    const add = (shape, material, p, s, r = [0, 0, 0]) => {
      const object = mesh(shape, material, p, s, stationGroup, r); parts.push(object); return object;
    };
    const width = kind === 'fryer' ? 3.8 : kind === 'machine' ? 2.6 : 2.4;
    const height = kind === 'fryer' ? 1.02 : kind === 'machine' ? 1.1 : 0.94;
    const counter = collider(`level${index}-station-counter`, x, z, width, 1.25, height, kind === 'bench' ? materials.wood : materials.metal);
    stationGroup.attach(counter.mesh); parts.push(counter.mesh);
    let canopy = null, skewer = null;
    if (kind === 'fryer') {
      const enamel = mat(0x438b88), cream = mat(0xe8d6ac), oil = mat(0x945827, { metalness: 0.18, roughness: 0.36 });
      const bread = mat(0xce9659), meat = mat(0x995d3b), fresh = mat(0x68985b);
      add('box', enamel, [0, 0.57, 0.64], [3.78, 0.77, 0.055]);
      add('box', cream, [0, 0.6, 0.68], [2.2, 0.3, 0.025]);
      // The sign is a geometric shawarma icon, so no language is baked into textures.
      add('cone', bread, [0, 0.59, 0.71], [0.16, 0.36, 0.045], [0, 0, Math.PI]);
      add('leaf', fresh, [0, 0.77, 0.72], [0.15, 0.06, 0.055]);
      for (const side of [-1, 1]) {
        const pole = add('cylinder', materials.metal, [side * 1.78, 1.8, -0.48], [0.05, 1.7, 0.05]);
        falling.push(pole);
      }
      canopy = new THREE.Group(); canopy.position.set(0, 2.65, -0.02); stationGroup.add(canopy); parts.push(canopy);
      mesh('box', enamel, [0, 0, 0], [4.35, 0.16, 2.3], canopy, [-0.08, 0, 0]);
      for (let n = -4; n <= 4; n++) mesh('box', cream, [n * 0.46, 0.085, 0], [0.2, 0.02, 2.27], canopy, [-0.08, 0, 0]);
      mesh('box', enamel, [0, -0.17, 1.08], [4.35, 0.32, 0.1], canopy);
      mesh('box', materials.glow, [0, -0.13, 0.3], [2.9, 0.035, 0.06], canopy);
      // Open fryer basin with a raised rim, recessed oil and wire basket handle.
      add('box', materials.dark, [-1.1, 1.055, 0], [1.05, 0.06, 0.91]);
      add('box', oil, [-1.1, 1.095, 0], [0.88, 0.025, 0.7]);
      for (const side of [-1, 1]) {
        add('box', materials.light, [-1.1 + side * 0.51, 1.16, 0], [0.075, 0.23, 0.96]);
        add('box', materials.light, [-1.1, 1.16, side * 0.45], [1.09, 0.23, 0.075]);
      }
      for (let n = -3; n <= 3; n++) add('box', materials.metal, [-1.1 + n * 0.11, 1.13, 0], [0.014, 0.018, 0.62]);
      add('box', materials.dark, [-1.1, 1.31, 0.65], [0.12, 0.08, 0.45], [-0.2, 0, 0]);
      // Vertical skewer, burner backing and shaved meat tray on the other half.
      add('box', materials.dark, [1.08, 1.64, -0.43], [0.82, 1.15, 0.13]);
      for (const offset of [-0.24, 0, 0.24]) add('box', materials.glow, [1.08 + offset, 1.64, -0.35], [0.07, 0.87, 0.035]);
      skewer = new THREE.Group(); skewer.position.set(1.08, 1.09, 0); stationGroup.add(skewer); parts.push(skewer);
      mesh('cylinder', materials.metal, [0, 0.61, 0], [0.025, 1.34, 0.025], skewer);
      for (let n = 0; n < 7; n++) mesh('cylinder', n % 2 ? meat : bread, [0, 0.23 + n * 0.12, 0], [0.22 + n * 0.013, 0.15, 0.22 + n * 0.013], skewer, [0, n * 0.6, 0]);
      add('box', materials.light, [1.08, 1.06, 0.24], [0.92, 0.06, 0.72]);
      for (let n = 0; n < 5; n++) add('box', bread, [0.9 + (n % 3) * 0.12, 1.12, 0.28 + Math.floor(n / 3) * 0.13], [0.14, 0.05, 0.07], [0, n * 0.5, 0]);
      add('cylinder', cream, [0.04, 1.1, 0.13], [0.22, 0.09, 0.22]);
      add('leaf', fresh, [0.04, 1.16, 0.13], [0.17, 0.06, 0.17]);
    } else if (kind === 'bench') {
      add('box', materials.light, [0, 0.97, 0], [2.55, 0.11, 1.4]);
      for (const side of [-1, 1]) {
        add('box', materials.dark, [side * 0.92, 0.45, 0], [0.2, 0.9, 1]);
        add('box', materials.wood, [side * 0.92, 0.76, -0.55], [0.11, 0.6, 0.11]);
      }
      for (let n = -2; n <= 2; n++) add('box', materials.edge, [n * 0.44, 1.034, 0], [0.023, 0.02, 1.36]);
      add('cylinder', materials.wood, [-0.65, 1.15, -0.2], [0.12, 0.9, 0.12], [Math.PI / 2, 0.25, 0]);
      add('box', materials.metal, [0.85, 1.14, -0.3], [0.22, 0.24, 0.3]);
    } else {
      add('box', materials.dark, [0, 1.14, 0], [2.75, 0.15, 1.4]);
      for (const side of [-1, 1]) add('box', materials.metal, [side * 1.1, 1.65, -0.4], [0.25, 1.8, 0.3]);
      add('box', materials.metal, [0, 2.5, -0.4], [2.6, 0.4, 0.6]);
      add('cylinder', materials.light, [0, 2.18, -0.3], [0.16, 0.65, 0.16]);
      const press = add('box', materials.metal, [0, 1.95, -0.3], [0.8, 0.22, 0.7]); falling.push(press);
      for (let n = -3; n <= 3; n++) add('box', n % 2 ? materials.black : materials.yellow, [n * 0.36, 0.62, 0.64], [0.35, 0.3, 0.03]);
      add('box', materials.glow, [1.2, 1.7, 0], [0.1, 0.12, 0.08]);
      add('box', materials.mint, [1.2, 1.5, 0], [0.1, 0.12, 0.08]);
    }
    // Debris is placed deterministically and never starts an unstable physics pile.
    for (let n = 0; n < 7; n++) {
      const fragment = add('box', n % 2 ? materials.wood : materials.metal, [(n % 3 - 1) * 0.7, 0.11, 0.95 + Math.floor(n / 3) * 0.22], [0.35 + n * 0.03, 0.09, 0.2], [0, n * 0.8, 0.12]);
      fragment.visible = false; debris.push(fragment);
    }
    const contact = { x: x + (kind === 'fryer' ? -1.1 : 0), y: kind === 'fryer' ? 1.18 : height + 0.15, z };
    const localPacks = [packChildren(stationGroup, [counter.mesh, ...falling])];
    if (canopy) localPacks.push(packChildren(canopy));
    if (skewer) localPacks.push(packChildren(skewer));
    let collapsed = false;
    const station = {
      id: `level${index}-station-${kind}`, kind, effect: kind === 'fryer' ? 'steam' : kind === 'bench' ? 'smash' : 'sparks',
      x: contact.x, z, radius: 2.7, contact, approach: { x: contact.x, z: z + 1.25 },
      mesh: stationGroup, parts: [...stationGroup.children], broken: false, colliderId: counter.id,
      break() {
        if (collapsed) return;
        collapsed = true; station.broken = true; counter.solid = false;
        counter.mesh.scale.y *= 0.38; counter.mesh.position.y = 0.23; counter.mesh.rotation.z = 0.06;
        if (canopy) { canopy.position.set(0.2, 0.35, -1.2); canopy.rotation.set(-0.13, 0.16, 0.09); }
        if (skewer) { skewer.position.set(1.2, 0.22, 0.3); skewer.rotation.z = 1.2; }
        falling.forEach((part, i) => { part.rotation.z += i % 2 ? 0.65 : -0.8; part.position.y *= 0.4; });
        for (const piece of parts) {
          if (piece === canopy || piece === skewer || piece === counter.mesh || falling.includes(piece) || debris.includes(piece)) continue;
          if (piece.position.y > 0.8) { piece.position.y = 0.2 + (piece.position.x + 2) * 0.025; piece.rotation.z += 0.17; }
        }
        debris.forEach(piece => { piece.visible = true; });
        localPacks.forEach(pack => pack.refresh());
      },
    };
    stations.push(station); return station;
  }
  if (index === 0) interactionStation('fryer', 6.8, 9.4);
  else if (index === 1) interactionStation('bench', 6.8, -12);
  else interactionStation('machine', 6.8, -13);

  function lamp(x, z, height = 5) {
    cyl(materials.dark, [x, height / 2, z], [0.075, height, 0.075]);
    const side = -Math.sign(x);
    box(materials.dark, [x + side * 0.42, height, z], [0.94, 0.09, 0.1]);
    box(materials.metal, [x + side * 0.78, height - 0.06, z], [0.55, 0.16, 0.33]);
    box(materials.glow, [x + side * 0.78, height - 0.15, z], [0.47, 0.025, 0.25]);
    cyl(materials.edge, [x, 0.13, z], [0.22, 0.26, 0.22]);
  }

  if (index === 0) {
    const bricks = [mat(0x76675e), mat(0x8a7a68), mat(0x546879), mat(0x6a6d78)];
    const planterLeaf = mat(0x526960);
    // Pavement, inset drains, road repairs and mellow lane paint.
    for (const side of [-1, 1]) {
      box(materials.stone, [side * 10.5, 0.055, -5], [3, 0.1, 51]);
      for (let z = -29; z < 20; z += 2) box(materials.edge, [side * 10.5, 0.113, z], [3, 0.015, 0.035]);
      for (let z = -25; z < 20; z += 10) {
        box(materials.dark, [side * 8.75, 0.015, z], [0.45, 0.02, 0.8]);
        for (let n = -2; n <= 2; n++) box(materials.metal, [side * 8.75, 0.03, z + n * 0.13], [0.4, 0.015, 0.035]);
      }
      for (let z = -26; z < 20; z += 9) lamp(side * 10.2, z);
      for (let row = 0; row < 8; row++) {
        const z = 19 - row * 7.2;
        const height = 7 + random() * 7;
        const x = side * (16 + random() * 1.4);
        const facade = bricks[row % bricks.length];
        box(facade, [x, height / 2, z], [7.5, height, 6.7]);
        box(materials.dark, [x, height + 0.15, z], [7.7, 0.3, 6.9]);
        const faceX = x - side * 3.81;
        for (let floor = 0; floor < Math.floor(height / 2.2); floor++) {
          box(materials.light, [faceX, floor * 2.2 + 0.5, z], [0.12, 0.11, 6.7]);
          for (let col = -1; col <= 1; col++) {
            box(materials.dark, [faceX - side * 0.025, 1.5 + floor * 2.2, z + col * 1.8], [0.09, 1.32, 1.05]);
            box(random() > 0.6 ? materials.glow : materials.window, [faceX - side * 0.08, 1.5 + floor * 2.2, z + col * 1.8], [0.04, 1.1, 0.85]);
            box(materials.light, [faceX - side * 0.13, 1.48 + floor * 2.2, z + col * 1.8], [0.06, 0.055, 0.9]);
          }
        }
        box(materials.dark, [x - side * 3.9, 2.35, z], [1.25, 0.13, 5.7], [0, 0, -side * 0.12]);
        box(row % 2 ? materials.pink : materials.metal, [x - side * 4, 2.3, z], [1.35, 0.1, 5.5], [0, 0, -side * 0.12]);
        box(materials.metal, [x, height + 0.65, z - 1.1], [1.8, 1, 1.5]);
        for (let vent = 0; vent < 5; vent++) box(materials.dark, [x - side * 0.92, height + 0.65, z - 1.6 + vent * 0.23], [0.025, 0.65, 0.08]);
      }
    }
    // Narrow balcony/fire-escape silhouettes and overhead service cables.
    for (const z of [11, -5, -21]) {
      for (let segment = 0; segment < 12; segment++) {
        const ax = -12 + segment * 2, bx = ax + 2;
        lineBetween([ax, 6.3 - 1.3 * Math.sin((ax + 12) / 24 * Math.PI), z], [bx, 6.3 - 1.3 * Math.sin((bx + 12) / 24 * Math.PI), z], 0.017, materials.dark);
      }
      for (const x of [-7, -3, 1, 5, 9]) {
        const y = 6.3 - 1.3 * Math.sin((x + 12) / 24 * Math.PI);
        box(materials.glow, [x, y - 0.1, z], [0.08, 0.16, 0.08]);
      }
    }
    for (const x of [-9.8, 9.8]) {
      for (const z of [15, -2, -20]) {
        box(materials.edge, [x, 0.35, z], [1.3, 0.7, 1.5]);
        for (let n = 0; n < 4; n++) instance('leaf', planterLeaf, [x + (random() - 0.5) * 0.7, 0.9, z + (random() - 0.5)], [0.55, 0.45, 0.6]);
      }
    }
    // Landmark water tank, backed by skyline masses.
    cyl(materials.metal, [-16.5, 15, -22], [1.9, 3, 1.9]);
    instance('cone', materials.dark, [-16.5, 16.8, -22], [2.1, 0.8, 2.1]);
    for (const dx of [-1.2, 1.2]) for (const dz of [-1.2, 1.2]) box(materials.dark, [-16.5 + dx, 12.8, -22 + dz], [0.13, 2.4, 0.13]);
    for (let n = 0; n < 12; n++) box(bricks[n % 4], [(n - 5.5) * 5.3, 7 + random() * 5, -38 - random() * 5], [4.6, 16 + random() * 7, 5]);
  } else if (index === 1) {
    const leafMats = [mat(0x37574a), mat(0x456650), mat(0x5b785b), mat(0x739171)];
    const bark = mat(0x635b4c), grass = mat(0x718469), rockMats = [materials.stone, materials.edge, mat(0x85958a)];
    function tree(x, z, size) {
      cyl(bark, [x, size * 0.45, z], [0.16 * size, size * 0.9, 0.14 * size]);
      for (let n = 0; n < 3; n++) instance('cone', leafMats[Math.floor(random() * leafMats.length)], [x, size * (0.65 + n * 0.22), z], [size * (0.53 - n * 0.12), size * 0.7, size * (0.53 - n * 0.12)], [0, random() * Math.PI, 0]);
      for (let n = 0; n < 3; n++) lineBetween([x, 0.04, z], [x + Math.cos(n * 2.1) * size * 0.35, 0.025, z + Math.sin(n * 2.1) * size * 0.35], 0.09, bark);
    }
    for (const side of [-1, 1]) {
      for (let n = 0; n < 21; n++) {
        const z = 22 - n * 2.8 + random() * 1.2;
        const x = side * (13 + random() * 6);
        tree(x, z, 4.4 + random() * 4.2);
        instance('rock', rockMats[n % 3], [side * (12.8 + random() * 2), 1.8, z], [2.3 + random(), 2.1 + random() * 2, 2.4], [0.2, random() * 3, 0.15]);
      }
      for (let n = 0; n < 25; n++) {
        const x = side * (9.2 + random() * 2.3), z = 20 - n * 2 + random();
        instance('rock', rockMats[n % 3], [x, 0.12, z], [0.3 + random() * 0.5, 0.25, 0.4 + random() * 0.4], [random(), random() * 4, random()]);
        for (let tuft = 0; tuft < 3; tuft++) instance('cone', grass, [x + (random() - 0.5) * 0.5, 0.26, z + (random() - 0.5) * 0.7], [0.09, 0.5, 0.05], [0.2, random() * 3, 0.2]);
      }
    }
    // Timber route surfaces: visible planks and cross-braces, no false climb affordances.
    for (const c of [vault, climb, hang]) {
      for (let x = c.x - c.w / 2 + 0.16; x < c.x + c.w / 2; x += 0.32) box(materials.wood, [x, c.h + 0.035, c.z], [0.29, 0.06, c.d - 0.12]);
      for (const side of [-1, 1]) {
        box(bark, [c.x + side * (c.w / 2 - 0.15), c.h / 2, c.z + c.d / 2 + 0.025], [0.16, c.h, 0.12]);
      }
      lineBetween([c.x - c.w / 2 + 0.2, 0.15, c.z + c.d / 2 + 0.06], [c.x + c.w / 2 - 0.2, c.h - 0.1, c.z + c.d / 2 + 0.06], 0.07, bark);
    }
    // Trail camp and rope fence outside the clear combat corridor.
    for (const z of [-3, -12, -23]) {
      for (const side of [-1, 1]) {
        cyl(bark, [side * 10, 0.7, z], [0.09, 1.4, 0.09]);
        cyl(materials.glow, [side * 10, 1.5, z], [0.13, 0.28, 0.13]);
        instance('cone', materials.dark, [side * 10, 1.7, z], [0.22, 0.15, 0.22]);
        if (z !== -23) lineBetween([side * 10, 1.1, z], [side * 10, 1.1, z - (z === -3 ? 9 : 11)], 0.025, materials.light);
      }
    }
    // Raised stream banks remain outside movement bounds; water is decorative.
    const water = mat(0x6ba5a0, { metalness: 0.55, roughness: 0.24 });
    box(water, [17, -0.05, -7], [4.3, 0.08, 53]);
    for (let n = 0; n < 35; n++) box(materials.mint, [16 + random() * 2.5, 0.003, 20 - random() * 53], [0.6 + random(), 0.012, 0.035]);
    for (let n = 0; n < 9; n++) tree(-20 + n * 5, -36 - random() * 4, 7 + random() * 5);
    for (let n = 0; n < 50; n++) {
      const x = (random() - 0.5) * 17, z = 18 - random() * 47;
      box(n % 2 ? materials.edge : materials.wood, [x, 0.006, z], [0.06 + random() * 0.1, 0.012, 0.15 + random() * 0.15], [0, random() * Math.PI, 0]);
    }
  } else {
    const rust = mat(0x976855), steel = mat(0x365a67, { metalness: 0.7, roughness: 0.45 });
    for (const side of [-1, 1]) {
      for (let z = 17; z > -31; z -= 6) {
        box(steel, [side * 11.8, 4.5, z], [0.45, 9, 0.5]);
        box(materials.dark, [side * 11.8, 0.2, z], [0.85, 0.4, 0.9]);
        stripes(side * 11.8, 0.41, z, 0.85, 0.85);
        box(materials.metal, [side * 11.94, 3.2, z - 2.7], [0.12, 0.1, 5.5]);
        box(materials.window, [side * 12.01, 5.1, z - 2.7], [0.035, 2.2, 5.2]);
        for (let pane = -2; pane <= 2; pane++) box(steel, [side * 11.95, 5.1, z - 2.7 + pane], [0.07, 2.3, 0.07]);
      }
      for (let n = 0; n < 4; n++) {
        const z = 12 - n * 10.5;
        box(materials.dark, [side * 9.9, 0.16, z], [2, 0.32, 3.1]);
        cyl(steel, [side * 10, 2.1, z], [0.75, 3.8, 0.75]);
        for (const y of [0.4, 1.4, 3.5]) cyl(materials.metal, [side * 10, y, z], [0.82, 0.12, 0.82]);
        cyl(rust, [side * 10, 4.5, z], [0.16, 1.3, 0.16]);
        box(materials.glow, [side * 9.21, 1.5, z + 0.14], [0.04, 0.12, 0.2]);
      }
      lineBetween([side * 10.8, 7.2, 20], [side * 10.8, 7.2, -30], 0.23, rust);
      lineBetween([side * 11.4, 7.7, 20], [side * 11.4, 7.7, -30], 0.12, materials.metal);
    }
    for (const z of [17, 5, -7, -19, -29]) {
      box(steel, [0, 8.7, z], [24, 0.4, 0.45]);
      lineBetween([-11.5, 8.7, z], [-7, 10.3, z], 0.09, materials.metal);
      lineBetween([11.5, 8.7, z], [7, 10.3, z], 0.09, materials.metal);
      box(materials.dark, [0, 8.2, z], [3, 0.18, 0.6]);
      box(materials.glow, [0, 8.09, z], [2.8, 0.03, 0.45]);
    }
    for (const c of [vault, climb, hang]) {
      stripes(c.x, c.h + 0.05, c.z + c.d / 2 - 0.12, c.w, 0.2);
      for (const side of [-1, 1]) box(steel, [c.x + side * (c.w / 2 - 0.18), c.h / 2, c.z + c.d / 2 + 0.04], [0.22, c.h, 0.06]);
      for (let x = c.x - c.w / 2 + 0.3; x < c.x + c.w / 2; x += 0.4) box(materials.dark, [x, c.h + 0.029, c.z], [0.04, 0.02, c.d - 0.5]);
    }
    for (const x of [-7.7, 7.7]) {
      box(materials.yellow, [x, 0.012, -5], [0.1, 0.02, 49]);
      for (let z = -28; z < 20; z += 1.4) box(materials.edge, [x + Math.sign(x) * 0.4, 0.012, z], [0.8, 0.02, 0.05]);
    }
    // Boss landmark: furnace doors, an overhead crane and suspended hook.
    box(rust, [0, 4.2, -31.3], [11, 8.4, 2]);
    box(materials.dark, [0, 3.2, -30.23], [7.2, 5, 0.14]);
    for (let i = -3; i <= 3; i++) box(materials.glow, [i * 0.82, 3.2, -30.13], [0.42, 3.8, 0.03]);
    box(materials.dark, [0, 8.9, -23], [17.5, 0.65, 1]);
    stripes(0, 8.9, -22.48, 17.4, 0.6, true);
    box(materials.yellow, [3.5, 8.35, -23], [1.4, 0.65, 1.3]);
    lineBetween([3.5, 8, -23], [3.5, 5.8, -23], 0.025, materials.dark);
    mesh('ring', materials.metal, [3.5, 5.6, -23], [0.23, 0.28, 0.23]);
    for (const side of [-1, 1]) {
      box(rust, [side * 15, 6, -9], [4, 12, 42]);
      cyl(materials.metal, [side * 15, 14, -23], [1, 7, 1]);
    }
  }

  // A legible exit arch that changes state only when the game unlocks it.
  const gate = new THREE.Group(); gate.name = 'exit-gate'; gate.position.set(0, 0, -27);
  const gateMaterial = mat(palette.warm, { emissive: palette.warm, emissiveIntensity: 0.8 });
  for (const side of [-1, 1]) {
    mesh('box', materials.dark, [side * 1.9, 1.8, 0], [0.32, 3.6, 0.4], gate);
    mesh('box', gateMaterial, [side * 1.7, 1.8, 0.23], [0.075, 3.3, 0.055], gate);
    mesh('box', materials.metal, [side * 1.9, 0.13, 0], [0.65, 0.26, 0.7], gate);
  }
  mesh('box', materials.dark, [0, 3.5, 0], [4.1, 0.3, 0.4], gate);
  mesh('box', gateMaterial, [0, 3.51, 0.23], [3.5, 0.07, 0.05], gate);
  mesh('ring', gateMaterial, [0, 0.025, 0], [1.45, 1.45, 1.45], gate, [-Math.PI / 2, 0, 0]);
  for (const side of [-1, 1]) mesh('box', gateMaterial, [side * 0.23, 2.85, 0.23], [0.65, 0.09, 0.05], gate, [0, 0, -side * 0.65]);
  group.add(gate);

  // Low-cost drifting environmental motes: one draw call, no gameplay collision.
  const dustCount = index === 1 ? 100 : 70;
  const dustData = new Float32Array(dustCount * 3);
  for (let i = 0; i < dustCount; i++) {
    dustData[i * 3] = (random() - 0.5) * 22;
    dustData[i * 3 + 1] = 0.5 + random() * 7;
    dustData[i * 3 + 2] = 19 - random() * 49;
  }
  const dustGeo = new THREE.BufferGeometry(); dustGeo.setAttribute('position', new THREE.BufferAttribute(dustData, 3)); ownedGeometries.add(dustGeo);
  const dustMat = new THREE.PointsMaterial({ color: index === 2 ? palette.warm : palette.light, size: 0.045, transparent: true, opacity: 0.48, depthWrite: false }); ownedMaterials.add(dustMat);
  const dust = new THREE.Points(dustGeo, dustMat); dust.name = 'ambient-motes'; group.add(dust);

  // Commit all immutable details to shared instanced draw calls.
  for (const batch of batches.values()) {
    const instanced = new THREE.InstancedMesh(geometry(batch.kind), batch.material, batch.matrices.length);
    batch.matrices.forEach((m, i) => instanced.setMatrixAt(i, m));
    instanced.castShadow = true; instanced.receiveShadow = true; instanced.name = `details-${batch.kind}`;
    instanced.computeBoundingSphere(); group.add(instanced);
  }
  const hemisphere = new THREE.HemisphereLight(index === 2 ? 0xc5e0ee : 0xc3d9dc, palette.dark, 2.1);
  const sun = new THREE.DirectionalLight(palette.sun, index === 1 ? 2.5 : 3.1);
  sun.position.set(-14, 24, 12); sun.target.position.set(0, 0, -5); sun.castShadow = true;
  sun.shadow.mapSize.set(1024, 1024); sun.shadow.camera.left = -20; sun.shadow.camera.right = 20;
  sun.shadow.camera.top = 29; sun.shadow.camera.bottom = -29; sun.shadow.camera.near = 1; sun.shadow.camera.far = 70;
  sun.shadow.bias = -0.0006; sun.shadow.normalBias = 0.035;
  const rim = new THREE.DirectionalLight(palette.accent, 0.7); rim.position.set(12, 7, -20);
  group.add(hemisphere, sun, sun.target, rim);
  scene.background = new THREE.Color(palette.sky);
  scene.fog = new THREE.Fog(palette.fog, index === 1 ? 20 : 31, index === 1 ? 67 : 91);
  scene.add(group);

  let elapsed = 0, unlocked = false;
  const enemies = index === 0
    ? [{ kind: 'grunt', x: -1.8, z: 5 }, { kind: 'swift', x: 4.2, z: 0.4 }, { kind: 'grunt', x: -5.7, z: -9.2 }, { kind: 'brute', x: 2.4, z: -21 }]
    : index === 1
      ? [{ kind: 'swift', x: -2.7, z: 4 }, { kind: 'grunt', x: 5.9, z: -3 }, { kind: 'swift', x: -6.6, z: -12 }, { kind: 'brute', x: 1.8, z: -23 }]
      : [{ kind: 'grunt', x: -2.4, z: 5 }, { kind: 'brute', x: 5.6, z: -3.8 }, { kind: 'swift', x: -6.2, z: -11 }, { kind: 'oz', x: 0, z: -23 }];
  return {
    group, colliders, props, stations, route, enemies, spawn: { x: 0, z: 14 },
    exit: { x: 0, z: -27, radius: 2.1, mesh: gate }, gate,
    bounds: { minX: -12, maxX: 12, minZ: -30, maxZ: 20 },
    level: LEVELS[index], palette,
    setExitUnlocked(value) {
      unlocked = Boolean(value);
      gateMaterial.color.setHex(unlocked ? palette.accent : palette.warm);
      gateMaterial.emissive.copy(gateMaterial.color);
    },
    update(dt) {
      elapsed += Math.min(dt, 0.05);
      for (const a of animated) a.material.emissiveIntensity = 0.35 + Math.sin(elapsed * 2 + a.phase) * 0.15;
      gateMaterial.emissiveIntensity = (unlocked ? 1 : 0.55) + Math.sin(elapsed * 2.1) * 0.2;
      dust.rotation.y = Math.sin(elapsed * 0.035) * 0.025;
      dust.position.y = Math.sin(elapsed * 0.4) * 0.14;
    },
    dispose() {
      scene.remove(group);
      ownedGeometries.forEach(g => g.dispose());
      ownedMaterials.forEach(m => m.dispose());
      sun.shadow.map?.dispose();
    },
  };
}
