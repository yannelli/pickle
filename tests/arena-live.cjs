// Run explicitly against wrangler dev or a deployed Worker. Uses Node 24's native WebSocket.
const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const endpoint = process.argv[2] || 'ws://127.0.0.1:8788/arena';
const peerEndpoint = process.argv[3] || endpoint;
const code = () => randomBytes(3).toString('hex').toUpperCase();
const sockets = [];
function connect(name, room, base = endpoint) {
  const url = new URL(base); url.searchParams.set('name', name); url.searchParams.set('brine', 'classic'); url.searchParams.set('outfit', 'sprout'); if (room) url.searchParams.set('room', room);
  const socket = new WebSocket(url); sockets.push(socket);
  const client = { socket, welcome: null, state: null, history: new Map(), closed: null, error: null };
  socket.addEventListener('message', event => {
    const data = JSON.parse(event.data);
    if (data.type === 'welcome') client.welcome = data;
    if (data.type === 'state') { client.state = data; client.history.set(data.tick, data); }
  });
  socket.addEventListener('close', event => { client.closed = event.code; });
  socket.addEventListener('error', () => { client.error = new Error('WebSocket connection failed'); });
  return client;
}
async function until(predicate, message, timeout = 12000) {
  const start = Date.now();
  while (!predicate()) { if (Date.now() - start > timeout) throw new Error(message); await new Promise(resolve => setTimeout(resolve, 30)); }
}
(async () => {
  const { RULES } = await import('../server/arena-engine.mjs');
  const room = code(), otherRoom = code();
  const a = connect('Live Alpha', room), b = connect('Live Beta', room, peerEndpoint), isolated = connect('Other Garden', otherRoom);
  await until(() => a.state?.humans === 2 && b.state?.humans === 2 && isolated.state?.humans === 1, 'Clients did not join shared and isolated rooms');
  assert.equal(a.welcome.room, b.welcome.room); assert.notEqual(a.welcome.id, b.welcome.id);
  assert.equal(a.state.bots, RULES.population - 2); assert.equal(isolated.state.bots, RULES.population - 1);
  assert.equal(a.state.width, RULES.width); assert.equal(a.state.height, RULES.height);
  assert.ok(a.state.players.some(p => p.id === b.welcome.id));
  assert.ok(!isolated.state.players.some(p => p.id === b.welcome.id));
  await until(() => [...a.history.keys()].some(tick => tick > 0 && b.history.has(tick) && a.history.get(tick).humans === 2 && b.history.get(tick).humans === 2), 'No common server tick');
  const tick = [...a.history.keys()].find(tick => tick > 0 && b.history.has(tick) && a.history.get(tick).humans === 2 && b.history.get(tick).humans === 2);
  assert.deepEqual(a.history.get(tick), b.history.get(tick), 'Clients must receive the same authoritative state');
  const start = a.state.players.find(p => p.id === a.welcome.id);
  for (let seq = 1; seq <= 12; seq++) {
    a.socket.send(JSON.stringify({ type: 'input', seq, x: 500, y: 500, mass: 99999, position: [0, 0] }));
    await new Promise(resolve => setTimeout(resolve, 50));
  }
  const moved = b.state.players.find(p => p.id === a.welcome.id);
  assert.ok(Math.hypot(moved.x - start.x, moved.y - start.y) > 10, 'Remote player must visibly move');
  assert.ok(Math.hypot(moved.x - start.x, moved.y - start.y) < 300, 'Movement must be server-limited');
  assert.ok(moved.mass < 200, 'Forged mass must not be applied');
  a.socket.send(JSON.stringify({ type: 'setMass', mass: 999999 }));
  await until(() => a.closed === 1008, 'Invalid protocol message must close the connection');
  await until(() => b.state?.humans === 1 && b.state?.bots === RULES.population - 1, 'Bots should refill a departed human slot');
  const publicA = connect('Public Alpha'), publicB = connect('Public Beta', undefined, peerEndpoint);
  await until(() => publicA.state && publicB.state, 'Public matchmaking failed');
  assert.equal(publicA.welcome.room, publicB.welcome.room);
  await until(() => publicA.state.players.some(p => p.id === publicB.welcome.id), 'Public players must share a live arena');
  console.log('PASS: public matchmaking, shared private room, room isolation, identical ticks, remote movement, anti-teleport, forged-score rejection, disconnect cleanup, bot refill.');
})().catch(error => { console.error(error); process.exitCode = 1; }).finally(() => { for (const socket of sockets) if (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING) socket.close(); });
