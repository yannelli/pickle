import { ArenaEngine, HAZARDS, restorePlayer, RULES, parseIntent, cleanName, BRINES, OUTFITS, VARIETIES, BOT_NAMES } from './arena-engine.mjs';
const CHECKPOINT_KEY = 'arena-checkpoint-v1', CHECKPOINT_MS = 1000;
const json = (body, status = 200) => Response.json(body, { status, headers: { 'Cache-Control': 'no-store' } });
const validRoom = value => /^[A-Z0-9]{6}$/.test(value || '');
const validResumeRoom = value => /^(public-(?:[1-9]|1[0-6])|crew-[A-Z0-9]{6})$/.test(value || '');
const validResumeToken = value => /^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(value || '');
const sameSecret = (given, secret) => {
  const a = new TextEncoder().encode(given), b = new TextEncoder().encode(secret);
  return a.length === b.length && (crypto.subtle.timingSafeEqual?.(a, b) ?? a.reduce((diff, byte, i) => diff | (byte ^ b[i]), 0) === 0);
};
export function clientIP(request, env) {
  const claimed = request.headers.get('X-Arena-Client-IP');
  const trusted = env.ARENA_PROXY_SECRET && claimed && sameSecret(request.headers.get('X-Arena-Proxy-Secret') || '', env.ARENA_PROXY_SECRET);
  return (trusted ? claimed : request.headers.get('CF-Connecting-IP')) || 'local';
}
const roomRequest = (url, request, ip) => {
  const forwarded = new Request(url, request);
  forwarded.headers.set('X-Arena-Client-IP', ip);
  forwarded.headers.delete('X-Arena-Proxy-Secret');
  return forwarded;
};

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
    if (url.pathname === '/health') return json({ app: 'Little Dill · Brine Royale', protocol: 1, mode: 'server-authoritative', maxPlayers: RULES.maxHumans, width: RULES.width, height: RULES.height, massLimit: null, sessionLimitSeconds: null, durableRecovery: true, checkpointIntervalMs: CHECKPOINT_MS, botsFillTo: RULES.population, botNameCount: BOT_NAMES.length, foodCount: RULES.foodCount, foodDeltas: true, foodMass: RULES.foodMass, bonusFoodMass: RULES.bonusFoodMass, decayFloor: RULES.decayFloor, decayGraceSeconds: RULES.decayGraceSeconds, decayPerSecond: RULES.decayPerSecond, maxCells: RULES.maxCells, splitMinMass: RULES.splitMinMass, splitCooldown: RULES.splitCooldown, mergeSeconds: RULES.mergeSeconds, eatOverlap: RULES.eatOverlap, reconnectGraceSeconds: RULES.reconnectGraceSeconds, hazards: HAZARDS.map(h => h.kind), hazardRadius: RULES.hazardRadius, leakFloor: RULES.leakFloor, hazardSplitMass: RULES.hazardSplitMass, hazardSplitCooldown: RULES.hazardSplitCooldown });
    if (url.pathname === '/.well-known/apple-app-site-association') return json({ applinks: { details: [{ appIDs: ['2P58V89SR7.com.littledill.ios'], components: [{ '/': '/', comment: 'Public arena and private crew invitations.' }] }] } });
    if (url.pathname !== '/arena' && env.ASSETS) return env.ASSETS.fetch(request);
    if (url.pathname !== '/arena' || request.method !== 'GET') return json({ error: 'Not found.' }, 404);
    if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') return json({ error: 'A WebSocket connection is required.' }, 426);
    const room = url.searchParams.get('room');
    if (room && !validRoom(room)) return json({ error: 'Room codes have six letters or digits.' }, 400);
    const ip = clientIP(request, env);
    const resumeToken = url.searchParams.get('resumeToken'), resumeRoom = url.searchParams.get('resumeRoom');
    if (resumeToken || resumeRoom) {
      if (!validResumeToken(resumeToken) || !validResumeRoom(resumeRoom)) return json({ error: 'Invalid reconnect credentials.' }, 400);
      // A reconnect must target the original object, including a full public room.
      const internal = new URL(request.url); internal.searchParams.set('assignedRoom', resumeRoom);
      return env.ARENAS.getByName(resumeRoom).fetch(roomRequest(internal, request, ip));
    }
    if (room && env.CREW_JOINS && !(await env.CREW_JOINS.limit({ key: ip })).success) return json({ error: 'Too many private rooms. Try again in a minute.' }, 429);
    // Try public rooms in order. Each object atomically enforces the configured human capacity.
    let refused;
    for (let n = 1; n <= (room ? 1 : 16); n++) {
      const id = room ? `crew-${room}` : `public-${n}`;
      const internal = new URL(request.url); internal.searchParams.set('assignedRoom', id);
      const response = await env.ARENAS.getByName(id).fetch(roomRequest(internal, request, ip));
      if (room || (response.status !== 503 && response.status !== 429)) return response;
      if (response.status === 429) refused = response;
    }
    return refused || json({ error: 'All gardens are full. Try again in a moment.' }, 503);
  }
};

export class ArenaRoom {
  constructor(ctx) {
    this.ctx = ctx; this.engine = new ArenaEngine(); this.lastFood = this.engine.snapshot().food;
    this.sessions = new Map(); this.reconnects = new Map(); this.timer = null; this.room = ''; this.now = Date.now;
    this.lastCheckpointAt = 0; this.pendingCheckpoint = Promise.resolve();
    this.ready = ctx.blockConcurrencyWhile(() => this.restoreCheckpoint());
  }
  async restoreCheckpoint() {
    const saved = await this.ctx.storage.get(CHECKPOINT_KEY);
    if (!saved) return;
    const records = saved.version === 1 ? saved.reconnects.filter(record => record.expiresAt > this.now()) : [];
    if (!records.length) { await this.ctx.storage.delete(CHECKPOINT_KEY); await this.ctx.storage.deleteAlarm(); return; }
    this.room = saved.room; this.engine = new ArenaEngine({ checkpoint:saved.engine, publicRoom:this.room?.startsWith('public-') });
    // Older installed clients reject decreasing tick numbers. Skip the wall-clock
    // gap in sequence only; simulation time/timers remain frozen during recovery.
    this.engine.tick += Math.ceil(Math.max(0,this.now()-saved.savedAt)*RULES.tickRate/1000)+1;
    for (const record of records) {
      const player = record.player ? restorePlayer(record.player) : this.engine.players.get(record.id);
      if (!player) continue;
      player.dx = 0; player.dy = 0;
      this.reconnects.set(record.token,{ ...record, player, socket:null });
    }
    // Disconnected humans stay outside combat until their own socket returns.
    for (const [id,player] of this.engine.players) if (!player.bot) this.engine.players.delete(id);
    this.lastFood = this.engine.snapshot().food;
    console.info(JSON.stringify({event:'arena_checkpoint_restored',runs:this.heldSlots}));
  }
  saveCheckpoint() {
    const now = this.now(); this.lastCheckpointAt = now;
    const reconnects = [...this.reconnects.values()].map(record => ({
      token:record.token, id:record.id, player:record.player,
      pausedAt:record.player ? record.pausedAt : this.engine.time,
      // One checkpoint interval of slack prevents active recovery losing part
      // of its grace window. Explicit disconnect deadlines never move.
      expiresAt:record.player ? record.expiresAt : now+RULES.reconnectGraceSeconds*1000+CHECKPOINT_MS
    }));
    const operations = reconnects.length ? [
      this.ctx.storage.put(CHECKPOINT_KEY,structuredClone({version:1,room:this.room,savedAt:now,engine:this.engine.checkpoint(),reconnects})),
      this.ctx.storage.setAlarm(Math.max(...reconnects.map(record => record.expiresAt)))
    ] : [this.ctx.storage.delete(CHECKPOINT_KEY),this.ctx.storage.deleteAlarm()];
    this.pendingCheckpoint = Promise.all(operations);
    this.ctx.waitUntil(this.pendingCheckpoint.catch(() => console.error(JSON.stringify({event:'arena_checkpoint_failed'}))));
    return this.pendingCheckpoint;
  }
  async alarm() {
    await this.ready; this.expireReservations(); this.stopIfEmpty(); await this.saveCheckpoint();
  }
  get heldSlots() { return [...this.reconnects.values()].filter(record => record.player).length; }
  expireReservations(now = this.now()) {
    for (const [token, record] of this.reconnects) if (record.player && now >= record.expiresAt) this.reconnects.delete(token);
  }
  stopIfEmpty() {
    if (this.sessions.size || this.heldSlots) return;
    clearInterval(this.timer); this.timer = null; this.engine = new ArenaEngine(); this.lastFood = this.engine.snapshot().food;
  }
  expiredResume() {
    console.warn(JSON.stringify({event:'arena_resume_rejected',reason:'missing_or_expired',activeConnections:this.sessions.size,heldRuns:this.heldSlots}));
    const [client, server] = Object.values(new WebSocketPair()); server.accept();
    server.send(JSON.stringify({ type: 'resume-expired' })); server.close(1000, 'Reconnect window ended.');
    return new Response(null, { status: 101, webSocket: client });
  }
  async fetch(request) {
    await this.ready;
    if (request.headers.get('Upgrade')?.toLowerCase() !== 'websocket') return json({ error: 'WebSocket required.' }, 426);
    const now = this.now(); this.expireReservations(now);
    const url = new URL(request.url); this.room = url.searchParams.get('assignedRoom') || 'public-1';
    this.engine.publicRoom = this.room.startsWith('public-');
    this.engine.assignHardBot();
    const token = url.searchParams.get('resumeToken');
    let record = token ? this.reconnects.get(token) : null;
    if (token && !record) return this.expiredResume();
    if (!record && this.engine.humans + this.heldSlots >= RULES.maxHumans) return json({ error: 'This garden is full.' }, 503);
    const ip = request.headers.get('X-Arena-Client-IP') || request.headers.get('CF-Connecting-IP') || 'local';
    if ([...this.sessions.entries()].filter(([socket,s]) => s.ip === ip && socket !== record?.socket).length >= 8) return json({ error: 'Too many connections from this network.' }, 429);
    const name = cleanName(url.searchParams.get('name'));
    const brine = url.searchParams.get('brine'), outfit = url.searchParams.get('outfit'), variety = url.searchParams.get('variety');
    if ((brine && !BRINES.includes(brine)) || (outfit && !OUTFITS.includes(outfit)) || (variety && !VARIETIES.includes(variety))) return json({ error: 'Unknown pickle appearance.' }, 400);
    const resumed = !!record, id = record?.id || crypto.randomUUID();
    const [client, server] = Object.values(new WebSocketPair());
    server.accept();
    if (record?.socket) {
      // A mobile radio can reconnect before the old TCP socket reports closure.
      // Replace that socket atomically; its late close event cannot remove the run.
      const old = record.socket; this.sessions.delete(old); old.close(4001, 'Resumed on another connection.');
    } else if (record?.player) {
      const p = record.player, paused = this.engine.time - record.pausedAt;
      for (const field of ['lastMeal','shieldUntil','dashUntil','dashReady','splitReady','mergeUntil','diedAt']) p[field] += paused;
      for (const field of ['hazardSplitReady','hurtUntil','botHazardReady']) if (p[field] > record.pausedAt) p[field] += paused;
      this.engine.players.set(id,p); this.engine.balanceBots();
    } else this.engine.addPlayer(id, { name, brine, outfit, variety });
    const p = this.engine.players.get(id); p.dx = 0; p.dy = 0; p.seq = -1; p.lastInput = this.engine.time;
    if (!record && url.searchParams.get('reconnect') === '1') {
      record = { token: crypto.randomUUID(), id };
      this.reconnects.set(record.token,record);
    }
    if (record) Object.assign(record, { socket: server, player: null, expiresAt: null });
    this.sessions.set(server, { id, ip, record, foodDeltas: url.searchParams.get('foodDeltas') === '1', tokens: 60, refill: now, lastSeen: now });
    server.addEventListener('message', event => this.onMessage(server, event.data));
    server.addEventListener('close', () => this.remove(server));
    server.addEventListener('error', () => this.remove(server));
    // Do not issue a reconnect secret until its authoritative run is durable.
    await this.saveCheckpoint();
    server.send(JSON.stringify({ type: 'welcome', protocol: 1, id, room: this.room, tickRate: RULES.tickRate, ...(record ? { resumeToken: record.token, resumeRoom: this.room, reconnectGraceSeconds: RULES.reconnectGraceSeconds, resumed } : {}) }));
    server.send(JSON.stringify(this.engine.snapshot()));
    if (!this.timer) this.timer = setInterval(() => this.tick(), 1000 / RULES.tickRate);
    return new Response(null, { status: 101, webSocket: client });
  }
  onMessage(socket, raw) {
    const session = this.sessions.get(socket); if (!session) return;
    const now = this.now(); session.tokens = Math.min(60, session.tokens + (now - session.refill) * 0.03); session.refill = now;
    if (--session.tokens < 0) { this.remove(socket,false); socket.close(1008, 'Too many inputs.'); return; }
    const input = parseIntent(raw);
    if (!input) { this.remove(socket,false); socket.close(1008, 'Invalid game input.'); return; }
    session.lastSeen = now;
    if (input.type === 'leave') { this.remove(socket,false); socket.close(1000,'Left arena.'); return; }
    if (input.type === 'ping') { socket.send(JSON.stringify({ type: 'pong' })); return; }
    this.engine.input(session.id, input);
  }
  tick() {
    const now = this.now(); this.expireReservations(now);
    for (const [socket, session] of this.sessions) {
      // Only an idle transport times out. Run age must never end active play.
      if (now - session.lastSeen > 15000) { this.remove(socket); socket.close(1001,'Connection timed out.'); }
    }
    if (!this.sessions.size) {
      this.stopIfEmpty();
      if (!this.heldSlots) this.saveCheckpoint();
      return;
    }
    this.engine.step();
    if (now-this.lastCheckpointAt >= CHECKPOINT_MS) this.saveCheckpoint();
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
  remove(socket, retain = true) {
    const session = this.sessions.get(socket); if (!session) return;
    this.sessions.delete(socket);
    if (session.record) {
      const player = this.engine.players.get(session.id);
      if (retain && player) {
        player.dx = 0; player.dy = 0;
        Object.assign(session.record, { socket: null, player, pausedAt: this.engine.time, expiresAt: this.now()+RULES.reconnectGraceSeconds*1000 });
      } else this.reconnects.delete(session.record.token);
    }
    this.engine.removePlayer(session.id); this.stopIfEmpty(); this.saveCheckpoint();
  }
}
