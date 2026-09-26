const { test } = require('node:test');
const assert = require('node:assert/strict');
const fixture = require('./fixtures/arena-parity.json');

test('web and server follow the shared arena gameplay fixtures', async () => {
  const web = await import('../arena-web/arena-core.mjs');
  const { RULES } = await import('../server/arena-engine.mjs');
  for (const [key, value] of Object.entries(fixture.rules)) assert.equal(RULES[key], value, key);
  for (const row of fixture.splits) assert.equal(web.splitState(row.player).enabled, row.enabled, row.name);
  for (const row of fixture.radii) assert.ok(Math.abs(web.radius(row.mass) - row.radius) < 1e-9, `radius ${row.mass}`);
  for (const row of fixture.zoom) assert.ok(Math.abs(web.easeZoom(row.current, row.target, row.dt) - row.result) < 1e-9);
  for (const row of fixture.food) {
    const sorted = values => [...values].sort((a, b) => a[0] - b[0]);
    assert.deepEqual(sorted(web.applyFoodUpdate(row.before, row.snapshot)), row.after, row.name);
  }
  for (const [id, look] of Object.entries(fixture.varieties)) assert.deepEqual(web.VARIETIES[id], look, id);
  assert.deepEqual(web.GADGET_STROKE_SECONDS, fixture.gadgetPeriods);
  assert.equal(web.EAT_OVERLAP, RULES.eatOverlap);
  assert.deepEqual(web.SMILES, fixture.smiles);
  let cadence = null;
  for (const row of fixture.pickups) {
    const cue = web.pickupCue(cadence, row.time);
    assert.equal(cue?.index ?? null, row.index);
    if (cue) { assert.ok(Math.abs(cue.volume - row.volume) < 1e-9); cadence = cue; }
  }
});
