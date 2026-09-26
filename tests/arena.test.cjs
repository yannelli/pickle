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
test('the bot pool has distinct everyday handles', async () => {
  const { BOT_NAMES, cleanName } = await setup();
  assert.ok(BOT_NAMES.length>=240);
  assert.equal(new Set(BOT_NAMES.map(name=>name.toLowerCase())).size,BOT_NAMES.length);
  assert.equal(BOT_NAMES[0],'maya.j'); assert.equal(BOT_NAMES[71],'Harper');
  assert.ok(BOT_NAMES.every(name=>cleanName(name)===name));
});
test('public bot mass is bounded and becomes rarer in each larger band', async () => {
  const { publicBotMass, ArenaEngine, RULES } = await engineModule;
  const random = seeded(17), counts = [0,0,0,0,0];
  for (let n=0;n<100000;n++) {
    const mass = publicBotMass(random);
    assert.ok(mass>=25 && mass<=5000);
    counts[mass<150?0:mass<500?1:mass<1200?2:mass<3000?3:4]++;
  }
  assert.ok(counts.every((count,i)=>i===0 || count<counts[i-1]),counts.join(','));
  assert.ok(counts[4]>1000 && counts[4]<2000,counts.join(','));
  const publicRoom = new ArenaEngine({random:seeded(8),publicRoom:true});
  const human = publicRoom.addPlayer('human',{name:'maya.j'});
  assert.equal(human.mass,RULES.startMass);
  assert.equal(human.name,'Dilly');
  const bots = [...publicRoom.players.values()].filter(p=>p.bot);
  assert.equal(bots.length,RULES.population-1);
  assert.equal(bots.filter(p=>p.profile.hard).length,1);
  assert.equal(new Set([...publicRoom.players.values()].map(p=>p.name.toLowerCase())).size,RULES.population);
  for(let n=0;n<25;n++) publicRoom.addPlayer(`human-${n}`,{name:'Dilly'});
  assert.equal([...publicRoom.players.values()].filter(p=>p.bot&&p.profile.hard).length,1);
  assert.equal(new Set([...publicRoom.players.values()].map(p=>p.name.toLowerCase())).size,RULES.population);
  const checkpoint=publicRoom.checkpoint(); delete checkpoint.publicRoom; delete checkpoint.hardBotId;
  const restored=new ArenaEngine({checkpoint,publicRoom:true,random:seeded(9)});
  assert.equal([...restored.players.values()].filter(p=>p.bot&&p.profile.hard).length,1);
  for(let n=0;n<25;n++) restored.removePlayer(`human-${n}`);
  assert.equal([...restored.players.values()].filter(p=>p.bot&&p.profile.hard).length,1);
  const crew=new ArenaEngine({random:seeded(8)}); crew.addPlayer('crew-member');
  assert.ok([...crew.players.values()].filter(p=>p.bot).every(p=>p.mass>=25&&p.mass<=54&&!p.profile.hard));
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
    p.mass = 480; p.x = 350 + (n % 8)*740; p.y = 280 + Math.floor(n/8)*550;
    for (let split=0;split<3;split++) {p.splitReady=0;engine.split(p);}
    p.shieldUntil = 100; p.mergeUntil = 100;
  }
  for (let tick = 0; tick < 120; tick++) engine.step();
  assert.equal(engine.humans, 64);
  assert.equal(engine.liveCells().length, 512);
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
      if (p.alive) for (const cell of p.cells) { const r = radius(cell.mass); assert.ok(cell.x >= r - 2 && cell.x <= RULES.width - r + 2); }
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
test('pet varieties reach snapshots and checkpoints, fall back within the brine, and spread across bots', async () => {
  const { engine, VARIETIES, BRINES, pickVariety, ArenaEngine } = await setup();
  assert.equal(engine.addPlayer('a', { brine: 'spicy', variety: 'butter' }).variety, 'butter');
  for (const id of ['b', 'c', 'dd', 'eee']) assert.ok(['chili', 'pepper'].includes(engine.addPlayer(id, { brine: 'spicy', variety: 'hacked' }).variety));
  assert.equal(pickVariety(undefined, 'garlic', 'x'), pickVariety(undefined, 'garlic', 'x'));
  const state = engine.snapshot(false);
  assert.equal(state.players.find(p => p.id === 'a').variety, 'butter');
  const bots = state.players.filter(p => p.bot);
  assert.deepEqual(new Set(bots.map(p => p.variety)), new Set(VARIETIES));
  for (const bot of bots) assert.equal(bot.brine, BRINES[Math.floor(VARIETIES.indexOf(bot.variety) / 2)]);
  assert.equal(new ArenaEngine({ checkpoint: engine.checkpoint() }).players.get('a').variety, 'butter');
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
test('split enforces per-piece mass, cooldown and eight-piece maximum without spending mass', async () => {
  const {engine,p,RULES} = await soloSplit(59);
  assert.equal(engine.split(p),false); p.mass=480;
  assert.ok(engine.split(p)); assert.equal(engine.split(p),false);
  engine.time += RULES.splitCooldown+.01; assert.ok(engine.split(p));
  assert.equal(p.cells.length,4); assert.equal(p.mass,480);
  engine.time += RULES.splitCooldown+.01; assert.ok(engine.split(p));
  assert.equal(p.cells.length,8); assert.equal(p.mass,480);
  engine.time += 2; assert.equal(engine.split(p),false); assert.equal(p.mass,480);
  p.alive=false; assert.equal(engine.split(p),false);
});
test('eight independently moving slices cannot merge early and regroup without losing mass', async () => {
  const {engine,p,RULES} = await soloSplit(240);
  for (let split=0;split<3;split++) {engine.time += RULES.splitCooldown+.01; engine.split(p);}
  const ready = p.mergeUntil;
  while(engine.time < ready-.1) { engine.step(); assert.equal(p.cells.length,8); }
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
  p.cells[0].x=1000; p.cells[0].y=600; p.cells[1].x=1800; p.cells[1].y=1000;
  for(const c of p.cells) c.vx=c.vy=0;
  hunter.x=1000; hunter.y=600; engine.step();
  assert.equal(p.cells.length,1); assert.ok(p.alive); assert.equal(hunter.kills,0); assert.equal(p.mass,60);
  assert.equal(engine.snapshot(false).players.find(player => player.id === p.id).hurt,2.4);
  assert.equal(engine.events[0].eliminated,false); assert.equal(engine.input(p.id,{type:'respawn'}),false);
  hunter.x=p.x; hunter.y=p.y; engine.step();
  assert.equal(p.cells.length,0); assert.equal(p.alive,false); assert.equal(hunter.kills,1);
  assert.equal(engine.snapshot(false).players.find(player => player.id === p.id).hurt,0);
  assert.equal(engine.events[0].eliminated,true); engine.step(); assert.equal(hunter.kills,1);
  engine.time+=2.1; assert.ok(engine.respawn(p)); assert.equal(p.cells.length,1); assert.equal(p.mass,25); assert.equal(p.splitReady,0); assert.equal(p.hurtUntil,0);
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

async function fieldPair(mass = 25) {
  const api = await setup(), inside = api.engine.addPlayer('inside'), outside = api.engine.addPlayer('outside');
  for (const [id,p] of api.engine.players) if (p.bot) api.engine.players.delete(id);
  const h = api.HAZARDS[0];
  api.engine.food = []; inside.mass = outside.mass = mass;
  inside.x = h.x; inside.y = h.y; outside.x = 1000; outside.y = 1000;
  return {...api,inside,outside,h};
}
const snapCells = (engine,id) => engine.snapshot(false).players.find(p => p.id === id).cells;
test('kitchen gadget fields appear in every snapshot with the fixed contract', async () => {
  const {engine,HAZARDS,RULES} = await setup();
  const expected = [{id:'slicer-1',kind:'slicer',x:1650,y:1300,r:150},{id:'shaker-1',kind:'shaker',x:4350,y:1300,r:150},{id:'grater-1',kind:'grater',x:3000,y:3250,r:150}];
  assert.deepEqual(HAZARDS,expected); assert.ok(Object.isFrozen(HAZARDS) && HAZARDS.every(Object.isFrozen));
  assert.deepEqual(engine.snapshot().hazards,expected); assert.deepEqual(engine.snapshot(false).hazards,expected);
  assert.deepEqual(JSON.parse(JSON.stringify(engine.snapshot(false))).hazards,expected);
  const {hazardRadius,hazardSlow,leakRate,leakMin,leakMax,leakFloor,spitMass} = RULES;
  assert.deepEqual({hazardRadius,hazardSlow,leakRate,leakMin,leakMax,leakFloor,spitMass},{hazardRadius:150,hazardSlow:0.5,leakRate:0.05,leakMin:4,leakMax:60,leakFloor:500,spitMass:4});
  assert.equal('hazards' in engine.checkpoint(),false);
});
test('draining cells steer at half speed while split launch velocity is unchanged', async () => {
  const {engine,inside,outside} = await fieldPair();
  for (const p of [inside,outside]) engine.input(p.id,{type:'input',seq:1,x:1,y:0});
  let start = [inside.x,outside.x]; engine.step();
  assert.ok(outside.x-start[1] > 9);
  assert.ok(Math.abs((inside.x-start[0])/(outside.x-start[1])-0.5) < 1e-9);
  for (const p of [inside,outside]) { engine.input(p.id,{type:'input',seq:2,x:0,y:0}); p.cells[0].vx = 520; p.cells[0].vy = 0; }
  start = [inside.x,outside.x]; engine.step();
  assert.ok(Math.abs((inside.x-start[0])-(outside.x-start[1])) < 1e-9);
});
test('snapshot cells carry drain only while each cell overlaps a field', async () => {
  const {engine,inside,outside,h,radius} = await fieldPair(1200);
  const edge = h.r+radius(inside.mass);
  inside.x = h.x+edge-1; assert.equal(snapCells(engine,'inside')[0].drain,1);
  inside.x = h.x+edge+1; assert.equal('drain' in snapCells(engine,'inside')[0],false);
  assert.equal('drain' in snapCells(engine,'outside')[0],false);
  engine.split(inside); inside.cells[0].x = h.x; inside.cells[0].y = h.y; inside.cells[1].x = 900; inside.cells[1].y = 900;
  const cells = snapCells(engine,'inside');
  assert.equal(cells[0].drain,1); assert.equal('drain' in cells[1],false);
});
test('leaking stops at the floor and leaves the player alive, even after a minute inside', async () => {
  const {engine,inside,RULES} = await fieldPair(700);
  for (let n = 0; n < 60*RULES.tickRate; n++) { inside.lastMeal=engine.time; engine.step(); assert.ok(inside.mass >= RULES.leakFloor); }
  assert.equal(inside.mass,RULES.leakFloor); assert.ok(inside.alive); assert.equal(inside.cells.length,1);
  assert.equal('drain' in snapCells(engine,'inside')[0],false);
});
test('leaked mass returns as value-4 pellets beyond the far side, and eaten spit becomes normal food', async () => {
  const {engine,RULES,HAZARDS,radius} = await setup(), {foodDelta} = await import('../server/arena-worker.mjs'), h = HAZARDS[0];
  const p = engine.addPlayer('drained');
  for (const [id,o] of engine.players) if (o.bot) engine.players.delete(id);
  for (const f of engine.food) if (Math.hypot(f.x-h.x,f.y-h.y) < 450) { f.x = 5500; f.y = 4000; }
  p.mass = 800; p.x = h.x-150; p.y = h.y;
  const before = engine.snapshot().food, oldIds = new Set(engine.food.map(f => f.id));
  for (let n = 0; n < 100; n++) engine.step();
  const spat = engine.food.filter(f => f.value === RULES.spitMass);
  assert.ok(spat.length >= 8, `spat ${spat.length}`);
  for (const f of spat) {
    const d = Math.hypot(f.x-h.x,f.y-h.y);
    assert.ok(d >= h.r+40-1e-9 && d <= h.r+180+1e-9, `distance ${d}`);
    assert.ok(f.x > h.x, 'spit lands on the far side from the drained cell');
    assert.equal(oldIds.has(f.id),false);
  }
  assert.equal(engine.food.length,RULES.foodCount);
  assert.ok(Math.abs(800-p.mass-(spat.length*RULES.spitMass+engine.hazardLeak['slicer-1'])) < 1e-9);
  const delta = foodDelta(before,engine.snapshot().food);
  assert.equal(delta.foodRemoved.length,spat.length);
  assert.deepEqual(delta.foodAdded.map(f => f[0]).sort(),spat.map(f => f.id).sort());
  engine.players.delete(p.id);
  const pellet = spat[0], eater = engine.addPlayer('eater');
  eater.x = pellet.x; eater.y = pellet.y;
  const eaten = engine.food.filter(f => Math.hypot(f.x-eater.x,f.y-eater.y) < radius(eater.mass)+4);
  const slots = eaten.map(f => engine.food.indexOf(f));
  assert.ok(eaten.includes(pellet) && eaten.every(f => f.value === RULES.spitMass));
  engine.step();
  assert.equal(eater.mass,RULES.startMass+eaten.length*RULES.spitMass);
  assert.ok(eaten.every(f => !engine.food.some(g => g.id === f.id)));
  assert.ok(slots.every(i => [RULES.foodMass,RULES.bonusFoodMass].includes(engine.food[i].value)));
  assert.equal(engine.food.length,RULES.foodCount);
});
test('bots skip food and prey inside fields and steer out from a field edge', async () => {
  const {engine,HAZARDS,radius} = await setup(), h = HAZARDS[0];
  engine.addPlayer('human');
  const bot = [...engine.players.values()].find(p => p.bot);
  for (const [id,p] of engine.players) if (p !== bot) engine.players.delete(id);
  bot.mass = 60; bot.shieldUntil = 0;
  const reach = radius(bot.mass);
  bot.x = h.x+h.r+reach+400; bot.y = h.y;
  engine.food = [{id:1,x:h.x+60,y:h.y,value:3},{id:2,x:bot.x,y:bot.y+250,value:3}];
  engine.think(bot); assert.ok(bot.dy > 0.99, 'targets the pellet outside the field');
  const prey = engine.addPlayer('prey');
  prey.x = h.x; prey.y = h.y; prey.shieldUntil = 0; bot.x = h.x+h.r+reach+200;
  engine.food = [{id:3,x:bot.x,y:bot.y+250,value:3}];
  engine.think(bot); assert.ok(bot.dy > 0.99, 'ignores draining prey');
  engine.players.delete(prey.id);
  bot.x = h.x+h.r+reach-10; bot.y = h.y; bot.botHazardReady = Infinity;
  engine.food = [{id:4,x:h.x-h.r-300,y:h.y,value:3}];
  engine.think(bot); assert.ok(bot.dx > 0, 'steers away from the field centre');
  for (let n = 0; n < 60; n++) engine.step();
  assert.ok(Math.hypot(bot.x-h.x,bot.y-h.y) >= h.r+radius(bot.mass), 'left the field');
});
test('spawn points keep clear of every field', async () => {
  const {engine,HAZARDS,RULES} = await setup(), h = HAZARDS[0];
  const scripted = [(h.x-80)/(RULES.width-160),(h.y-80)/(RULES.height-160),0.1,0.9], next = seeded(7);
  engine.random = () => scripted.length ? scripted.shift() : next();
  assert.deepEqual(engine.spawnPoint(RULES.startMass),{x:80+0.1*(RULES.width-160),y:80+0.9*(RULES.height-160)});
  for (let n = 0; n < 500; n++) {
    const spawn = engine.spawnPoint(RULES.startMass);
    assert.ok(HAZARDS.every(field => Math.hypot(spawn.x-field.x,spawn.y-field.y) >= field.r+250));
  }
});
test('an engine restored from a checkpoint without hazard state still drains and spits', async () => {
  const {engine,ArenaEngine,HAZARDS,RULES} = await setup(), h = HAZARDS[2];
  const p = engine.addPlayer('saved');
  for (const [id,o] of engine.players) if (o.bot) engine.players.delete(id);
  p.mass = 700; p.x = h.x; p.y = h.y;
  const saved = engine.checkpoint();
  assert.equal('hazardLeak' in saved,false);
  const restored = new ArenaEngine({checkpoint:saved,random:seeded(9)}); delete restored.hazardLeak;
  const q = restored.players.get('saved');
  for (let n = 0; n < 200; n++) restored.step();
  assert.ok(q.alive); assert.ok(q.mass < 700);
  assert.ok(restored.food.some(f => f.value === RULES.spitMass));
  assert.equal(restored.food.length,RULES.foodCount);
  assert.ok(restored.hazardLeak['grater-1'] < RULES.spitMass);
});
test('worker health reports gadget fields alongside existing capabilities', async () => {
  const worker = (await import('../server/arena-worker.mjs')).default;
  const body = await (await worker.fetch(new Request('https://arena.test/health'),{})).json();
  assert.deepEqual(body.hazards,['slicer','shaker','grater']); assert.equal(body.hazardRadius,150);
  assert.equal(body.protocol,1); assert.equal(body.durableRecovery,true); assert.equal(body.foodDeltas,true);
  assert.equal(body.maxCells,8); assert.equal(body.reconnectGraceSeconds,30); assert.equal(body.foodCount,3375);
});

test('a giant pickle leaks at most leakMax per second', async () => {
  const { ArenaEngine, RULES, HAZARDS } = await engineModule;
  const engine = new ArenaEngine({ random: () => 0.5 }), cell = engine.makeCell(HAZARDS[0].x, HAZARDS[0].y, 100000);
  engine.leak(HAZARDS[0], cell, 0.1, { replace() {} });
  assert.ok(Math.abs(100000 - cell.mass - RULES.leakMax * 0.1) < 1e-6);
});
test('a gadget slows small players without draining them', async () => {
  const {engine,inside,h} = await fieldPair(50);
  engine.input(inside.id,{type:'input',seq:1,x:1,y:0});
  const start = inside.x;
  for(let n=0;n<20;n++) engine.step();
  assert.equal(inside.mass,50);
  assert.ok(inside.x>start);
  assert.equal('drain' in snapCells(engine,inside.id)[0],false);
  inside.mass=25; inside.x=h.x;
  for(let n=0;n<20;n++) engine.step();
  assert.equal(inside.mass,25);
});
test('a gadget protects 500 mass in each touching piece', async () => {
  const {engine,inside,h} = await fieldPair(1200);
  assert.ok(engine.split(inside));
  for(const cell of inside.cells){cell.x=h.x;cell.y=h.y;cell.vx=cell.vy=0;}
  for(let n=0;n<190;n++) {inside.lastMeal=engine.time;engine.step();}
  assert.equal(inside.cells.length,2);
  assert.ok(Math.abs(inside.mass-1000)<1e-8);
  assert.ok(inside.cells.every(cell=>cell.mass===500));
  assert.ok(snapCells(engine,inside.id).every(cell=>!('drain' in cell)));
});
test('a gadget splits only touching pieces over 2500 with a player-wide two-second cooldown', async () => {
  const {engine,inside,h,RULES} = await fieldPair(5002);
  inside.x=h.x; inside.y=h.y;
  engine.step(0);
  assert.equal(inside.mass,5002); assert.equal(inside.cells.length,2);
  assert.equal(inside.hazardSplitReady,engine.time+2);
  assert.equal(inside.mergeUntil,engine.time+RULES.mergeSeconds);
  assert.equal(engine.split(inside,true),false);
  inside.cells[0].x=h.x; inside.cells[0].y=h.y;
  inside.cells[1].x=900; inside.cells[1].y=900;
  engine.time+=2.01;
  assert.ok(engine.split(inside,true));
  assert.equal(inside.cells.length,3); assert.equal(inside.mass,5002);
  for(const cell of inside.cells){cell.x=h.x;cell.y=h.y;cell.mass=2501;}
  inside.hazardSplitReady=engine.time+2;
  engine.time+=2.01;
  assert.ok(engine.split(inside,true));
  assert.equal(inside.cells.length,6);
  assert.equal(inside.mass,7503);
});
test('eating requires overlap past the published 0.6 prey-radius boundary', async () => {
  const {engine,RULES,radius} = await fieldPair(25);
  const predator=engine.players.get('inside'), prey=engine.players.get('outside');
  engine.food=[]; predator.mass=200; prey.mass=25;
  predator.shieldUntil=prey.shieldUntil=0;
  predator.x=1000;predator.y=1000;
  const boundary=radius(predator.mass)-RULES.eatOverlap*radius(prey.mass);
  prey.x=predator.x+boundary+0.1;prey.y=1000;
  engine.step(0);
  assert.ok(prey.alive);
  prey.x=predator.x+boundary-0.1;
  engine.step(0);
  assert.equal(prey.alive,false);
  assert.equal(RULES.eatOverlap,0.6);
});
test('nonfatal hurt survives checkpoint recovery and decays to zero', async () => {
  const {engine,ArenaEngine} = await setup(), victim=engine.addPlayer('victim'), hunter=engine.addPlayer('hunter');
  for(const [id,p] of engine.players) if(p.bot) engine.players.delete(id);
  victim.mass=120;engine.split(victim);engine.food=[];
  victim.shieldUntil=hunter.shieldUntil=0;hunter.mass=100;
  victim.cells[0].x=hunter.x=1000;victim.cells[0].y=hunter.y=1000;
  victim.cells[1].x=1800;victim.cells[1].y=1000;
  for(const cell of victim.cells) cell.vx=cell.vy=0;
  engine.step(0);
  assert.equal(engine.snapshot(false).players.find(p=>p.id==='victim').hurt,2.4);
  const restored=new ArenaEngine({checkpoint:engine.checkpoint()});
  const saved=restored.players.get('victim');
  assert.equal(saved.hurtUntil,restored.time+2.4);
  restored.time+=2.5;
  assert.equal(restored.snapshot(false).players.find(p=>p.id==='victim').hurt,0);
  const old=engine.checkpoint();delete old.players.find(p=>p.id==='victim').hurtUntil;
  assert.equal(new ArenaEngine({checkpoint:old}).players.get('victim').hurtUntil,0);
});
test('bots retain distinct perception and risk profiles and keep a visible target', async () => {
  const {engine,HAZARDS} = await setup();
  const cautious=engine.addPlayer('bot-1',{bot:true,name:'one'}),bold=engine.addPlayer('bot-4',{bot:true,name:'four'});
  engine.food=[{id:1,x:1000,y:1350,value:3},{id:2,x:1000,y:1030,value:3}];
  for(const bot of [cautious,bold]){bot.x=1000;bot.y=1000;bot.shieldUntil=0;bot.mass=100;}
  assert.ok(cautious.profile.awareness<bold.profile.awareness);
  assert.ok(cautious.profile.intelligence<bold.profile.intelligence);
  assert.ok(cautious.profile.risk<bold.profile.risk);
  engine.think(cautious);assert.equal(cautious.botTarget.id,2);
  engine.food[0].y=1020;
  engine.think(cautious);assert.equal(cautious.botTarget.id,2);
  engine.food=[{id:1,x:1000,y:1300,value:3}];
  cautious.dx=0;engine.think(cautious);assert.equal(cautious.dx,0);
  engine.think(bold);assert.equal(bold.botTarget.id,1);
  assert.ok(HAZARDS.every(h=>Math.hypot(h.x-1000,h.y-1000)>bold.profile.awareness));
});
test('the public hard opponent leads moving prey and uses ordinary movement', async () => {
  const {ArenaEngine,speed} = await engineModule, engine=new ArenaEngine({random:seeded(31),publicRoom:true});
  const bot=engine.addPlayer('bot-1',{bot:true,name:'Adrian'}), prey=engine.addPlayer('human',{name:'Player'});
  for(const [id,p] of engine.players) if(p!==bot&&p!==prey) engine.players.delete(id);
  engine.assignHardBot();engine.food=[];
  bot.mass=500;bot.x=1000;bot.y=2500;bot.shieldUntil=0;
  prey.mass=100;prey.x=1350;prey.y=2500;prey.dy=1;prey.shieldUntil=0;
  engine.time=1;
  engine.think(bot);
  assert.equal(bot.profile.hard,true);assert.ok(bot.dx>0&&bot.dy>0);
  const before={x:bot.x,y:bot.y};engine.step(0.05);
  assert.ok(Math.hypot(bot.x-before.x,bot.y-before.y)<=speed(bot.mass)*0.05+0.001);
});
test('gadget routes keep a direction across food, threat, and split-body trajectories', async () => {
  const {ArenaEngine,HAZARDS,radius} = await engineModule, field=HAZARDS[0];
  for(const scenario of ['food','threat','split']) {
    const engine=new ArenaEngine({random:seeded(103),publicRoom:true});
    const bot=engine.addPlayer('bot-1',{bot:true,name:'Adrian'});
    engine.assignHardBot();engine.food=[];bot.mass=scenario==='split'?6000:scenario==='food'?3000:250;
    bot.x=field.x+field.r+radius(bot.mass)+(scenario==='split'?-1:115);bot.y=field.y;
    bot.shieldUntil=Infinity;bot.botHazardReady=Infinity;
    if(scenario==='split') {assert.ok(engine.split(bot,true));for(const cell of bot.cells)cell.vx=cell.vy=0;bot.hazardSplitReady=Infinity;}
    if(scenario==='threat') {
      const predator=engine.addPlayer('predator',{name:'Predator'});
      predator.mass=10000;predator.x=bot.x+180;predator.y=bot.y;predator.shieldUntil=Infinity;
    } else engine.food=[{id:1,x:field.x-field.r-radius(bot.cells[0].mass)-115,y:field.y,value:3}];
    const startX=bot.x, headings=[];
    for(let tick=0;tick<240;tick++) {
      engine.step();
      if(tick%6===0) headings.push(Math.atan2(bot.dy,bot.dx));
    }
    const flips=headings.slice(1).filter((angle,i)=>Math.cos(angle-headings[i]) < -0.2).length;
    assert.ok(flips<=2,`${scenario}: ${flips} heading reversals`);
    assert.ok(Math.hypot(bot.x-startX,bot.y-field.y)>130,`${scenario}: bot did not progress`);
    if(scenario==='split') assert.ok(bot.cells.some(cell=>Math.hypot(cell.x-field.x,cell.y-field.y)>field.r+radius(cell.mass)), 'a split piece exited');
  }
});
test('bot curiosity enters briefly then retreats without rerolling the encounter', async () => {
  const {engine,HAZARDS,radius} = await setup(), h=HAZARDS[0];
  const bot=engine.addPlayer('bot-4',{bot:true,name:'four'});
  engine.food=[];bot.x=h.x+h.r+radius(bot.mass)+110;bot.y=h.y;
  let rolls=0;engine.random=()=>{rolls++;return 0.5;};
  engine.think(bot);
  assert.equal(bot.botHazard.phase,'approach');assert.ok(bot.dx<0);
  const firstRolls=rolls;
  for(let n=0;n<5;n++) engine.think(bot);
  assert.equal(rolls,firstRolls);
  bot.x=h.x+h.r+radius(bot.mass)-30;
  engine.think(bot);
  assert.equal(bot.botHazard.phase,'retreat');assert.ok(bot.dx>0);
  for(let n=0;n<5;n++) engine.think(bot);
  assert.equal(bot.botHazard.phase,'retreat');assert.equal(rolls,firstRolls);
  bot.x=bot.botHazard.exit.x;bot.y=bot.botHazard.exit.y;engine.think(bot);
  assert.equal(bot.botHazard.phase,'detour');
  bot.x=bot.botHazard.around.x;bot.y=bot.botHazard.around.y;engine.think(bot);
  assert.equal(bot.botHazard,null);assert.ok(bot.botHazardReady>engine.time);
});
test('an avoiding bot clears the field and continues around it without reversing at its exit', async () => {
  const {engine,HAZARDS,radius} = await setup(), h=HAZARDS[0];
  const bot=engine.addPlayer('bot-1',{bot:true,name:'one'});
  engine.food=[{id:1,x:h.x-500,y:h.y,value:3}];
  bot.mass=60;bot.x=h.x+h.r+radius(bot.mass)+110;bot.y=h.y;
  engine.random=()=>0.99;
  engine.think(bot);
  assert.equal(bot.botHazard.phase,'avoid');
  const phases=[];
  for(let n=0;n<220;n++){
    engine.step();
    phases.push(bot.botHazard?.phase || 'clear');
    assert.ok(Math.hypot(bot.x-h.x,bot.y-h.y)>=h.r+radius(bot.mass)-1);
  }
  assert.ok(phases.includes('detour'));
  assert.ok(phases.includes('clear'));
  assert.equal(bot.botHazard,null);
  assert.ok(bot.x<h.x);
  assert.equal(phases.lastIndexOf('avoid'),phases.indexOf('detour')-1);
});
test('rare bot crossings commit to the far side on one encounter roll', async () => {
  const {engine,HAZARDS,radius} = await setup(), h=HAZARDS[0];
  const bot=engine.addPlayer('bot-4',{bot:true,name:'four'});
  engine.food=[];bot.x=h.x+h.r+radius(bot.mass)+110;bot.y=h.y;
  let rolls=0;engine.random=()=>{rolls++;return 0.005;};
  engine.think(bot);
  assert.equal(bot.botHazard.phase,'cross');assert.ok(bot.dx<0);
  for(let n=0;n<10;n++) engine.think(bot);
  assert.equal(rolls,1);assert.equal(bot.botHazard.phase,'cross');
  bot.x=h.x-h.r-radius(bot.mass)-90;engine.think(bot);
  assert.equal(bot.botHazard,null);
});
