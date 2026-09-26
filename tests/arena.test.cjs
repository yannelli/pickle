const { test } = require('node:test');
const assert = require('node:assert/strict');
const engineModule = import('../server/arena-engine.mjs');
function seeded(seed = 42) { return () => { seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0; return seed / 4294967296; }; }
async function setup() { const api = await engineModule; return { ...api, engine: new api.ArenaEngine({ random: seeded() }) }; }

test('empty gardens fill with honest server bots, displaced one-for-one by humans', async () => {
  const { engine, RULES } = await setup();
  for (let i = 0; i < 12; i++) {
    engine.addPlayer('human-' + i, { name: 'Dilly' });
    assert.equal(engine.humans, i + 1);
    assert.equal([...engine.players.values()].filter(p => p.bot).length, Math.max(0, RULES.population - i - 1));
  }
  engine.removePlayer('human-11'); engine.removePlayer('human-10'); engine.removePlayer('human-9');
  assert.equal(engine.snapshot().bots, RULES.population - 9);
});
test('human room capacity is enforced independently of bots', async () => {
  const { engine, RULES } = await setup();
  for (let i = 0; i < RULES.maxHumans; i++) assert.ok(engine.addPlayer('p-' + i));
  assert.equal(engine.addPlayer('overflow'), null); assert.equal(engine.humans, RULES.maxHumans); assert.equal(engine.snapshot().bots, 0);
});
test('expanded gardens retain food density and use varied, unique everyday handles', async () => {
  const { engine, RULES } = await setup();
  engine.addPlayer('human', { name: 'maya.j' });
  assert.equal(RULES.width * RULES.height / (2400 * 1800), 6.25);
  assert.equal(RULES.foodCount / (RULES.width * RULES.height), 540 / (2400 * 1800));
  assert.equal(RULES.maxHumans, 64);
  const names = [...engine.players.values()].map(p => p.name.toLowerCase());
  assert.equal(new Set(names).size, RULES.population);
  assert.ok(names.every(name => name.length <= 18 && !/\bbot\b|dillbert|briney/.test(name)));
});
test('food lookup crosses bucket edges and updates replacement locations in the same tick', async () => {
  const { engine } = await setup();
  const a = engine.addPlayer('a'), b = engine.addPlayer('b');
  for (const [id, p] of engine.players) if (p.bot) engine.players.delete(id);
  a.x = 179; a.y = 179; b.x = 1200; b.y = 1200;
  engine.food = [{ id: 1, x: 181, y: 181, value: 3 }];
  engine.makeFood = () => ({ id: engine.nextFood++, x: b.x, y: b.y, value: 9 });
  engine.step();
  assert.equal(a.mass, 28);
  assert.equal(b.mass, 34, 'later player can collect a pellet relocated into its bucket');
  assert.equal(engine.food.length, 1);
});
test('food deltas preserve relocated spawn trails, replacements and removals', async () => {
  const { foodDelta } = await import('../server/arena-worker.mjs');
  const before = [[1,100,100,3],[2,200,200,9],[3,300,300,3]];
  const after = [[1,110,130,3],[4,800,900,9],[3,300,300,3]];
  assert.deepEqual(foodDelta(before,after), {foodAdded:[[1,110,130,3],[4,800,900,9]],foodRemoved:[2]});
  assert.deepEqual(foodDelta(after,after), {foodAdded:[],foodRemoved:[]});
  assert.deepEqual(foodDelta(after,[]), {foodAdded:[],foodRemoved:[1,4,3]});
  assert.deepEqual(foodDelta([],before), {foodAdded:before,foodRemoved:[]});
});
test('a full room simulates every split cell and fits the native packet budget', async () => {
  const { engine, RULES, radius } = await setup();
  for (let n = 0; n < RULES.maxHumans; n++) {
    const p = engine.addPlayer(`full-${n}`, { name: `Player ${n}` });
    p.mass = 240; p.x = 350 + (n % 8)*740; p.y = 280 + Math.floor(n/8)*550;
    engine.split(p); p.splitReady = 0; engine.split(p);
    p.shieldUntil = 100; p.mergeUntil = 100;
  }
  for (let tick = 0; tick < 120; tick++) engine.step();
  assert.equal(engine.humans, 64);
  assert.equal(engine.liveCells().length, 256);
  assert.equal(engine.food.length, RULES.foodCount);
  for (const { cell } of engine.liveCells()) {
    assert.ok(Number.isFinite(cell.x+cell.y+cell.mass));
    assert.ok(cell.x >= radius(cell.mass) && cell.x <= RULES.width-radius(cell.mass));
    assert.ok(cell.y >= radius(cell.mass) && cell.y <= RULES.height-radius(cell.mass));
  }
  assert.ok(Buffer.byteLength(JSON.stringify(engine.snapshot())) < 512 * 1024);
});
test('input parser rejects forged state, large payloads, binary data, invalid sequence and nonfinite movement', async () => {
  const { parseIntent } = await setup();
  for (const raw of ['bad', 'x'.repeat(257), '{"type":"state","mass":9999}', '{"type":"input","seq":-1,"x":1,"y":0}', '{"type":"input","seq":1,"x":null,"y":0}', new Uint8Array(3)]) assert.equal(parseIntent(raw), null);
  const intent = parseIntent('{"type":"input","seq":1,"x":500,"y":500,"mass":9999}');
  assert.equal(intent.mass, undefined); assert.ok(Math.hypot(intent.x, intent.y) <= 1.000001);
});
test('movement is server-limited and replayed input sequences do not move a player', async () => {
  const { engine, speed } = await setup(); const p = engine.addPlayer('human');
  engine.food = []; p.x = 1000; p.y = 1000;
  assert.ok(engine.input(p.id, { type: 'input', seq: 1, x: 900, y: 900 }));
  engine.step(0.1); assert.ok(Math.hypot(p.x - 1000, p.y - 1000) <= speed(p.mass) * 0.1 + 0.001);
  assert.equal(engine.input(p.id, { type: 'input', seq: 1, x: -1, y: 0 }), false);
  assert.equal(engine.input('unknown', { type: 'dash' }), false);
});
test('stale input stops movement and disconnected players are removed', async () => {
  const { engine } = await setup(); const p = engine.addPlayer('human'); engine.food = [];
  engine.input(p.id, { type: 'input', seq: 1, x: 1, y: 0 });
  for (let i = 0; i < 12; i++) engine.step();
  const x = p.x; engine.step(); assert.equal(p.x, x);
  engine.removePlayer(p.id); assert.equal(engine.players.has(p.id), false);
});
test('food adds authoritative mass and is replaced without changing food count', async () => {
  const { engine } = await setup(); const p = engine.addPlayer('human');
  engine.food = [{ id: 1, x: p.x, y: p.y, value: 4 }];
  engine.step(); assert.equal(p.mass, 29); assert.equal(engine.food.length, 1); assert.notEqual(engine.food[0].id, 1);
});
test('shields protect new players and cannot be used to eat others', async () => {
  const { engine } = await setup(); const a = engine.addPlayer('a'), b = engine.addPlayer('b');
  engine.food = []; a.mass = 150; b.mass = 25; a.x = b.x = 1000; a.y = b.y = 1000;
  engine.step(); assert.ok(a.alive); assert.ok(b.alive);
  b.shieldUntil = 0; engine.step(); assert.ok(b.alive);
});
test('larger pickles absorb smaller players exactly once and produce a death record', async () => {
  const { engine } = await setup(); const a = engine.addPlayer('a', { name: 'Hunter' }), b = engine.addPlayer('b');
  engine.food = []; a.mass = 80; b.mass = 25; a.x = b.x = 1000; a.y = b.y = 1000; a.shieldUntil = b.shieldUntil = 0;
  engine.step(); assert.equal(b.alive, false); assert.equal(b.eatenBy, 'Hunter'); assert.equal(a.kills, 1); assert.equal(a.mass, 97.5);
  engine.step(); assert.equal(a.kills, 1);
});
test('equal-sized players cannot absorb each other', async () => {
  const { engine } = await setup(); const a = engine.addPlayer('a'), b = engine.addPlayer('b');
  engine.food = []; a.mass = b.mass = 30; a.x = b.x = 1000; a.y = b.y = 1000; a.shieldUntil = b.shieldUntil = 0;
  engine.step(); assert.ok(a.alive && b.alive);
});
test('food and absorbing rivals keep increasing mass beyond 1600 and save the true best', async () => {
  const { engine } = await setup(); const a = engine.addPlayer('a'), b = engine.addPlayer('b');
  for (const [id,p] of engine.players) if (p.bot) engine.players.delete(id);
  a.mass = 1599; a.x = b.x = 1200; a.y = b.y = 900; b.mass = 500;
  engine.food = [{id:1,x:1200,y:900,value:9}];
  engine.step(); assert.equal(a.mass,1608); assert.equal(a.best,1608);
  engine.food = []; a.shieldUntil = b.shieldUntil = 0;
  engine.step(); assert.equal(a.mass,1958); assert.equal(a.best,1958); assert.equal(b.alive,false);
  a.mass = 100000; a.lastMeal = engine.time;
  engine.food = [{id:2,x:a.x,y:a.y,value:9}];
  engine.step(); assert.equal(a.mass,100009); assert.equal(engine.snapshot().players[0].best,100009);
});
test('giant pickles keep growing visibly, moving and staying inside the garden', async () => {
  const { engine, radius, speed, RULES } = await setup(); const p = engine.addPlayer('a');
  for (const [id,other] of engine.players) if (other.bot) engine.players.delete(id);
  engine.food = []; let previousRadius = 0;
  for (const mass of [25,1600,10000,1000000,1e12]) {
    const r = radius(mass); assert.ok(r > previousRadius); previousRadius = r;
    assert.ok(r < RULES.height/4); assert.ok(speed(mass) >= 55);
    p.mass = mass; p.lastMeal = engine.time; p.x = RULES.width/2; p.y = RULES.height/2;
    engine.input(p.id,{type:'input',seq:mass,x:1,y:0}); engine.step(.1);
    assert.ok(p.x > RULES.width/2); assert.ok(Number.isFinite(p.x+p.y+p.mass));
    p.x = 0; p.y = RULES.height; engine.step();
    assert.ok(p.x >= radius(p.mass)); assert.ok(p.y <= RULES.height-radius(p.mass));
  }
});
test('respawn has a server cooldown and resets mass, but preserves session best', async () => {
  const { engine, RULES } = await setup(); const p = engine.addPlayer('a');
  p.alive = false; p.mass = 90; p.best = 90; p.diedAt = engine.time;
  assert.equal(engine.input(p.id, { type: 'respawn' }), false);
  engine.time += 2.1; assert.ok(engine.input(p.id, { type: 'respawn' }));
  assert.equal(p.mass, RULES.startMass); assert.equal(p.best, 90); assert.equal(p.shieldUntil, engine.time + 4);
  assert.equal(engine.input(p.id, { type: 'respawn' }), false);
});
test('dash spends mass, requires movement and respects cooldown', async () => {
  const { engine } = await setup(); const p = engine.addPlayer('a');
  p.mass = 40; assert.equal(engine.dash(p), false); p.dx = 1;
  assert.ok(engine.dash(p)); assert.equal(p.mass, 35); assert.equal(engine.dash(p), false);
  engine.time += 4.1; assert.ok(engine.dash(p)); assert.equal(p.mass, 30);
  engine.time += 4.1; assert.equal(engine.dash(p), false);
});
test('bots independently forage, grow, avoid predators and respawn', async () => {
  const { engine, RULES, radius } = await setup(); engine.addPlayer('human');
  let hadGrowth = false, hadMovement = false;
  const initial = new Map([...engine.players.values()].map(p => [p.id, { x: p.x, y: p.y }]));
  for (let i = 0; i < 1200; i++) {
    engine.step();
    for (const p of engine.players.values()) {
      assert.ok(Number.isFinite(p.x + p.y + p.mass)); assert.ok(p.mass >= 0);
      if (p.alive) { const r = radius(p.mass); assert.ok(p.x >= r - 2 && p.x <= RULES.width - r + 2); }
      if (p.bot && p.best > 100) hadGrowth = true;
      if (p.bot && Math.hypot(p.x - initial.get(p.id).x, p.y - initial.get(p.id).y) > 30) hadMovement = true;
    }
  }
  assert.ok(hadGrowth); assert.ok(hadMovement); assert.equal(engine.food.length, RULES.foodCount);
});
test('snapshots preserve opponent types internally, omit private input fields, and optionally omit food', async () => {
  const { engine, RULES } = await setup(); engine.addPlayer('a');
  const state = engine.snapshot(); assert.equal(state.humans, 1); assert.equal(state.bots, RULES.population - 1);
  assert.equal(state.players[0].seq, undefined); assert.equal(state.players[0].dx, undefined);
  assert.ok(state.food.length); assert.equal(engine.snapshot(false).food, undefined);
});
test('names and appearances are bounded at the server', async () => {
  const { engine, cleanName } = await setup();
  assert.equal(cleanName('\n\t'), 'Dilly'); assert.equal(Array.from(cleanName('🥒'.repeat(30))).length, 18);
  const p = engine.addPlayer('a', { name: 'a\u0000b', brine: 'hacked', outfit: 'unknown' });
  assert.equal(p.name, 'ab'); assert.equal(p.brine, 'classic'); assert.equal(p.outfit, 'sprout');
});
test('pet varieties reach snapshots, fall back within the brine, and spread across bots', async () => {
  const { engine, VARIETIES, BRINES, pickVariety } = await setup();
  assert.equal(engine.addPlayer('a', { brine: 'spicy', variety: 'butter' }).variety, 'butter');
  for (const id of ['b', 'c', 'dd', 'eee']) assert.ok(['chili', 'pepper'].includes(engine.addPlayer(id, { brine: 'spicy', variety: 'hacked' }).variety));
  assert.equal(pickVariety(undefined, 'garlic', 'x'), pickVariety(undefined, 'garlic', 'x'));
  const state = engine.snapshot(false);
  assert.equal(state.players.find(p => p.id === 'a').variety, 'butter');
  const bots = state.players.filter(p => p.bot);
  assert.deepEqual(new Set(bots.map(p => p.variety)), new Set(VARIETIES));
  for (const bot of bots) assert.equal(bot.brine, BRINES[Math.floor(VARIETIES.indexOf(bot.variety) / 2)]);
});
test('joins reject unknown varieties', async () => {
  const { ArenaRoom } = await workerModule;
  const response = await new ArenaRoom({}).fetch(arenaRequest('?assignedRoom=public-1&variety=cucumber'));
  assert.equal(response.status, 400); assert.equal((await response.json()).error, 'Unknown pickle appearance.');
});

test('fresh pickles can forage to dash quickly and reach 100 mass without a long empty-world grind', async () => {
  const { ArenaEngine } = await engineModule;
  for (let seed = 1; seed <= 30; seed++) {
    const engine = new ArenaEngine({ random: seeded(seed) }), player = engine.addPlayer('forager');
    // Test food pacing independently of combat luck, using real movement and pickup rules.
    for (const [id, p] of engine.players) if (p.bot) engine.players.delete(id);
    let dashAt = null, fiftyAt = null, hundredAt = null;
    for (let seq = 1; seq <= 300; seq++) {
      const target = engine.food.reduce((a,b) => !a || Math.hypot(b.x-player.x,b.y-player.y) < Math.hypot(a.x-player.x,a.y-player.y) ? b : a, null);
      const dx = target.x-player.x, dy = target.y-player.y, length = Math.hypot(dx,dy) || 1;
      engine.input(player.id,{type:'input',seq,x:dx/length,y:dy/length}); engine.step();
      if (player.mass >= 35 && dashAt === null) dashAt = engine.time;
      if (player.mass >= 50 && fiftyAt === null) fiftyAt = engine.time;
      if (player.mass >= 100 && hundredAt === null) hundredAt = engine.time;
    }
    assert.ok(dashAt !== null && dashAt < 2, `seed ${seed}: first dash ${dashAt}`);
    assert.ok(fiftyAt !== null && fiftyAt < 4, `seed ${seed}: double size ${fiftyAt}`);
    assert.ok(hundredAt !== null && hundredAt < 10, `seed ${seed}: 100 mass ${hundredAt}`);
  }
});
test('spawn snack trails stay bounded through repeated respawns and do not award idle mass', async () => {
  const { engine, RULES } = await setup(); const p = engine.addPlayer('human');
  for (let n = 0; n < 40; n++) {
    p.alive = false; p.diedAt = engine.time - 3; assert.ok(engine.respawn(p));
    assert.equal(engine.food.length, RULES.foodCount);
    assert.equal(p.mass, RULES.startMass);
    assert.ok(engine.food.every(f => f.x >= 20 && f.x <= RULES.width-20 && f.y >= 20 && f.y <= RULES.height-20));
    assert.ok(engine.food.filter(f => Math.hypot(f.x-p.x,f.y-p.y) < 160).length >= 4);
  }
});
test('early growth never decays and larger pickles retain almost all mass during a quiet minute', async () => {
  const { engine } = await setup(); const p = engine.addPlayer('a');
  for (const [id,b] of engine.players) if (b.bot) engine.players.delete(id);
  engine.food = []; p.mass = 250;
  for (let i = 0; i < 1200; i++) engine.step();
  assert.equal(p.mass,250);
  p.mass = 1000; p.lastMeal = engine.time;
  for (let i = 0; i < 140; i++) engine.step();
  assert.equal(p.mass,1000,'eating grants a grace period');
  for (let i = 0; i < 1200; i++) engine.step();
  assert.ok(p.mass > 950 && p.mass < 1000,'giants should lose less than 5% during a quiet minute');
  engine.food = [{id:99999,x:p.x,y:p.y,value:3}]; engine.step();
  engine.food = []; const fedMass = p.mass;
  for (let i = 0; i < 100; i++) engine.step();
  assert.equal(p.mass,fedMass,'another snack restarts the grace period');
});

async function soloSplit(mass = 240) {
  const api = await setup(), p = api.engine.addPlayer('splitter');
  for (const [id,other] of api.engine.players) if (other.bot) api.engine.players.delete(id);
  api.engine.food = []; p.mass = mass; p.x = 1200; p.y = 900;
  return {...api,p};
}
test('split intent is authoritative, halves eligible pieces and launches in the steering direction', async () => {
  const {engine,p,parseIntent} = await soloSplit(120);
  engine.input(p.id,{type:'input',seq:1,x:1,y:0});
  assert.deepEqual(parseIntent('{"type":"split","mass":999999,"cells":100}'),{type:'split'});
  assert.ok(engine.input(p.id,{type:'split'}));
  assert.equal(p.cells.length,2); assert.equal(p.mass,120); assert.ok(p.cells.every(c => c.mass===60));
  const original = p.cells[0], launched = p.cells[1], start = launched.x;
  engine.step(.1);
  assert.ok(launched.x > start+35); assert.ok(launched.x > original.x);
  assert.equal(new Set(p.cells.map(c => c.id)).size,2);
});
test('split enforces per-piece mass, cooldown and four-piece maximum without spending mass', async () => {
  const {engine,p,RULES} = await soloSplit(59);
  assert.equal(engine.split(p),false); p.mass=240;
  assert.ok(engine.split(p)); assert.equal(engine.split(p),false);
  engine.time += RULES.splitCooldown+.01; assert.ok(engine.split(p));
  assert.equal(p.cells.length,4); assert.equal(p.mass,240);
  engine.time += 2; assert.equal(engine.split(p),false); assert.equal(p.mass,240);
  p.alive=false; assert.equal(engine.split(p),false);
});
test('four independently moving siblings cannot merge early and regroup automatically without losing mass', async () => {
  const {engine,p,RULES} = await soloSplit();
  engine.split(p); engine.time += RULES.splitCooldown+.01; engine.split(p);
  const ready = p.mergeUntil;
  while(engine.time < ready-.1) { engine.step(); assert.equal(p.cells.length,4); }
  assert.equal(p.mass,240);
  for(let n=0;n<100&&p.cells.length>1;n++) engine.step();
  assert.equal(p.cells.length,1); assert.equal(p.mass,240); assert.equal(p.mergeUntil,0);
  assert.ok(engine.time < ready+4,'regroup should finish promptly after the countdown');
});
test('stationary splits use the last heading and remain inside world boundaries', async () => {
  const {engine,p,RULES,radius} = await soloSplit(240);
  engine.input(p.id,{type:'input',seq:1,x:-1,y:0}); engine.input(p.id,{type:'input',seq:2,x:0,y:0});
  p.x=100; p.y=100; engine.split(p);
  assert.ok(p.cells[1].vx<0);
  for(let n=0;n<50;n++) engine.step();
  for(const c of p.cells) { const r=radius(c.mass); assert.ok(c.x>=r&&c.x<=RULES.width-r); assert.ok(c.y>=r&&c.y<=RULES.height-r); }
});
test('eating one piece keeps its owner alive; eliminating its last piece awards exactly one kill', async () => {
  const {engine,p} = await soloSplit(120); const hunter=engine.addPlayer('hunter');
  for(const [id,other] of engine.players) if(other.bot) engine.players.delete(id);
  engine.split(p); engine.food=[]; p.shieldUntil=hunter.shieldUntil=0; hunter.mass=100;
  p.cells[0].x=1000; p.cells[0].y=600; p.cells[1].x=1800; p.cells[1].y=1200;
  for(const c of p.cells) c.vx=c.vy=0;
  hunter.x=1000; hunter.y=600; engine.step();
  assert.equal(p.cells.length,1); assert.ok(p.alive); assert.equal(hunter.kills,0); assert.equal(p.mass,60);
  assert.equal(engine.events[0].eliminated,false); assert.equal(engine.input(p.id,{type:'respawn'}),false);
  hunter.x=p.x; hunter.y=p.y; engine.step();
  assert.equal(p.cells.length,0); assert.equal(p.alive,false); assert.equal(hunter.kills,1);
  assert.equal(engine.events[0].eliminated,true); engine.step(); assert.equal(hunter.kills,1);
  engine.time+=2.1; assert.ok(engine.respawn(p)); assert.equal(p.cells.length,1); assert.equal(p.mass,25); assert.equal(p.splitReady,0);
});
test('absorption compares individual piece mass rather than combined player mass', async () => {
  const {engine,p} = await soloSplit(240); const rival=engine.addPlayer('rival');
  for(const [id,other] of engine.players) if(other.bot) engine.players.delete(id);
  engine.split(p); engine.food=[]; p.shieldUntil=rival.shieldUntil=0; rival.mass=170;
  p.cells[0].x=1000; p.cells[0].y=600; p.cells[1].x=1800; p.cells[1].y=1200;
  for(const c of p.cells) c.vx=c.vy=0;
  rival.x=1000; rival.y=600; engine.step();
  assert.ok(rival.alive&&p.alive); assert.equal(p.cells.length,1); assert.equal(rival.mass,254);
});
test('every piece can forage, but decay allowance and dash cost belong to the whole player', async () => {
  const {engine,p} = await soloSplit(240); engine.split(p);
  for(const c of p.cells) c.vx=c.vy=0;
  p.cells[0].x=600; p.cells[1].x=1800;
  engine.food=p.cells.map((c,i)=>({id:900+i,x:c.x,y:c.y,value:3})); engine.step();
  assert.equal(p.mass,246); assert.ok(p.cells.every(c=>c.mass===123));
  engine.food=[]; p.dx=1; assert.ok(engine.dash(p)); assert.equal(p.mass,241);
  p.mass=1200; engine.time+=1.01; engine.split(p); p.lastMeal=-20;
  const baseline=await soloSplit(1200); baseline.p.lastMeal=-20; baseline.engine.time=engine.time;
  for(let n=0;n<100;n++) { engine.step(); baseline.engine.step(); }
  assert.ok(Math.abs(p.mass-baseline.p.mass)<1e-8,'four pieces must not get four free decay floors');
});
test('split snapshots expose stable cells and regroup countdown while preserving one leaderboard entry', async () => {
  const {engine,p} = await soloSplit(240); engine.split(p); engine.time+=1.01; engine.split(p);
  const snapshot=engine.snapshot(false), player=snapshot.players[0];
  assert.equal(snapshot.players.length,1); assert.equal(snapshot.humans,1); assert.equal(player.cells.length,4);
  assert.equal(player.mass,240); assert.equal(player.merge,12); assert.equal(player.splitCooldown,1);
  assert.ok(player.cells.every(c=>c.vx===undefined&&c.vy===undefined));
  assert.equal(player.cells.reduce((sum,c)=>sum+c.mass,0),player.mass);
  assert.ok(JSON.stringify(snapshot).length<5000);
});
const workerModule = import('../server/arena-worker.mjs');
function arenaRequest(query = '', headers = {}) { return new Request('https://arena.test/arena' + query, { headers: { Upgrade: 'websocket', 'CF-Connecting-IP': '203.0.113.1', ...headers } }); }
function fakeArenas(statuses) {
  const calls = [];
  return { calls, getByName: id => ({ fetch: async req => { calls.push({ id, ip: req.headers.get('X-Arena-Client-IP'), secret: req.headers.get('X-Arena-Proxy-Secret'), room: new URL(req.url).searchParams.get('assignedRoom') }); const status = statuses[calls.length - 1] ?? 200; return Response.json({ id, status }, { status }); } }) };
}
test('public matchmaking skips rooms refusing a full garden or a crowded network', async () => {
  const worker = (await workerModule).default;
  let ARENAS = fakeArenas([429, 503, 200]);
  let response = await worker.fetch(arenaRequest(), { ARENAS });
  assert.equal(response.status, 200); assert.deepEqual(ARENAS.calls.map(c => c.id), ['public-1', 'public-2', 'public-3']); assert.equal(ARENAS.calls[2].room, 'public-3');
  ARENAS = fakeArenas([503, 429, ...Array(14).fill(503)]);
  response = await worker.fetch(arenaRequest(), { ARENAS });
  assert.equal(ARENAS.calls.length, 16); assert.equal(response.status, 429); assert.equal((await response.json()).id, 'public-2');
  ARENAS = fakeArenas(Array(16).fill(503));
  response = await worker.fetch(arenaRequest(), { ARENAS });
  assert.equal(response.status, 503); assert.equal((await response.json()).error, 'All gardens are full. Try again in a moment.');
  ARENAS = fakeArenas([429]);
  response = await worker.fetch(arenaRequest('?room=ABC123'), { ARENAS });
  assert.equal(response.status, 429); assert.deepEqual(ARENAS.calls.map(c => c.id), ['crew-ABC123']);
});
test('forwarded client IPs are trusted only with the matching proxy secret', async () => {
  const worker = (await workerModule).default;
  const proxied = secret => arenaRequest('', { 'X-Arena-Client-IP': '198.51.100.7', 'X-Arena-Proxy-Secret': secret });
  for (const [env, request, ip] of [
    [{ ARENA_PROXY_SECRET: 'brine-secret' }, proxied('brine-secret'), '198.51.100.7'],
    [{ ARENA_PROXY_SECRET: 'brine-secret' }, proxied('brine-secreT'), '203.0.113.1'],
    [{ ARENA_PROXY_SECRET: 'brine-secret' }, proxied('short'), '203.0.113.1'],
    [{ ARENA_PROXY_SECRET: 'brine-secret' }, arenaRequest('', { 'X-Arena-Client-IP': '198.51.100.7' }), '203.0.113.1'],
    [{}, proxied('brine-secret'), '203.0.113.1'],
    [{}, proxied(''), '203.0.113.1'],
    [{}, arenaRequest(), '203.0.113.1']
  ]) {
    const ARENAS = fakeArenas([200]);
    assert.equal((await worker.fetch(request, { ...env, ARENAS })).status, 200);
    assert.equal(ARENAS.calls[0].ip, ip); assert.equal(ARENAS.calls[0].secret, null);
  }
  const { ArenaRoom } = await workerModule, room = new ArenaRoom({});
  for (let i = 0; i < 8; i++) room.sessions.set({}, { ip: '198.51.100.7' });
  const crowded = await room.fetch(arenaRequest('?assignedRoom=public-1', { 'X-Arena-Client-IP': '198.51.100.7' }));
  assert.equal(crowded.status, 429); assert.equal((await crowded.json()).error, 'Too many connections from this network.');
});
test('crew room joins are rate limited per resolved client IP when the binding exists', async () => {
  const worker = (await workerModule).default, keys = [];
  const CREW_JOINS = { limit: async ({ key }) => { keys.push(key); return { success: keys.length <= 1 }; } };
  const env = { ARENA_PROXY_SECRET: 'brine-secret', CREW_JOINS };
  const crew = () => arenaRequest('?room=ABC123', { 'X-Arena-Client-IP': '198.51.100.7', 'X-Arena-Proxy-Secret': 'brine-secret' });
  let ARENAS = fakeArenas([200]);
  assert.equal((await worker.fetch(crew(), { ...env, ARENAS })).status, 200); assert.equal(ARENAS.calls.length, 1);
  ARENAS = fakeArenas([200]);
  const limited = await worker.fetch(crew(), { ...env, ARENAS });
  assert.equal(limited.status, 429); assert.equal((await limited.json()).error, 'Too many private rooms. Try again in a minute.');
  assert.equal(ARENAS.calls.length, 0); assert.deepEqual(keys, ['198.51.100.7', '198.51.100.7']);
  ARENAS = fakeArenas([200]);
  assert.equal((await worker.fetch(arenaRequest(), { ...env, ARENAS })).status, 200); assert.equal(keys.length, 2);
  ARENAS = fakeArenas([200]);
  assert.equal((await worker.fetch(crew(), { ARENAS })).status, 200); assert.equal(ARENAS.calls[0].id, 'crew-ABC123');
});
test('humans cannot take the self label or a bot handle, while bots keep their handles', async () => {
  const { engine, humanName } = await setup();
  for (const name of ['you', ' YOU ', 'You', 'maya.j', 'MAYA.J', 'sophiek', 'Harper', 'you\u2800', 'noah\u3164']) assert.equal(humanName(name), 'Dilly', name);
  for (const name of ['Maya', 'you2', 'your pickle', 'Dilly']) assert.equal(humanName(name), name);
  assert.equal(engine.addPlayer('h1', { name: 'You' }).name, 'Dilly');
  assert.equal(engine.addPlayer('h2', { name: 'noah' }).name, 'Dilly');
  assert.equal(engine.addPlayer('bot-x', { bot: true, name: 'maya.j' }).name, 'maya.j');
});
test('join snapshot starts from the food list the next delta is built against', async () => {
  const { ArenaRoom } = await workerModule, room = new ArenaRoom({}), sent = [];
  const server = { accept() {}, addEventListener() {}, send: data => sent.push(JSON.parse(data)) };
  globalThis.WebSocketPair = function () { return { 0: {}, 1: server }; };
  room.lastFood = [[-1, 10, 10, 0]];
  await room.fetch(arenaRequest('?assignedRoom=public-1&foodDeltas=1')).catch(() => {});
  clearInterval(room.timer); delete globalThis.WebSocketPair;
  assert.deepEqual(sent[1].food, [[-1, 10, 10, 0]]);
});
