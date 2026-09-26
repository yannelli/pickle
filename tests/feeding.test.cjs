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
    dispatch(name, event = {}) { return Promise.all((this.listeners.get(name) || []).map(callback => callback({ target: this, currentTarget: this, ...event }))); }
    contains(element) { return element === this; }
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
    createElement: () => new Element(),
    querySelector: selector => groups[selector]?.[0] || get(selector), querySelectorAll: selector => groups[selector] || [],
    addEventListener: (name, cb) => { if (!events.has(name)) events.set(name, []); events.get(name).push(cb); } };
  const pet = { version: 1, fullness: 60, happiness: 20, energy: 80, hygiene: 60, ageTicks: 120, neglect: 0,
    sleeping: false, sick: false, dead: false, updatedAt: now, ...changes };
  const storage = new Map([['little-dill.v1', JSON.stringify(pet)], ...Object.entries(options.storage || {})]);
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
    matchMedia: () => ({ matches: false }), addEventListener() {}, LittleDillAudio: { create: () => sound }, LittleDillSaves: options.saves,
    LittleDillPhotos: options.photos };
  sandbox.window = sandbox;
  const dispatch = (name, event = {}) => { for (const cb of events.get(name) || []) cb(event); };
  document.documentElement = options.fullscreen || {};
  vm.runInNewContext(source, sandbox);
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
  return { get, jars, pads, lanes, cues, storage, run, until, document, foodAt: sandbox.LittleDillFeedFood.at,
    click: id => get(id).click(), saved: () => JSON.parse(storage.get('little-dill.v2') || storage.get('little-dill.v1')),
    key: key => dispatch('keydown', { key, target: { tagName: 'BODY' }, preventDefault() {} }),
    visible: visible => { document.hidden = !visible; dispatch('visibilitychange'); },
    start: type => { get('play').click(); choices[['hunt', 'memory', 'catch'].indexOf(type)].click(); } };
}

test('feeding rotates five foods and a refused feed keeps the next selection', () => {
  const app = client({ fullness: 0 });
  assert.deepEqual([0, 1, 2, 3, 4, 5].map(app.foodAt), ['carrot', 'strawberry', 'broccoli', 'apple', 'cheese', 'carrot']);
  const offered = [];
  for (let bite = 0; bite < 3; bite++) {
    app.click('feed');
    offered.push(app.get('feed-food').dataset.food);
    assert.equal(app.get('feed-food').hidden, false);
  }
  assert.deepEqual(offered, ['carrot', 'strawberry', 'broccoli']);
  app.click('feed');
  assert.deepEqual(offered, ['carrot', 'strawberry', 'broccoli']);
  assert.match(app.get('message').textContent, /full to the brim/);
  app.run(60 * 60 * 1000);
  app.click('feed');
  assert.equal(app.get('feed-food').dataset.food, 'apple');
  app.run(60 * 60 * 1000);
  app.click('feed');
  assert.equal(app.get('feed-food').dataset.food, 'cheese');
  app.run(2900);
  assert.equal(app.get('feed-food').hidden, true);
});


test('feeding resumes the saved assortment after a page reload', () => {
  const app = client({ fullness: 0 }, { storage: { 'little-dill.food-turn.v1': '2' } });
  app.click('feed');
  assert.equal(app.get('feed-food').dataset.food, 'broccoli');
  app.click('feed');
  assert.equal(app.get('feed-food').dataset.food, 'apple');
});
