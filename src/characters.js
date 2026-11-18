import * as THREE from 'three';

// Editable character modelling + animation source. Metres; +Z is forward.
// All visible parts are actual geometry and are bound to the named skeleton.
const TAU = Math.PI * 2;
const clamp = THREE.MathUtils.clamp;
const mix = THREE.MathUtils.lerp;
const ease = t => { t = clamp(t, 0, 1); return t * t * (3 - 2 * t); };
const pulse = (p, a, b, c) => p < b ? ease((p - a) / (b - a)) : 1 - ease((p - b) / (c - b));
let faceAtlasTexture;
function faceAtlas() {
  if (typeof document === 'undefined') return null;
  if (!faceAtlasTexture) {
    faceAtlasTexture = new THREE.TextureLoader().load(new URL('../assets/face-atlas.png', import.meta.url).href);
    faceAtlasTexture.colorSpace = THREE.SRGBColorSpace;
    faceAtlasTexture.wrapS = faceAtlasTexture.wrapT = THREE.ClampToEdgeWrapping;
    faceAtlasTexture.anisotropy = 4;
  }
  return faceAtlasTexture;
}
// Project a newly painted albedo onto genuinely curved facial geometry. These
// feature correspondences prevent the atlas from stretching the eyes/mouth.
function faceUV(x, y, oz = false) {
  const landmarks = [[.351, 0], [.30, .12], [.228, .36], [.201, .425], [.129, .57], [.068, .70], [-.04, oz ? .90 : .85], [-.227, 1]];
  let v = y >= landmarks[0][0] ? 0 : 1;
  for (let i = 0; i < landmarks.length - 1; i++) {
    const [ya, va] = landmarks[i], [yb, vb] = landmarks[i + 1];
    if (y <= ya && y >= yb) { v = mix(va, vb, (ya - y) / (ya - yb)); break; }
  }
  const u = clamp(.5 + x / (oz ? .53 : .46), .01, .99);
  return [u * .5 + (oz ? .5 : 0), 1 - v];
}

export const ANIMATION_STATES = ['idle', 'walk', 'run', 'carry', 'punch', 'kick', 'grab', 'throw', 'envGrab', 'envSlam', 'envVictim', 'dodge', 'crouch', 'hit', 'fall', 'getup', 'victory', 'use', 'jump', 'land', 'vault', 'hang', 'shimmy', 'climb', 'bossWindup', 'bossAttack'];

// Elliptical ring surfaces produce continuous silhouettes, rather than a stack
// of primitives. Each row is [height, widthRadius, depthRadius, depthOffset].
function rings(rows, segments = 20, cap = true) {
  const vertices = [], uv = [], indices = [];
  for (let r = 0; r < rows.length; r++) {
    const [y, rx, rz, z = 0] = rows[r];
    for (let s = 0; s <= segments; s++) {
      const a = s / segments * TAU;
      vertices.push(Math.cos(a) * rx, y, Math.sin(a) * rz + z);
      uv.push(s / segments, r / (rows.length - 1));
    }
  }
  for (let r = 0; r < rows.length - 1; r++) for (let s = 0; s < segments; s++) {
    const a = r * (segments + 1) + s, b = a + segments + 1;
    indices.push(a, b, a + 1, b, b + 1, a + 1);
  }
  if (cap) for (const r of [0, rows.length - 1]) {
    const center = vertices.length / 3;
    vertices.push(0, rows[r][0], rows[r][3] || 0); uv.push(.5, .5);
    for (let s = 0; s < segments; s++) {
      const a = r * (segments + 1) + s;
      if (r === 0) indices.push(center, a, a + 1); else indices.push(center, a + 1, a);
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(vertices, 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute(uv, 2));
  g.setIndex(indices); g.computeVertexNormals(); return g;
}

function tube(points, radius = .003, radialSegments = 5, closed = false) {
  const c = new THREE.CatmullRomCurve3(points.map(p => new THREE.Vector3(...p)), closed);
  return new THREE.TubeGeometry(c, Math.max(4, points.length * 2), radius, radialSegments, closed);
}

function material(name, color, roughness = .8, extra = {}) {
  const m = new THREE.MeshStandardMaterial({ color, roughness, metalness: 0, ...extra });
  m.name = name; return m;
}

/** Create a skinned, stylised Nathan, Oz or lighter ordinary enemy. */
export function createCharacter(kind = 'nathan', variant = 0) {
  const isNathan = kind === 'nathan', isOz = kind === 'oz';
  const hero = isNathan || isOz;
  const root = new THREE.Group(); root.name = `${kind}-character`;
  const bones = {}, boneList = [], parts = [], materials = [];
  const palette = {
    skin: material('warm skin', isOz ? '#c58c70' : '#cda084'),
    skinLight: material('face planes', isOz ? '#d39e82' : '#d8af92'),
    skinShade: material('ear and eyelid', '#a66f5d'),
    lip: material('lips', '#a57669'),
    eye: material('eye whites', '#cbd1c4', .5),
    iris: material('iris', isOz ? '#4a4932' : '#4b5148', .43),
    pupil: material('pupils and nostrils', '#1d1a1a', .48),
    hair: material('hair', isOz ? '#514c45' : '#6b533e'),
    hairLight: material('hair strands', isOz ? '#8c8575' : '#a18460'),
    beard: material('beard', isOz ? '#63584e' : '#493c31'),
    beardLight: material('beard strands', isOz ? '#989080' : '#796852'),
    shirt: material('shirt', isNathan ? '#191d25' : isOz ? '#b94438' : ['#3a6970', '#a17a41', '#62667a'][variant % 3]),
    shirtLight: material('shirt seams', isNathan ? '#303641' : isOz ? '#d46553' : '#7c8991'),
    shorts: material('shorts or trousers', isNathan ? '#ec548d' : isOz ? '#30333f' : '#414958'),
    shortsLight: material('waistband and piping', isNathan ? '#ff8bb4' : '#545769'),
    shoe: material('shoe upper', isNathan ? '#eb6e9e' : '#282a31', .68),
    sole: material('shoe sole', isNathan ? '#f2d8df' : '#737679', .83),
    stripe: material('three shoe stripes', '#fff2e7', .6),
    ink: material('tattoo ink', '#4c5552', .95),
    metal: material('glasses metal', '#c3c6b7', .25, { metalness: .8 }),
    lens: material('clear glasses', '#c1e2dc', .1, { transparent: true, opacity: .12, depthWrite: false }),
    facePaint: material('painted face albedo', '#ffffff', .94, { map: hero ? faceAtlas() : null }),
  };
  for (const mat of Object.values(palette)) materials.push(mat);
  function bone(name, parent, position) {
    const b = new THREE.Bone(); b.name = name; b.position.set(...position);
    (parent || root).add(b); bones[name] = b; boneList.push(b); return b;
  }
  function part(geometry, mat, parent, position = [0, 0, 0], scale = [1, 1, 1], rotation = [0, 0, 0]) {
    const m = new THREE.Matrix4().compose(new THREE.Vector3(...position), new THREE.Quaternion().setFromEuler(new THREE.Euler(...rotation)), new THREE.Vector3(...scale));
    parts.push({ geometry, material: mat, bone: parent, matrix: m });
  }
  const sphere = (parent, mat, pos, scale, detail = 16) => part(new THREE.SphereGeometry(1, detail, Math.max(8, detail / 2)), mat, parent, pos, scale);
  const box = (parent, mat, pos, scale, rotation) => part(new THREE.BoxGeometry(...scale), mat, parent, pos, [1, 1, 1], rotation);
  const line = (parent, mat, points, radius = .003, sides = 5) => part(tube(points, radius, sides), mat, parent);
  const hips = bone('hips', null, [0, .92, 0]);
  const spine = bone('spine', hips, [0, .13, 0]);
  const chest = bone('chest', spine, [0, .2, -.013]);
  const neck = bone('neck', chest, [0, .275, 0]);
  const head = bone('head', neck, [0, .075, 0]);
  const shirtHem = bone('shirtHem', spine, [0, 0, 0]);
  const waistband = bone('waistband', hips, [0, 0, 0]);
  const shoulderWidth = hero ? .346 : .265;
  for (const [side, sign] of [['left', -1], ['right', 1]]) {
    const upper = bone(`${side}UpperArm`, chest, [shoulderWidth * sign, .205, 0]);
    const lower = bone(`${side}ForeArm`, upper, [0, -.29, 0]);
    const hand = bone(`${side}Hand`, lower, [0, -.265, .003]);
    const thigh = bone(`${side}Thigh`, hips, [(hero ? .17 : .13) * sign, -.035, 0]);
    const shin = bone(`${side}Shin`, thigh, [0, -.405, 0]);
    const foot = bone(`${side}Foot`, shin, [0, -.375, .015]);
    const armRadius = hero ? .103 : .075;
    part(rings([[-.29, .075, .077], [-.23, armRadius, armRadius], [-.1, armRadius * 1.14, armRadius * 1.12], [.025, .103, .098]]), palette.skin, upper);
    part(rings([[-.15, armRadius * 1.22, armRadius * 1.2], [-.08, armRadius * 1.35, armRadius * 1.24], [.025, armRadius * 1.28, armRadius * 1.15], [.065, .075, .07]]), palette.shirt, upper);
    part(rings([[-.265, .054, .055], [-.2, .067, .068], [-.11, armRadius * .87, armRadius * .87], [.016, .079, .079]], 16), palette.skin, lower);
    sphere(lower, palette.skin, [0, -.003, 0], [.079, .081, .078], 16);
    sphere(hand, palette.skin, [0, .005, .002], [.056, .052, .055], 14);
    sphere(hand, palette.skin, [0, -.051, .012], [hero ? .065 : .052, .082, .047]);
    sphere(hand, palette.skinLight, [-sign * .045, -.032, .035], [.028, .043, .026], 12);
    for (let f = 0; f < 4; f++) {
      const finger = bone(`${side}Finger${f}`, hand, [(f - 1.5) * .024, -.058, .023]);
      sphere(finger, palette.skin, [0, -.026, 0], [.014, .035 - Math.abs(1.5 - f) * .003, .024], 10);
      line(finger, palette.skinShade, [[-.009, -.015, .021], [0, -.018, .023], [.009, -.015, .021]], .0014, 4);
    }
    const legRadius = hero ? .135 : .093;
    part(rings([[-.41, legRadius * .77, legRadius * .8], [-.3, legRadius * .91, legRadius], [-.13, legRadius * 1.15, legRadius * 1.14], [.035, legRadius, legRadius]], 18), isNathan ? palette.skin : palette.shorts, thigh);
    if (isNathan) {
      part(rings([[-.275, .146, .145, .012], [-.2, .159, .15, 0], [-.025, .16, .16], [.04, .14, .14]], 18), palette.shorts, thigh);
      part(rings([[-.28, .152, .151, .012], [-.264, .154, .153, .012]], 18), palette.shortsLight, thigh);
      line(thigh, palette.shortsLight, [[sign * .148, .01, .015], [sign * .16, -.12, .018], [sign * .146, -.26, .023]], .004);
    }
    part(rings([[-.375, .065, .068], [-.3, .073, .082, -.01], [-.15, hero ? .103 : .075, hero ? .111 : .077, -.015], [.015, legRadius * .78, legRadius * .81]], 18), isNathan ? palette.skin : palette.shorts, shin);
    sphere(shin, isNathan ? palette.skin : palette.shorts, [0, -.004, 0], [legRadius * .8, legRadius * .84, legRadius * .83], 16);
    sphere(foot, isNathan ? palette.skin : palette.shorts, [0, .027, -.011], [.066, .055, .065], 14);
    sphere(foot, palette.shoe, [0, -.015, .074], [.092, .077, .169], 18);
    // Continuous shaped sole, low heel and a separate rounded toe cap.
    part(rings([[-.095, .084, .155, .07], [-.077, .098, .171, .073], [-.059, .096, .169, .074]], 20), palette.sole, foot);
    sphere(foot, palette.shoe, [0, .012, .01], [.079, .079, .086], 14);
    line(foot, palette.shortsLight, [[-.067, .005, .16], [0, .028, .214], [.067, .005, .16]], .003);
    for (let l = 0; l < 3; l++) line(foot, palette.stripe, [[-.043, .046 - l * .005, .082 + l * .026], [.043, .046 - l * .005, .082 + l * .026]], .003);
    if (isNathan) for (let s = 0; s < 3; s++) {
      // Three individual broad geometric stripes on BOTH outer and inner sides.
      for (const flank of [-1, 1]) {
        const z = .016 + s * .039;
        line(foot, palette.stripe, [[flank * .077, .039, z], [flank * .091, .005, z + .019], [flank * .093, -.044, z + .039]], .0095, 5);
      }
    }
    if (isNathan) {
      // Original stylised floral/blackwork interpretation, never a photo decal.
      // The ink sits on the curved skin instead of floating in a flat rectangle.
      for (let flower = 0; flower < 3; flower++) {
        const cy = -.07 - flower * .061;
        const cr = .068 + (2 - flower) * .005;
        const sideAngle = sign > 0 ? .28 : Math.PI - .28;
        for (let petal = 0; petal < 7; petal++) {
          const angle = petal / 7 * TAU;
          const points = [];
          for (let n = 0; n <= 8; n++) {
            const t = n / 8 * TAU;
            const axial = Math.sin(t) * .013 + Math.sin(angle) * .014;
            const wrap = sideAngle + Math.cos(angle) * .23 + Math.cos(t) * .13;
            points.push([Math.cos(wrap) * cr, cy + axial, Math.sin(wrap) * cr]);
          }
          line(lower, palette.ink, points, .0023, 4);
        }
      }
      line(lower, palette.ink, [[sign * .07, -.02, .035], [sign * .082, -.06, .005], [sign * .068, -.12, .028], [sign * .06, -.19, .01], [sign * .054, -.23, .024]], .004, 4);
      if (side === 'left') {
        part(rings([[-.246, .058, .059], [-.233, .06, .061]], 16), palette.shirt, lower);
        box(lower, palette.shirtLight, [-.055, -.239, .024], [.016, .037, .035]);
      }
    }
  }

  const bodyW = hero ? 1 : .77;
  // Pelvis and abdomen: broad, soft proportions, not a bodybuilder torso.
  part(rings([[-.09, .215 * bodyW, .15], [.02, .285 * bodyW, .19], [.10, .317 * bodyW, .237, .035], [.18, .33 * bodyW, .25, .045], [.27, .317 * bodyW, .23, .035]], 28), palette.skin, hips);
  part(rings([[-.10, .23 * bodyW, .16], [-.01, .286 * bodyW, .195], [.053, .292 * bodyW, .20]], 24), palette.shorts, waistband);
  part(rings([[.035, .294 * bodyW, .202], [.062, .294 * bodyW, .202]], 24), palette.shortsLight, waistband);
  if (isNathan) {
    line(waistband, palette.stripe, [[-.022, .059, .202], [-.018, .012, .213], [-.03, -.017, .21]], .0035);
    line(waistband, palette.stripe, [[.022, .059, .202], [.018, .008, .215], [.031, -.02, .21]], .0035);
    sphere(hips, palette.skinShade, [0, .104, .253], [.012, .009, .004], 10);
    // Tiny upper rear crease only; it is covered in neutral stance.
    line(hips, palette.skinShade, [[0, .061, -.197], [0, .037, -.199], [0, .021, -.198]], .0018, 4);
  }
  part(rings([[-.11, .328 * bodyW, .256, .044], [-.04, .334 * bodyW, .25, .04], [.025, .328 * bodyW, .237, .03], [.10, .32 * bodyW, .22, .02], [.17, .307 * bodyW, .20, .01], [.235, .287 * bodyW, .173], [.28, .16, .12]], 28), palette.shirt, chest);
  // Lower shirt attached separately so it can lift a little over the belly.
  part(rings([[.023, .329 * bodyW, .256, .039], [.068, .335 * bodyW, .26, .04], [.118, .332 * bodyW, .254, .04]], 28), palette.shirt, shirtHem);
  part(rings([[.021, .33 * bodyW, .258, .039], [.032, .332 * bodyW, .259, .039]], 28), palette.shirtLight, shirtHem);
  line(chest, palette.shirtLight, [[-.25 * bodyW, .14, -.167], [0, .17, -.185], [.25 * bodyW, .14, -.167]], .0025);
  for (const s of [-1, 1]) line(chest, palette.shirtLight, [[s * .29 * bodyW, -.07, -.018], [s * .312 * bodyW, .035, -.01], [s * .31 * bodyW, .14, -.008]], .002);
  part(rings([[-.015, .098, .083], [.09, .092, .08]], 18), palette.skin, neck);
  part(rings([[-.007, .119, .097], [.008, .115, .094]], 20), palette.shirtLight, neck);

  // Facial sculpture. The primary photos set brow, hairline, nose and beard.
  const faceW = isOz ? .171 : .156;
  const face = new THREE.SphereGeometry(1, hero ? 48 : 28, hero ? 36 : 20);
  const pos = face.attributes.position;
  for (let i = 0; i < pos.count; i++) {
    let x = pos.getX(i), y = pos.getY(i), z = pos.getZ(i);
    // Flatter face plane, prominent cheeks, broad forehead, squarer jaw.
    const width = y < -.25 ? mix(.82, 1, ease((y + 1) / .75)) : 1;
    x *= faceW * width;
    z *= z > 0 ? .137 : .151;
    if (z > 0) {
      z += .008 * (1 - Math.abs(y));
      // Cheek planes and jaw are sculpted into the continuous head, not balls.
      z += .009 * Math.exp(-Math.pow((Math.abs(x) - .084) / .055, 2) - Math.pow((y + .2) / .33, 2));
      if (y < -.45) z += .011 * (1 - Math.abs(y));
      if (hero) {
        const localY = y * .184 + .159;
        // A nose sculpted directly into the face avoids a ball tip and the
        // dark seam of a separately attached bridge in close portrait views.
        z += .042 * Math.exp(-Math.pow(x / .028, 2) - Math.pow((localY - .129) / .025, 2));
        z += .019 * Math.exp(-Math.pow(x / .021, 2) - Math.pow((localY - .171) / .052, 2));
      }
    }
    pos.setXYZ(i, x, y * .184 + .159, z - .006);
  }
  face.computeVertexNormals();
  if (hero) {
    const front = face.clone(), back = face.clone(), frontIndex = [], backIndex = [];
    for (let i = 0; i < face.index.count; i += 3) {
      const a = face.index.getX(i), b = face.index.getX(i + 1), c = face.index.getX(i + 2);
      const z = (pos.getZ(a) + pos.getZ(b) + pos.getZ(c)) / 3;
      (z > -.004 ? frontIndex : backIndex).push(a, b, c);
    }
    front.setIndex(frontIndex); back.setIndex(backIndex);
    part(front, palette.facePaint, head); part(back, palette.skin, head); face.dispose();
  } else part(face, palette.skin, head);
  for (const s of [-1, 1]) {
    sphere(head, palette.skin, [s * (faceW + .002), .148, -.008], [.029, .052, .023], 14);
    sphere(head, palette.skinShade, [s * (faceW + .007), .149, .012], [.016, .034, .007], 12);
    // Ordinary enemies keep economical geometric facial details. Named faces
    // use the painted atlas on a curved mesh, avoiding competing cartoon eyes.
    if (!hero) {
    const eyeX = isOz ? .071 : .063;
    sphere(head, palette.eye, [s * eyeX, .201, .131], [.026, .0095, .005], 16);
    sphere(head, palette.iris, [s * eyeX, .201, .136], [.0088, .009, .002], 12);
    sphere(head, palette.pupil, [s * eyeX, .201, .138], [.004, .0058, .001], 10);
    sphere(head, palette.eye, [s * eyeX - .0025, .204, .139], [.0015, .0015, .0006], 8);
    line(head, palette.skin, [[s * (eyeX - .027), .203, .132], [s * eyeX, .212, .135], [s * (eyeX + .027), .201, .123]], .0045);
    line(head, palette.skin, [[s * (eyeX - .026), .198, .132], [s * eyeX, .192, .135], [s * (eyeX + .027), .198, .123]], .0035);
    line(head, palette.hair, [[s * .034, .225, .134], [s * .064, .232, .128], [s * .099, .225, .108]], isOz ? .0065 : .0055, 6);
    // Nasolabial crease and realistic nostril wings.
    line(head, palette.skinShade, [[s * .032, .114, .135], [s * .04, .09, .126], [s * .043, .075, .118]], .001, 4);
    sphere(head, palette.skin, [s * .023, .125, .151], [.019, .015, .017], 14);
    sphere(head, palette.pupil, [s * .021, .116, .161], [.007, .003, .003], 10);
    }
  }
  if (!hero) {
  sphere(head, palette.skin, [0, .163, .143], [.020, .049, .022], 18);
  sphere(head, palette.skin, [0, .129, .163], [.026, .020, .022], 20);
  sphere(head, palette.lip, [0, .068, .122], [.043, .007, .005], 18);
  line(head, palette.pupil, [[-.038, .07, .122], [0, .067, .127], [.038, .07, .122]], .0014, 5);
  sphere(head, palette.lip, [0, .058, .12], [.034, .005, .004], 16);
  }

  if (isNathan) {
    // Hair cap follows the skull with a short swept top and clipped sides.
    const hairCap = new THREE.SphereGeometry(1, 32, 16, 0, TAU, 0, .82);
    part(hairCap, palette.facePaint, head, [0, .17, -.012], [.158, .178, .15]);
    // A close-cut continuous back cap removes the bald V between side patches.
    const backHair = new THREE.SphereGeometry(1, 24, 18, Math.PI, Math.PI, .60, 1.45);
    part(backHair, palette.hair, head, [0, .159, -.006], [.158, .187, .153]);
    for (const s of [-1, 1]) sphere(head, palette.hair, [s * .142, .225, -.032], [.012, .065, .086], 16);
    // Unified beard shell grows from sideburns around the jaw. Open mouth area.
    const beardGeometry = rings([[-.227, .018, .027, .085], [-.208, .052, .048, .083], [-.17, .082, .067, .074], [-.115, .111, .083, .066], [-.05, .133, .092, .05], [.005, .128, .07, .034], [.045, .118, .055, .025]], 32);
    beardGeometry.userData.faceRegion = 'beard';
    part(beardGeometry, palette.facePaint, head);
    for (const s of [-1, 1]) {
      sphere(head, palette.beard, [s * .13, .075, .013], [.025, .083, .062], 18);
    }
    // A few fine silhouette strands; the albedo supplies the dense hair detail.
    for (let n = 0; n < 10; n++) {
      const a = .06 + n / 9 * Math.PI * .96;
      const x = Math.cos(a) * .127, z = Math.sin(a) * .094 + .043;
      const y = -.012 - ((n * 7) % 9) * .006;
      line(head, palette.beard, [[x, y + .025, z], [x * .9, y - .045, z + .01], [x * .65, y - .112, z + .003], [x * .36, y - .17, z - .015]], .0006, 3);
    }
  } else if (isOz) {
    // Hair is deliberately sparse on top; preserve Oz's high open forehead.
    for (const s of [-1, 1]) {
      sphere(head, palette.hair, [s * .151, .207, -.04], [.026, .081, .087], 14);
      for (let n = 0; n < 5; n++) line(head, palette.hairLight, [[s * (.12 + .006 * n), .276 - n * .005, -.024], [s * (.1 + .007 * n), .301 - n * .004, -.052], [s * (.078 + .009 * n), .312 - n * .004, -.075]], .0018, 4);
    }
    for (const s of [-1, 1]) {
      const cx = s * .073;
      const outline = [[cx - .057, .242, .161], [cx + .049, .244, .156], [cx + .061, .224, .153], [cx + .055, .168, .158], [cx + .039, .153, .163], [cx - .043, .154, .167], [cx - .06, .173, .166], [cx - .062, .223, .163], [cx - .057, .242, .161]];
      line(head, palette.metal, outline, .0033, 6);
      sphere(head, palette.lens, [cx, .198, .16], [.055, .043, .004], 18);
      line(head, palette.metal, [[s * .132, .232, .154], [s * .164, .225, .09], [s * .169, .17, -.024]], .0032);
    }
    line(head, palette.metal, [[-.018, .217, .168], [0, .225, .174], [.018, .217, .168]], .0031, 6);
    line(head, palette.metal, [[-.123, .25, .157], [0, .259, .163], [.123, .25, .157]], .0026, 6);
  } else {
    const cap = new THREE.SphereGeometry(1, 16, 8, 0, TAU, 0, 1.4);
    part(cap, palette.hair, head, [0, .17, -.009], [.158, .18, .15]);
    if (variant % 3 === 1) part(rings([[-.018, .09, .062, .05], [.035, .12, .07, .04]], 16), palette.beard, head);
  }

  // Bake all parts to bind space, then combine per material into one skinned mesh.
  // This keeps the draw-call budget to the material count, not hundreds of parts.
  root.updateMatrixWorld(true);
  const positions = [], normals = [], uvs = [], indices = [], skinIndices = [], skinWeights = [];
  const geometry = new THREE.BufferGeometry();
  let vertexOffset = 0, indexOffset = 0;
  const usedMaterials = materials.filter(m => parts.some(p => p.material === m));
  for (let mi = 0; mi < usedMaterials.length; mi++) {
    const begin = indexOffset;
    for (const p of parts.filter(p => p.material === usedMaterials[mi])) {
      const g = p.geometry;
      if (p.material === palette.facePaint) {
        const gp = g.getAttribute('position'), projectedUV = [];
        const localPoint = new THREE.Vector3();
        for (let i = 0; i < gp.count; i++) {
          localPoint.fromBufferAttribute(gp, i).applyMatrix4(p.matrix);
          const uv = faceUV(localPoint.x, localPoint.y, isOz);
          if (g.userData.faceRegion === 'beard') uv[1] = mix(.14, .005, clamp((.045 - localPoint.y) / .272, 0, 1));
          projectedUV.push(...uv);
        }
        g.setAttribute('uv', new THREE.Float32BufferAttribute(projectedUV, 2));
      }
      const transform = new THREE.Matrix4().multiplyMatrices(p.bone.matrixWorld, p.matrix); g.applyMatrix4(transform);
      const ps = g.getAttribute('position'), ns = g.getAttribute('normal'), us = g.getAttribute('uv');
      const boneIndex = boneList.indexOf(p.bone);
      for (let i = 0; i < ps.count; i++) {
        positions.push(ps.getX(i), ps.getY(i), ps.getZ(i));
        const nx = ns.getX(i), ny = ns.getY(i), nz = ns.getZ(i);
        if (nx * nx + ny * ny + nz * nz < 1e-12) normals.push(0, 1, 0); else normals.push(nx, ny, nz);
        uvs.push(us ? us.getX(i) : 0, us ? us.getY(i) : 0); skinIndices.push(boneIndex, 0, 0, 0); skinWeights.push(1, 0, 0, 0);
      }
      if (g.index) for (let i = 0; i < g.index.count; i++) indices.push(g.index.getX(i) + vertexOffset);
      else for (let i = 0; i < ps.count; i++) indices.push(i + vertexOffset);
      indexOffset = indices.length; vertexOffset += ps.count; g.dispose();
    }
    geometry.addGroup(begin, indexOffset - begin, mi);
  }
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
  geometry.setAttribute('normal', new THREE.Float32BufferAttribute(normals, 3));
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(skinIndices, 4));
  geometry.setAttribute('skinWeight', new THREE.Float32BufferAttribute(skinWeights, 4));
  geometry.setIndex(indices); geometry.normalizeNormals(); geometry.computeBoundingSphere(); geometry.computeBoundingBox();
  const mesh = new THREE.SkinnedMesh(geometry, usedMaterials); mesh.name = `${kind}-skinned-mesh`;
  mesh.castShadow = true; mesh.receiveShadow = true; mesh.frustumCulled = false;
  const skeleton = new THREE.Skeleton(boneList); mesh.bind(skeleton); root.add(mesh);
  const rest = Object.fromEntries(boneList.map(b => [b.name, { position: b.position.clone(), rotation: b.rotation.clone(), scale: b.scale.clone() }]));
  const target = Object.fromEntries(boneList.map(b => [b.name, { x: 0, y: 0, z: 0 }]));
  const inverseRoot = new THREE.Matrix4(), footPoint = new THREE.Vector3();
  const groundedStates = new Set(['idle', 'walk', 'run', 'carry', 'punch', 'kick', 'grab', 'throw', 'envGrab', 'envSlam', 'dodge', 'crouch', 'hit', 'victory', 'use', 'land', 'bossWindup', 'bossAttack']);
  let elapsed = 0;

  function update(dt = 1 / 60, pose = {}) {
    elapsed += Math.max(0, dt);
    const state = pose.state || 'idle', time = pose.time ?? elapsed, phase = clamp(pose.phase ?? 0, 0, 1);
    for (const key of Object.keys(target)) target[key].x = target[key].y = target[key].z = 0;
    const set = (name, x = 0, y = 0, z = 0) => { target[name].x = x; target[name].y = y; target[name].z = z; };
    const breathe = Math.sin(time * 2.3);
    let hipY = .004 * breathe, hipZ = 0, hemLift = 0, shortsDrop = 0;
    set('leftUpperArm', -.08, -.05, -.14); set('rightUpperArm', -.08, .05, .14);
    set('leftForeArm', -.18); set('rightForeArm', -.18);
    set('chest', -.012 + breathe * .006);
    set('head', .012 + Math.sin(time * 1.3) * .009);
    const guard = () => { set('leftUpperArm', -.53, -.12, -.22); set('rightUpperArm', -.42, .18, .22); set('leftForeArm', -.9); set('rightForeArm', -.95); set('chest', .045, -.08); };
    if (state === 'walk' || state === 'run') {
      const run = state === 'run', speed = clamp(pose.speed ?? 1, 0, 1.5);
      const c = time * (run ? 9.6 : 6.3), stride = Math.sin(c) * (run ? .68 : .4) * Math.max(.25, speed);
      set('leftThigh', stride); set('rightThigh', -stride);
      set('leftShin', Math.max(0, -Math.sin(c)) * (run ? 1.2 : .54)); set('rightShin', Math.max(0, Math.sin(c)) * (run ? 1.2 : .54));
      set('leftFoot', -Math.max(0, Math.sin(c)) * .15); set('rightFoot', -Math.max(0, -Math.sin(c)) * .15);
      set('leftUpperArm', -stride * .78 - .08, 0, -.16); set('rightUpperArm', stride * .78 - .08, 0, .16);
      set('leftForeArm', run ? -.95 : -.3); set('rightForeArm', run ? -.95 : -.3);
      set('chest', run ? .12 : .035, stride * -.065); set('head', run ? -.08 : -.02);
      hipY = -(run ? .035 : .016) * Math.abs(Math.cos(c)); hemLift = run ? .008 : 0;
    } else if (state === 'carry') {
      const moving = clamp(pose.speed ?? 0, 0, 1), stride = Math.sin(time * 6.3) * .3 * moving;
      set('leftThigh', stride); set('rightThigh', -stride);
      set('leftShin', Math.max(0, -Math.sin(time * 6.3)) * .45 * moving); set('rightShin', Math.max(0, Math.sin(time * 6.3)) * .45 * moving);
      set('leftUpperArm', -.75, -.15, -.10); set('rightUpperArm', -.75, .15, .10);
      set('leftForeArm', -.93); set('rightForeArm', -.93); set('leftHand', 0, -.12); set('rightHand', 0, .12);
      set('chest', -.03); hipY = -.012 * Math.abs(Math.cos(time * 6.3)) * moving;
    } else if (state === 'punch' || state === 'bossAttack') {
      guard(); const swing = pulse(phase, .05, .38, .9); const wind = pulse(phase, 0, .16, .36);
      const right = (pose.combo ?? 0) % 2 === 0, side = right ? 'right' : 'left', sign = right ? 1 : -1;
      set(`${side}UpperArm`, -.5 - swing * 1.1 + wind * .24, sign * (-.08 + swing * -.16), sign * (.22 - swing * .20));
      set(`${side}ForeArm`, -.95 + swing * .92);
      set('chest', .03 + swing * .13, sign * (.15 - swing * .52)); set('hips', 0, sign * (.08 - swing * .2));
      set('head', -.03, sign * swing * .15); hipY = -.025 * swing;
    } else if (state === 'kick') {
      guard(); const lift = pulse(phase, 0, .34, .95), extension = pulse(phase, .18, .45, .78);
      set('rightThigh', -1.65 * lift, .08 * lift, .12 * lift); set('rightShin', 1.45 * lift * (1 - extension));
      set('rightFoot', -.08 - .2 * extension); set('leftThigh', .14 * lift); set('leftShin', .12 * lift);
      set('chest', -.25 * lift, -.19 * lift); set('rightUpperArm', -.35, .2, .55 * lift + .1);
      set('leftUpperArm', -.6, -.2, -.35); hipY = -.045 * lift; hemLift = .025 * lift; shortsDrop = .018 * lift;
    } else if (state === 'grab' || state === 'throw') {
      const hold = state === 'grab' ? ease(phase * 3) : 1;
      const toss = state === 'throw' ? ease((phase - .32) / .42) : 0;
      const crouch = state === 'throw' ? pulse(phase, 0, .28, .7) : .12;
      set('leftUpperArm', -1.10 * hold - toss * .9, -.18, -.12); set('rightUpperArm', -1.15 * hold - toss * .9, .18, .12);
      set('leftForeArm', -.22 - .6 * crouch); set('rightForeArm', -.22 - .6 * crouch);
      set('chest', .28 * crouch - .3 * toss, -.42 * toss); set('hips', 0, -.45 * toss);
      set('leftThigh', -.45 * crouch); set('rightThigh', -.48 * crouch); set('leftShin', .8 * crouch); set('rightShin', .8 * crouch);
      hipY = -.14 * crouch; hemLift = .02 * toss;
    } else if (state === 'envGrab' || state === 'envSlam') {
      const slam = state === 'envSlam' ? ease((phase - .15) / .5) : 0;
      const reach = state === 'envGrab' ? ease(phase * 3) : 1;
      set('leftUpperArm', -1.42 * reach + .55 * slam, -.18, -.12); set('rightUpperArm', -1.42 * reach + .55 * slam, .18, .12);
      set('leftForeArm', -.23 - .5 * slam); set('rightForeArm', -.23 - .5 * slam);
      set('chest', .08 + .55 * slam); set('head', .15 * slam);
      set('leftThigh', -.2 - .45 * slam); set('rightThigh', -.12 - .45 * slam); set('leftShin', .25 + .65 * slam); set('rightShin', .18 + .65 * slam);
      hipY = -.05 - .18 * slam; hipZ = -.06 * slam;
    } else if (state === 'envVictim') {
      // World controller owns the victim's bend/translation. The rig remains
      // compact and braced; unlike fall, it adds no hidden root displacement.
      set('leftUpperArm', -1.42, -.15, -.16); set('rightUpperArm', -1.42, .15, .16);
      set('leftForeArm', -.82); set('rightForeArm', -.82); set('head', .16);
      set('leftThigh', -.1); set('rightThigh', -.08); set('leftShin', .18); set('rightShin', .14);
    } else if (state === 'dodge') {
      const dip = Math.sin(phase * Math.PI); hipY = -.19 * dip; set('chest', .38 * dip, -.25 * dip);
      set('leftThigh', -.5 * dip); set('leftShin', .9 * dip); set('rightThigh', .4 * dip); set('rightShin', .4 * dip);
      set('leftUpperArm', .3, 0, -.4); set('rightUpperArm', -.9, .3, .3); set('rightForeArm', -1.2);
    } else if (state === 'crouch') {
      hipY = -.31; hipZ = -.075; set('hips', .08); set('chest', .28); set('head', -.22);
      set('leftThigh', -.9, 0, -.10); set('rightThigh', -.9, 0, .10); set('leftShin', 1.45); set('rightShin', 1.45);
      set('leftFoot', -.52); set('rightFoot', -.52); set('leftUpperArm', -.55, 0, -.2); set('rightUpperArm', -.55, 0, .2);
      set('leftForeArm', -.45); set('rightForeArm', -.45); shortsDrop = .024; hemLift = .012;
    } else if (state === 'hit') {
      const recoil = pulse(phase, 0, .2, 1); set('chest', -.24 * recoil, .19 * recoil); set('head', -.16 * recoil);
      set('leftUpperArm', -.6, -.1, -.35); set('rightUpperArm', -.4, .3, .42); hipY = -.04 * recoil;
    } else if (state === 'fall' || state === 'getup') {
      const fallen = state === 'fall' ? ease(phase * 1.4) : 1 - ease(phase);
      set('hips', -Math.PI * .48 * fallen); hipY = -.74 * fallen;
      set('chest', .18 * fallen); set('head', .2 * fallen); set('leftThigh', -.22 * fallen); set('rightThigh', -.4 * fallen);
      set('leftShin', .35 * fallen); set('rightShin', .55 * fallen); set('leftUpperArm', -.4 * fallen, 0, -.5 * fallen); set('rightUpperArm', -.5 * fallen, 0, .6 * fallen);
    } else if (state === 'victory') {
      set('leftUpperArm', -.6, -.2, -2.25); set('rightUpperArm', -.6, .2, 2.25); set('leftForeArm', -1.1); set('rightForeArm', -1.1);
      set('chest', -.08); set('head', -.1, Math.sin(time) * .12); hipY = .01 * Math.sin(time * 3);
    } else if (state === 'use') {
      const item = pose.item || 'shawarma', use = pulse(phase, 0, .4, 1);
      set('rightUpperArm', item === 'ozempic' ? -.35 * use : -.86 * use, -.3 * use, -.18 * use);
      set('rightForeArm', item === 'ozempic' ? -1.35 * use : -1.9 * use);
      set('rightHand', 0, .6 * use, 0); set('head', .13 * use); set('leftUpperArm', -.12, -.2, -.24);
      if (item === 'ozempic') { set('leftForeArm', -1.3 * use); hemLift = .05 * use; }
    } else if (state === 'jump') {
      const tuck = .25 + .45 * Math.sin(phase * Math.PI);
      set('leftThigh', -.7 * tuck); set('rightThigh', -.5 * tuck); set('leftShin', .9 * tuck); set('rightShin', .8 * tuck);
      set('leftUpperArm', -.8, 0, -.4); set('rightUpperArm', -.8, 0, .4); set('leftForeArm', -.6); set('rightForeArm', -.6);
      set('chest', .1); hemLift = .015;
    } else if (state === 'land') {
      const sink = 1 - ease(phase); hipY = -.16 * sink; set('chest', .28 * sink);
      set('leftThigh', -.6 * sink); set('rightThigh', -.6 * sink); set('leftShin', .9 * sink); set('rightShin', .9 * sink);
      set('leftUpperArm', -.5 * sink, 0, -.35); set('rightUpperArm', -.5 * sink, 0, .35);
    } else if (state === 'vault') {
      const over = Math.sin(phase * Math.PI); set('chest', .4 * over, -.15 * over);
      set('leftUpperArm', -1.65 + .65 * phase, -.1, -.12); set('rightUpperArm', -1.65 + .65 * phase, .1, .12);
      set('leftForeArm', -.15 - .6 * over); set('rightForeArm', -.15 - .6 * over);
      set('leftThigh', -1.35 * over, 0, -.22 * over); set('rightThigh', -.95 * over, 0, .15 * over);
      set('leftShin', 1.6 * over); set('rightShin', 1.35 * over); hemLift = .025 * over;
    } else if (state === 'hang' || state === 'shimmy' || state === 'climb') {
      const pull = state === 'climb' ? ease(phase) : 0, sway = state === 'shimmy' ? Math.sin(time * 7) : 0;
      set('leftUpperArm', -2.9 + 1.8 * pull, -.05, -.14 - sway * .07); set('rightUpperArm', -2.9 + 1.8 * pull, .05, .14 - sway * .07);
      set('leftForeArm', -.12 - .85 * Math.sin(pull * Math.PI)); set('rightForeArm', -.12 - .85 * Math.sin(pull * Math.PI));
      set('leftHand', -.22); set('rightHand', -.22); set('chest', .08 + pull * .36); set('head', -.17);
      set('leftThigh', -.15 - pull * .9, 0, -.03 + sway * .06); set('rightThigh', -.14 - pull * .5, 0, .03 + sway * .06);
      set('leftShin', .22 + pull * 1.1); set('rightShin', .22 + pull * .9); hemLift = .04;
    } else if (state === 'bossWindup') {
      const wind = ease(phase); set('chest', -.09, -.45 * wind); set('head', .04, .28 * wind);
      set('rightUpperArm', -.3 + .8 * wind, .4, .85 * wind); set('rightForeArm', -1.25);
      set('leftUpperArm', -.9, -.25, -.24); set('leftForeArm', -.7); hipY = -.065 * wind;
    }
    for (const side of ['left', 'right']) for (let f = 0; f < 4; f++) {
      const opened = ['carry', 'grab', 'throw', 'envGrab', 'envSlam', 'envVictim', 'hang', 'shimmy', 'climb', 'vault'].includes(state);
      set(`${side}Finger${f}`, opened ? -.4 : .35);
    }
    const alpha = pose.immediate ? 1 : 1 - Math.exp(-Math.min(Math.max(dt, 0), .1) * 24);
    for (const b of boneList) {
      const t = target[b.name]; b.rotation.x = mix(b.rotation.x, t.x, alpha); b.rotation.y = mix(b.rotation.y, t.y, alpha); b.rotation.z = mix(b.rotation.z, t.z, alpha);
    }
    hips.position.y = mix(hips.position.y, rest.hips.position.y + hipY, alpha); hips.position.z = mix(hips.position.z, hipZ, alpha);
    shirtHem.position.y = mix(shirtHem.position.y, hemLift, alpha); waistband.position.y = mix(waistband.position.y, -shortsDrop, alpha);
    const slim = isNathan ? clamp(pose.slim ?? 0, 0, 1) : 0;
    hips.scale.set(mix(hips.scale.x, 1 - slim * .17, alpha), 1, mix(hips.scale.z, 1 - slim * .26, alpha));
    head.scale.set(1 / hips.scale.x, 1, 1 / hips.scale.z);
    root.updateMatrixWorld(true);
    if (groundedStates.has(state)) {
      // Plant the lowest supporting shoe after posing. Gameplay still owns root
      // motion, while the skeleton prevents floating feet and floor penetration.
      inverseRoot.copy(root.matrixWorld).invert();
      let soleY = Infinity;
      for (const side of ['left', 'right']) for (const z of [-.08, .22]) {
        footPoint.set(0, -.095, z).applyMatrix4(bones[`${side}Foot`].matrixWorld).applyMatrix4(inverseRoot);
        soleY = Math.min(soleY, footPoint.y);
      }
      if (Number.isFinite(soleY)) hips.position.y -= clamp(soleY, -.35, .35);
      root.updateMatrixWorld(true);
    }
    skeleton.update();
  }
  update(0, { immediate: true });
  const metadata = {
    kind, variant, heightMetres: 1.95, designMassKg: hero ? 140 : 78,
    triangles: indices.length / 3, vertices: positions.length / 3, bones: boneList.length,
    materials: usedMaterials.length, geometryType: 'SkinnedMesh', source: 'src/characters.js',
    animations: [...ANIMATION_STATES], privatePhotoTextures: false,
    sockets: { leftPalm: { bone: 'leftHand', local: [0, -.06, .025] }, rightPalm: { bone: 'rightHand', local: [0, -.06, .025] }, headContact: { bone: 'head', local: [0, .16, .04] } },
    likeness: 'Stylised interpretation; rear views and missing body views are designed.',
    faceTexture: hero ? 'assets/face-atlas.png (original generated painting; no source photograph pixels)' : null,
  };
  root.userData.character = metadata;
  function placeHand(side, worldTarget, weight = 1) {
    const upper = bones[`${side}UpperArm`], fore = bones[`${side}ForeArm`], hand = bones[`${side}Hand`];
    if (!upper || !worldTarget || weight <= 0) return Infinity;
    const originalUpper = upper.quaternion.clone(), originalFore = fore.quaternion.clone();
    const end = new THREE.Vector3(), goal = new THREE.Vector3(), from = new THREE.Vector3(), toward = new THREE.Vector3();
    const inverse = new THREE.Matrix4(), rotation = new THREE.Quaternion();
    // CCD in each joint parent's coordinates also respects a slim/scaled rig.
    // Only existing joints rotate: neither the actor root nor limb lengths move.
    for (let iteration = 0; iteration < 16; iteration++) {
      root.updateMatrixWorld(true);
      hand.localToWorld(end.set(0, -.06, .025));
      if (end.distanceToSquared(worldTarget) < .000004) break;
      for (const joint of [fore, upper]) {
        root.updateMatrixWorld(true);
        inverse.copy(joint.parent.matrixWorld).invert();
        hand.localToWorld(end.set(0, -.06, .025));
        from.copy(end).applyMatrix4(inverse).sub(joint.position).normalize();
        toward.copy(worldTarget).applyMatrix4(inverse).sub(joint.position).normalize();
        if (from.lengthSq() < .5 || toward.lengthSq() < .5) continue;
        rotation.setFromUnitVectors(from, toward);
        joint.quaternion.premultiply(rotation);
      }
    }
    if (weight < 1) {
      upper.quaternion.copy(originalUpper.slerp(upper.quaternion.clone(), weight));
      fore.quaternion.copy(originalFore.slerp(fore.quaternion.clone(), weight));
    }
    root.updateMatrixWorld(true); skeleton.update();
    return hand.localToWorld(goal.set(0, -.06, .025)).distanceTo(worldTarget);
  }
  function dispose() { geometry.dispose(); for (const m of materials) m.dispose(); skeleton.dispose(); }
  return { root, bones, skeleton, mesh, update, placeHand, dispose, metadata };
}

/** Sample the editable procedural animation poses into standard Three.js clips. */
export function createAnimationClips(character, fps = 24) {
  const durations = { idle: 2.7, walk: 1, run: .65, carry: 1, punch: .55, kick: .8, grab: .6, throw: 1.1, envGrab: .65, envSlam: .9, envVictim: .9, dodge: .5, crouch: 1.5, hit: .4, fall: .8, getup: .9, victory: 2, use: 1.3, jump: 1, land: .3, vault: .85, hang: 2, shimmy: 1, climb: 1.2, bossWindup: .8, bossAttack: .8 };
  const clips = [];
  for (const state of ANIMATION_STATES) {
    const duration = durations[state], frameCount = Math.ceil(duration * fps), times = [];
    const values = Object.fromEntries(Object.keys(character.bones).map(n => [n, { q: [], p: [], s: [] }]));
    for (let i = 0; i <= frameCount; i++) {
      const t = i / frameCount * duration; times.push(t);
      character.update(0, { state, time: t, phase: i / frameCount, speed: 1, immediate: true });
      for (const [name, b] of Object.entries(character.bones)) {
        values[name].q.push(b.quaternion.x, b.quaternion.y, b.quaternion.z, b.quaternion.w);
        values[name].p.push(b.position.x, b.position.y, b.position.z); values[name].s.push(b.scale.x, b.scale.y, b.scale.z);
      }
    }
    const tracks = [];
    for (const [name, val] of Object.entries(values)) {
      tracks.push(new THREE.QuaternionKeyframeTrack(`${name}.quaternion`, times, val.q));
      if (['hips', 'shirtHem', 'waistband'].includes(name)) tracks.push(new THREE.VectorKeyframeTrack(`${name}.position`, times, val.p));
    }
    clips.push(new THREE.AnimationClip(state, duration, tracks));
  }
  character.update(0, { immediate: true }); return clips;
}
