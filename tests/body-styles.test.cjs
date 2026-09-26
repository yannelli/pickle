const test = require('node:test');
const assert = require('node:assert/strict');
const fixture = require('./fixtures/arena-parity.json');
const petBody = require('../pet-body.js');

test('six arena bodies share upright profiles and sampled geometry', async () => {
  const { BODY_PROFILES, bodyRadius } = await import('../arena-web/pickle-body.mjs');
  const { VARIETIES, bodyShape, shapeRadius } = await import('../arena-web/arena-core.mjs');
  assert.deepEqual(BODY_PROFILES, fixture.bodyProfiles);
  assert.deepEqual(petBody.profiles, fixture.bodyProfiles);
  assert.equal(new Set(Object.values(VARIETIES).map(v => v.shape)).size, 6);
  for (const row of fixture.bodySamples) {
    assert.ok(Math.abs(petBody.radius(row.shape, row.angle, row.width, row.height) - row.radius) < 1e-9);
    assert.ok(Math.abs(bodyRadius(row.shape, row.angle, row.width, row.height) - row.radius) < 1e-9);
    const variety = Object.keys(VARIETIES).find(id => VARIETIES[id].shape === row.shape);
    const shape = bodyShape({ variety }, 50);
    assert.equal(shape.lean, 0);
    assert.ok(Math.abs(shapeRadius(shape, row.angle) - row.radius) < 1e-9);
    assert.ok(Math.abs(shapeRadius(shape, Math.PI - row.angle) - row.radius) < 1e-9, 'the upright body is left/right symmetric');
  }
});

test('all profiles dent on contact and recover their own silhouette', async () => {
  const { VARIETIES, bodyShape, shapeRadius, makeMembrane, membraneOutline, stepMembrane } = await import('../arena-web/arena-core.mjs');
  const signatures = [];
  for (const variety of Object.keys(VARIETIES)) {
    const shape = bodyShape({ variety }, 50);
    const body = { x: 100, y: 100, shape, m: makeMembrane(72) };
    const original = membraneOutline(shape, body.m);
    signatures.push(JSON.stringify(original));
    const bounds = { width: 100 + shapeRadius(shape, 0) - 4, height: 500 };
    for (let n = 0; n < 120; n++) stepMembrane(body.m, body, [], bounds, { jitter: 0 });
    assert.ok(body.m.dr[0] < -1, variety + ' wall contact');
    assert.ok(Math.abs(body.m.dr[36]) < .1, variety + ' free side');
    for (let n = 0; n < 180; n++) stepMembrane(body.m, body, [], null, { jitter: 0 });
    assert.ok(Math.max(...body.m.dr.map(Math.abs)) < .1, variety + ' recovery');
  }
  assert.equal(new Set(signatures).size, 6);
});

test('split cucumbers use native proportions until regrouped', async () => {
  const { bodyShape, shapeRadius } = await import('../arena-web/arena-core.mjs');
  const shape = bodyShape({ variety: 'pepper', cells: [{}, {}] }, 50);
  assert.equal(shapeRadius(shape, 0), 35);
  assert.equal(shapeRadius(shape, Math.PI / 2), 50);
  assert.equal(bodyShape({ variety: 'pepper', cells: [{}] }, 50).profile, 'ribbed');
});
