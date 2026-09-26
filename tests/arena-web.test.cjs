const test = require('node:test');
const assert = require('node:assert/strict');
const modulePath = '../arena-web/arena-core.mjs';
const resumeToken = '12345678-1234-4321-9876-123456789abc';

// Executes the real browser controller against deterministic DOM/socket/timers.
// This exercises reconnect event ordering without a server or browser dependency.
async function browserHarness({ saved = null, storageUnavailable = false, sharedStorage = null } = {}) {
  const vm = require('node:vm'), fs = require('node:fs');
  const core = await import(modulePath), clock = { now: 100000 }, timers = new Map(), sockets = [], stored = sharedStorage || new Map();
  if (saved) stored.set('little-dill.arena.resume.v1', JSON.stringify(saved));
  let timerID = 0, document;
  class Node {
    constructor(id) { this.id = id; this.listeners = new Map(); this.style = { setProperty() {} }; this.dataset = {}; this.value = ''; this.hidden = false; this.classList = { toggle() {} }; }
    addEventListener(type, fn) { const all = this.listeners.get(type) || []; all.push(fn); this.listeners.set(type, all); }
    fire(type, value = {}) { for (const fn of this.listeners.get(type) || []) fn({ target: this, preventDefault() {}, ...value }); }
    setAttribute(name, value) { this[name] = value; }
    focus() { document.activeElement = this; }
    blur() { document.activeElement = null; }
    append() {} replaceChildren() {}
    getContext() {
      this.calls ||= [];
      return this.context ||= new Proxy({ measureText: () => ({ width: 10 }) }, { get: (target, key) => key in target ? target[key] : (...args) => this.calls.push([key, ...args, ...(key === 'stroke' ? [target.strokeStyle] : [])]), set: (target, key, value) => { target[key] = value; return true; } });
    }
    getBoundingClientRect() { return this.id === '.game-top' ? { top: 0, bottom: 160 } : this.id === '.game-controls' ? { top: 440, bottom: 568 } : { top: 0, left: 0, right: 320, bottom: 568, width: 320, height: 568 }; }
  }
  const nodes = new Map(), node = id => { if (!nodes.has(id)) nodes.set(id, new Node(id)); return nodes.get(id); };
  document = new Node('document'); document.hidden = false; document.body = new Node('body'); document.activeElement = null;
  document.getElementById = node; document.querySelectorAll = () => []; document.querySelector = node; document.createElement = () => new Node('element');
  const window = new Node('window');
  class FakeSocket {
    static OPEN = 1;
    constructor(url) { this.url = new URL(url); this.readyState = 0; this.sent = []; sockets.push(this); }
    open() { this.readyState = 1; this.onopen?.(); }
    send(value) { if (this.readyState !== 1) throw Error('Not open'); this.sent.push(JSON.parse(value)); }
    message(packet) { this.onmessage?.({ data: JSON.stringify(packet) }); }
    close(code = 1000) { this.readyState = 3; this.onclose?.({ code }); }
  }
  const timer = (fn, delay = 0, interval = 0) => { const id = ++timerID; timers.set(id, { fn, at: clock.now + delay, interval }); return id; };
  const context = vm.createContext({ ...core, window, document, navigator: { onLine: true }, URL, WebSocket: FakeSocket,
    location: { origin: 'https://arena.littledill.app', href: 'https://arena.littledill.app/' },
    history: { replaceState(_a, _b, url) { assert.ok(!url.includes(resumeToken)); } },
    localStorage: { getItem(key) { if (storageUnavailable) throw Error('Storage unavailable'); return stored.get(key) || null; }, setItem(key, value) { if (storageUnavailable) throw Error('Storage unavailable'); stored.set(key, value); }, removeItem(key) { if (storageUnavailable) throw Error('Storage unavailable'); stored.delete(key); } },
    Date: class extends Date { static now() { return clock.now; } }, performance: { now: () => clock.now },
    innerWidth: 320, innerHeight: 568, devicePixelRatio: 1, matchMedia: () => ({ matches: false }), ResizeObserver: class { observe() {} }, requestAnimationFrame() {},
    setTimeout: (fn, delay) => timer(fn, delay), clearTimeout: id => timers.delete(id), setInterval: (fn, delay) => timer(fn, delay, delay), clearInterval: id => timers.delete(id),
    readResumeRecord: (value, now = clock.now) => core.readResumeRecord(value, now), refreshResumeRecord: (value, now = clock.now) => core.refreshResumeRecord(value, now), resumeFromWelcome: (value, now = clock.now) => core.resumeFromWelcome(value, now), resumeRetryDelay: (attempt, deadline, now = clock.now) => core.resumeRetryDelay(attempt, deadline, now)
  });
  const source = fs.readFileSync(require.resolve('../arena-web/arena.js'), 'utf8').replace(/^import .*;\n/, '');
  vm.runInContext(source, context);
  function advance(ms) {
    const end = clock.now + ms;
    for (let steps = 0; steps < 10000; steps++) {
      const next = [...timers].filter(([, t]) => t.at <= end).sort((a, b) => a[1].at - b[1].at)[0];
      if (!next) break;
      const [id, task] = next; clock.now = task.at;
      if (task.interval) task.at += task.interval; else timers.delete(id);
      task.fn();
    }
    clock.now = end;
  }
  function welcome(socket, resumed = false) {
    socket.open(); socket.message({ type: 'welcome', protocol: 1, id: 'player', room: 'public-3', resumeToken, resumeRoom: 'public-3', reconnectGraceSeconds: 30, resumed });
  }
  function snapshot(socket, tick = 1) {
    socket.message({ type: 'state', tick, width: 6000, height: 4500, food: [], players: [{ id: 'player', name: 'Dilly', alive: true, mass: 120, best: 120, kills: 0, x: 500, y: 500, shield: 0, dash: 0, cooldown: 0, splitCooldown: 0, merge: 5, cells: [{ id: 'a', x: 480, y: 500, mass: 60 }, { id: 'b', x: 520, y: 500, mass: 60 }] }] });
  }
  return { node, sockets, stored, advance, welcome, snapshot, window, document, context, read: code => vm.runInContext(code, context) };
}
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
  assert.equal(url.searchParams.get('reconnect'), '1');
  assert.equal(socketURL('http://localhost:8788', {}, null).protocol, 'ws:');
  assert.equal(url.searchParams.get('variety'), 'dill');
  assert.equal(socketURL('https://arena.littledill.app', { brine: 'spicy', variety: 'pepper' }).searchParams.get('variety'), 'pepper');
});
test('web pickles keep their variety look and change face with the game', async () => {
  const { VARIETIES, varietyOf, pickleBody, faceMood, blinking, drawPickle } = await import(modulePath);
  assert.equal(varietyOf({ variety: 'butter', brine: 'classic' }), 'butter');
  assert.equal(varietyOf({ variety: 'constructor', brine: 'spicy' }), 'chili');
  assert.equal(new Set(Object.values(VARIETIES).map(v => v.shape)).size, 6);
  assert.ok(pickleBody('round', 50).halfWidth > pickleBody('long', 50).halfWidth); assert.equal(pickleBody('pear', 50).lean, 0);
  assert.equal(faceMood({ threatened: true }), 'threatened');
  assert.equal(faceMood({ threatened: true, dash: 1 }), 'threatened');
  assert.equal(faceMood({ drain: 1, dash: 1 }), 'threatened', 'a draining cell looks threatened');
  assert.equal(faceMood({ drain: 1, alive: false }), 'calm');
  assert.equal(faceMood({ threatened: true, shield: 2 }), 'calm');
  assert.equal(faceMood({ dash: 1 }), 'dash');
  assert.equal(blinking('anyone', 0), false);
  const calls = [], ctx = new Proxy({}, { get: (target, key) => key in target ? target[key] : () => calls.push(key), set: (target, key, value) => { target[key] = value; return true; } });
  for (const variety of Object.keys(VARIETIES)) for (const extra of [{}, { drain: 1 }, { dash: 1 }, { threatened: true }, { sliced: true }]) drawPickle(ctx, { variety, outfit: 'crown', lookX: 1, ...extra }, 0, 0, 40, 1.5);
  assert.ok(calls.includes('quadraticCurveTo') && calls.includes('ellipse') && calls.includes('roundRect'));
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
  assert.equal(splitState({ ...base, cells: ['a', 'b', 'c', 'd'].map(id => cell(id, 80)) }).enabled, true);
  assert.equal(splitState({ ...base, cells: Array.from({ length: 8 }, (_, i) => cell(String(i), 80)) }).enabled, false);
  assert.equal(splitState(base).enabled, false, 'legacy servers do not understand the new split intent');
  assert.equal(splitState({ ...base, alive: false, cells: [cell('a', 120)] }).count, 0);
  assert.deepEqual(splitState({ ...base, cells: [cell('a', 70), cell('b', 50)], merge: 11.8 }), { count: 2, enabled: true, reason: 'Launch a little dill', merge: 11.8 });
});
test('web camera contains every launched piece inside the unobscured viewport', async () => {
  const { cameraFrame, radius } = await import(modulePath);
  const player = { id: 'p', alive: true, mass: 960, x: 700, y: 600, cells: Array.from({ length: 8 }, (_, i) => ({ id: String(i), x: 100 + i % 4 * 470, y: i < 4 ? 100 : 1100, mass: 120 })) };
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
test('web resume credentials have a strict 30-second deadline and never enter share links', async () => {
  const { readResumeRecord, refreshResumeRecord, resumeFromWelcome, resumeRetryDelay, socketURL, shareURL } = await import(modulePath);
  const token = '12345678-1234-4321-9876-123456789abc', now = 100000;
  const saved = resumeFromWelcome({ room: 'public-3', resumeToken: token, resumeRoom: 'public-3', reconnectGraceSeconds: 30 }, now);
  assert.deepEqual(saved, { token, room: 'public-3', deadline: 130000 });
  assert.deepEqual(readResumeRecord(saved, 129999), saved);
  assert.equal(readResumeRecord(saved, 130000), null);
  assert.equal(readResumeRecord({ ...saved, deadline: 200000 }, now), null);
  assert.equal(readResumeRecord({ ...saved, token: '<bad-token>' }, now), null);
  assert.equal(readResumeRecord({ ...saved, room: 'https://other.test/' }, now), null);
  for (const room of ['public-0', 'public-17', 'public-100', 'public-01']) assert.equal(readResumeRecord({ ...saved, room }, now), null);
  assert.equal(readResumeRecord({ ...saved, room: 'public-16' }, now).room, 'public-16');
  assert.equal(resumeFromWelcome({ room: 'public-3', resumeToken: token, resumeRoom: 'public-4', reconnectGraceSeconds: 30 }, now), null);
  assert.equal(resumeFromWelcome({ resumeToken: token, resumeRoom: 'public-1', reconnectGraceSeconds: 900 }, now), null);
  assert.equal(refreshResumeRecord(saved, 125000).deadline, 155000);
  const resumedURL = socketURL('https://arena.littledill.app', { name: 'Dilly' }, null, saved);
  assert.equal(resumedURL.searchParams.get('resumeToken'), token);
  assert.equal(resumedURL.searchParams.get('resumeRoom'), 'public-3');
  assert.equal(resumedURL.searchParams.get('reconnect'), '1');
  assert.equal(shareURL(resumedURL.href, 'ABC123'), 'https://arena.littledill.app/?room=ABC123');
  assert.equal(shareURL(resumedURL.href), 'https://arena.littledill.app/');
  assert.throws(() => socketURL('https://arena.littledill.app', {}, null, { token: 'invalid', room: 'public-1' }), /Invalid resume/);
  assert.equal(resumeRetryDelay(0, 130000, now), 250);
  assert.equal(resumeRetryDelay(99, 130000, 129900), 100);
  assert.equal(resumeRetryDelay(2, 130000, 130000), null);
});
test('web renders split cells as slices until the authoritative count returns to one', async () => {
  const { flattenCells } = await import(modulePath);
  const cells = Array.from({ length: 8 }, (_, i) => ({ id: String(i), x: i * 50, y: 20, mass: 80 }));
  const player = { id: 'p', alive: true, x: 175, y: 20, mass: 640, cells };
  assert.ok(flattenCells([player]).every(cell => cell.sliced));
  assert.equal(flattenCells([{ ...player, cells: [cells[0]] }])[0].sliced, false);
});
test('web reconnect preserves the run, resets sequence, and explicit exit sends leave', async () => {
  const app = await browserHarness();
  app.node('join-form').fire('submit'); const first = app.sockets[0];
  app.welcome(first); app.snapshot(first);
  app.advance(100); assert.equal(app.read('phase'), 'playing');
  assert.equal(app.node('cell-count').textContent, '2 / 8 slices');
  first.close(1006); assert.equal(app.read('phase'), 'reconnecting');
  assert.equal(app.read('state.players[0].mass'), 120);
  app.advance(250); const resumed = app.sockets[1];
  assert.equal(resumed.url.searchParams.get('resumeToken'), resumeToken);
  assert.equal(resumed.url.searchParams.get('resumeRoom'), 'public-3');
  app.welcome(resumed, true); app.snapshot(resumed, 1); app.advance(50);
  assert.equal(app.read('phase'), 'playing');
  assert.equal(resumed.sent.find(p => p.type === 'input').seq, 0);
  app.node('overlay-back').fire('click');
  assert.equal(resumed.sent.at(-1).type, 'leave');
  assert.equal(app.read('phase'), 'lobby');
  assert.equal(app.stored.has('little-dill.arena.resume.v1'), false);
});
test('web restores reload credentials but stops on takeover, protocol close, and expired resume', async () => {
  for (const close of [4001, 1008, 'expired']) {
    const app = await browserHarness({ saved: { token: resumeToken, room: 'public-3', deadline: 130000 } });
    app.advance(0); const socket = app.sockets[0];
    assert.equal(socket.url.searchParams.get('resumeRoom'), 'public-3');
    if (close === 'expired') socket.message({ type: 'resume-expired' }); else socket.close(close);
    assert.equal(app.read('phase'), 'disconnected');
    if (close === 'expired') {
      assert.match(app.node('overlay-message').textContent,/server could not restore/);
      assert.doesNotMatch(app.node('overlay-message').textContent,/window has ended/,'server rejection does not prove the local grace period elapsed');
    }
    assert.equal(app.stored.has('little-dill.arena.resume.v1'), false);
    app.advance(31000); assert.equal(app.sockets.length, 1, 'no automatic fresh start or retry after rejection');
  }
});
test('web background recovery works without storage and never extends an offline deadline', async () => {
  const app = await browserHarness({ storageUnavailable: true });
  app.node('join-form').fire('submit'); app.welcome(app.sockets[0]); app.snapshot(app.sockets[0]);
  app.document.hidden = true; app.document.fire('visibilitychange');
  assert.equal(app.read('phase'), 'reconnecting');
  assert.ok(!app.sockets[0].sent.some(p => p.type === 'leave'));
  app.advance(1000); assert.equal(app.sockets.length, 1);
  app.document.hidden = false; app.document.fire('visibilitychange'); app.advance(0);
  assert.equal(app.sockets[1].url.searchParams.get('resumeToken'), resumeToken);
  app.context.navigator.onLine = false; app.sockets[1].close(1006);
  app.advance(30000);
  assert.equal(app.read('phase'), 'disconnected');
  assert.equal(app.read('resumeSession'), null);
  const attempts = app.sockets.length; app.context.navigator.onLine = true; app.window.fire('online'); app.advance(4000);
  assert.equal(app.sockets.length, attempts, 'expired runs require an explicit fresh start');
});
test('web rejects resume welcomes with mismatched token, canonical room, or requested room', async () => {
  for (const mismatch of [{ resumeToken: '87654321-1234-4321-9876-123456789abc' }, { room: 'public-4' }, { room: 'public-4', resumeRoom: 'public-4' }]) {
    const app = await browserHarness({ saved: { token: resumeToken, room: 'public-3', deadline: 130000 } });
    app.advance(0); const socket = app.sockets[0]; socket.open();
    socket.message({ type: 'welcome', protocol: 1, id: 'player', room: 'public-3', resumeToken, resumeRoom: 'public-3', reconnectGraceSeconds: 30, resumed: true, ...mismatch });
    assert.equal(app.read('phase'), 'disconnected');
    assert.equal(app.read('resumeSession'), null);
    app.advance(31000); assert.equal(app.sockets.length, 1);
  }
});
test('web takeover cannot delete the new tab’s shared resume record, even on repeated cleanup', async () => {
  const sharedStorage = new Map(), first = await browserHarness({ sharedStorage });
  first.node('join-form').fire('submit'); first.welcome(first.sockets[0]); first.snapshot(first.sockets[0]);
  const oldRecord = sharedStorage.get('little-dill.arena.resume.v1');
  const second = await browserHarness({ sharedStorage }); second.advance(0);
  second.welcome(second.sockets[0], true); second.snapshot(second.sockets[0]);
  const activeRecord = sharedStorage.get('little-dill.arena.resume.v1');
  assert.notEqual(activeRecord, oldRecord, 'each tab marks its own persistence writes');
  first.sockets[0].close(4001);
  assert.equal(first.read('phase'), 'disconnected'); assert.equal(first.read('resumeSession'), null);
  assert.equal(sharedStorage.get('little-dill.arena.resume.v1'), activeRecord);
  first.node('overlay-back').fire('click');
  assert.equal(sharedStorage.get('little-dill.arena.resume.v1'), activeRecord, 'old-tab exit must not remove the active record');
  second.node('overlay-back').fire('click');
  assert.equal(sharedStorage.has('little-dill.arena.resume.v1'), false, 'the owning tab still clears its own intentional exit');
});
test('web fear eyes use each cell’s mass, another owner, and the exact eating-threat boundary', async () => {
  const { threatenedCellIDs, cellKey, radius } = await import(modulePath);
  const prey = { id: 'prey', alive: true, shield: 0, mass: 400, cells: [{ id: 'small', x: 0, y: 0, mass: 100 }, { id: 'large', x: 10, y: 0, mass: 300 }] };
  const reach = radius(122) + radius(100) * .4 + 45;
  const hunter = { id: 'hunter', alive: true, shield: 0, mass: 122, cells: [{ id: 'small', x: reach, y: 0, mass: 122 }] };
  const atBoundary = threatenedCellIDs([prey, hunter]);
  assert.ok(atBoundary.has(cellKey('prey', 'small')));
  assert.ok(!atBoundary.has(cellKey('prey', 'large')), 'a player’s small slice cannot threaten a larger slice');
  assert.ok(!threatenedCellIDs([prey, { ...hunter, cells: [{ ...hunter.cells[0], x: reach + .001 }] }]).has(cellKey('prey', 'small')));
  assert.ok(!threatenedCellIDs([prey, { ...hunter, cells: [{ ...hunter.cells[0], mass: 121.99 }] }]).has(cellKey('prey', 'small')));
  assert.ok(!threatenedCellIDs([{ ...prey, cells: [prey.cells[0]] }, { ...hunter, mass: 1000, cells: [{ ...hunter.cells[0], x: 0, mass: 100 }] }]).has(cellKey('prey', 'small')), 'aggregate hunter mass must not trigger the cue');
  assert.equal(threatenedCellIDs([prey]).size, 0, 'sibling slices never scare each other');
  assert.notEqual(cellKey('prey', 'small'), cellKey('hunter', 'small'));
});
test('web fear eyes clear for shields, dead cells, equal opponents, and departed threats', async () => {
  const { threatenedCellIDs, cellKey } = await import(modulePath);
  const prey = { id: 'prey', alive: true, shield: 0, x: 0, y: 0, mass: 25 };
  const hunter = { id: 'hunter', alive: true, shield: 0, x: 10, y: 0, mass: 50 };
  assert.ok(threatenedCellIDs([prey, hunter]).has(cellKey('prey', 'prey')));
  for (const players of [[{ ...prey, shield: .1 }, hunter], [prey, { ...hunter, shield: .1 }], [{ ...prey, alive: false }, hunter], [prey, { ...hunter, alive: false }], [prey, { ...hunter, mass: 25 }], [prey]]) assert.equal(threatenedCellIDs(players).size, 0);
});
test('web controller replaces its fear-eye cache as threats enter and leave snapshots', async () => {
  const app = await browserHarness(); app.node('join-form').fire('submit'); app.welcome(app.sockets[0]); app.snapshot(app.sockets[0]);
  assert.equal(app.read('threatened.size'), 0);
  const current = JSON.parse(app.read('JSON.stringify(state)'));
  const hunter = { id: 'hunter', name: 'Dill', alive: true, shield: 0, mass: 100, x: 500, y: 500 };
  app.sockets[0].message({ ...current, tick: 2, players: [...current.players, hunter] });
  assert.equal(app.read('threatened.size'), 2);
  app.sockets[0].message({ ...current, tick: 3 });
  assert.equal(app.read('threatened.size'), 0);
});
test('web zoom eases in log space, faster out than in, and snaps from an unset zoom', async () => {
  const { easeZoom } = await import(modulePath);
  const out = easeZoom(1, .5, .05), back = easeZoom(.5, 1, .05);
  assert.ok(out < 1 && out > .5); assert.ok(back > .5 && back < 1);
  assert.ok(Math.abs(Math.log(out) - Math.log(.5) * (1 - Math.exp(-7 * .05))) < 1e-9, 'zooming out uses rate 7/s');
  assert.ok(Math.abs(Math.log(back) - Math.log(.5) * Math.exp(-2.5 * .05)) < 1e-9, 'zooming in uses rate 2.5/s');
  assert.ok(Math.log(1 / out) > Math.log(back / .5), 'zooming out covers more log distance per frame');
  let zoom = 1; for (let frame = 0; frame < 120; frame++) zoom = easeZoom(zoom, .2, 1 / 60);
  assert.ok(Math.abs(zoom - .2) < .2 * 1e-4);
  for (const current of [null, undefined, NaN, 0, -1, Infinity]) assert.equal(easeZoom(current, .7, .016), .7);
  assert.equal(easeZoom(.7, .7, .016), .7);
});
test('web kill rings mark the exact eat line for hunters that threaten your own pieces', async () => {
  const { killRings, radius } = await import(modulePath);
  const me = { id: 'me', alive: true, shield: 0, mass: 100, cells: [{ id: 'a', x: 0, y: 0, mass: 100 }] };
  const hunter = x => ({ id: 'big', alive: true, shield: 0, mass: 400, cells: [{ id: 'h', x, y: 0, mass: 400 }] });
  const threshold = radius(400) - .6 * radius(100);
  const [ring] = killRings([me, hunter(threshold + 100)], 'me');
  assert.deepEqual({ ...ring, alpha: undefined }, { ownerID: 'big', cellID: 'h', x: threshold + 100, y: 0, radius: threshold, alpha: undefined });
  assert.ok(Math.abs(ring.alpha - (.25 + .65 * (1 - 100 / 320))) < 1e-9);
  assert.ok(Math.abs(killRings([me, hunter(threshold - 50)], 'me')[0].alpha - .9) < 1e-9, 'alpha caps at .9 inside the line');
  assert.equal(killRings([me, hunter(threshold + 320)], 'me').length, 0, 'far hunters are ignored');
  assert.ok(killRings([me, hunter(threshold + 319)], 'me')[0].alpha >= .25);
  assert.equal(killRings([me, { ...hunter(10), shield: 1 }], 'me').length, 0, 'shielded hunters cannot eat');
  assert.equal(killRings([{ ...me, shield: 1 }, hunter(10)], 'me').length, 0, 'shielded pieces cannot be eaten');
  assert.equal(killRings([me, { ...hunter(10), cells: [{ id: 'h', x: 10, y: 0, mass: 121 }] }], 'me').length, 0, 'hunters need 1.22x mass');
  assert.equal(killRings([{ ...me, cells: [...me.cells, { id: 'b', x: 50, y: 0, mass: 400 }] }], 'me').length, 0, 'your own pieces never ring each other');
  assert.equal(killRings([me, hunter(10), { id: 'other', alive: true, shield: 0, mass: 20, cells: [{ id: 'o', x: 5, y: 0, mass: 20 }] }], 'me').length, 1, 'rings only threaten your own pieces');
  const pair = { ...me, cells: [{ id: 'far', x: -300, y: 0, mass: 100 }, { id: 'near', x: 0, y: 0, mass: 25 }] };
  assert.equal(killRings([pair, hunter(radius(400))], 'me')[0].radius, radius(400) - .6 * radius(25), 'ring uses the closest threatened piece');
  assert.equal(killRings([{ ...me, alive: false }, hunter(10)], 'me').length, 0);
});
test('web membranes dent where bodies press together or reach a wall and relax when free', async () => {
  const { bodyShape, shapeRadius, makeMembrane, resizeMembrane, stepMembrane, outlineRadius, membraneOutline, membraneSize, radius } = await import(modulePath);
  const capsule = { hw: 80, hh: 100, lean: 0, ellipse: false };
  assert.equal(shapeRadius(capsule, 0), 80); assert.equal(shapeRadius(capsule, Math.PI / 2), 100);
  assert.ok(Math.abs(shapeRadius(capsule, Math.PI / 4) - 92.88) < .01);
  assert.equal(shapeRadius({ hw: 96, hh: 90, ellipse: true }, 0), 96);
  assert.deepEqual(bodyShape({ sliced: true }, 50), { hw: 35, hh: 50, lean: 0, ellipse: false });
  assert.equal(bodyShape({ variety: 'garlic' }, 50).lean, 0);
  assert.equal(membraneSize(10), 18); assert.equal(membraneSize(1000), 72); assert.equal(membraneSize(150) % 6, 0);
  const slice = r => ({ hw: r, hh: r, lean: 0, ellipse: false }), r = radius(200);
  const a = { x: 500, y: 500, shape: slice(r), m: makeMembrane(36) }, b = { x: 500 + r * 1.7, y: 500, shape: slice(r), m: makeMembrane(36) };
  for (let step = 0; step < 120; step++) for (const body of [a, b]) stepMembrane(body.m, body, [a, b], null, { jitter: 0 });
  assert.ok(a.m.dr[0] < -.05 * r && b.m.dr[18] < -.05 * r, 'facing sides dent');
  assert.ok(Math.abs(a.m.dr[18]) < 1 && Math.abs(b.m.dr[0]) < 1, 'far sides keep their shape');
  assert.ok(outlineRadius(a.shape, a.m, 0) + outlineRadius(b.shape, b.m, Math.PI) < r * 1.7 + 4, 'the two outlines meet instead of overlapping');
  assert.ok(Math.min(...a.m.dr) >= -.35 * r - 1e-9, 'dents are capped');
  const wall = { x: r - 6, y: 500, shape: slice(r), m: makeMembrane(36) };
  for (let step = 0; step < 60; step++) stepMembrane(wall.m, wall, [wall], { width: 6000, height: 4500 }, { jitter: 0 });
  assert.ok(wall.m.dr[18] < -4, 'the wall side flattens');
  const free = { x: 3000, y: 2000, shape: slice(r), m: makeMembrane(36) }; free.m.dr.fill(-10);
  for (let step = 0; step < 120; step++) stepMembrane(free.m, free, [free], { width: 6000, height: 4500 }, { jitter: 0 });
  assert.ok(Math.max(...free.m.dr.map(Math.abs)) < .1, 'free bodies relax back');
  const resized = resizeMembrane(a.m, 72);
  assert.equal(resized.n, 72); assert.ok(Math.abs(resized.dr[0] - a.m.dr[0]) < 1e-9); assert.equal(resizeMembrane(resized, 72), resized);
  assert.equal(membraneOutline(a.shape, a.m).length, 36);
});
test('web draws kitchen gadgets without a boundary, drain droplets, spit flights and kill rings', async () => {
  const { drawHazard, hazardKind, HAZARD_KINDS, drawDroplet, drainDroplets, hazardFor, spitFlight, drawPickle, radius, bodyShape, makeMembrane, membraneOutline } = await import(modulePath);
  const calls = [], ctx = new Proxy({}, { get: (target, key) => key in target ? target[key] : (...args) => calls.push([key, ...args]), set: (target, key, value) => { target[key] = value; return true; } });
  const device = { id: 'h1', x: 1000, y: 800, r: 150 }, cell = { x: 1000 + 150 + radius(100) - 20, y: 800, mass: 100, drain: 1 };
  assert.equal(hazardFor(cell, [{ id: 'far', x: 4000, y: 800, r: 150 }, device]), device);
  const drops = drainDroplets(cell, device, 1.23);
  assert.equal(drops.length, 8);
  for (const drop of drops) { assert.ok(drop.x >= device.x - 20 && drop.x <= cell.x); assert.ok(drop.r >= 0 && drop.r <= 4); }
  assert.deepEqual(HAZARD_KINDS, ['slicer', 'shaker', 'grater']);
  assert.equal(hazardKind({ kind: 'grater' }), 'grater'); assert.equal(hazardKind({ kind: 'spoon' }, 1), 'shaker'); assert.equal(hazardKind({}, 5), 'grater');
  const drawn = {};
  for (const kind of HAZARD_KINDS) for (const hungry of [false, true]) {
    const start = calls.length;
    drawHazard(ctx, { ...device, kind }, { time: 1.2, hungry, lookX: 1, lookY: 0, droplets: hungry ? drops : [] });
    const own = calls.slice(start);
    assert.ok(!own.some(([key, dash]) => key === 'setLineDash' && dash.length), `${kind} has no dashed boundary`);
    assert.ok(!own.some(([key, , , r]) => key === 'arc' && r === device.r), `${kind} has no ring at the field radius`);
    assert.ok(own.filter(([key]) => key === 'ellipse').length >= 4, `${kind} has a face`);
    drawn[kind] = own.map(([key]) => key).join();
  }
  assert.equal(new Set(Object.values(drawn)).size, 3, 'each gadget has its own art');
  drawDroplet(ctx, 5, 5, 6);
  const outline = danger => { const strokes = [], pen = new Proxy({}, { get: (target, key) => key in target ? target[key] : () => { if (key === 'stroke') strokes.push([target.strokeStyle, target.globalAlpha]); }, set: (target, key, value) => { target[key] = value; return true; } }); drawPickle(pen, { variety: 'dill', danger }, 0, 0, 40, 1); return strokes; };
  assert.ok(outline(.6).some(([style, alpha]) => style === '#C8553D' && alpha === .6), 'pickles that can eat you get a red outline');
  assert.ok(!outline(0).some(([style]) => style === '#C8553D'));
  assert.deepEqual(spitFlight(0, 0, 100, 0, 0), { x: 0, y: 0, done: false });
  assert.ok(spitFlight(0, 0, 100, 0, .1).x > 100 * .1 / .45, 'ease-out leaves the device quickly');
  assert.deepEqual(spitFlight(0, 0, 100, 50, .45), { x: 100, y: 50, done: true });
  const before = calls.length;
  const membrane = makeMembrane(24); membrane.dr[0] = -8;
  drawPickle(ctx, { variety: 'dill', drain: 1, outline: membraneOutline(bodyShape({ variety: 'dill' }, 40), membrane) }, 10, 10, 40, 1);
  const traced = calls.slice(before);
  assert.ok(traced.filter(([key]) => key === 'quadraticCurveTo').length >= 24 * 3, 'shadow, body and clip trace the membrane');
  assert.ok(traced.some(([key, cx, cy]) => key === 'quadraticCurveTo' && Math.abs(cx - 24) < 1e-9 && Math.abs(cy) < 1e-9), 'the dented point is drawn at the capsule side minus 8');
  assert.ok(traced.some(([key]) => key === 'clip'), 'spots and shine stay inside the dented body');
});
test('web controller tracks spit pellets from the device and drops them when eaten', async () => {
  const app = await browserHarness(); app.node('join-form').fire('submit'); app.welcome(app.sockets[0]); app.snapshot(app.sockets[0]);
  const current = JSON.parse(app.read('JSON.stringify(state)')), hazards = [{ id: 'h1', x: 900, y: 500, r: 150 }];
  app.sockets[0].message({ ...current, tick: 2, food: undefined, hazards, foodAdded: [[7, 900 + 260, 500, 4], [8, 3000, 3000, 4], [9, 910, 500, 3]] });
  assert.deepEqual(JSON.parse(app.read('JSON.stringify(spits.get(7))')), { t0: app.read('arrived'), x: 900, y: 500 });
  assert.equal(app.read('spits.get(8)'), null, 'spit far from any device lands without a flight');
  assert.equal(app.read('spits.has(9)'), false, 'normal pellets are not tracked');
  app.sockets[0].message({ ...current, tick: 3, food: undefined, hazards, foodRemoved: [7] });
  assert.deepEqual(JSON.parse(app.read('JSON.stringify([...spits.keys()])')), [8]);
  app.sockets[0].message({ ...current, tick: 4, food: undefined, hazards: undefined });
  assert.deepEqual(app.read('state.hazards').length, 0, 'older snapshots draw no devices');
});
test('web render draws gadgets, drain streams, spit, membrane pieces and danger outlines from live snapshots', async () => {
  const app = await browserHarness(); app.node('join-form').fire('submit'); app.welcome(app.sockets[0]); app.snapshot(app.sockets[0]);
  const current = JSON.parse(app.read('JSON.stringify(state)'));
  const me = { ...current.players[0], cells: [{ id: 'a', x: 480, y: 500, mass: 60, drain: 1 }, { id: 'b', x: 530, y: 500, mass: 60 }] };
  const hunter = { id: 'hunter', name: 'Big', alive: true, shield: 0, mass: 400, x: 650, y: 500, cells: [{ id: 'h', x: 650, y: 500, mass: 400 }] };
  app.sockets[0].message({ ...current, tick: 2, players: [me, hunter], hazards: [{ id: 'h1', x: 330, y: 500, r: 150 }], food: [[7, 60, 500, 4], [8, 900, 900, 3]] });
  const arena = app.node('arena');
  app.read('render(performance.now() + 16); render(performance.now() + 32)');
  const arcs = arena.calls.filter(([key]) => key === 'arc');
  assert.ok(arena.calls.some(([key, x, y]) => key === 'translate' && x === 330 && y === 500) && arena.calls.some(([key, x, y]) => key === 'scale' && x === 1.25 && y === 1.25), 'gadget');
  assert.ok(!arena.calls.some(([key, text]) => key === 'fillText' && /pickle/i.test(text) && text !== 'you'), 'no gadget label');
  assert.ok(JSON.parse(app.read(`JSON.stringify([...membranes.values()].map(m => Math.min(...m.dr)))`)).every(min => min < 0), 'overlapping slices dent each other');
  assert.ok(!arcs.some(([, x, y]) => x === 650 && y === 500), 'no ring over the hunter');
  assert.ok(arena.calls.some(([key, style]) => key === 'stroke' && style === '#C8553D'), 'the hunter gets a red outline');
  assert.ok(app.node('minimap').calls.some(([key]) => key === 'roundRect'), 'gadget on the minimap');
  assert.ok(app.read('zoom') > 0);
});
test('each gadget drains with its own stroke rhythm and switching gadgets restarts the rhythm', async () => {
  const { scheduleStrokes, GADGET_STROKE_SECONDS, HAZARD_KINDS } = await import(modulePath);
  assert.deepEqual(Object.keys(GADGET_STROKE_SECONDS), HAZARD_KINDS);
  assert.equal(new Set(Object.values(GADGET_STROKE_SECONDS)).size, 3, 'three distinct rhythms');
  let { loop, times } = scheduleStrokes(null, 'shaker', 10);
  assert.deepEqual(times.map(t => +t.toFixed(3)), [10.01, 10.23]);
  ({ loop, times } = scheduleStrokes(loop, 'shaker', 10.1));
  assert.deepEqual(times.map(t => +t.toFixed(3)), [], 'already scheduled strokes are not repeated');
  ({ loop, times } = scheduleStrokes(loop, 'shaker', 10.25));
  assert.deepEqual(times.map(t => +t.toFixed(3)), [10.45]);
  ({ loop, times } = scheduleStrokes(loop, 'grater', 10.3));
  assert.deepEqual(times.map(t => +t.toFixed(3)), [10.31], 'a new gadget starts its own rhythm');
  assert.deepEqual(scheduleStrokes(loop, 'spoon', 11), { loop: null, times: [] });
});

test('piece loss suppresses routine pickup sounds even when nearby food offsets lost mass', async () => {
  const app = await browserHarness();
  app.read("globalThis.heard = []; sound = kind => heard.push(kind)");
  const before = {id:'me',alive:true,mass:120,kills:0,hurt:0,cells:[{id:'a',x:0,y:0,mass:60},{id:'b',x:0,y:0,mass:60}]};
  const after = {...before,mass:130,hurt:2.4,cells:[{id:'a',x:0,y:0,mass:130}]};
  app.read(`feedingSounds(${JSON.stringify(after)}, ${JSON.stringify(before)}, [])`);
  assert.equal(app.read('JSON.stringify(heard)'), '["crunch"]');
});
