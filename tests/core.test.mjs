import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { Game, dist } from '../src/core.js';
import { createWorld } from '../src/world.js';

const DT = 1 / 60;
const input = (x = 0, y = 0) => ({ x, y });
const controllable = p => ['idle', 'walk', 'run', 'crouch'].includes(p.state);
function advance(game, seconds, movement = input(), observe = null) {
  for (let i = 0; i < Math.ceil(seconds / DT); i++) { game.tick(DT, movement); observe?.(game); }
}
function until(game, condition, seconds = 5, movement = input()) {
  for (let i = 0; i < Math.ceil(seconds / DT); i++) { if (condition()) return; game.tick(DT, movement); }
  assert.ok(condition(), `Condition not reached; player=${JSON.stringify(game.snapshot().player)}`);
}
function arena(enemies = [{ kind: 'grunt', x: 0, z: -1.2 }]) {
  const world = { spawn: { x: 0, z: 0 }, enemies, props: [], colliders: [], stations: [],
    route: [{ id: 'jump', type: 'jump', x: 0, z: 0 }], exit: { x: 100, z: 100, radius: 1 } };
  const game = new Game(world);
  for (const enemy of game.enemies) enemy.cooldown = 1000;
  return game;
}
function isolatedWorld(index) {
  const world = createWorld(new THREE.Scene(), index);
  world.enemies = []; // Isolated traversal fixture; campaign below retains every real enemy.
  return { world, game: new Game(world, index) };
}
function place(game, x, z, y = 0) {
  Object.assign(game.player, { x, y, z, vy: 0, vx: 0, vz: 0, state: 'idle', time: 0, duration: 0, parkour: null });
}

test('a landed swing damages once; a miss has no contact event', () => {
  const game = arena(), target = game.enemies[0];
  assert.equal(game.command('punch'), true);
  advance(game, 1.2);
  assert.equal(target.health, 48);
  assert.equal(game.events.filter(e => e.type === 'hit').length, 1);
  const miss = arena([{ kind: 'grunt', x: 0, z: -4 }]);
  miss.change(miss.enemies[0], 'recover', 100);
  miss.command('kick'); advance(miss, 1);
  assert.equal(miss.enemies[0].health, 65);
  assert.equal(miss.events.filter(e => e.type === 'hit').length, 0);
});

test('attack cannot hit or grab through a solid wall', () => {
  const game = arena();
  game.world.colliders.push({ x: 0, z: -.6, w: 3, d: .2, y: 0, h: 3, solid: true });
  game.command('kick'); advance(game, 1);
  assert.equal(game.enemies[0].health, 65);
  assert.equal(game.command('throw'), false);
});

test('buffered punch to kick starts at recovery cancellation and has separate contacts', () => {
  const game = arena();
  game.command('punch'); until(game, () => game.player.time > .23);
  assert.equal(game.command('kick'), true);
  until(game, () => game.player.state === 'kick');
  advance(game, .55);
  assert.deepEqual(game.events.filter(e => e.type === 'hit').map(e => e.kind), ['punch', 'kick']);
  assert.equal(game.enemies[0].health, 21);
});

test('pause freezes active buffs, actor states, and world clock', () => {
  const game = arena([]);
  game.command('use:v30'); advance(game, .85);
  game.command('use:weed'); advance(game, .85);
  game.command('use:ozempic'); advance(game, .85);
  game.setMode('paused');
  const before = JSON.stringify(game.snapshot()), time = game.clock;
  advance(game, 30, input(1, 1));
  assert.equal(JSON.stringify(game.snapshot()), before);
  assert.equal(game.clock, time);
  assert.equal(game.command('kick'), false);
  game.setMode('playing'); advance(game, .5);
  assert.ok(game.buffs.weed < JSON.parse(before).buffs.weed);
});

test('stronger power replaces weaker, cannot be downgraded, and expires', () => {
  const game = arena([]);
  game.command('use:v20'); advance(game, .85); assert.equal(game.buffs.power, 20);
  game.command('use:v30'); advance(game, .85); assert.equal(game.buffs.power, 30);
  const weakerCount = game.inventory.v20;
  assert.equal(game.command('use:v20'), false);
  assert.equal(game.inventory.v20, weakerCount);
  advance(game, 121);
  assert.equal(game.buffs.power, 0); assert.equal(game.buffs.powerTime, 0);
});

test('shawarma restores at most 45 and never consumes at full health', () => {
  const game = arena([]), original = game.inventory.shawarma;
  assert.equal(game.command('use:shawarma'), false); assert.equal(game.inventory.shawarma, original);
  game.player.health = 90; game.command('use:shawarma'); assert.equal(game.player.health, 135);
  advance(game, .85); game.command('use:shawarma'); assert.equal(game.player.health, 160);
});

test('analog displacement is linear and diagonal displacement is normalized', () => {
  const full = arena([]), half = arena([]), diagonal = arena([]);
  advance(full, 1, input(0, 1)); advance(half, 1, input(0, .5)); advance(diagonal, 1, input(1, 1));
  assert.ok(Math.abs(dist(full.player, { x: 0, z: 0 }) - 4.5) < .01);
  assert.ok(Math.abs(dist(half.player, { x: 0, z: 0 }) - 2.25) < .01);
  assert.ok(Math.abs(dist(diagonal.player, { x: 0, z: 0 }) - 4.5) < .01);
});

test('Ozempic speed is temporary and weed slows enemy locomotion', () => {
  const game = arena([]); game.command('use:ozempic'); advance(game, .85);
  const start = game.player.z; advance(game, 1, input(0, 1));
  assert.ok(Math.abs(start - game.player.z - 4.5 * 1.7) < .01);
  advance(game, 121); assert.equal(game.buffs.slim, 0);
  const normal = arena([{ kind: 'grunt', x: 0, z: -8 }]), slow = arena([{ kind: 'grunt', x: 0, z: -8 }]);
  slow.command('use:weed'); advance(normal, 1); advance(slow, 1);
  assert.ok(Math.abs((slow.enemies[0].z + 8) / (normal.enemies[0].z + 8) - .42) < .01);
});

test('paired throw aligns continuously, releases, and hits another enemy once', () => {
  const game = arena([{ kind: 'grunt', x: 0, z: -1 }, { kind: 'grunt', x: 0, z: -4.6 }]);
  const [target, other] = game.enemies; game.change(other, 'recover', 100);
  assert.equal(game.command('throw'), true);
  let previous = { x: target.x, z: target.z }, maximumStep = 0, maximumHeight = 0;
  advance(game, 2.6, input(), () => {
    maximumStep = Math.max(maximumStep, dist(previous, target)); maximumHeight = Math.max(maximumHeight, target.y);
    previous = { x: target.x, z: target.z };
  });
  assert.ok(maximumStep < .2, `Unexpected teleport: ${maximumStep}`);
  assert.ok(maximumHeight > 1);
  assert.equal(target.health, 27);
  assert.equal(other.health, 33);
  assert.equal(game.events.filter(e => e.type === 'hit' && e.amount === 32).length, 1);
  assert.equal(game.pair, null); assert.notEqual(target.state, 'held'); assert.equal(target.y, 0);
});

test('incoming hit cancels a paired move and releases both actors without hovering', () => {
  const game = arena(); game.command('throw'); advance(game, .4);
  assert.ok(game.pair); assert.ok(game.enemies[0].y > 0);
  game.hitPlayer(10, { x: 1, z: 0, attackType: 'punch' }); advance(game, 2);
  assert.equal(game.pair, null); assert.notEqual(game.enemies[0].state, 'held'); assert.equal(game.enemies[0].y, 0);
  assert.ok(controllable(game.player)); assert.equal(game.player.health, 150);
});

for (let level = 0; level < 3; level++) {
  test(`level ${level}: environmental finisher collapses station and releases the target`, () => {
    const world = createWorld(new THREE.Scene(), level), s = world.stations[0];
    world.spawn = { x: s.approach.x - .45, z: s.approach.z + .35 };
    world.enemies = [{ kind: 'brute', x: s.approach.x + .28, z: s.approach.z + .2 }];
    const game = new Game(world, level); game.enemies[0].cooldown = 100;
    assert.equal(game.command('interact'), true); assert.equal(game.player.state, 'envSlam');
    let previous = { x: game.player.x, z: game.player.z }, maximumStep = 0;
    advance(game, 2.5, input(), () => {
      maximumStep = Math.max(maximumStep, dist(previous, game.player));
      previous = { x: game.player.x, z: game.player.z };
      if (game.pair) {
        const victim = game.pair.target;
        assert.equal(game.blocked(game.player.x, game.player.z, game.player.y, game.player.radius), false, 'Pair alignment enters counter');
        assert.equal(game.blocked(victim.x, victim.z, victim.y, victim.radius), false, 'Victim alignment enters counter');
        assert.ok(dist(game.player, victim) >= game.player.radius + victim.radius - .02, 'Pair roots overlap');
      }
    });
    assert.ok(maximumStep < .25, `Pair alignment teleports by ${maximumStep}m`);
    assert.equal(s.broken, true); assert.equal(world.colliders.find(c => c.id === s.colliderId).solid, false);
    assert.equal(game.events.filter(e => e.type === 'environment').length, 1);
    assert.equal(game.pair, null); assert.notEqual(game.enemies[0].state, 'held'); assert.equal(game.enemies[0].y, 0);
    s.break(); world.dispose();
  });
}

// These helpers are an automated player: they only issue the same movement and
// action commands as the UI. The campaign test does not set health, enemy states,
// position, milestones, inventories, or completion flags.
function planPath(game, goal, stopRadius = .2) {
  const step = .5, bounds = game.world.bounds;
  const gx = x => Math.round((x - bounds.minX) / step), gz = z => Math.round((z - bounds.minZ) / step);
  const wx = x => bounds.minX + x * step, wz = z => bounds.minZ + z * step;
  const start = [gx(game.player.x), gz(game.player.z)], key = (x, z) => `${x},${z}`;
  const queue = [start], previous = new Map([[key(...start), null]]);
  let reached = null, head = 0, best = start, bestDistance = Infinity;
  while (head < queue.length) {
    const cell = queue[head++], [cx, cz] = cell, distance = Math.hypot(wx(cx) - goal.x, wz(cz) - goal.z);
    if (distance < bestDistance) { bestDistance = distance; best = cell; }
    if (distance < Math.max(stopRadius, .38)) { reached = cell; break; }
    for (const [dx, dz] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = cx + dx, nz = cz + dz, id = key(nx, nz), x = wx(nx), z = wz(nz);
      if (previous.has(id) || x < bounds.minX + .5 || x > bounds.maxX - .5 || z < bounds.minZ + .5 || z > bounds.maxZ - .5) continue;
      if (game.blocked(x, z, game.player.y, game.player.radius + .06)) continue;
      previous.set(id, cell); queue.push([nx, nz]);
    }
  }
  let cell = reached || best;
  const path = [];
  while (cell) { path.push({ x: wx(cell[0]), z: wz(cell[1]) }); cell = previous.get(key(...cell)); }
  path.reverse(); path.shift();
  if (reached && !game.blocked(goal.x, goal.z, game.player.y, game.player.radius)) path.push(goal);
  return path;
}
function movementTo(game, point) {
  const dx = point.x - game.player.x, dz = point.z - game.player.z, length = Math.hypot(dx, dz);
  return length > .02 ? input(dx / length, -dz / length) : input();
}
function goTo(game, goal, limit = 30) {
  let path = [], repath = 0;
  for (let frame = 0; frame < limit / DT; frame++) {
    if (dist(game.player, goal) < .17 || ['levelcomplete', 'victory'].includes(game.mode)) return;
    if (frame >= repath || !path.length) { path = planPath(game, goal); repath = frame + 20; }
    while (path.length && dist(game.player, path[0]) < .16) path.shift();
    game.tick(DT, movementTo(game, path[0] || goal));
    assert.notEqual(game.mode, 'defeat', 'Player died during navigation');
  }
  assert.fail(`Navigation stalled at ${game.player.x},${game.player.y},${game.player.z} toward ${goal.x},${goal.z}`);
}
function fightAll(game) {
  let path = [], repath = 0, targetId = null;
  for (let frame = 0; frame < 240 / DT; frame++) {
    const enemy = game.enemies.filter(e => !e.dead).sort((a, b) => dist(a, game.player) - dist(b, game.player))[0];
    if (!enemy) return;
    assert.notEqual(game.mode, 'defeat', `Combat defeat in chapter ${game.level}: ${JSON.stringify(game.snapshot())}`);
    const distance = dist(enemy, game.player);
    if (controllable(game.player) && game.player.health < 92 && game.inventory.shawarma > 0) game.command('use:shawarma');
    else if (distance < 2.05 && game.lineClear(game.player, enemy)) {
      game.command(game.rage >= 100 ? 'rage' : 'kick');
    }
    let movement = input();
    if (distance > 1.7 || !game.lineClear(game.player, enemy)) {
      if (targetId !== enemy.id || frame >= repath || !path.length) { path = planPath(game, enemy, 1.4); targetId = enemy.id; repath = frame + 18; }
      while (path.length && dist(game.player, path[0]) < .18) path.shift();
      movement = movementTo(game, path[0] || enemy);
    }
    game.tick(DT, movement);
  }
  assert.fail(`Combat stalled in chapter ${game.level}: ${JSON.stringify(game.snapshot())}`);
}

test('all three real chapters complete through movement and combat commands, including Oz', () => {
  let carry = null;
  const results = [];
  for (let level = 0; level < 3; level++) {
    const world = createWorld(new THREE.Scene(), level), game = new Game(world, level, carry);
    if (level === 0) { assert.equal(game.command('use:v30'), true); advance(game, .85); }
    if (level === 2) { assert.equal(game.command('use:weed'), true); advance(game, .85); }
    fightAll(game);
    for (const route of world.route) {
      goTo(game, route);
      until(game, () => controllable(game.player), 3);
      assert.equal(game.command('parkour'), true, `Failed ${route.type} in chapter ${level}`);
      if (route.type === 'hang') {
        until(game, () => game.player.state === 'hang', 2);
        advance(game, .3, input(1, 0));
        assert.equal(game.command('parkour'), true);
      }
      until(game, () => controllable(game.player), 3);
      assert.ok(game.routeDone.has(route.id), `Missing ${route.id}`);
    }
    goTo(game, world.exit);
    assert.equal(game.mode, level === 2 ? 'victory' : 'levelcomplete');
    assert.equal(game.enemies.filter(e => !e.dead).length, 0);
    assert.equal(game.routeDone.size, 4);
    if (level === 2) assert.equal(game.enemies.find(e => e.kind === 'oz').health, 0);
    results.push({ level, seconds: Math.round(game.clock * 10) / 10, health: game.player.health, kills: game.kills });
    carry = { health: game.player.health, inventory: game.inventory, buffs: game.buffs, kills: game.kills };
    world.dispose();
  }
  console.log('Command-driven campaign:', JSON.stringify(results));
});

test('Oz grab uses continuous alignment, a real throw arc and recovery', () => {
  const game = arena([{ kind: 'oz', x: 0, z: -1.3 }]), boss = game.enemies[0];
  boss.angle = 0; boss.attackType = 'grab'; game.change(boss, 'bossAttack', .62); boss.time = .17;
  let previous = { x: 0, z: 0 }, maxStep = 0, peak = 0, sawHeld = false, sawFall = false;
  advance(game, 3, input(), () => {
    maxStep = Math.max(maxStep, dist(previous, game.player)); peak = Math.max(peak, game.player.y);
    sawHeld ||= game.player.state === 'held'; sawFall ||= game.player.state === 'fall';
    previous = { x: game.player.x, z: game.player.z };
  });
  assert.ok(sawHeld && sawFall); assert.ok(peak > .8); assert.ok(maxStep < .2, `Boss teleported player ${maxStep}m`);
  assert.equal(game.player.health, 137); assert.equal(game.player.y, 0); assert.ok(controllable(game.player));
  assert.equal(game.bossPair, null);
});

test('Oz telegraph resists light hit interruption, but recovery permits a throw', () => {
  const game = arena([{ kind: 'oz', x: 0, z: -1.2 }]), boss = game.enemies[0];
  game.change(boss, 'bossWindup', .86); boss.attackType = 'punch';
  game.damage(boss, 17, game.player, 'punch'); assert.equal(boss.state, 'bossWindup');
  assert.equal(game.command('throw'), false);
  game.change(boss, 'recover', 1); boss.invuln = 0;
  assert.equal(game.command('throw'), true);
});

test('collision subdivides large moves and cannot tunnel through a wall', () => {
  const game = arena([]);
  game.world.colliders.push({ id: 'wall', x: 0, z: -2, w: 5, d: .5, h: 3, y: 0, solid: true });
  game.move(game.player, 0, -100);
  assert.ok(game.player.z >= -1.37 - .001);
  assert.equal(game.blocked(game.player.x, game.player.z, game.player.y, game.player.radius), false);
});

test('walking off a raised platform cannot trap the collision body in its edge', () => {
  const { world, game } = isolatedWorld(0);
  const platform = world.route.find(r => r.type === 'climb').target;
  place(game, platform.x, platform.z, platform.h);
  advance(game, 1.4, input(-1, 0));
  assert.ok(game.player.x < platform.x - platform.w / 2 - game.player.radius);
  assert.equal(game.player.y, 0); assert.ok(controllable(game.player));
  assert.equal(game.blocked(game.player.x, game.player.z, game.player.y, game.player.radius), false);
  world.dispose();
});

test('repeated enemy contact cannot create an uninterrupted damage chain', () => {
  const game = arena([]), source = { x: 1, z: 0, attackType: 'charge' };
  assert.equal(game.hitPlayer(18, source), true);
  for (let n = 0; n < 20; n++) assert.equal(game.hitPlayer(18, source), false);
  advance(game, .9); assert.ok(controllable(game.player));
  assert.equal(game.hitPlayer(18, source), true); assert.equal(game.player.health, 124);
});

test('an ordinary enemy navigates around a solid obstacle rather than entering it', () => {
  const game = arena([{ kind: 'grunt', x: 0, z: -6 }]);
  game.world.colliders.push({ id: 'block', x: 0, z: -3, w: 3, d: 1, h: 2, y: 0, solid: true });
  advance(game, 6, input(), () => assert.equal(game.blocked(game.enemies[0].x, game.enemies[0].z, 0, game.enemies[0].radius), false));
  assert.ok(dist(game.enemies[0], game.player) < 1.5);
});

test('carried props must be thrown before climbing, then hit and break correctly', () => {
  const game = arena([{ kind: 'grunt', x: 0, z: -3.1 }]);
  game.change(game.enemies[0], 'recover', 100);
  const prop = { id: 'stool', x: .65, z: -.2, y: 0, w: .6, d: .6, h: .6, hp: 18, state: 'intact', solid: true };
  game.world.props.push(prop); game.world.colliders.push(prop);
  assert.equal(game.command('interact'), true); advance(game, .55);
  assert.equal(game.command('parkour'), false); assert.equal(game.held, prop);
  game.player.angle = Math.PI; assert.equal(game.command('throw'), true); advance(game, 2);
  assert.equal(game.enemies[0].health, 17); assert.equal(prop.state, 'broken'); assert.equal(prop.solid, false);
  assert.equal(game.projectiles.length, 0); assert.equal(game.held, null);
});

test('held item context takes priority over a nearby environmental finisher', () => {
  const game = arena();
  game.world.stations.push({ id: 'fryer', x: 0, z: -1, radius: 2.7, broken: false });
  game.held = { id: 'stool', x: 0, z: 0, state: 'held', solid: false, hp: 18 };
  assert.equal(game.context().interact, 'throwItem');
  assert.equal(game.command('interact'), true);
  assert.equal(game.held, null); assert.equal(game.projectiles.length, 1); assert.equal(game.pair, null);
});

for (let level = 0; level < 3; level++) {
  test(`level ${level}: jump, vault, climb, hang, shimmy, drop and pull-up return control`, () => {
    const { world, game } = isolatedWorld(level), p = game.player;
    const marker = type => world.route.find(r => r.type === type);
    let r = marker('jump'); place(game, r.x, r.z); game.command('parkour');
    let jumpPeak = 0; advance(game, 1.2, input(0, .5), () => { jumpPeak = Math.max(jumpPeak, p.y); });
    assert.ok(jumpPeak > 1); assert.ok(game.routeDone.has(r.id)); assert.ok(controllable(p));
    for (const type of ['vault', 'climb']) {
      r = marker(type); place(game, r.x, r.z); assert.equal(game.command('parkour'), true);
      let last = { x: p.x, y: p.y, z: p.z }, maxStep = 0;
      advance(game, 1.45, input(), () => {
        maxStep = Math.max(maxStep, Math.hypot(p.x - last.x, p.y - last.y, p.z - last.z)); last = { x: p.x, y: p.y, z: p.z };
        assert.equal(game.blocked(p.x, p.z, p.y, p.radius), false, `${type} body penetrates obstacle at ${JSON.stringify(last)}`);
      });
      assert.ok(maxStep < .2); assert.ok(game.routeDone.has(r.id)); assert.ok(controllable(p));
      assert.equal(p.y, type === 'climb' ? r.target.h : 0);
    }
    r = marker('hang'); place(game, r.x, r.z); game.command('parkour'); advance(game, .7);
    assert.equal(p.state, 'hang'); const startX = p.x;
    advance(game, .5, input(1, 0)); assert.equal(p.state, 'shimmy'); assert.ok(p.x > startX + .4);
    assert.equal(game.command('kick'), false); assert.equal(game.command('interact'), true); advance(game, 1);
    assert.equal(p.y, 0); assert.ok(controllable(p)); assert.equal(game.routeDone.has(r.id), false);
    assert.equal(game.command('parkour'), true); advance(game, .7); assert.equal(p.state, 'hang');
    assert.equal(game.command('parkour'), true); advance(game, 1.4);
    assert.ok(controllable(p)); assert.equal(p.y, r.target.h); assert.ok(game.routeDone.has(r.id));
    assert.equal(game.routeDone.size, 4); world.dispose();
  });
}
