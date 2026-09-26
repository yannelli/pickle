// Dependency-free authoritative simulation. Clients send intent, never position or mass.
export const RULES = Object.freeze({ width: 6000, height: 4500, tickRate: 20, maxHumans: 64, population: 32, foodCount: 3375, foodMass: 3, bonusFoodMass: 9, startMass: 25, shieldSeconds: 4, respawnSeconds: 2, decayFloor: 300, decayGraceSeconds: 8, decayPerSecond: 0.001, maxCells: 8, reconnectGraceSeconds: 30, splitMinMass: 60, splitCooldown: 1, mergeSeconds: 12, eatOverlap: 0.6, hazardRadius: 150, hazardSlow: 0.5, hazardSplitMass: 2500, hazardSplitCooldown: 2, leakRate: 0.05, leakMin: 4, leakMax: 60, leakFloor: 500, spitMass: 4 });
// Kitchen gadgets sit at fixed garden positions, so checkpoints carry no hazard state.
export const HAZARDS = Object.freeze([
  { id: 'slicer-1', kind: 'slicer', x: 1650, y: 1300 }, { id: 'shaker-1', kind: 'shaker', x: 4350, y: 1300 }, { id: 'grater-1', kind: 'grater', x: 3000, y: 3250 }
].map(h => Object.freeze({ ...h, r: RULES.hazardRadius })));
export const BRINES = ['classic', 'garlic', 'spicy'];
export const OUTFITS = ['original', 'sprout', 'bow', 'shades', 'crown', 'party'];
// Pet varieties in brine order: two per brine, matching PickleVariety in the iOS app.
export const VARIETIES = ['dill', 'gherkin', 'garlic', 'butter', 'chili', 'pepper'];
export const BOT_NAMES = Object.freeze(['maya.j', 'alex_27', 'SophieK', 'noah', 'emilyrose', 'Leo99', 'itsChloe', 'sam.r', 'oliver', 'NoraB', 'luke_7', 'isabel', 'Theo', 'grace.m', 'Jules', 'benji', 'zoe17', 'henry', 'mila_', 'jackson', 'AvaGrace', 'rylee', 'ethan_42', 'sienna', 'Finn', 'ellie.j', 'Caleb', 'rubyroo', 'oscar', 'lucy.h', 'daniel', 'Freya', 'Maxwell', 'tess', 'will_8', 'amelia', 'joshua', 'violet', 'Nathan', 'eve_22', 'charlie', 'Leah', 'aaron_7', 'poppy', 'Dylan', 'lilymae', 'owen', 'amber.k', 'Archie', 'hannah', 'eli_19', 'clara', 'mason', 'Sadie', 'jamie', 'alice.w', 'isaac', 'Eva', 'nico_5', 'summer', 'Jordan', 'holly', 'felix', 'rosie', 'miles', 'erin_23', 'seb', 'Maddie', 'cole', 'lauren', 'kai_11', 'Harper',
  // One hundred additional handles; keep the original pool above.
  'tyler.t', 'brooklyn', 'harry_23', 'ivy.w', 'Asher', 'scarlett', 'tommy_8', 'Eliza', 'jayden', 'mia.s', 'Reese', 'cameron_21', 'Phoebe', 'liam.k', 'stella', 'evan_17', 'Juniper', 'morgan', 'rory.g', 'emerson', 'george', 'bella_4', 'Austin', 'florence', 'toby', 'Addison', 'rebecca', 'zach_10', 'maisie', 'tristan', 'ariana', 'hugo_29', 'bailey', 'Cora', 'drew.m', 'jasmine', 'patrick', 'lucas_16', 'jess.m', 'Hayden', 'victoria', 'ted_8', 'rachel', 'Spencer', 'lena', 'jake_31', 'sasha', 'Elliot', 'paige.h', 'milo', 'serena', 'archie_12', 'keira', 'andrew', 'Piper', 'ben_24', 'molly', 'alexis', 'RyanH', 'georgia', 'amelie', 'chase_6', 'daisy.k', 'Rowan', 'sebastian', 'caitlin', 'jude_18', 'naomi', 'Wyatt', 'shelby', 'levi_9', 'vanessa', 'travis', 'Esme', 'matthew', 'lola_25', 'simon', 'Hazel', 'jesse', 'abigail', 'brody_3', 'talia', 'jordan_88', 'beatrice', 'Colin', 'elena', 'callum', 'sydney.m', 'gavin', 'Katie', 'wesley_14', 'harriet', 'derek', 'Lydia', 'louie', 'natasha', 'aiden_2', 'brianna', 'elliott.s', 'mara',
  'adrian', 'alina', 'amira', 'andrea', 'anjali', 'arjun', 'audrey', 'avery', 'benjamin', 'bianca', 'blake', 'camila', 'carter', 'celeste', 'daphne', 'david', 'diego', 'elijah', 'elise', 'felicity', 'frankie', 'gabriel', 'gianna', 'grayson', 'helen', 'imogen', 'ines', 'iris', 'jamal', 'javier', 'joanna', 'jonah', 'julian', 'kiran', 'lara', 'layla', 'lena.p', 'luca', 'lucia', 'malik', 'marina', 'matilda', 'micah', 'nadia', 'nina', 'omar', 'orla', 'parker', 'priya', 'quinn', 'rafael', 'ramona', 'renee', 'rhea', 'rohan', 'rosa', 'sabrina', 'selena', 'simone', 'soren', 'talia.m', 'tariq', 'tessa.k', 'uma', 'valerie', 'vera', 'victor', 'willa', 'yara', 'yasmin', 'yusuf', 'zara', 'zeke', 'zuri']);
export const clamp = (n, a, b) => Math.max(a, Math.min(b, n));
export const radius = mass => {
  const base = 13 + Math.sqrt(Math.max(0, mass)) * 3.4;
  // Mass keeps growing. Taper giant bodies so the fixed garden remains navigable.
  const excess = Math.max(0, base - 149);
  return base <= 149 ? base : 149 + 260 * excess / (260 + excess);
};
export const speed = mass => Math.max(55, 195 / Math.pow(Math.max(25, mass) / 25, 0.16));
const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
const hazardFor = cell => HAZARDS.find(h => distance(cell, h) < h.r + radius(cell.mass));
const crossesField = (start, end, field, clearance) => {
  const dx = end.x-start.x, dy = end.y-start.y, lengthSquared = dx*dx+dy*dy;
  const along = lengthSquared ? clamp(((field.x-start.x)*dx+(field.y-start.y)*dy)/lengthSquared,0,1) : 0;
  return Math.hypot(start.x+dx*along-field.x,start.y+dy*along-field.y) < clearance;
};
const routeAround = (bot, anchor, target, reach) => {
  const route = bot.botRoute, previous = HAZARDS.find(h => h.id === route?.id);
  const blocked = HAZARDS.find(h => crossesField(anchor,target,h,h.r+reach+70));
  const field = previous && (blocked?.id === previous.id || crossesField(anchor,target,previous,previous.r+reach+105)) ? previous : blocked;
  if (!field) { bot.botRoute = null; return target; }
  const gap = Math.hypot(anchor.x-field.x,anchor.y-field.y) || 1;
  const radialX = (anchor.x-field.x)/gap, radialY = (anchor.y-field.y)/gap;
  const turn = route?.id === field.id ? route.turn : Math.sign(radialX*(target.y-anchor.y)-radialY*(target.x-anchor.x)) || (Number(bot.id.slice(4)) % 2 ? 1 : -1);
  bot.botRoute = { id:field.id, turn };
  const clearance = field.r+reach+85;
  const outward = clamp((clearance-gap)/65,0,2);
  const tangentX = -radialY*turn, tangentY = radialX*turn;
  return { x:anchor.x+(tangentX+radialX*outward)*300, y:anchor.y+(tangentY+radialY*outward)*300 };
};
const hazardDetour = (field, reach, sideX, sideY, turn) => {
  const tangentX = -sideY*turn, tangentY = sideX*turn, clearance = field.r+reach+180;
  return {
    exit: { x:field.x+sideX*(field.r+reach+260)+tangentX*clearance, y:field.y+sideY*(field.r+reach+260)+tangentY*clearance },
    around: { x:field.x-sideX*(field.r+reach+160)+tangentX*clearance, y:field.y-sideY*(field.r+reach+160)+tangentY*clearance }
  };
};
const BOT_PROFILES = Object.freeze([
  Object.freeze({ awareness: 300, intelligence: 0.35, risk: 0.15 }),
  Object.freeze({ awareness: 390, intelligence: 0.55, risk: 0.4 }),
  Object.freeze({ awareness: 480, intelligence: 0.75, risk: 0.7 }),
  Object.freeze({ awareness: 570, intelligence: 0.95, risk: 0.9 })
]);
const HARD_PROFILE = Object.freeze({ awareness: 1100, intelligence: 1, risk: 0.8, hard: true });
const botProfile = id => BOT_PROFILES[(Number(String(id).replace(/^bot-/, '')) - 1 + BOT_PROFILES.length) % BOT_PROFILES.length] || BOT_PROFILES[0];
export const publicBotMass = random => {
  const roll = random();
  if (roll < 0.55) return 25 + Math.floor(random()*125);
  if (roll < 0.82) return 150 + Math.floor(random()*350);
  if (roll < 0.94) return 500 + Math.floor(random()*700);
  if (roll < 0.985) return 1200 + Math.floor(random()*1800);
  return 3000 + Math.floor(random()*2001);
};
// Broad-phase food lookup keeps a larger garden cheap even with 64 split players.
class FoodGrid {
  constructor(food) {
    this.buckets = new Map();
    food.forEach((pellet, index) => this.add(index, pellet));
  }
  key(food) { return `${Math.floor(food.x / 180)},${Math.floor(food.y / 180)}`; }
  add(index, food) {
    const key = this.key(food);
    if (!this.buckets.has(key)) this.buckets.set(key, new Set());
    this.buckets.get(key).add(index);
  }
  replace(index, before, after) {
    this.buckets.get(this.key(before))?.delete(index);
    this.add(index, after);
  }
  near(cell, reach) {
    const indices = [];
    for (let x = Math.floor((cell.x-reach)/180); x <= Math.floor((cell.x+reach)/180); x++) {
      for (let y = Math.floor((cell.y-reach)/180); y <= Math.floor((cell.y+reach)/180); y++) {
        for (const index of this.buckets.get(`${x},${y}`) || []) indices.push(index);
      }
    }
    return indices;
  }
}
export function cleanName(name) { return Array.from(String(name || 'Dilly').replace(/[\p{C}\u115F\u1160\u2800\u3164\uFFA0]/gu, '').trim()).slice(0, 18).join('') || 'Dilly'; }
const RESERVED_NAMES = new Set(['you', ...BOT_NAMES].map(name => name.toLowerCase()));
export function humanName(name) { const clean = cleanName(name); return RESERVED_NAMES.has(clean.toLowerCase()) ? 'Dilly' : clean; }
// Older clients send no variety, so pick one of their brine's two from the player ID.
export function pickVariety(variety, brine, id = '') {
  if (VARIETIES.includes(variety)) return variety;
  const pair = Math.max(0, BRINES.indexOf(brine)) * 2;
  return VARIETIES[pair + ([...String(id)].reduce((sum, c) => sum + c.charCodeAt(0), 0) & 1)];
}
export function parseIntent(raw) {
  if (typeof raw !== 'string' || raw.length > 256) return null;
  let p; try { p = JSON.parse(raw); } catch { return null; }
  if (p?.type === 'input' && Number.isSafeInteger(p.seq) && p.seq >= 0 && p.seq < 2147483647 && Number.isFinite(p.x) && Number.isFinite(p.y)) {
    let x = clamp(p.x, -1, 1), y = clamp(p.y, -1, 1); const length = Math.hypot(x, y);
    if (length > 1) { x /= length; y /= length; }
    return { type: 'input', seq: p.seq, x, y };
  }
  if (p?.type === 'dash' || p?.type === 'split' || p?.type === 'respawn' || p?.type === 'ping' || p?.type === 'leave') return { type: p.type };
  return null;
}

// Structured storage turns accessors into values; rebuild the live aggregates.
export function restorePlayer(fields) {
  return {
    hurtUntil: 0, hazardSplitReady: 0, botHazard: null, botHazardReady: 0, botTarget: null, botRoute: null, ...(fields.bot ? { profile: botProfile(fields.id) } : {}), ...fields,
    get mass() { return this.cells.reduce((sum,c) => sum+c.mass,0); },
    set mass(value) { const total = this.mass; if (this.cells.length === 1) this.cells[0].mass = value; else if (total > 0) for (const c of this.cells) c.mass *= value/total; },
    get x() { const total = this.mass; return total > 0 ? this.cells.reduce((sum,c) => sum+c.x*c.mass,0)/total : this.lastX; },
    set x(value) { const delta = value-this.x; for (const c of this.cells) c.x += delta; this.lastX = value; },
    get y() { const total = this.mass; return total > 0 ? this.cells.reduce((sum,c) => sum+c.y*c.mass,0)/total : this.lastY; },
    set y(value) { const delta = value-this.y; for (const c of this.cells) c.y += delta; this.lastY = value; }
  };
}

export class ArenaEngine {
  constructor({ random = Math.random, checkpoint, publicRoom = false } = {}) {
    this.random = random; this.time = 0; this.tick = 0; this.players = new Map(); this.food = []; this.events = []; this.nextFood = 1; this.nextBot = 1; this.nextCell = 1; this.hazardLeak = {}; this.publicRoom = publicRoom; this.hardBotId = null;
    if (checkpoint) {
      Object.assign(this,structuredClone(checkpoint));
      this.publicRoom = checkpoint.publicRoom ?? publicRoom;
      this.players = new Map(this.players.map(p => [p.id,restorePlayer(p)]));
      this.assignHardBot();
      return;
    }
    for (let i = 0; i < RULES.foodCount; i++) this.food.push(this.makeFood());
  }
  checkpoint() {
    return structuredClone({ time:this.time, tick:this.tick, players:[...this.players.values()], food:this.food, nextFood:this.nextFood, nextBot:this.nextBot, nextCell:this.nextCell, publicRoom:this.publicRoom, hardBotId:this.hardBotId });
  }
  makeCell(x, y, mass) { return { id: `cell-${this.nextCell++}`, x, y, mass, vx: 0, vy: 0 }; }
  liveCells() { return [...this.players.values()].filter(p => p.alive).flatMap(owner => owner.cells.map(cell => ({ owner, cell }))); }
  boundCell(cell) { const r = radius(cell.mass); cell.x = clamp(cell.x, r, RULES.width-r); cell.y = clamp(cell.y, r, RULES.height-r); }
  makeFood() { return { id: this.nextFood++, x: 20 + this.random() * (RULES.width - 40), y: 20 + this.random() * (RULES.height - 40), value: this.random() > 0.9 ? RULES.bonusFoodMass : RULES.foodMass }; }
  seedSpawnFood(player) {
    // A short trail gives every fresh spawn a visible route to the first dash.
    // Relocate distant pellets: food count stays bounded, even after repeated respawns.
    const candidates = this.food.filter(f => distance(f, player) > 350).sort((a,b) => distance(b,player) - distance(a,player)).slice(0,10);
    const angle = Math.atan2(RULES.height/2-player.y,RULES.width/2-player.x);
    candidates.forEach((f,i) => {
      const reach = 65 + i*23, bend = angle + Math.sin(i*0.7)*0.2;
      f.x = clamp(player.x+Math.cos(bend)*reach,30,RULES.width-30);
      f.y = clamp(player.y+Math.sin(bend)*reach,30,RULES.height-30);
      f.value = RULES.foodMass;
    });
  }
  get humans() { return [...this.players.values()].filter(p => !p.bot).length; }
  spawnPoint(mass) {
    let candidate = { x: RULES.width / 2, y: RULES.height / 2 };
    let best = candidate, bestDistance = -1;
    for (let i = 0; i < 24; i++) {
      candidate = { x: 80 + this.random() * (RULES.width - 160), y: 80 + this.random() * (RULES.height - 160) };
      if (HAZARDS.some(h => distance(candidate, h) < h.r + 250)) continue;
      const nearest = Math.min(1000, ...this.liveCells().filter(({cell}) => cell.mass > mass).map(({cell}) => distance(candidate, cell) - radius(cell.mass)));
      if (nearest > bestDistance) { best = candidate; bestDistance = nearest; }
      if (nearest > 260) break;
    }
    return best;
  }
  addPlayer(id, { name, brine, outfit, variety, bot = false } = {}) {
    if (this.players.has(id) || (!bot && this.humans >= RULES.maxHumans)) return null;
    const mass = bot ? this.publicRoom ? publicBotMass(this.random) : 25 + Math.floor(this.random() * 30) : RULES.startMass;
    const spawn = this.spawnPoint(mass);
    const p = restorePlayer({
      id, name: this.uniqueName(bot ? cleanName(name) : humanName(name)), brine: BRINES.includes(brine) ? brine : 'classic', outfit: OUTFITS.includes(outfit) ? outfit : 'sprout', variety: pickVariety(variety, brine, id), bot,
      cells: [this.makeCell(spawn.x,spawn.y,mass)], lastX: spawn.x, lastY: spawn.y,
      best: mass, kills: 0, alive: true, dx: 0, dy: 0, aimX: 0, aimY: -1, seq: -1, lastInput: this.time, lastMeal: this.time,
      shieldUntil: this.time + RULES.shieldSeconds, dashUntil: 0, dashReady: 0, splitReady: 0, hazardSplitReady: 0, mergeUntil: 0, hurtUntil: 0, diedAt: 0, eatenBy: '', joinedAt: this.time
    });
    this.players.set(id, p);
    if (!bot) { this.balanceBots(); this.seedSpawnFood(p); }
    return p;
  }
  removePlayer(id) { this.players.delete(id); this.balanceBots(); }
  uniqueName(name) {
    const used = new Set([...this.players.values()].map(p => p.name.toLowerCase()));
    if (!used.has(name.toLowerCase())) return name;
    for (let n = 2; ; n++) {
      const suffix = `_${n}`, candidate = name.slice(0,18-suffix.length)+suffix;
      if (!used.has(candidate.toLowerCase())) return candidate;
    }
  }
  assignHardBot() {
    const bots = [...this.players.values()].filter(p => p.bot);
    if (!this.publicRoom || !bots.length) { this.hardBotId = null; for (const bot of bots) bot.profile = botProfile(bot.id); return; }
    if (!bots.some(bot => bot.id === this.hardBotId)) this.hardBotId = bots[0].id;
    for (const bot of bots) bot.profile = bot.id === this.hardBotId ? HARD_PROFILE : botProfile(bot.id);
  }
  balanceBots() {
    const target = Math.max(0, RULES.population - this.humans);
    const bots = [...this.players.values()].filter(p => p.bot);
    while (bots.length > target) this.players.delete(bots.pop().id);
    while (bots.length < target) {
      const n = this.nextBot++;
      const usedNames = new Set([...this.players.values()].map(p => p.name.toLowerCase()));
      const availableNames = BOT_NAMES.filter(name => !usedNames.has(name.toLowerCase()));
      const name = availableNames[Math.floor(this.random()*availableNames.length)] || `guest_${n}`;
      const variety = VARIETIES[(n + Math.floor(n / VARIETIES.length)) % VARIETIES.length];
      const bot = this.addPlayer(`bot-${n}`, { bot: true, name, brine: BRINES[Math.floor(VARIETIES.indexOf(variety) / 2)], outfit: OUTFITS[n % OUTFITS.length], variety });
      bots.push(bot);
    }
    this.assignHardBot();
  }
  input(id, intent) {
    const p = this.players.get(id); if (!p || p.bot) return false;
    if (intent.type === 'input') {
      if (!p.alive || intent.seq <= p.seq || !Number.isFinite(intent.x) || !Number.isFinite(intent.y)) return false;
      const length = Math.max(1, Math.hypot(intent.x, intent.y));
      p.dx = clamp(intent.x / length, -1, 1); p.dy = clamp(intent.y / length, -1, 1); p.seq = intent.seq; p.lastInput = this.time;
      if (Math.hypot(p.dx,p.dy) > 0.1) { p.aimX = p.dx; p.aimY = p.dy; }
      return true;
    }
    if (intent.type === 'dash') return this.dash(p);
    if (intent.type === 'split') return this.split(p);
    if (intent.type === 'respawn') return this.respawn(p);
    return intent.type === 'ping';
  }
  dash(p) {
    if (!p.alive || p.mass < 35 || p.dashReady > this.time || Math.hypot(p.dx, p.dy) < 0.1) return false;
    p.mass -= 5; p.dashUntil = this.time + 0.65; p.dashReady = this.time + 4;
    return true;
  }
  split(p, forced = false) {
    if (!p.alive || (forced ? p.hazardSplitReady : p.splitReady) > this.time || p.cells.length >= RULES.maxCells) return false;
    const eligible = p.cells.filter(c => forced ? c.mass > RULES.hazardSplitMass && hazardFor(c) : c.mass >= RULES.splitMinMass).sort((a,b) => b.mass-a.mass).slice(0,RULES.maxCells-p.cells.length);
    if (!eligible.length) return false;
    const heading = Math.hypot(p.dx,p.dy) > 0.1 ? {x:p.dx,y:p.dy} : {x:p.aimX,y:p.aimY};
    const length = Math.hypot(heading.x,heading.y) || 1, dx = heading.x/length, dy = heading.y/length;
    for (const cell of eligible) {
      cell.mass /= 2;
      const offset = Math.min(45,radius(cell.mass)*0.6);
      const launched = this.makeCell(cell.x+dx*offset,cell.y+dy*offset,cell.mass);
      cell.x -= dx*offset; cell.y -= dy*offset;
      launched.vx = dx*520; launched.vy = dy*520;
      cell.vx -= dx*45; cell.vy -= dy*45;
      this.boundCell(cell); this.boundCell(launched); p.cells.push(launched);
    }
    if (forced) p.hazardSplitReady = this.time+RULES.hazardSplitCooldown;
    else p.splitReady = this.time+RULES.splitCooldown;
    p.mergeUntil = this.time+RULES.mergeSeconds;
    return true;
  }
  respawn(p) {
    if (p.alive || this.time - p.diedAt < RULES.respawnSeconds) return false;
    const spawn = this.spawnPoint(RULES.startMass);
    p.cells = [this.makeCell(spawn.x,spawn.y,RULES.startMass)];
    Object.assign(p, { alive: true, dx: 0, dy: 0, aimX: 0, aimY: -1, lastMeal: this.time, shieldUntil: this.time + RULES.shieldSeconds, dashUntil: 0, dashReady: 0, splitReady: 0, hazardSplitReady: 0, mergeUntil: 0, hurtUntil: 0, eatenBy: '', botHazard: null, botTarget: null, botRoute: null });
    if (!p.bot) this.seedSpawnFood(p);
    return true;
  }
  think(bot) {
    if (!bot.alive) { this.respawn(bot); return; }
    const anchor = bot.cells.reduce((a,b) => a.mass > b.mass ? a : b), reach = radius(anchor.mass), profile = bot.profile || botProfile(bot.id);
    const others = this.liveCells().filter(({owner,cell}) => owner !== bot && distance(cell,anchor) < profile.awareness);
    const threat = others.filter(({cell}) => cell.mass > anchor.mass*(1.15+profile.risk*0.35)).sort((a,b) => distance(a.cell,anchor)-distance(b.cell,anchor))[0];
    const nearHazard = HAZARDS.find(h => distance(anchor,h) < h.r+reach+130);
    let encounter = bot.botHazard, field = encounter && HAZARDS.find(h => h.id === encounter.id);
    if (!encounter && nearHazard && this.time >= bot.botHazardReady) {
      const gap = distance(anchor,nearHazard) || 1, cross = this.random() < 0.0075;
      const sideX = (anchor.x-nearHazard.x)/gap, sideY = (anchor.y-nearHazard.y)/gap;
      encounter = { id:nearHazard.id, phase:cross ? 'cross' : this.random() < 0.3+profile.risk*0.55 ? 'approach' : 'avoid', sideX, sideY, until:this.time+2.8, ...hazardDetour(nearHazard,reach,sideX,sideY,Number(bot.id.slice(4))%2 ? 1 : -1) };
      bot.botHazard = encounter; field = nearHazard;
    }
    if (encounter && field && !encounter.exit) Object.assign(encounter,hazardDetour(field,reach,encounter.sideX,encounter.sideY,1));
    let target, away = false, prey;
    if (threat) { target = threat.cell; away = true; if (profile.intelligence > 0.5 && this.random() < 0.12) this.dash(bot); }
    else if (encounter && field) {
      const gap = distance(anchor,field);
      if (encounter.phase === 'approach' && (gap < field.r+reach-25 || this.time >= encounter.until)) encounter.phase = 'retreat';
      if (encounter.phase === 'cross' && (anchor.x-field.x)*encounter.sideX+(anchor.y-field.y)*encounter.sideY < -field.r-reach-80) {
        bot.botHazard = encounter = null; bot.botHazardReady = this.time+4;
      }
      if (encounter && ['avoid','retreat'].includes(encounter.phase) && distance(anchor,encounter.exit) < 75) encounter.phase = 'detour';
      if (encounter?.phase === 'detour' && distance(anchor,encounter.around) < 75) {
        bot.botHazard = encounter = null; bot.botHazardReady = this.time+4;
      }
      if (encounter) {
        if (encounter.phase === 'avoid' || encounter.phase === 'retreat') target = encounter.exit;
        else if (encounter.phase === 'detour') target = encounter.around;
        else {
          const direction = encounter.phase === 'cross' ? -1 : -0.15;
          target = { x:field.x+encounter.sideX*(field.r+reach+240)*direction, y:field.y+encounter.sideY*(field.r+reach+240)*direction };
        }
      }
    }
    if (!target && !threat) {
      const visible = others.filter(({owner,cell}) => anchor.mass > cell.mass*1.22 && owner.shieldUntil < this.time && !HAZARDS.some(h => distance(cell,h) < h.r+reach+80)).sort((a,b) => distance(a.cell,anchor)-distance(b.cell,anchor));
      prey = visible.find(({cell}) => anchor.mass/cell.mass > 1.45-profile.risk*0.2);
      const food = this.food.filter(f => distance(f,anchor) < profile.awareness && !HAZARDS.some(h => distance(f,h) < h.r+reach+80));
      const remembered = bot.botTarget && (bot.botTarget.kind === 'prey' ? visible.find(({cell}) => cell.id === bot.botTarget.id)?.cell : food.find(f => f.id === bot.botTarget.id));
      target = remembered || (prey && (profile.risk > 0.6 || !food.length) ? prey.cell : food.reduce((best,f) => !best || distance(f,anchor)-f.value*profile.intelligence*8 < distance(best,anchor)-best.value*profile.intelligence*8 ? f : best,null)) || prey?.cell;
      bot.botTarget = target ? { kind:visible.some(({cell}) => cell === target) ? 'prey' : 'food', id:target.id } : null;
    }
    if (!target && nearHazard) {
      const gap = distance(anchor,nearHazard) || 1;
      target = { x:nearHazard.x+(anchor.x-nearHazard.x)/gap*(nearHazard.r+reach+240), y:nearHazard.y+(anchor.y-nearHazard.y)/gap*(nearHazard.r+reach+240) };
    }
    if (!target) return;
    if (profile.hard && prey && !away && target === prey.cell) {
      const lead = Math.min(1.4,distance(anchor,target)/Math.max(1,speed(anchor.mass)));
      target = { x:clamp(target.x+prey.owner.dx*speed(target.mass)*lead,0,RULES.width), y:clamp(target.y+prey.owner.dy*speed(target.mass)*lead,0,RULES.height) };
    }
    if (away) target = { x:anchor.x+(anchor.x-target.x), y:anchor.y+(anchor.y-target.y) };
    if (!encounter || away) target = routeAround(bot,anchor,target,reach);
    let x = target.x-anchor.x, y = target.y-anchor.y;
    if (away) { if (anchor.x < 100) x += 250; if (anchor.x > RULES.width-100) x -= 250; if (anchor.y < 100) y += 250; if (anchor.y > RULES.height-100) y -= 250; }
    let length = Math.hypot(x,y) || 1; x /= length; y /= length;
    length = Math.hypot(x,y) || 1; bot.dx = x/length; bot.dy = y/length; bot.aimX = bot.dx; bot.aimY = bot.dy;
    if (prey && !away && bot.cells.length === 1 && anchor.mass/2 > prey.cell.mass*1.3 && distance(anchor,prey.cell) > radius(anchor.mass) && profile.risk > 0.6 && this.random() < 0.06) this.split(bot);
  }
  regroup(p, dt) {
    const ready = this.time >= p.mergeUntil;
    for (let i = 0; i < p.cells.length; i++) for (let j = i+1; j < p.cells.length; j++) {
      const a = p.cells[i], b = p.cells[j], separation = distance(a,b), reach = radius(a.mass)+radius(b.mass);
      if (ready && separation < reach*0.65) {
        const mass = a.mass+b.mass;
        a.x = (a.x*a.mass+b.x*b.mass)/mass; a.y = (a.y*a.mass+b.y*b.mass)/mass;
        a.vx = (a.vx*a.mass+b.vx*b.mass)/mass; a.vy = (a.vy*a.mass+b.vy*b.mass)/mass;
        a.mass = mass; p.cells.splice(j--,1);
      } else if (!ready && separation < reach) {
        // Siblings stay visibly distinct until their regroup timer expires.
        const dx = separation > 0.001 ? (b.x-a.x)/separation : 1;
        const dy = separation > 0.001 ? (b.y-a.y)/separation : 0;
        const push = (reach-separation)*Math.min(0.5,dt*6), total = a.mass+b.mass;
        a.x -= dx*push*b.mass/total; a.y -= dy*push*b.mass/total;
        b.x += dx*push*a.mass/total; b.y += dy*push*a.mass/total;
      }
    }
    if (p.cells.length === 1) p.mergeUntil = 0;
  }
  leak(hazard, cell, dt, foodGrid, available = Infinity) {
    const before = cell.mass;
    cell.mass -= Math.min(Math.max(0,available),Math.max(0,before-RULES.leakFloor),clamp(before*RULES.leakRate,RULES.leakMin,RULES.leakMax)*dt);
    const pending = this.hazardLeak ??= {};
    pending[hazard.id] = (pending[hazard.id] ?? 0)+before-cell.mass;
    while (pending[hazard.id] >= RULES.spitMass) { pending[hazard.id] -= RULES.spitMass; this.spit(hazard,cell,foodGrid); }
  }
  // Relocate a distant pellet beyond the field so food count stays fixed; a failed search drops the mass.
  spit(hazard, cell, foodGrid) {
    for (let tries = 0; tries < 8 && this.food.length; tries++) {
      const i = Math.floor(this.random()*this.food.length), before = this.food[i];
      if (distance(before,hazard) <= 700 || before.value === RULES.spitMass) continue;
      const angle = Math.atan2(hazard.y-cell.y,hazard.x-cell.x)+(this.random()-0.5)*2.4, reach = hazard.r+40+this.random()*140;
      const after = { id: this.nextFood++, x: clamp(hazard.x+Math.cos(angle)*reach,30,RULES.width-30), y: clamp(hazard.y+Math.sin(angle)*reach,30,RULES.height-30), value: RULES.spitMass };
      this.food[i] = after; foodGrid.replace(i,before,after);
      return;
    }
  }
  step(dt = 1 / RULES.tickRate) {
    dt = clamp(Number.isFinite(dt) ? dt : 0,0,0.1);
    this.time += dt; this.tick++; this.events = [];
    // Spread decisions over six ticks instead of pausing every bot on the same frame.
    for (const p of this.players.values()) if (p.bot && Number(p.id.slice(4)) % 6 === this.tick % 6) this.think(p);
    const foodGrid = new FoodGrid(this.food);
    for (const p of this.players.values()) {
      if (!p.alive) continue;
      if (!p.bot && this.time-p.lastInput > 0.4) { p.dx = 0; p.dy = 0; }
      // Decay applies once to total mass, so splitting cannot multiply the free allowance.
      if (p.mass > RULES.decayFloor && this.time-p.lastMeal > RULES.decayGraceSeconds) p.mass -= (p.mass-RULES.decayFloor)*RULES.decayPerSecond*dt;
      if (p.hazardSplitReady <= this.time) this.split(p,true);
      const center = {x:p.x,y:p.y}, largest = Math.max(...p.cells.map(c => c.mass));
      const velocity = speed(largest)*(p.dashUntil > this.time ? 2.7 : 1);
      const pull = this.time >= p.mergeUntil ? 2.8 : 0.4;
      for (const cell of p.cells) {
        const hazard = hazardFor(cell), steer = velocity*(hazard ? RULES.hazardSlow : 1);
        const dx = center.x-cell.x, dy = center.y-cell.y, length = Math.hypot(dx,dy) || 1;
        const regroupSpeed = Math.min(this.time >= p.mergeUntil ? 220 : 65,length*pull);
        cell.x += (p.dx*steer+cell.vx+dx/length*regroupSpeed)*dt;
        cell.y += (p.dy*steer+cell.vy+dy/length*regroupSpeed)*dt;
        cell.vx *= Math.exp(-4*dt); cell.vy *= Math.exp(-4*dt); this.boundCell(cell);
        const r = radius(cell.mass);
        for (const i of foodGrid.near(cell,r+4)) if (distance(cell,this.food[i]) < r+4) {
          const before = this.food[i], after = this.makeFood();
          cell.mass += before.value; p.lastMeal = this.time; this.food[i] = after;
          foodGrid.replace(i,before,after);
        }
        if (hazard && cell.mass > RULES.leakFloor) this.leak(hazard,cell,dt,foodGrid);
      }
      this.regroup(p,dt); p.best = Math.max(p.best,p.mass);
    }
    const alive = this.liveCells().sort((a,b) => b.cell.mass-a.cell.mass || a.cell.id.localeCompare(b.cell.id));
    for (const {owner:predator,cell:hunter} of alive) {
      if (!predator.alive || !predator.cells.includes(hunter) || predator.shieldUntil > this.time) continue;
      for (const {owner:prey,cell:snack} of alive) {
        if (predator === prey || !prey.alive || !prey.cells.includes(snack) || prey.shieldUntil > this.time || hunter.mass < snack.mass*1.22) continue;
        if (distance(hunter,snack) >= radius(hunter.mass)-radius(snack.mass)*RULES.eatOverlap) continue;
        prey.lastX = snack.x; prey.lastY = snack.y; prey.cells.splice(prey.cells.indexOf(snack),1);
        hunter.mass += snack.mass*0.7; predator.lastMeal = this.time; predator.best = Math.max(predator.best,predator.mass);
        const eliminated = prey.cells.length === 0;
        if (eliminated) { prey.alive = false; prey.diedAt = this.time; prey.eatenBy = predator.name; prey.dx = 0; prey.dy = 0; prey.mergeUntil = 0; prey.hurtUntil = 0; predator.kills++; }
        else { prey.hurtUntil = this.time+2.4; if (prey.cells.length === 1) prey.mergeUntil = 0; }
        this.events.push({hunter:predator.id,prey:prey.id,cell:snack.id,eliminated});
      }
    }
    for (const {cell} of this.liveCells()) this.boundCell(cell);
  }
  snapshot(includeFood = true) {
    const round = n => Math.round(n * 10) / 10;
    return {
      type: 'state', tick: this.tick, time: round(this.time), width: RULES.width, height: RULES.height,
      humans: this.humans, bots: [...this.players.values()].filter(p => p.bot).length, hazards: HAZARDS.map(h => ({ ...h })),
      players: [...this.players.values()].map(p => ({ id: p.id, name: p.name, brine: p.brine, outfit: p.outfit, variety: p.variety, bot: p.bot, x: round(p.x), y: round(p.y), mass: round(p.mass), best: Math.floor(p.best), kills: p.kills, alive: p.alive, shield: round(Math.max(0, p.shieldUntil - this.time)), dash: round(Math.max(0, p.dashUntil - this.time)), cooldown: round(Math.max(0, p.dashReady - this.time)), splitCooldown: round(Math.max(0,p.splitReady-this.time)), merge: p.cells.length > 1 ? round(Math.max(0,p.mergeUntil-this.time)) : 0, hurt: round(Math.max(0,p.hurtUntil-this.time)), cells: p.cells.map(c => ({id:c.id,x:round(c.x),y:round(c.y),mass:round(c.mass),...(c.mass > RULES.leakFloor && hazardFor(c) ? {drain:1} : {})})), respawn: p.alive ? 0 : round(Math.max(0, RULES.respawnSeconds - (this.time - p.diedAt))), eatenBy: p.eatenBy })),
      ...(includeFood ? { food: this.food.map(f => [f.id, Math.round(f.x), Math.round(f.y), f.value]) } : {})
    };
  }
}
