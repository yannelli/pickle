const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync(require.resolve('../index.html'), 'utf8');
const source = fs.readFileSync(require.resolve('../pet-life.js'), 'utf8') + '\n' + html.match(/<script>([\s\S]*?)<\/script>/)[1];

// Exercise the shipped game handlers with a tiny DOM and deterministic clock.
// Browser verification separately covers layout, native inputs, and Web Audio.
function client(changes = {}, options = {}) {
  let now = 1800000000000, nextId = 0;
  const timers = new Map(), elements = new Map(), events = new Map();
  class Element {
    constructor() {
      this.textContent = ''; this.hidden = false; this.disabled = false; this.open = false;
      this.dataset = {}; this.style = { setProperty(name, value) { this[name] = value; } }; this.children = new Map(); this.listeners = new Map(); this.attributes = {};
      const classes = new Set();
      this.classList = { add: (...names) => names.forEach(n => classes.add(n)), remove: (...names) => names.forEach(n => classes.delete(n)),
        contains: n => classes.has(n), toggle: (n, force = !classes.has(n)) => force ? classes.add(n) : classes.delete(n) };
    }
    querySelector(name) { if (!this.children.has(name)) this.children.set(name, new Element()); return this.children.get(name); }
    setAttribute(name, value) { this.attributes[name] = String(value); }
    addEventListener(name, callback) { if (!this.listeners.has(name)) this.listeners.set(name, []); this.listeners.get(name).push(callback); }
    click() { if (!this.disabled) this.dispatch('click'); }
    dispatch(name, event = {}) { for (const callback of this.listeners.get(name) || []) callback({ target: this, currentTarget: this, ...event }); }
    focus() { document.activeElement = this; }
    showModal() { this.open = true; }
    close() { this.open = false; this.dispatch('close'); }
    replaceChildren() {}
    get clientWidth() { return 237; }
  }
  const get = id => { if (!elements.has(id)) elements.set(id, new Element()); return elements.get(id); };
  for (const match of html.matchAll(/id="([^"]+)"/g)) get(match[1]);
  const jars = [0, 1, 2].map(() => new Element());
  const pads = [0, 1, 2].map(() => new Element());
  const lanes = [0, 1, 2].map(() => new Element());
  const choices = ['hunt', 'memory', 'catch'].map(game => Object.assign(new Element(), { dataset: { game } }));
  const groups = { '.jar': jars, '.memory-pad': pads, '.catch-lane': lanes, '.game-choice': choices };
  const document = { hidden: false, activeElement: null, getElementById: get,
    querySelector: selector => groups[selector]?.[0] || get(selector), querySelectorAll: selector => groups[selector] || [],
    addEventListener: (name, cb) => { if (!events.has(name)) events.set(name, []); events.get(name).push(cb); } };
  const pet = { version: 1, fullness: 60, happiness: 20, energy: 80, hygiene: 60, ageTicks: 120, neglect: 0,
    sleeping: false, sick: false, dead: false, updatedAt: now, ...changes };
  const storage = new Map([['little-dill.v1', JSON.stringify(pet)]]);
  const localStorage = { getItem: key => storage.get(key) ?? null, setItem: (key, value) => { if (options.blockStorage) throw Error('blocked'); storage.set(key, value); } };
  let preferences = { music: true, sfx: true, volume: .45 };
  const cues = [];
  const sound = { play: (name, pitch) => cues.push([name, pitch]), unlock() {}, setActive() {}, setResting() {},
    configure: changes => { preferences = { ...preferences, ...changes }; }, get preferences() { return preferences; } };
  const schedule = (fn, delay, interval = 0) => { const id = ++nextId; timers.set(id, { fn, at: now + delay, interval }); return id; };
  const sandbox = { document, localStorage, performance: { now: () => now }, Date: class extends Date { static now() { return now; } },
    Math: Object.assign(Object.create(Math), { random: () => .1 }), navigator: { userAgent: '', platform: '' }, location: { protocol: 'http:' },
    setTimeout: (fn, delay) => schedule(fn, delay), clearTimeout: id => timers.delete(id),
    setInterval: (fn, delay) => schedule(fn, delay, delay), clearInterval: id => timers.delete(id),
    matchMedia: () => ({ matches: false }), addEventListener() {}, LittleDillAudio: { create: () => sound } };
  sandbox.window = sandbox;
  vm.runInNewContext(source, sandbox);
  const dispatch = (name, event = {}) => { for (const cb of events.get(name) || []) cb(event); };
  const run = duration => {
    const end = now + duration;
    while (true) {
      const entry = [...timers].filter(([, t]) => t.at <= end).sort((a, b) => a[1].at - b[1].at)[0];
      if (!entry) break;
      const [id, timer] = entry; now = timer.at;
      if (timer.interval) timer.at += timer.interval; else timers.delete(id);
      timer.fn();
    }
    now = end;
  };
  const until = predicate => { for (let i = 0; !predicate() && i < 1200; i++) run(25); assert.ok(predicate(), 'condition reached in 30 seconds'); };
  return { get, jars, pads, lanes, cues, storage, run, until, document,
    click: id => get(id).click(), saved: () => JSON.parse(storage.get('little-dill.v1')),
    key: key => dispatch('keydown', { key, target: { tagName: 'BODY' }, preventDefault() {} }),
    visible: visible => { document.hidden = !visible; dispatch('visibilitychange'); },
    start: type => { get('play').click(); choices[['hunt', 'memory', 'catch'].indexOf(type)].click(); } };
}

test('petting increases and persists happiness without energy, and never blocks Play', () => {
  const app = client();
  app.click('pet');
  assert.equal(app.saved().happiness, 28);
  assert.equal(app.saved().energy, 80);
  app.click('cuddle');
  assert.equal(app.saved().happiness, 28, 'rapid pets do not duplicate rewards');
  app.run(2000); app.key('p');
  assert.ok(Math.abs(app.saved().happiness - 36) < .01);
  app.click('play');
  assert.equal(app.get('game').hidden, false);
  assert.equal(app.get('game-title').textContent, 'THE DILL ARCADE');
});

test('care gives happiness, caps at 100, and persists recovery from sickness', () => {
  const app = client({ happiness: 24, sick: true });
  app.click('pet');
  assert.equal(app.saved().sick, false);
  app.click('feed'); app.click('clean');
  assert.equal(app.saved().happiness, 39);
  assert.equal(app.saved().fullness, 100);
  assert.equal(app.saved().hygiene, 100);
  const capped = client({ happiness: 98 }); capped.click('pet');
  assert.equal(capped.saved().happiness, 100);
  assert.match(capped.get('message').textContent, /\+2 happy/);
});

test('a tired pickle can gain happiness and nap; games enforce energy on every entry', () => {
  const app = client({ energy: 2 });
  app.click('pet'); assert.equal(app.saved().happiness, 28);
  app.start('hunt'); assert.equal(app.get('game').hidden, true);
  assert.match(app.get('message').textContent, /6 energy/);
  app.key('s'); app.run(12 * 60000);
  assert.ok(app.saved().energy >= 8);
  app.click('pet'); assert.equal(app.saved().sleeping, false);
  app.start('hunt'); assert.equal(app.get('game').hidden, false);
  assert.ok(app.saved().energy < 6);
  app.click('game-menu-button'); app.key('2');
  assert.equal(app.get('game').hidden, true);
});

test('Heart Hunt pays once after three rounds and replay starts a fresh paid game', () => {
  const app = client(); app.start('hunt');
  assert.equal(app.saved().energy, 74);
  for (let round = 0; round < 3; round++) {
    app.until(() => !app.jars[0].disabled);
    app.jars.find(jar => jar.querySelector('.prize').textContent === '♥').click();
    app.run(1150);
  }
  assert.equal(app.get('game-again').hidden, false);
  assert.match(app.get('message').textContent, /3\/3 hearts found/);
  assert.ok(app.saved().happiness > 52 && app.saved().happiness <= 54);
  const happy = app.saved().happiness;
  app.jars[0].dispatch('click'); assert.equal(app.saved().happiness, happy);
  const energy = app.saved().energy;
  app.click('game-again'); assert.ok(Math.abs(app.saved().energy - (energy - 6)) < .001);
  assert.equal(app.get('game-again').hidden, true);
});

test('all misses still give a real happiness reward', () => {
  const app = client(); app.start('hunt');
  for (let round = 0; round < 3; round++) {
    app.until(() => !app.jars[0].disabled);
    app.jars.find(jar => jar.querySelector('.prize').textContent === '·').click(); app.run(1150);
  }
  assert.ok(app.saved().happiness > 28);
  assert.match(app.get('message').textContent, /\+10 happy/);
});

test('Dill Says grows its sequence and rewards all five completed levels', () => {
  const app = client(); app.start('memory');
  for (let level = 1; level <= 5; level++) {
    app.until(() => !app.pads[0].disabled);
    for (let note = 0; note < level + 1; note++) app.key('1');
  }
  assert.match(app.get('message').textContent, /five levels/);
  assert.equal(app.get('game-again').hidden, false);
  assert.equal(JSON.parse(app.storage.get('little-dill.arcade.v1')).memory, 5);
  assert.ok(app.saved().happiness > 50);
});

test('memory mistakes and timeouts reward trying, without a delayed second payout', () => {
  const app = client(); app.start('memory'); app.until(() => !app.pads[0].disabled);
  app.key('2'); assert.match(app.get('message').textContent, /nice try/);
  const happy = app.saved().happiness;
  app.run(18000); assert.ok(app.saved().happiness < happy);
  app.click('game-again'); app.until(() => !app.pads[0].disabled); app.run(14000);
  assert.match(app.get('message').textContent, /good practice/);
  assert.equal(app.get('game-again').hidden, false);
});

test('Brine Catch uses lanes, combos, and salt dodges, then ends at twelve drops', () => {
  const app = client(); app.start('catch');
  for (let round = 1; round <= 12; round++) {
    app.until(() => !app.get('catch-drop').hidden && app.get('game-meta').textContent.startsWith('DROP ' + round + '/'));
    app.key(round % 4 === 0 ? '2' : '1');
    app.until(() => app.get('catch-drop').hidden);
  }
  assert.equal(app.get('game-again').hidden, false);
  assert.equal(JSON.parse(app.storage.get('little-dill.arcade.v1')).catch, 16);
  assert.ok(app.saved().happiness > 51);
});

test('hidden pages preserve remaining game timers; leaving cancels old callbacks', () => {
  const app = client(); app.start('memory'); app.run(500);
  const message = app.get('message').textContent;
  app.visible(false); app.run(20000);
  assert.equal(app.get('message').textContent, message);
  assert.ok(app.pads.every(pad => pad.disabled));
  app.visible(true); app.until(() => !app.pads[0].disabled);
  app.key('Escape'); const happy = app.saved().happiness;
  app.run(20000);
  assert.equal(app.get('game').hidden, true);
  assert.ok(app.saved().happiness < happy, 'no ghost reward after exit');
});

test('sleep and dead states refuse care and games; storage failures do not stop play', () => {
  const asleep = client({ sleeping: true }); asleep.click('play');
  assert.match(asleep.get('message').textContent, /Wake/);
  const dead = client({ dead: true }); dead.key('p'); dead.key('2');
  assert.equal(dead.saved().happiness, 20);
  const blocked = client({}, { blockStorage: true }); blocked.click('pet'); blocked.start('memory');
  blocked.until(() => !blocked.pads[0].disabled); blocked.key('2');
  assert.match(blocked.get('message').textContent, /\+10 happy/);
  assert.match(blocked.get('save-status').textContent, /unavailable/);
});
