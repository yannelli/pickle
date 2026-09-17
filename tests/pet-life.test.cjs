const { test } = require('node:test');
const assert = require('node:assert/strict');
const life = require('../pet-life.js');
const saves = require('../save-codec.js');
const NOW = 1800000000000;
function living(changes = {}) {
  return { ...life.fresh(NOW), phase: 'living', name: 'Sir Crunch', bornAt: NOW,
    brinedAt: NOW - life.HATCH_MS, hatchAt: NOW, ...changes };
}

test('one real minute of brining survives reload, then naming starts a safe baby life', () => {
  const pet = life.fresh(NOW);
  assert.equal(life.brine(pet, 'spicy', NOW, .99), true);
  assert.equal(pet.variety, 'pepper');
  const restored = life.restore(JSON.parse(JSON.stringify(pet)), NOW + 30000);
  life.advance(restored, NOW + 59999); assert.equal(restored.phase, 'brining');
  life.advance(restored, NOW + life.DAY * 5); assert.equal(restored.phase, 'naming');
  assert.equal(restored.fullness, 90, 'unclaimed hatchlings do not starve');
  assert.equal(life.name(restored, '  Sir   Crunch  ', NOW + life.DAY * 5), true);
  assert.equal(restored.name, 'Sir Crunch'); assert.equal(life.stage(restored, NOW + life.DAY * 5), 'baby');
  assert.equal(life.brine(restored, 'classic', NOW), false);
});

test('all six varieties are reachable, fixed at brining, and survive encrypted backups', async () => {
  const found = new Set();
  for (const brine of ['classic', 'garlic', 'spicy']) for (const random of [0, .99]) {
    const pet = life.fresh(NOW); life.brine(pet, brine, NOW, random); found.add(pet.variety);
    const restored = await saves.decode(await saves.encode(pet));
    assert.deepEqual(restored.pet, pet);
  }
  assert.equal(found.size, 6);
});

test('a healthy pickle is comfortable after a day and survives a weekend away', () => {
  const pet = living(); life.advance(pet, NOW + life.DAY);
  assert.deepEqual([pet.fullness, pet.happiness, pet.hygiene, pet.energy], [54, 61, 65, 100]);
  assert.equal(pet.dead, false); assert.equal(pet.sick, false);
  life.advance(pet, NOW + 2 * life.DAY);
  assert.equal(pet.dead, false); assert.equal(pet.sick, false);
  assert.equal(life.stage(pet, NOW + 2 * life.DAY), 'young');
});

test('elapsed time is independent of whether the app stayed open or was closed', () => {
  const open = living(), closed = living();
  for (let hour = 1; hour <= 90; hour++) life.advance(open, NOW + hour * life.HOUR);
  life.advance(closed, NOW + 90 * life.HOUR);
  for (const key of ['fullness', 'happiness', 'hygiene', 'energy', 'neglectMs']) assert.ok(Math.abs(open[key] - closed[key]) < 1e-6, key);
  assert.equal(open.dead, closed.dead);
});

test('neglect requires a continuous 48-hour empty-meter grace period, never minutes', () => {
  const pet = living({ fullness: 0 });
  life.advance(pet, NOW + 47 * life.HOUR); assert.equal(pet.dead, false);
  life.advance(pet, NOW + 48 * life.HOUR); assert.equal(pet.dead, true); assert.equal(pet.diedAt, NOW + 48 * life.HOUR);
  const rescued = living({ fullness: 0 }); life.advance(rescued, NOW + 30 * life.HOUR);
  for (const key of life.STATS) rescued[key] = 80;
  life.assess(rescued); assert.equal(rescued.neglectMs, 0); assert.equal(rescued.sick, false);
  life.advance(rescued, NOW + 54 * life.HOUR); assert.equal(rescued.dead, false);
});

test('daily care supports indefinite life, all 32 elders, and another elder lap', () => {
  const pet = living();
  for (let day = 1; day <= 1000; day++) {
    life.advance(pet, NOW + day * life.DAY);
    assert.equal(pet.dead, false, 'day ' + day);
    for (const key of life.STATS) pet[key] = 100;
    life.assess(pet);
  }
  assert.equal(life.ELDERS.length, 32);
  assert.equal(new Set(life.ELDERS.map(form => form.id)).size, 32);
  assert.equal(new Set(life.ELDERS.map(form => form.hat + ':' + form.prop)).size, 32);
  assert.equal(life.elder(pet, NOW + 1000 * life.DAY).unlocked, 32);
  assert.ok(life.elder(pet, NOW + 1000 * life.DAY).lap > 1);
});

test('partial care ends continuous neglect while sickness still needs full recovery', () => {
  const pet = living({ fullness: 0, happiness: 20, energy: 5, sick: true, neglectMs: 47 * life.HOUR });
  pet.fullness += 40;
  life.assess(pet);
  assert.equal(pet.neglectMs, 0);
  assert.equal(pet.sick, true);
  life.advance(pet, NOW + 21 * life.HOUR);
  assert.equal(pet.dead, false);
  assert.equal(pet.neglectMs, life.HOUR);
});

test('sickness recovery during elapsed time matches hourly updates awake and asleep', () => {
  for (const sleeping of [false, true]) {
    const open = living({ fullness: 80, happiness: 80, hygiene: 80, energy: 28, sick: true, sleeping });
    const closed = structuredClone(open);
    for (let hour = 1; hour <= 36; hour++) life.advance(open, NOW + hour * life.HOUR);
    life.advance(closed, NOW + 36 * life.HOUR);
    assert.equal(open.sick, false);
    assert.equal(closed.sick, false);
    life.advance(closed, NOW + 50 * life.HOUR);
    assert.equal(closed.sick, true);
  }
});

test('growth boundaries and elder forms use calendar time, including time away', () => {
  const pet = living();
  assert.equal(life.stage(pet, NOW + life.DAY - 1), 'baby');
  assert.equal(life.stage(pet, NOW + life.DAY), 'young');
  assert.equal(life.stage(pet, NOW + 3 * life.DAY), 'teen');
  assert.equal(life.stage(pet, NOW + 7 * life.DAY), 'adult');
  assert.equal(life.stage(pet, NOW + 14 * life.DAY), 'elder');
  for (let i = 0; i < 32; i++) assert.equal(life.elder(pet, NOW + (14 + i * 3) * life.DAY).id, life.ELDERS[i].id);
});

test('energy recovers while closed, naps auto-wake, and backward clocks cannot double-count', () => {
  const pet = living({ energy: 4, sleeping: true });
  life.advance(pet, NOW + 4 * life.HOUR); assert.equal(pet.energy, 100); assert.equal(pet.sleeping, false);
  const copy = structuredClone(pet);
  life.advance(pet, NOW + life.HOUR); assert.deepEqual(pet, copy);
  const awake = living({ energy: 4 }); life.advance(awake, NOW + 4 * life.HOUR); assert.equal(awake.energy, 12);
});

test('teens wear a different stereotype each day, seeded per pickle, and only between days 3 and 7', () => {
  const pet = living();
  assert.equal(life.TEENS.length, 8);
  assert.equal(new Set(life.TEENS.map(form => form.hat + ':' + form.prop)).size, 8);
  assert.equal(life.teen(pet, NOW + 2 * life.DAY), null);
  assert.equal(life.teen(pet, NOW + 7 * life.DAY), null);
  const days = [3, 4, 5, 6].map(day => life.teen(pet, NOW + day * life.DAY));
  assert.deepEqual(days.map(form => form.day), [0, 1, 2, 3]);
  assert.equal(new Set(days.map(form => form.id)).size, 4);
  assert.equal(life.teen(pet, NOW + 3 * life.DAY + life.DAY - 1).id, days[0].id);
  const other = living({ bornAt: NOW + 1000 });
  assert.notEqual(life.teen(other, NOW + 1000 + 3 * life.DAY).id, days[0].id);
});

test('old saves keep growth and stats without applying the old rapid decay on upgrade', () => {
  const old = { version: 1, fullness: 70, happiness: 40, energy: 50, hygiene: 60, ageTicks: 700, neglect: 20,
    sleeping: false, sick: true, dead: false, updatedAt: NOW - life.DAY };
  const pet = life.restore(old, NOW);
  assert.equal(pet.fullness, 70); assert.equal(life.stage(pet, NOW), 'elder');
  assert.equal(pet.neglectMs, 0); assert.equal(pet.updatedAt, NOW);
  assert.equal(pet.name, 'Little Dill');
});

test('names and v2 saves reject malformed values while preserving harmless Unicode', () => {
  const pet = { ...living(), phase: 'naming', name: '' };
  assert.equal(life.name(pet, ' '), false);
  assert.equal(life.name(pet, 'x'.repeat(25)), false);
  assert.equal(life.name(pet, 'hello\u200b'), false);
  assert.equal(life.name(pet, 'Díll 🥒', NOW), true);
  assert.equal(life.validate(pet).name, 'Díll 🥒');
  for (const changes of [{ name: 'x'.repeat(25) }, { phase: 'unknown' }, { variety: 'made up' }, { fullness: NaN }, { neglectMs: Infinity }, { bornAt: NOW + 1 }]) {
    assert.throws(() => life.validate({ ...pet, ...changes }));
  }
});

test('all elder accessories are visible SVGs and every form has distinct artwork', () => {
  const vm = require('node:vm'), fs = require('node:fs');
  const attrs = new Set(['hidden']);
  const art = { dataset: {}, style: {}, innerHTML: '', toggleAttribute: (name, on) => on ? attrs.add(name) : attrs.delete(name) };
  const sceneAttrs = new Set(['hidden']);
  const scene = { dataset: {}, style: {}, innerHTML: '', toggleAttribute: (name, on) => on ? sceneAttrs.add(name) : sceneAttrs.delete(name) };
  const room = { dataset: {}, style: { setProperty() {} } };
  const sandbox = { LittleDillLife: life, document: { getElementById: id => id === 'scene-art' ? scene : art } };
  vm.runInNewContext(fs.readFileSync(require.resolve('../pet-art.js'), 'utf8'), sandbox);
  const seen = new Set();
  for (let i = 0; i < 32; i++) {
    sandbox.LittleDillArt.render(living(), room, NOW + (14 + i * 3) * life.DAY);
    assert.equal(attrs.has('hidden'), false);
    assert.ok(!art.innerHTML.includes('undefined')); seen.add(art.innerHTML);
  }
  assert.equal(seen.size, 32);
  sandbox.LittleDillArt.render(living(), room, NOW);
  assert.equal(attrs.has('hidden'), true);
  const teens = new Set();
  for (let day = 0; day < 8; day++) {
    sandbox.LittleDillArt.render(living({ bornAt: NOW - day * life.DAY * 8 }), room, NOW + 3 * life.DAY + day * life.DAY);
  }
  for (let day = 3; day < 7; day++) {
    sandbox.LittleDillArt.render(living(), room, NOW + day * life.DAY);
    assert.equal(attrs.has('hidden'), false); assert.ok(!art.innerHTML.includes('undefined')); teens.add(art.innerHTML);
  }
  assert.equal(teens.size, 4);
  for (const vibe of ['shades', 'lounge', 'fire', 'book']) {
    sandbox.LittleDillArt.render(living(), room, NOW + 8 * life.DAY, vibe);
    assert.equal(attrs.has('hidden'), false); assert.ok(!art.innerHTML.includes('undefined')); teens.add(art.innerHTML + scene.innerHTML);
    assert.equal(sceneAttrs.has('hidden'), !['lounge', 'fire'].includes(vibe), vibe);
    assert.ok(!scene.innerHTML.includes('undefined'));
  }
  assert.equal(teens.size, 8);
  sandbox.LittleDillArt.render(living(), room, NOW, 'book');
  assert.ok(art.innerHTML.includes('translate(-7 -19)'), 'baby-worn items shift to the baby face');
  sandbox.LittleDillArt.render(living(), room, NOW + 8 * life.DAY, 'hop');
  assert.equal(attrs.has('hidden'), true); assert.equal(sceneAttrs.has('hidden'), true);
});
