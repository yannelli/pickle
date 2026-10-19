const { test } = require('node:test');
const assert = require('node:assert/strict');
const arena = import('../server/arena-engine.mjs');
const fixture = require('./fixtures/arena-parity.json');

function seeded(seed = 23) {
  return () => { seed = (Math.imul(seed,1664525)+1013904223)>>>0; return seed/4294967296; };
}
async function quietEngine() {
  const api = await arena, engine = new api.ArenaEngine({ random: seeded() });
  return { engine, ...api };
}
const dropBots = engine => { for (const [id,p] of engine.players) if (p.bot) engine.players.delete(id); };
const ringOf = (engine, jar, r) => engine.food.filter(f => Math.abs(Math.hypot(f.x-jar.x,f.y-jar.y)-r) < 1);

test('server event rules and goal pool match the shared fixture', async () => {
  const { RULES, GOAL_POOL } = await arena;
  for (const key of ['jarFirstSeconds','jarPeriodSeconds','jarWarnSeconds','jarLingerSeconds','jarPellets','jarRadius','bountyMinMass','bountyBonus','goalCount']) assert.equal(RULES[key], fixture.rules[key], key);
  assert.deepEqual(JSON.parse(JSON.stringify(GOAL_POOL)), fixture.goals.pool);
});

test('a jar warns, spills a bonus ring from existing pellets, lingers, and reschedules', async () => {
  const { engine, RULES, HAZARDS } = await quietEngine();
  engine.step(0);
  assert.equal(engine.snapshot(false).jar, undefined);
  engine.time = RULES.jarFirstSeconds-RULES.jarWarnSeconds-0.05; engine.step(0);
  assert.equal(engine.snapshot(false).jar, undefined);
  engine.step(0.1);
  const warning = engine.snapshot(false).jar;
  assert.ok(warning.warn > 9.8 && warning.warn <= RULES.jarWarnSeconds);
  const margin = RULES.jarRadius;
  assert.ok(warning.x > margin && warning.x < RULES.width-margin && warning.y > margin && warning.y < RULES.height-margin);
  for (const h of HAZARDS) assert.ok(Math.hypot(warning.x-h.x,warning.y-h.y) >= h.r+RULES.jarRadius+250, h.id);
  const ids = engine.food.map(f => f.id).sort((a,b) => a-b);
  engine.time = RULES.jarFirstSeconds; engine.step(0);
  const spilled = engine.snapshot();
  assert.deepEqual(spilled.jar, { x: warning.x, y: warning.y, warn: 0 });
  assert.equal(spilled.food.length, RULES.foodCount);
  assert.deepEqual(engine.food.map(f => f.id).sort((a,b) => a-b), ids, 'pellets move in place and keep their ids');
  const ring = ringOf(engine, warning, RULES.jarRadius);
  assert.equal(ring.length, RULES.jarPellets);
  assert.ok(ring.every(f => f.value === RULES.bonusFoodMass));
  engine.time = RULES.jarFirstSeconds+RULES.jarLingerSeconds-0.1; engine.step(0);
  assert.equal(engine.snapshot(false).jar.warn, 0);
  engine.time = RULES.jarFirstSeconds+RULES.jarLingerSeconds; engine.step(0);
  assert.equal(engine.snapshot(false).jar, undefined);
  assert.equal(engine.nextJarAt, RULES.jarFirstSeconds+RULES.jarPeriodSeconds);
});

test('jar spills reach full-food and delta clients with an unchanged pellet count', async () => {
  const { engine, RULES } = await quietEngine(), { foodDelta } = await import('../server/arena-worker.mjs');
  const { applyFoodUpdate } = await import('../arena-web/arena-core.mjs');
  dropBots(engine);
  const before = engine.snapshot().food;
  engine.time = RULES.jarFirstSeconds; engine.step(0); engine.step(0);
  const after = engine.snapshot().food, changes = foodDelta(before, after);
  assert.equal(changes.foodRemoved.length, 0);
  assert.ok(changes.foodAdded.length >= RULES.jarPellets);
  const byId = rows => [...rows].sort((a,b) => a[0]-b[0]);
  assert.deepEqual(byId(applyFoodUpdate(before, { foodAdded: changes.foodAdded, foodRemoved: changes.foodRemoved })), byId(after));
  assert.equal(applyFoodUpdate(before, { food: after }).length, RULES.foodCount);
});

test('jar state survives a checkpoint taken mid-warning', async () => {
  const { engine, ArenaEngine, RULES } = await quietEngine();
  engine.time = RULES.jarFirstSeconds-4; engine.step(0);
  const warning = engine.snapshot(false).jar;
  const restored = new ArenaEngine({ checkpoint: structuredClone(engine.checkpoint()), random: seeded(5) });
  assert.deepEqual(restored.snapshot(false).jar, warning);
  restored.time = RULES.jarFirstSeconds; restored.step(0);
  assert.deepEqual(restored.snapshot(false).jar, { x: warning.x, y: warning.y, warn: 0 });
  assert.equal(ringOf(restored, warning, RULES.jarRadius).length, RULES.jarPellets);
  const legacy = engine.checkpoint(); delete legacy.jar; delete legacy.nextJarAt; legacy.time = 500;
  const old = new ArenaEngine({ checkpoint: legacy });
  assert.equal(old.jar, null);
  assert.equal(old.nextJarAt, 500+RULES.jarFirstSeconds);
});

test('the heaviest alive player over the threshold carries the bounty', async () => {
  const { engine, RULES } = await quietEngine();
  const a = engine.addPlayer('a',{name:'A'}), b = engine.addPlayer('b',{name:'B'}); dropBots(engine);
  engine.food = []; a.x = 500; a.y = 500; b.x = 3000; b.y = 3000;
  a.mass = RULES.bountyMinMass-1; b.mass = 300; engine.step(0);
  assert.equal(engine.snapshot(false).bounty, undefined);
  a.mass = RULES.bountyMinMass; engine.step(0);
  assert.equal(engine.snapshot(false).bounty, 'a');
  b.mass = 900; engine.step(0);
  assert.equal(engine.snapshot(false).bounty, 'b');
  b.alive = false; engine.step(0);
  assert.equal(engine.snapshot(false).bounty, 'a');
  const bot = engine.addPlayer('bot-90',{name:'Bot',bot:true}); bot.mass = 5000; bot.x = 6000; bot.y = 5000;
  engine.step(0);
  assert.equal(engine.snapshot(false).bounty, 'bot-90', 'bots qualify');
});

test('eating the bounty holder pays 10% of absorbed mass into mass and earnedMass', async () => {
  const { engine, RULES, radius } = await quietEngine();
  const hunter = engine.addPlayer('hunter',{name:'Hunter'}), holder = engine.addPlayer('holder',{name:'Holder'}); dropBots(engine);
  engine.food = [];
  holder.cells = [engine.makeCell(4000,3000,600), engine.makeCell(4600,3000,600)];
  hunter.x = 1000; hunter.y = 1000; hunter.mass = 1100; hunter.shieldUntil = holder.shieldUntil = 0;
  engine.step(0);
  assert.equal(engine.bountyId, 'holder');
  hunter.mass = 2000; hunter.cells[0].x = 4000; hunter.cells[0].y = 3000;
  assert.ok(2000 >= 600*1.22 && radius(2000)-radius(600)*RULES.eatOverlap > 0, 'eat rule unchanged');
  const earnedBefore = hunter.earnedMass;
  engine.step(0);
  assert.equal(holder.cells.length, 1);
  const bonus = 600*0.7*RULES.bountyBonus;
  assert.ok(Math.abs(hunter.mass-(2000+420+bonus)) < 1e-9);
  assert.ok(Math.abs(hunter.earnedMass-earnedBefore-(420+bonus)) < 1e-9);
  assert.equal(engine.bountyId, 'hunter');
  const plain = engine.addPlayer('plain',{name:'Plain'}); dropBots(engine);
  plain.cells = [engine.makeCell(7000,5000,100)]; plain.shieldUntil = 0;
  holder.alive = false; holder.cells = [];
  hunter.cells[0].x = 7000; hunter.cells[0].y = 5000; engine.bountyId = null;
  const massBefore = hunter.mass;
  engine.step(0);
  assert.equal(plain.alive, false);
  assert.ok(Math.abs(hunter.mass-massBefore-70) < 1e-9, 'non-bounty prey pays no bonus');
});

test('humans roll three distinct goals from the pool; bots get none', async () => {
  const { engine, RULES, GOAL_POOL } = await quietEngine();
  const human = engine.addPlayer('human',{name:'Human'}), bot = [...engine.players.values()].find(p => p.bot);
  assert.equal(human.goals.length, RULES.goalCount);
  assert.equal(new Set(human.goals.map(g => g[0])).size, RULES.goalCount);
  for (const [kind,target,progress] of human.goals) { assert.ok(GOAL_POOL[kind].includes(target)); assert.equal(progress, 0); }
  assert.deepEqual(bot.goals, []);
  engine.step(0);
  const snap = engine.snapshot(false), mine = snap.players.find(p => p.id === 'human'), theirs = snap.players.find(p => p.bot);
  assert.equal(mine.goals.length, RULES.goalCount); assert.equal(mine.goalsDone, 0); assert.equal(mine.run.length, 4);
  for (const key of ['goals','goalsDone','run']) assert.equal(key in theirs, false, key);
});

test('goal progress counts this life and goalsDone accumulates across respawns', async () => {
  const { engine, RULES } = await quietEngine();
  const p = engine.addPlayer('human',{name:'Human'}); dropBots(engine);
  p.goals = [['food',2,0],['survive',60,0],['jar',1,0]];
  engine.food = [{id:1,x:p.x,y:p.y,value:3},{id:2,x:p.x+1,y:p.y,value:3}];
  engine.makeFood = () => ({id:engine.nextFood++,x:8000,y:6000,value:3});
  engine.step(0);
  assert.deepEqual(p.goals[0], ['food',2,2]); assert.equal(p.goalsDone, 1);
  engine.time = p.spawnedAt+59.5; engine.step(0);
  assert.equal(p.goals[1][2], 59);
  engine.time = p.spawnedAt+61; engine.step(0);
  assert.deepEqual(p.goals[1], ['survive',60,60]); assert.equal(p.goalsDone, 2);
  engine.jar = { x: p.x+RULES.jarRadius, y: p.y, spillAt: engine.time, spilled: true }; engine.nextJarAt = engine.time+RULES.jarPeriodSeconds;
  engine.step(0);
  assert.deepEqual(p.goals[2], ['jar',1,1]); assert.equal(p.goalsDone, 3);
  engine.step(0); assert.equal(p.goalsDone, 3, 'completed goals pay once');
  const run = engine.snapshot(false).players[0].run;
  assert.equal(run[1], 0); assert.equal(run[3], 1);
  p.alive = false; p.cells = []; p.diedAt = engine.time; engine.time += 5; engine.step(0);
  assert.equal(engine.snapshot(false).players[0].run[2], Math.floor(p.diedAt-p.spawnedAt), 'time alive freezes at death');
  assert.equal(engine.respawn(p), true);
  assert.equal(p.goals.length, RULES.goalCount);
  assert.ok(p.goals.every(g => g[2] === 0));
  assert.equal(p.goalsDone, 3);
  assert.deepEqual([p.runKills,p.runFood,p.runJar,p.runRank], [0,0,0,0]);
});

test('goals and run counters survive checkpoint restore without a reroll', async () => {
  const { engine, ArenaEngine, restorePlayer } = await quietEngine();
  const p = engine.addPlayer('human',{name:'Human'}); dropBots(engine);
  p.goals[0][2] = 1; p.goalsDone = 4; p.runKills = 2; p.runFood = 7;
  const goals = structuredClone(p.goals);
  const restored = new ArenaEngine({ checkpoint: engine.checkpoint(), random: seeded(99) }).players.get('human');
  assert.deepEqual(restored.goals, goals);
  assert.deepEqual([restored.goalsDone,restored.runKills,restored.runFood,restored.spawnedAt], [4,2,7,p.spawnedAt]);
  const fields = structuredClone(p);
  for (const key of ['goals','goalsDone','spawnedAt','runPeak','runKills','runFood','runJar','runRank']) delete fields[key];
  const legacy = restorePlayer(fields);
  assert.deepEqual(legacy.goals, []); assert.equal(legacy.goalsDone, 0); assert.equal(legacy.spawnedAt, p.joinedAt);
});
