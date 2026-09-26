const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const body = require('../pet-body.js');
const life = require('../pet-life.js');
const now = 1800000000000;
const mapping = { dill: 'long', gherkin: 'gherkin', garlic: 'pear', butter: 'round', chili: 'tapered', pepper: 'ribbed' };

test('six saved varieties use distinct upright silhouettes', () => {
  assert.deepEqual(Object.fromEntries(life.VARIETIES.map(v => [v.id, v.shape])), mapping);
  const contours = new Set();
  for (const shape of Object.values(mapping)) {
    const profile = body.profile(shape), points = body.points(shape, profile.width, profile.height);
    assert.equal(points.length, 72);
    contours.add(JSON.stringify(points));
    for (let i = 0; i < 72; i++) {
      const angle = i * Math.PI * 2 / 72;
      const r = body.radius(shape, angle, profile.width, profile.height);
      assert.ok(Number.isFinite(r) && r > 0);
      assert.ok(Math.abs(r - body.radius(shape, Math.PI - angle, profile.width, profile.height)) < 1e-12,
        shape + ' has mirrored left and right sides');
    }
  }
  assert.equal(contours.size, 6);
  assert.deepEqual(body.profile('unknown'), body.profile('long'));
});

test('body geometry distinguishes barrel, pear, tapered, and scalloped forms', () => {
  const r = (shape, angle) => body.radius(shape, angle, 1, 1);
  assert.ok(r('gherkin', Math.PI / 4) > r('round', Math.PI / 4));
  assert.ok(r('pear', Math.PI / 4) > r('pear', -Math.PI / 4));
  assert.ok(r('tapered', Math.PI / 4) < r('tapered', -Math.PI / 4));
  assert.ok(r('ribbed', 0) > 1);
  assert.ok(r('ribbed', Math.asin(1 / 3)) < 1);
});

function client() {
  const nodes = new Map();
  const node = id => {
    if (!nodes.has(id)) nodes.set(id, { dataset: {}, style: {}, attrs: {}, innerHTML: '',
      setAttribute(name, value) { this.attrs[name] = value; },
      toggleAttribute(name, value) { this.attrs[name] = value; } });
    return nodes.get(id);
  };
  const room = { dataset: {}, style: { setProperty(name, value) { this[name] = value; } } };
  const sandbox = { LittleDillBody: body, LittleDillLife: life, document: { getElementById: node } };
  vm.runInNewContext(fs.readFileSync(require.resolve('../pet-art.js'), 'utf8'), sandbox);
  const render = (variety, days, vibe = '') => {
    const pet = { ...life.fresh(now), phase: 'living', name: 'Dill', variety, bornAt: now - days * life.DAY };
    sandbox.LittleDillArt.render(pet, room, now, vibe);
    return sandbox.LittleDillArt.frame(life.stage(pet, now), mapping[variety]);
  };
  return { room, node, render };
}

test('pet art sizes every stage, centers the face, and clips markings to its body', () => {
  const app = client();
  for (const days of [0, 2, 4, 8, 14]) {
    const silhouettes = new Set();
    for (const variety of Object.keys(mapping)) {
      const frame = app.render(variety, days, 'book');
      const svg = app.node('body-art');
      assert.equal(app.room.dataset.shape, mapping[variety]);
      assert.ok(Math.abs(parseFloat(app.room.style['--body-width']) - frame.w - 6) < .001);
      assert.ok(Math.abs(parseFloat(app.room.style['--body-height']) - frame.h - 6) < .001);
      assert.ok(Math.abs(parseFloat(app.room.style['--face-x']) + 16 - frame.w / 2) < .001);
      assert.ok(Math.abs(parseFloat(app.room.style['--face-y']) - frame.face) < .001);
      assert.ok(frame.armEdge < frame.w / 2);
      assert.match(svg.innerHTML, /clip-path="url\(#pet-body-clip\)"/);
      assert.match(svg.innerHTML, /linearGradient/);
      assert.doesNotMatch(svg.innerHTML, /NaN|undefined|null/);
      silhouettes.add(svg.innerHTML.match(/<clipPath[^>]*><path d="([^"]+)"/)[1]);
    }
    assert.equal(silhouettes.size, 6);
  }
});

test('switching a saved variety updates accessory anchors at the same age', () => {
  const app = client();
  app.render('dill', 14, 'book');
  const before = app.node('elder-art').innerHTML;
  app.render('butter', 14, 'book');
  assert.notEqual(app.node('elder-art').innerHTML, before);
  assert.match(app.node('elder-art').innerHTML, /translate\(39 26.52\)/);
  app.render('dill', 0, 'book');
  assert.match(app.node('elder-art').innerHTML, /translate\(21 15\)/);
});

test('the PWA loads and caches the browser body module', () => {
  const html = fs.readFileSync(require.resolve('../index.html'), 'utf8');
  const worker = fs.readFileSync(require.resolve('../sw.js'), 'utf8');
  assert.ok(html.indexOf('src="./pet-body.js"') < html.indexOf('src="./pet-art.js"'));
  assert.match(worker, /'\.\/pet-body.js'/);
  assert.doesNotMatch(html, /data-shape="crooked"|scale: 1\.18 \.87/);
});
