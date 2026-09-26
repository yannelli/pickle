import { ArenaEngine, RULES, parseIntent, cleanName, BRINES, OUTFITS, VARIETIES } from './arena-engine.mjs';
const json = (body, status = 200) => Response.json(body, { status, headers: { 'Cache-Control': 'no-store' } });
const validRoom = value => /^[A-Z0-9]{6}$/.test(value || '');
const sameSecret = (given, secret) => {
  const a = new TextEncoder().encode(given), b = new TextEncoder().encode(secret);
  return a.length === b.length && (crypto.subtle.timingSafeEqual?.(a, b) ?? a.reduce((diff, byte, i) => diff | (byte ^ b[i]), 0) === 0);
};
export function clientIP(request, env) {
  const claimed = request.headers.get('X-Arena-Client-IP');
  const trusted = env.ARENA_PROXY_SECRET && claimed && sameSecret(request.headers.get('X-Arena-Proxy-Secret') || '', env.ARENA_PROXY_SECRET);
  return (trusted ? claimed : request.headers.get('CF-Connecting-IP')) || 'local';
}

export function foodDelta(before, after) {
  const previous = new Map(before.map(pellet => [pellet[0], pellet]));
  const remaining = new Set(after.map(pellet => pellet[0]));
  return {
    foodAdded: after.filter(pellet => {
      const old = previous.get(pellet[0]);
      return !old || pellet.some((value, index) => value !== old[index]);
    }),
    foodRemoved: before.filter(pellet => !remaining.has(pellet[0])).map(pellet => pellet[0])
  };
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    // The claimed preview endpoint forwards older installed apps into the same rooms.
    if (env.ARENA_UPSTREAM) {
      const upstream = new URL(env.ARENA_UPSTREAM);
      url.protocol = upstream.protocol; url.host = upstream.host;
      const forwarded = new Request(url, request), ip = request.headers.get('CF-Connecting-IP');
      if (ip) forwarded.headers.set('X-Arena-Client-IP', ip); else forwarded.headers.delete('X-Arena-Client-IP');
      if (env.ARENA_PROXY_SECRET) forwarded.headers.set('X-Arena-Proxy-Secret', env.ARENA_PROXY_SECRET); else forwarded.headers.delete('X-Arena-Proxy-Secret');
      return fetch(forwarded);
    }
    if (url.pathname === '/health') return json({ app: 'Little Dill · Brine Royale', protocol: 1, mode: 'server-authoritative', maxPlayers: RULES.maxHumans, width: RULES.width, height: RULES.height, massLimit: null, botsFillTo: RULES.population, foodCount: RULES.foodCount, foodDeltas: true, foodMass: RULES.foodMass, bonusFoodMass: RULES.bonusFoodMass, decayFloor: RULES.decayFloor, decayGraceSeconds: RULES.decayGraceSeconds, decayPerSecond: RULES.decayPerSecond, maxCells: RULES.maxCells, splitMinMass: RULES.splitMinMass, splitCooldown: RULES.splitCooldown, mergeSeconds: RULES.mergeSeconds });
    if (url.pathname === '/.well-known/apple-app-site-association') return json({ applinks: { details: [{ appIDs: ['2P58V89SR7.com.littledill.ios'], components: [{ '/': '/', comment: 'Public arena and private crew invitations.' }] }] } });
    if (url.pathname !== '/arena' && env.ASSETS) return env.ASSETS.fetch(request);
    if (url.pathname !== '/arena' || request.method !== 'GET') return json({ error: 'Not found.' }, 404);
    if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') return json({ error: 'A WebSocket connection is required.' }, 426);
    const room = url.searchParams.get('room');
    if (room && !validRoom(room)) return json({ error: 'Room codes have six letters or digits.' }, 400);
    const ip = clientIP(request, env);
    if (room && env.CREW_JOINS && !(await env.CREW_JOINS.limit({ key: ip })).success) return json({ error: 'Too many private rooms. Try again in a minute.' }, 429);
    // Try public rooms in order. Each object atomically enforces the configured human and per-network capacity.
    let refused;
    for (let n = 1; n <= (room ? 1 : 16); n++) {
      const id = room ? `crew-${room}` : `public-${n}`;
      const internal = new URL(request.url); internal.searchParams.set('assignedRoom', id);
      const forwarded = new Request(internal, request); forwarded.headers.set('X-Arena-Client-IP', ip); forwarded.headers.delete('X-Arena-Proxy-Secret');
      const response = await env.ARENAS.getByName(id).fetch(forwarded);
      if (room || (response.status !== 503 && response.status !== 429)) return response;
      if (response.status === 429) refused = response;
    }
    return refused || json({ error: 'All gardens are full. Try again in a moment.' }, 503);
  }
};

export class ArenaRoom {
  constructor(ctx) { this.ctx = ctx; this.engine = new ArenaEngine(); this.lastFood = this.engine.snapshot().food; this.sessions = new Map(); this.timer = null; this.room = ''; }
  async fetch(request) {
    if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') return json({ error: 'WebSocket required.' }, 426);
    if (this.sessions.size >= RULES.maxHumans) return json({ error: 'This garden is full.' }, 503);
    const ip = request.headers.get('X-Arena-Client-IP') || 'local';
    if ([...this.sessions.values()].filter(s => s.ip === ip).length >= 8) return json({ error: 'Too many connections from this network.' }, 429);
    const url = new URL(request.url); this.room = url.searchParams.get('assignedRoom') || 'public-1';
    const name = cleanName(url.searchParams.get('name'));
    const brine = url.searchParams.get('brine'), outfit = url.searchParams.get('outfit'), variety = url.searchParams.get('variety');
    if ((brine && !BRINES.includes(brine)) || (outfit && !OUTFITS.includes(outfit)) || (variety && !VARIETIES.includes(variety))) return json({ error: 'Unknown pickle appearance.' }, 400);
    const id = crypto.randomUUID(); const [client, server] = Object.values(new WebSocketPair());
    server.accept();
    this.engine.addPlayer(id, { name, brine, outfit, variety });
    this.sessions.set(server, { id, ip, foodDeltas: url.searchParams.get('foodDeltas') === '1', tokens: 60, refill: Date.now(), lastSeen: Date.now(), joined: Date.now() });
    server.addEventListener('message', event => this.onMessage(server, event.data));
    server.addEventListener('close', () => this.remove(server));
    server.addEventListener('error', () => this.remove(server));
    server.send(JSON.stringify({ type: 'welcome', protocol: 1, id, room: this.room, tickRate: RULES.tickRate }));
    server.send(JSON.stringify({ ...this.engine.snapshot(), food: this.lastFood }));
    if (!this.timer) this.timer = setInterval(() => this.tick(), 1000 / RULES.tickRate);
    return new Response(null, { status: 101, webSocket: client });
  }
  onMessage(socket, raw) {
    const session = this.sessions.get(socket); if (!session) return;
    const now = Date.now(); session.tokens = Math.min(60, session.tokens + (now - session.refill) * 0.03); session.refill = now;
    if (--session.tokens < 0) { socket.close(1008, 'Too many inputs.'); this.remove(socket); return; }
    const input = parseIntent(raw);
    if (!input) { socket.close(1008, 'Invalid game input.'); this.remove(socket); return; }
    session.lastSeen = now;
    if (input.type === 'ping') { socket.send(JSON.stringify({ type: 'pong' })); return; }
    this.engine.input(session.id, input);
  }
  tick() {
    const now = Date.now();
    for (const [socket, session] of this.sessions) {
      if (now - session.lastSeen > 15000 || now - session.joined > RULES.sessionSeconds * 1000) { socket.close(1001, 'Take a breather and rejoin.'); this.remove(socket); }
    }
    if (!this.sessions.size) return;
    this.engine.step();
    if (this.engine.tick % 2 !== 0) return;
    const state = this.engine.snapshot(this.engine.tick % 4 === 0);
    const changes = state.food ? foodDelta(this.lastFood, state.food) : {};
    if (state.food) this.lastFood = state.food;
    let fullPacket, deltaPacket;
    for (const [socket, session] of this.sessions) {
      try {
        // Older installed clients retain full food snapshots. New clients get
        // reliable ordered changes at the same cadence, with a full join sync.
        const packet = session.foodDeltas
          ? (deltaPacket ??= JSON.stringify({ ...state, food: undefined, ...changes }))
          : (fullPacket ??= JSON.stringify(state));
        socket.send(packet);
      } catch { this.remove(socket); }
    }
  }
  remove(socket) {
    const session = this.sessions.get(socket); if (!session) return;
    this.sessions.delete(socket); this.engine.removePlayer(session.id);
    if (!this.sessions.size) { clearInterval(this.timer); this.timer = null; this.engine = new ArenaEngine(); this.lastFood = this.engine.snapshot().food; }
  }
}
