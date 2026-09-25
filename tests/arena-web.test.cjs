const test = require('node:test');
const assert = require('node:assert/strict');
const modulePath = '../arena-web/arena-core.mjs';
test('web invites share normalized room codes across native and browser clients', async () => {
  const { roomCode, shareURL } = await import(modulePath);
  assert.equal(roomCode(' ab12cd '), 'AB12CD');
  for (const input of ['', 'ABC', 'ABC1234', 'AB-123', '<script>']) assert.equal(roomCode(input), null);
  assert.equal(shareURL('https://arena.littledill.app', 'abc123'), 'https://arena.littledill.app/?room=ABC123');
  assert.equal(shareURL('https://arena.littledill.app', null), 'https://arena.littledill.app/');
});
test('web socket handshake carries only valid appearance, name and optional room', async () => {
  const { socketURL } = await import(modulePath);
  const url = socketURL('https://arena.littledill.app', { name: '  Pickle\n Pal  ', brine: 'forged', outfit: 'shades' }, 'abc123');
  assert.equal(url.protocol, 'wss:'); assert.equal(url.pathname, '/arena');
  assert.equal(url.searchParams.get('name'), 'Pickle Pal'); assert.equal(url.searchParams.get('brine'), 'classic');
  assert.equal(url.searchParams.get('outfit'), 'shades'); assert.equal(url.searchParams.get('room'), 'ABC123');
  assert.equal(url.searchParams.get('foodDeltas'), '1');
  assert.equal(socketURL('http://localhost:8788', {}, null).protocol, 'ws:');
});
test('web food deltas remove then upsert IDs, preserve omitted updates, and reset on full snapshots', async () => {
  const { applyFoodUpdate } = await import(modulePath);
  const initial = [[1, 10, 20, 3], [2, 30, 40, 9], [3, 50, 60, 3]];
  const copy = structuredClone(initial);
  assert.equal(applyFoodUpdate(initial, { tick: 1 }), initial);
  assert.equal(applyFoodUpdate(initial, { foodAdded: [], foodRemoved: [] }), initial);
  const updated = applyFoodUpdate(initial, { foodRemoved: [1, 2, 999], foodAdded: [[2, 35, 45, 9], [4, 70, 80, 3], [4, 75, 85, 3]] });
  assert.deepEqual(updated, [[3, 50, 60, 3], [2, 35, 45, 9], [4, 75, 85, 3]]);
  assert.deepEqual(initial, copy, 'delta application must not mutate the preceding snapshot');
  assert.deepEqual(applyFoodUpdate(updated, { foodRemoved: [3, 4] }), [[2, 35, 45, 9]]);
  assert.deepEqual(applyFoodUpdate([[2, 35, 45, 9]], { foodAdded: [[2, 99, 100, 3]] }), [[2, 99, 100, 3]]);
  assert.deepEqual(applyFoodUpdate(updated, { food: [[8, 1, 2, 3]] }), [[8, 1, 2, 3]]);
  assert.deepEqual(applyFoodUpdate(updated, { food: [] }), []);
  assert.deepEqual(applyFoodUpdate(undefined, { foodAdded: [[9, 1, 2, 9]] }), [[9, 1, 2, 9]]);
});
test('web movement normalizes diagonals and rejects nonfinite direction', async () => {
  const { direction } = await import(modulePath);
  assert.deepEqual(direction(0, 0), { x: 0, y: 0 });
  assert.deepEqual(direction(NaN, 2), { x: 0, y: 0 });
  assert.deepEqual(direction(.2, -.3), { x: .2, y: -.3 });
  const diagonal = direction(1, 1); assert.ok(Math.abs(Math.hypot(diagonal.x, diagonal.y) - 1) < .00001);
});
test('web interpolation never drags a respawn through the map or invents score', async () => {
  const { interpolate } = await import(modulePath);
  const previous = { x: 20, y: 50, mass: 25, alive: true }, next = { x: 40, y: 100, mass: 31, alive: true, best: 31, kills: 2 };
  assert.deepEqual(interpolate(previous, next, .5), { ...next, x: 30, y: 75, mass: 28 });
  assert.deepEqual(interpolate(previous, next, 2), next);
  assert.deepEqual(interpolate({ ...previous, alive: false }, next, 0), next);
  assert.deepEqual(interpolate(previous, { ...next, x: 2000 }, .5), { ...next, x: 2000 });
});
test('web visible viewport follows Safari pinch zoom, pan and the on-screen keyboard', async () => {
  const { viewportBounds } = await import(modulePath);
  assert.deepEqual(viewportBounds(390, 844), { width: 390, height: 844, left: 0, top: 0 });
  assert.deepEqual(viewportBounds(390, 844, { width: 195, height: 360, offsetLeft: 92.5, offsetTop: 143 }), { width: 195, height: 360, left: 92.5, top: 143 });
  assert.deepEqual(viewportBounds(390, 844, { width: 390, height: 280, offsetLeft: 0, offsetTop: 40 }), { width: 390, height: 280, left: 0, top: 40 });
  assert.deepEqual(viewportBounds(320, 568, { width: NaN, height: 0, offsetLeft: -8, offsetTop: Infinity }), { width: 320, height: 568, left: 0, top: 0 });
});
test('web pickle size matches authoritative collision geometry above the former mass cap', async () => {
  const { radius } = await import(modulePath);
  const { radius: authoritativeRadius } = await import('../server/arena-engine.mjs');
  let previous = 0;
  for (const mass of [25, 1600, 10000, 1e6, 1e12]) {
    assert.equal(radius(mass), authoritativeRadius(mass));
    assert.ok(radius(mass) > previous && radius(mass) < 409);
    previous = radius(mass);
  }
  assert.equal(radius(1600), 149);
});
test('web camera fits uncapped dills on compact, zoomed and desktop viewports', async () => {
  const { cameraZoom, radius } = await import(modulePath);
  for (const [width, height] of [[320, 568], [195, 360], [844, 390], [1440, 900]]) {
    let previousZoom = Infinity;
    for (const mass of [25, 1600, 10000, 1e6, 1e12]) {
      const zoom = cameraZoom(width, height, mass);
      assert.ok(Number.isFinite(zoom) && zoom > 0);
      assert.ok(zoom <= previousZoom);
      assert.ok(radius(mass) * zoom < Math.min(width, height) / 8);
      previousZoom = zoom;
    }
  }
  assert.ok(cameraZoom(320, 568, 1e12) < .1, 'large dills must not hit the old .38 minimum zoom');
});
test('web HUD uses bounded mass labels without imposing a gameplay cap', async () => {
  const { massLabel } = await import(modulePath);
  for (const [mass, expected] of [[25, '25'], [1600, '1600'], [10000, '10K'], [12500, '12.5K'], [1e6, '1M'], [1e12, '1T'], [1e30, '1e30']]) assert.equal(massLabel(mass), expected);
  for (const mass of [99999, 999999, 999999999, 1e12, 1e15, 1e30]) assert.ok(massLabel(mass).length <= 6);
});
test('web flattens cells without losing ownership and falls back for legacy snapshots', async () => {
  const { playerCells, flattenCells } = await import(modulePath);
  const legacy = { id: 'old', alive: true, x: 10, y: 20, mass: 70, name: 'Dilly', brine: 'spicy', bot: false };
  assert.deepEqual(playerCells(legacy), [{ id: 'old', x: 10, y: 20, mass: 70 }]);
  assert.deepEqual(playerCells({ ...legacy, alive: false }), []);
  const split = { ...legacy, id: 'new', mass: 120, cells: [{ id: 'a', x: 40, y: 20, mass: 60 }, { id: 'b', x: 80, y: 20, mass: 60 }] };
  const cells = flattenCells([legacy, split, { ...legacy, id: 'dead', alive: false }]);
  assert.equal(cells.length, 3);
  assert.deepEqual(cells.map(cell => [cell.id, cell.ownerID, cell.mass, cell.totalMass]), [['old', 'old', 70, 70], ['a', 'new', 60, 120], ['b', 'new', 60, 120]]);
  assert.equal(cells[2].name, 'Dilly'); assert.equal(cells[2].brine, 'spicy'); assert.equal(cells[2].bot, false);
});
test('web cell interpolation matches IDs across reordered, new and removed pieces', async () => {
  const { interpolate } = await import(modulePath);
  const before = { id: 'p', x: 50, y: 20, mass: 120, alive: true, cells: [{ id: 'a', x: 10, y: 20, mass: 90 }, { id: 'b', x: 80, y: 20, mass: 30 }] };
  const after = { ...before, x: 90, mass: 150, best: 150, cells: [{ id: 'b', x: 100, y: 40, mass: 30 }, { id: 'a', x: 30, y: 20, mass: 90 }, { id: 'c', x: 200, y: 20, mass: 30 }] };
  const halfway = interpolate(before, after, .5);
  assert.deepEqual(halfway.cells, [{ id: 'b', x: 90, y: 30, mass: 30 }, { id: 'a', x: 20, y: 20, mass: 90 }, { id: 'c', x: 200, y: 20, mass: 30 }]);
  assert.equal(halfway.best, 150);
  const survivor = { ...after, cells: [after.cells[0]], mass: 30 };
  assert.deepEqual(interpolate(after, survivor, .5).cells.map(cell => cell.id), ['b']);
  assert.deepEqual(interpolate({ ...before, alive: false }, after, .1), after);
});
test('web split eligibility uses each piece, capacity and authoritative cooldown', async () => {
  const { splitState } = await import(modulePath);
  const base = { id: 'p', alive: true, mass: 120, x: 10, y: 10, splitCooldown: 0, merge: 0 };
  const cell = (id, mass) => ({ id, mass, x: 10, y: 10 });
  assert.equal(splitState({ ...base, cells: [cell('a', 59.9)] }).enabled, false);
  assert.equal(splitState({ ...base, cells: [cell('a', 60)] }).enabled, true);
  assert.equal(splitState({ ...base, cells: [cell('a', 50), cell('b', 50)] }).enabled, false, 'total mass alone must not unlock splitting');
  assert.equal(splitState({ ...base, cells: [cell('a', 60)], splitCooldown: .1 }).enabled, false);
  assert.equal(splitState({ ...base, cells: ['a', 'b', 'c', 'd'].map(id => cell(id, 80)) }).enabled, false);
  assert.equal(splitState(base).enabled, false, 'legacy servers do not understand the new split intent');
  assert.equal(splitState({ ...base, alive: false, cells: [cell('a', 120)] }).count, 0);
  assert.deepEqual(splitState({ ...base, cells: [cell('a', 70), cell('b', 50)], merge: 11.8 }), { count: 2, enabled: true, reason: 'Launch a little dill', merge: 11.8 });
});
test('web camera contains every launched piece inside the unobscured viewport', async () => {
  const { cameraFrame, radius } = await import(modulePath);
  const player = { id: 'p', alive: true, mass: 480, x: 700, y: 600, cells: [{ id: 'a', x: 100, y: 100, mass: 120 }, { id: 'b', x: 1500, y: 100, mass: 120 }, { id: 'c', x: 100, y: 1100, mass: 120 }, { id: 'd', x: 1500, y: 1100, mass: 120 }] };
  for (const [width, height, insets] of [[320, 568, { top: 170, bottom: 150, left: 12, right: 12 }], [195, 360, { top: 130, bottom: 100, left: 10, right: 10 }], [1440, 900, { top: 180, bottom: 160, left: 24, right: 24 }]]) {
    const frame = cameraFrame(width, height, player, insets);
    assert.ok(frame.zoom > 0);
    for (const cell of player.cells) {
      const x = (cell.x - frame.x) * frame.zoom + frame.screenX, y = (cell.y - frame.y) * frame.zoom + frame.screenY;
      const r = radius(cell.mass) * frame.zoom;
      assert.ok(x - r * 1.7 >= insets.left && x + r * 1.7 <= width - insets.right);
      assert.ok(y - r * 1.9 >= insets.top && y + r * 1.9 <= height - insets.bottom);
    }
    const together = { ...player, cells: player.cells.map(cell => ({ ...cell, x: 700, y: 600 })) };
    assert.ok(cameraFrame(width, height, together, insets).zoom > frame.zoom);
  }
});
