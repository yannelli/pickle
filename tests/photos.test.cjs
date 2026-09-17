const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const Life = require('../pet-life.js');
const source = fs.readFileSync(require.resolve('../photos.js'), 'utf8');
const now = 1800000000000;
const pet = (days = 0, changes = {}) => ({ ...Life.fresh(now), phase: 'living', name: 'Sir Crunch', bornAt: now - days * Life.DAY, ...changes });
const tick = () => new Promise(resolve => setImmediate(resolve));

function client(options = {}) {
  const elements = new Map(), encodes = [], urls = new Map(), downloads = [], shares = [];
  class Element {
    constructor() {
      this.listeners = {}; this.attrs = {}; this.hidden = false; this.disabled = false; this.open = false;
      this.offsetLeft = 5; this.offsetTop = 5; this.offsetWidth = 12; this.offsetHeight = 7;
      this.dataset = { stage: 'baby', mood: 'idle', shape: 'long' };
    }
    addEventListener(name, callback) { this.listeners[name] = callback; }
    click() { return this.disabled ? undefined : this.listeners.click?.(); }
    setAttribute(name, value) { this.attrs[name] = value; }
    removeAttribute(name) { delete this[name]; }
    showModal() { this.open = true; }
    close() { this.open = false; this.listeners.close?.(); }
    querySelector(selector) { return get(selector); }
    querySelectorAll() { return []; }
    remove() {}
  }
  const get = id => { if (!elements.has(id)) elements.set(id, new Element()); return elements.get(id); };
  const context = new Proxy({ measureText: text => ({ width: text.length * 20 }) }, { get: (object, key) => object[key] || (() => {}) });
  const navigator = options.share ? {
    canShare: () => true,
    share: data => { shares.push(data); return options.share(data); }
  } : {};
  const sandbox = { LittleDillLife: Life, Date: class extends Date { static now() { return now; } }, Blob, File, navigator,
    URL: { createObjectURL: blob => { const url = 'blob:' + urls.size; urls.set(url, blob); return url; }, revokeObjectURL: url => urls.delete(url) },
    getComputedStyle: () => ({ display: 'block', content: 'normal', opacity: '1', transform: 'none', transformOrigin: '0px 0px',
      boxSizing: 'border-box', left: '0px', top: '0px', bottom: 'auto', width: '12px', height: '7px', color: '#304a35',
      backgroundColor: '#78954b', backgroundImage: 'none', boxShadow: 'none', fontWeight: '700', fontSize: '11px', fontFamily: 'monospace',
      borderTopWidth: '0px', borderRightWidth: '0px', borderBottomWidth: '0px', borderLeftWidth: '0px', borderTopColor: '#304a35',
      borderTopLeftRadius: '4px', borderTopRightRadius: '4px', borderBottomLeftRadius: '4px', borderBottomRightRadius: '4px',
      getPropertyValue: () => '#a1b56b' }),
    document: { getElementById: get, body: { append() {} }, createElement: tag => tag === 'canvas' ? {
      getContext: () => context, toBlob(callback) { encodes.push({ callback, width: this.width, height: this.height }); }
    } : { click() { downloads.push({ href: this.href, name: this.download }); }, remove() {} } }
  };
  vm.runInNewContext(source, sandbox);
  const api = sandbox.LittleDillPhotos, photos = api.create();
  return { api, get, photos, encodes, urls, downloads, shares,
    open: async value => { photos.open(value || pet(), get('room')); await tick(); },
    finish: async (index = 0, blob = new Blob(['png'], { type: 'image/png' })) => { encodes[index].callback(blob); await tick(); } };
}

test('photo labels preserve the name and use current age, variety, and unlocked look', () => {
  const { api } = client();
  assert.equal(api.describe(pet(), now).age, 'Just hatched');
  assert.equal(api.describe(pet(1), now).age, '1 day old');
  const elder = pet(20, { name: 'Émile <3 / 🥒', variety: 'pepper' });
  const details = api.describe(elder, now);
  assert.equal(details.name, elder.name);
  assert.equal(details.variety, 'Pepper Punk');
  assert.equal(details.badge, Life.elder(elder, now).name);
  assert.equal(details.slug, 'e-mile-3');
  assert.match(details.caption, /https:\/\/littledill\.app\//);
  assert.equal(api.describe(pet(4), now).badge, Life.teen(pet(4), now).name);
});

test('unsupported sharing produces a correctly sized PNG download', async () => {
  const app = client(); await app.open();
  assert.equal(app.get('photo-download').disabled, true);
  assert.equal(app.encodes[0].width, 1080); assert.equal(app.encodes[0].height, 1080);
  await app.finish();
  assert.equal(app.get('photo-share').hidden, true);
  app.get('photo-download').click();
  assert.equal(app.downloads[0].name, 'little-dill-sir-crunch-square.png');
  assert.equal(app.urls.get(app.downloads[0].href).type, 'image/png');
  app.get('photo-close').click(); assert.equal(app.urls.size, 0);
});

test('format changes discard a stale render and preserve the captured name', async () => {
  const app = client(), original = pet(); await app.open(original);
  original.name = 'Changed'; app.get('photo-story').click(); await tick();
  assert.equal(app.encodes[1].height, 1920);
  await app.finish(1); const current = app.get('photo-image').src;
  await app.finish(0);
  assert.equal(app.get('photo-image').src, current);
  assert.match(app.get('photo-image').alt, /Sir Crunch/);
  assert.equal(app.get('photo-story').attrs['aria-pressed'], 'true');
  app.get('photo-download').click(); assert.match(app.downloads[0].name, /-story\.png$/);
});

test('sharing sends the prepared PNG and treats cancellation without downloading', async () => {
  const app = client({ share: () => Promise.reject(Object.assign(new Error('cancel'), { name: 'AbortError' })) });
  await app.open(); await app.finish();
  const pending = app.get('photo-share').click();
  assert.equal(app.shares.length, 1);
  assert.equal(app.get('photo-story').disabled, true);
  await pending;
  assert.equal(app.shares[0].files[0].type, 'image/png');
  assert.match(app.shares[0].text, /Sir Crunch/);
  assert.equal(app.downloads.length, 0);
  assert.match(app.get('photo-status').textContent, /whenever you are/);
  assert.equal(app.get('photo-download').disabled, false);
});

test('share failures keep the download available', async () => {
  const app = client({ share: () => Promise.reject(new Error('denied')) });
  await app.open(); await app.finish(); await app.get('photo-share').click();
  assert.match(app.get('photo-status').textContent, /Download the PNG/);
  assert.equal(app.get('photo-download').disabled, false);
});

test('closing a pending render releases it and PNG failures leave close available', async () => {
  const app = client(); await app.open(); app.get('photo-close').click(); await app.finish();
  assert.equal(app.urls.size, 0); assert.equal(app.get('photo-image').hidden, true);
  await app.open(); await app.finish(1, null);
  assert.match(app.get('photo-status').textContent, /Close and try again/);
  assert.equal(app.get('photo-download').disabled, true);
  app.get('photo-close').click(); assert.equal(app.get('photo-dialog').open, false);
});

test('a delayed close event does not discard a reopened photo', async () => {
  const app = client(); await app.open(); await app.finish();
  app.get('photo-dialog').open = false;
  await app.open();
  app.get('photo-dialog').listeners.close();
  await app.finish(1);
  assert.equal(app.get('photo-image').hidden, false);
  assert.equal(app.get('photo-download').disabled, false);
});
