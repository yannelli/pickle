const { test } = require('node:test');
const assert = require('node:assert/strict');

const workerModule = import('../server/arena-worker.mjs');
const engineModule = import('../server/arena-engine.mjs');
const request = (query = '', headers = {}) => new Request(`https://arena.test/arena${query}`, {
  headers: { Upgrade: 'websocket', 'CF-Connecting-IP': '203.0.113.1', ...headers }
});
const arenas = (statuses = [200]) => {
  const calls = [];
  return {
    calls,
    getByName: id => ({ fetch: async forwarded => {
      calls.push({ id, ip: forwarded.headers.get('X-Arena-Client-IP'), secret: forwarded.headers.get('X-Arena-Proxy-Secret') });
      return Response.json({ id }, { status: statuses[calls.length - 1] ?? 200 });
    } })
  };
};

test('arena forwarding trusts a claimed address only with the proxy secret', async () => {
  const { default: worker } = await workerModule;
  for (const [secret, expected] of [['brine-secret', '198.51.100.7'], ['wrong', '203.0.113.1'], ['', '203.0.113.1']]) {
    const ARENAS = arenas();
    const response = await worker.fetch(request('', {
      'X-Arena-Client-IP': '198.51.100.7', 'X-Arena-Proxy-Secret': secret
    }), { ARENAS, ARENA_PROXY_SECRET: 'brine-secret' });
    assert.equal(response.status, 200);
    assert.equal(ARENAS.calls[0].ip, expected);
    assert.equal(ARENAS.calls[0].secret, null);
  }
});

test('public matchmaking skips crowded networks and full rooms', async () => {
  const { default: worker } = await workerModule;
  const ARENAS = arenas([429, 503, 200]);
  assert.equal((await worker.fetch(request(), { ARENAS })).status, 200);
  assert.deepEqual(ARENAS.calls.map(call => call.id), ['public-1', 'public-2', 'public-3']);
});

test('crew join rate limits keep reconnect credentials usable', async () => {
  const { default: worker } = await workerModule;
  const keys = [], CREW_JOINS = { limit: async ({ key }) => {
    keys.push(key); return { success: keys.length === 1 };
  } };
  const env = { ARENAS: arenas(), CREW_JOINS, ARENA_PROXY_SECRET: 'brine-secret' };
  const headers = { 'X-Arena-Client-IP': '198.51.100.7', 'X-Arena-Proxy-Secret': 'brine-secret' };
  assert.equal((await worker.fetch(request('?room=ABC123', headers), env)).status, 200);
  assert.equal((await worker.fetch(request('?room=ABC123', headers), env)).status, 429);
  const token = 'c930d75e-4b1b-437f-a412-664c395ab491';
  const resumed = await worker.fetch(request(`?room=ABC123&resumeToken=${token}&resumeRoom=crew-ABC123`, headers), env);
  assert.equal(resumed.status, 200);
  assert.deepEqual(keys, ['198.51.100.7', '198.51.100.7']);
  assert.equal(env.ARENAS.calls.at(-1).id, 'crew-ABC123');
  assert.equal(env.ARENAS.calls.at(-1).ip, '198.51.100.7');
});

test('room connection capacity uses the resolved network address', async () => {
  const { ArenaRoom } = await workerModule;
  const room = new ArenaRoom({
    storage: { get: async () => null }, blockConcurrencyWhile: callback => callback(), waitUntil() {}
  });
  for (let n = 0; n < 8; n++) room.sessions.set({}, { ip: '198.51.100.7' });
  const response = await room.fetch(request('?assignedRoom=public-1', {
    'X-Arena-Client-IP': '198.51.100.7'
  }));
  assert.equal(response.status, 429);
  assert.equal((await response.json()).error, 'Too many connections from this network.');
});

test('human names cannot impersonate the client label or bot handles', async () => {
  const { ArenaEngine, BOT_NAMES, humanName } = await engineModule;
  const engine = new ArenaEngine();
  for (const name of ['you', ' YOU ', 'You\u2800', 'noah\u3164', ...BOT_NAMES]) {
    assert.equal(humanName(name), 'Dilly', name);
  }
  assert.equal(engine.addPlayer('human', { name: 'Harper' }).name, 'Dilly');
  assert.equal(engine.addPlayer('bot', { bot: true, name: 'Harper' }).name, 'Harper');
});
