// Explicit WebSocket integration check; validates food-delta clients against a legacy peer.
const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const endpoint = process.argv[2] || 'ws://127.0.0.1:8794/arena';
const sockets = [], room = randomBytes(3).toString('hex').toUpperCase();
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
async function until(check, label) {
  const start = Date.now();
  while (!check()) { if (Date.now()-start > 15000) throw Error(label); await pause(30); }
}
function connect(modern, name) {
  const url = new URL(endpoint); url.searchParams.set('room',room); url.searchParams.set('name',name);
  if (modern) url.searchParams.set('foodDeltas','1');
  const socket = new WebSocket(url); sockets.push(socket);
  const client = {socket,id:null,state:null,joinedTick:null,food:new Map(),history:new Map(),full:0,delta:0,bytes:0};
  socket.addEventListener('message', event => {
    const data = JSON.parse(event.data);
    if (data.type === 'welcome') client.id = data.id;
    if (data.type !== 'state') return;
    client.bytes += event.data.length; client.state = data; client.joinedTick ??= data.tick;
    if (Array.isArray(data.food)) {client.food = new Map(data.food.map(f => [f[0],f])); client.full++;}
    if (Array.isArray(data.foodAdded)) {
      for (const id of data.foodRemoved || []) client.food.delete(id);
      for (const pellet of data.foodAdded) client.food.set(pellet[0],pellet);
      client.delta++;
    }
    if (data.tick % 4 === 0) client.history.set(data.tick,[...client.food.values()].sort((a,b) => a[0]-b[0]));
  });
  return client;
}
(async () => {
  const legacy = connect(false,'Legacy QA'), modern = connect(true,'Delta QA');
  await until(() => legacy.state?.humans === 2 && modern.state?.humans === 2,'initial clients must join');
  assert.equal(modern.full,1,'delta clients receive one full join inventory');
  let seq=0;
  for (let i=0;i<24;i++) {
    const me=modern.state.players.find(p=>p.id===modern.id);
    if (!me.alive) modern.socket.send(JSON.stringify({type:'respawn'}));
    else {
      const target=[...modern.food.values()].reduce((best,f) => !best || Math.hypot(f[1]-me.x,f[2]-me.y)<Math.hypot(best[1]-me.x,best[2]-me.y) ? f : best,null);
      const dx=target[1]-me.x,dy=target[2]-me.y,n=Math.hypot(dx,dy)||1;
      modern.socket.send(JSON.stringify({type:'input',seq:++seq,x:dx/n,y:dy/n}));
    }
    await pause(100);
  }
  const newcomer=connect(true,'Joining QA');
  await until(() => newcomer.delta >= 4 && modern.state.humans===3,'newcomer must join between delta updates');
  // Joining relocates a snack trail between ticks, after peers may have received
  // that tick's broadcast. Compare subsequent shared broadcasts, not the join sync.
  const common=[...modern.history.keys()].filter(t => t>newcomer.joinedTick && legacy.history.has(t) && newcomer.history.has(t));
  assert.ok(common.length >= 3);
  for(const tick of common) {
    assert.deepEqual(modern.history.get(tick),legacy.history.get(tick),`modern food at tick ${tick}`);
    assert.deepEqual(newcomer.history.get(tick),legacy.history.get(tick),`join synchronization at tick ${tick}`);
  }
  assert.equal(modern.full,1);assert.ok(legacy.full>5);assert.ok(modern.delta>5);
  assert.equal(modern.food.size,3375);
  assert.ok(modern.bytes<legacy.bytes*.65,'delta transport must substantially reduce traffic');
  console.log(`PASS: full join sync, foraging deltas, relocated spawn trails, mid-stream newcomer and legacy inventory parity at ${common.length} ticks; delta traffic ${Math.round(modern.bytes/legacy.bytes*100)}% of legacy.`);
})().catch(error => {console.error(error);process.exitCode=1;}).finally(() => {for(const socket of sockets) socket.close();});
