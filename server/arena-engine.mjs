// Dependency-free authoritative simulation. Clients send intent, never position or mass.
export const RULES = Object.freeze({ width: 6000, height: 4500, tickRate: 20, maxHumans: 64, population: 32, foodCount: 3375, foodMass: 3, bonusFoodMass: 9, startMass: 25, shieldSeconds: 4, respawnSeconds: 2, sessionSeconds: 1800, decayFloor: 300, decayGraceSeconds: 8, decayPerSecond: 0.001, maxCells: 4, splitMinMass: 60, splitCooldown: 1, mergeSeconds: 12 });
export const BRINES = ['classic', 'garlic', 'spicy'];
export const OUTFITS = ['original', 'sprout', 'bow', 'shades', 'crown', 'party'];
const BOT_NAMES = ['maya.j', 'alex_27', 'SophieK', 'noah', 'emilyrose', 'Leo99', 'itsChloe', 'sam.png', 'oliver', 'NoraB', 'luke_7', 'isabel', 'Theo', 'grace.m', 'Jules', 'benji', 'zoe17', 'henry', 'mila_', 'jackson', 'AvaGrace', 'rylee', 'ethan_42', 'sienna', 'Finn', 'ellie.jpg', 'Caleb', 'rubyroo', 'oscar', 'lucy.h', 'daniel', 'Freya', 'Maxwell', 'tess', 'will_8', 'amelia', 'josh.jpeg', 'violet', 'Nathan', 'eve_22', 'charlie', 'Leah', 'aaron_7', 'poppy', 'Dylan', 'lilymae', 'owen', 'amber.k', 'Archie', 'hannah', 'eli_19', 'clara', 'mason', 'Sadie', 'jamie', 'alice.w', 'isaac', 'Eva', 'nico_5', 'summer', 'Jordan', 'holly', 'felix', 'rosie', 'miles', 'erin_23', 'seb', 'Maddie', 'cole', 'lauren', 'kai_11', 'Harper'];
export const clamp = (n, a, b) => Math.max(a, Math.min(b, n));
export const radius = mass => {
  const base = 13 + Math.sqrt(Math.max(0, mass)) * 3.4;
  // Mass keeps growing. Taper giant bodies so the fixed garden remains navigable.
  const excess = Math.max(0, base - 149);
  return base <= 149 ? base : 149 + 260 * excess / (260 + excess);
};
export const speed = mass => Math.max(55, 195 / Math.pow(Math.max(25, mass) / 25, 0.16));
const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
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
export function parseIntent(raw) {
  if (typeof raw !== 'string' || raw.length > 256) return null;
  let p; try { p = JSON.parse(raw); } catch { return null; }
  if (p?.type === 'input' && Number.isSafeInteger(p.seq) && p.seq >= 0 && p.seq < 2147483647 && Number.isFinite(p.x) && Number.isFinite(p.y)) {
    let x = clamp(p.x, -1, 1), y = clamp(p.y, -1, 1); const length = Math.hypot(x, y);
    if (length > 1) { x /= length; y /= length; }
    return { type: 'input', seq: p.seq, x, y };
  }
  if (p?.type === 'dash' || p?.type === 'split' || p?.type === 'respawn' || p?.type === 'ping') return { type: p.type };
  return null;
}

export class ArenaEngine {
  constructor({ random = Math.random } = {}) {
    this.random = random; this.time = 0; this.tick = 0; this.players = new Map(); this.food = []; this.events = []; this.nextFood = 1; this.nextBot = 1; this.nextCell = 1;
    for (let i = 0; i < RULES.foodCount; i++) this.food.push(this.makeFood());
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
      const nearest = Math.min(1000, ...this.liveCells().filter(({cell}) => cell.mass > mass).map(({cell}) => distance(candidate, cell) - radius(cell.mass)));
      if (nearest > bestDistance) { best = candidate; bestDistance = nearest; }
      if (nearest > 260) break;
    }
    return best;
  }
  addPlayer(id, { name, brine, outfit, bot = false } = {}) {
    if (this.players.has(id) || (!bot && this.humans >= RULES.maxHumans)) return null;
    const mass = bot ? 25 + Math.floor(this.random() * 30) : RULES.startMass;
    const spawn = this.spawnPoint(mass);
    const p = {
      id, name: bot ? cleanName(name) : humanName(name), brine: BRINES.includes(brine) ? brine : 'classic', outfit: OUTFITS.includes(outfit) ? outfit : 'sprout', bot,
      cells: [this.makeCell(spawn.x,spawn.y,mass)], lastX: spawn.x, lastY: spawn.y,
      // Aggregate mass and center stay compatible with one-body clients and room scoring.
      get mass() { return this.cells.reduce((sum,c) => sum+c.mass,0); },
      set mass(value) { const total = this.mass; if (this.cells.length === 1) this.cells[0].mass = value; else if (total > 0) for (const c of this.cells) c.mass *= value/total; },
      get x() { const total = this.mass; return total > 0 ? this.cells.reduce((sum,c) => sum+c.x*c.mass,0)/total : this.lastX; },
      set x(value) { const delta = value-this.x; for (const c of this.cells) c.x += delta; this.lastX = value; },
      get y() { const total = this.mass; return total > 0 ? this.cells.reduce((sum,c) => sum+c.y*c.mass,0)/total : this.lastY; },
      set y(value) { const delta = value-this.y; for (const c of this.cells) c.y += delta; this.lastY = value; },
      best: mass, kills: 0, alive: true, dx: 0, dy: 0, aimX: 0, aimY: -1, seq: -1, lastInput: this.time, lastMeal: this.time,
      shieldUntil: this.time + RULES.shieldSeconds, dashUntil: 0, dashReady: 0, splitReady: 0, mergeUntil: 0, diedAt: 0, eatenBy: '', joinedAt: this.time
    };
    this.players.set(id, p);
    if (!bot) { this.balanceBots(); this.seedSpawnFood(p); }
    return p;
  }
  removePlayer(id) { this.players.delete(id); this.balanceBots(); }
  balanceBots() {
    const target = Math.max(0, RULES.population - this.humans);
    const bots = [...this.players.values()].filter(p => p.bot);
    while (bots.length > target) this.players.delete(bots.pop().id);
    while (bots.length < target) {
      const n = this.nextBot++;
      const usedNames = new Set([...this.players.values()].map(p => p.name.toLowerCase()));
      const availableNames = BOT_NAMES.filter(name => !usedNames.has(name.toLowerCase()));
      const name = availableNames[Math.floor(this.random()*availableNames.length)] || `guest_${n}`;
      const bot = this.addPlayer(`bot-${n}`, { bot: true, name, brine: BRINES[n % 3], outfit: OUTFITS[n % OUTFITS.length] });
      bots.push(bot);
    }
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
  split(p) {
    if (!p.alive || p.splitReady > this.time || p.cells.length >= RULES.maxCells) return false;
    const eligible = p.cells.filter(c => c.mass >= RULES.splitMinMass).sort((a,b) => b.mass-a.mass).slice(0,RULES.maxCells-p.cells.length);
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
    p.splitReady = this.time+RULES.splitCooldown; p.mergeUntil = this.time+RULES.mergeSeconds;
    return true;
  }
  respawn(p) {
    if (p.alive || this.time - p.diedAt < RULES.respawnSeconds) return false;
    const spawn = this.spawnPoint(RULES.startMass);
    p.cells = [this.makeCell(spawn.x,spawn.y,RULES.startMass)];
    Object.assign(p, { alive: true, dx: 0, dy: 0, aimX: 0, aimY: -1, lastMeal: this.time, shieldUntil: this.time + RULES.shieldSeconds, dashUntil: 0, dashReady: 0, splitReady: 0, mergeUntil: 0, eatenBy: '' });
    if (!p.bot) this.seedSpawnFood(p);
    return true;
  }
  think(bot) {
    if (!bot.alive) { this.respawn(bot); return; }
    const anchor = bot.cells.reduce((a,b) => a.mass > b.mass ? a : b);
    const others = this.liveCells().filter(({owner,cell}) => owner !== bot && distance(cell,anchor) < 450);
    const threat = others.filter(({cell}) => cell.mass > anchor.mass*1.2).sort((a,b) => distance(a.cell,anchor)-distance(b.cell,anchor))[0];
    let target, away = false, prey;
    if (threat) { target = threat.cell; away = true; if (this.random() < 0.12) this.dash(bot); }
    else {
      prey = others.filter(({owner,cell}) => anchor.mass > cell.mass*1.22 && owner.shieldUntil < this.time).sort((a,b) => distance(a.cell,anchor)-distance(b.cell,anchor))[0];
      target = prey?.cell || this.food.reduce((best,food) => !best || distance(food,anchor) < distance(best,anchor) ? food : best,null);
    }
    if (!target) return;
    let x = (target.x-anchor.x)*(away ? -1 : 1), y = (target.y-anchor.y)*(away ? -1 : 1);
    if (away) { if (anchor.x < 100) x += 250; if (anchor.x > RULES.width-100) x -= 250; if (anchor.y < 100) y += 250; if (anchor.y > RULES.height-100) y -= 250; }
    const length = Math.hypot(x,y) || 1; bot.dx = x/length; bot.dy = y/length; bot.aimX = bot.dx; bot.aimY = bot.dy;
    // Bots can make the same risky play, only when a half-sized piece can win.
    if (prey && !away && bot.cells.length === 1 && anchor.mass/2 > prey.cell.mass*1.3 && distance(anchor,prey.cell) > radius(anchor.mass) && this.random() < 0.06) this.split(bot);
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
      const center = {x:p.x,y:p.y}, largest = Math.max(...p.cells.map(c => c.mass));
      const velocity = speed(largest)*(p.dashUntil > this.time ? 2.7 : 1);
      const pull = this.time >= p.mergeUntil ? 2.8 : 0.4;
      for (const cell of p.cells) {
        const dx = center.x-cell.x, dy = center.y-cell.y, length = Math.hypot(dx,dy) || 1;
        const regroupSpeed = Math.min(this.time >= p.mergeUntil ? 220 : 65,length*pull);
        cell.x += (p.dx*velocity+cell.vx+dx/length*regroupSpeed)*dt;
        cell.y += (p.dy*velocity+cell.vy+dy/length*regroupSpeed)*dt;
        cell.vx *= Math.exp(-4*dt); cell.vy *= Math.exp(-4*dt); this.boundCell(cell);
        const r = radius(cell.mass);
        for (const i of foodGrid.near(cell,r+4)) if (distance(cell,this.food[i]) < r+4) {
          const before = this.food[i], after = this.makeFood();
          cell.mass += before.value; p.lastMeal = this.time; this.food[i] = after;
          foodGrid.replace(i,before,after);
        }
      }
      this.regroup(p,dt); p.best = Math.max(p.best,p.mass);
    }
    const alive = this.liveCells().sort((a,b) => b.cell.mass-a.cell.mass || a.cell.id.localeCompare(b.cell.id));
    for (const {owner:predator,cell:hunter} of alive) {
      if (!predator.alive || !predator.cells.includes(hunter) || predator.shieldUntil > this.time) continue;
      for (const {owner:prey,cell:snack} of alive) {
        if (predator === prey || !prey.alive || !prey.cells.includes(snack) || prey.shieldUntil > this.time || hunter.mass < snack.mass*1.22) continue;
        if (distance(hunter,snack) >= radius(hunter.mass)-radius(snack.mass)*0.35) continue;
        prey.lastX = snack.x; prey.lastY = snack.y; prey.cells.splice(prey.cells.indexOf(snack),1);
        hunter.mass += snack.mass*0.7; predator.lastMeal = this.time; predator.best = Math.max(predator.best,predator.mass);
        const eliminated = prey.cells.length === 0;
        if (eliminated) { prey.alive = false; prey.diedAt = this.time; prey.eatenBy = predator.name; prey.dx = 0; prey.dy = 0; prey.mergeUntil = 0; predator.kills++; }
        else if (prey.cells.length === 1) prey.mergeUntil = 0;
        this.events.push({hunter:predator.id,prey:prey.id,cell:snack.id,eliminated});
      }
    }
    for (const {cell} of this.liveCells()) this.boundCell(cell);
  }
  snapshot(includeFood = true) {
    const round = n => Math.round(n * 10) / 10;
    return {
      type: 'state', tick: this.tick, time: round(this.time), width: RULES.width, height: RULES.height,
      humans: this.humans, bots: [...this.players.values()].filter(p => p.bot).length,
      players: [...this.players.values()].map(p => ({ id: p.id, name: p.name, brine: p.brine, outfit: p.outfit, bot: p.bot, x: round(p.x), y: round(p.y), mass: round(p.mass), best: Math.floor(p.best), kills: p.kills, alive: p.alive, shield: round(Math.max(0, p.shieldUntil - this.time)), dash: round(Math.max(0, p.dashUntil - this.time)), cooldown: round(Math.max(0, p.dashReady - this.time)), splitCooldown: round(Math.max(0,p.splitReady-this.time)), merge: p.cells.length > 1 ? round(Math.max(0,p.mergeUntil-this.time)) : 0, cells: p.cells.map(c => ({id:c.id,x:round(c.x),y:round(c.y),mass:round(c.mass)})), respawn: p.alive ? 0 : round(Math.max(0, RULES.respawnSeconds - (this.time - p.diedAt))), eatenBy: p.eatenBy })),
      ...(includeFood ? { food: this.food.map(f => [f.id, Math.round(f.x), Math.round(f.y), f.value]) } : {})
    };
  }
}
