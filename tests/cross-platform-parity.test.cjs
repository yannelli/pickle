const { test } = require('node:test');
const assert = require('node:assert/strict');
const fixture = require('./fixtures/arena-parity.json');

test('web and server follow the shared arena gameplay fixtures', async () => {
  const web = await import('../arena-web/arena-core.mjs');
  const { RULES, radius } = await import('../server/arena-engine.mjs');
  for (const [key, value] of Object.entries(fixture.rules)) assert.equal(RULES[key], value, key);
  for (const row of fixture.splits) assert.equal(web.splitState(row.player).enabled, row.enabled, row.name);
  for (const row of fixture.radii) {
    assert.ok(Math.abs(web.radius(row.mass) - row.radius) < 1e-9, `web radius ${row.mass}`);
    assert.ok(Math.abs(radius(row.mass) - row.radius) < 1e-9, `server radius ${row.mass}`);
  }
  for (const row of fixture.joystick) {
    const input = web.stickInput(row.dx, row.dy, row.reach);
    for (const key of ['offsetX', 'offsetY', 'x', 'y']) assert.ok(Math.abs(input[key] - row[key]) < 1e-9, key);
    assert.equal(input.atEdge, row.atEdge);
  }
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

test('web and server follow the shared jar, bounty, goal and recap fixtures', async () => {
  const web = await import('../arena-web/arena-core.mjs');
  const { RULES, GOAL_POOL } = await import('../server/arena-engine.mjs');
  assert.deepEqual(JSON.parse(JSON.stringify(GOAL_POOL)), fixture.goals.pool);
  assert.equal(RULES.goalCount, fixture.rules.goalCount);
  assert.deepEqual({ ...web.JAR }, { warnSeconds: fixture.rules.jarWarnSeconds, lingerSeconds: fixture.rules.jarLingerSeconds, radius: fixture.rules.jarRadius });
  for (const row of fixture.goals.labels) assert.equal(web.goalLabel(row.goal), row.text, row.text);
  for (const row of fixture.eventSnapshots) {
    const { jar, bounty, goals, goalsDone, run } = row;
    assert.deepEqual(web.eventState(row.snapshot, 'you'), { jar, bounty, goals, goalsDone, run }, row.name);
  }
});
