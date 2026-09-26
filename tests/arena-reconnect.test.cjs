const { test, after } = require('node:test');
const assert = require('node:assert/strict');
const workerModule = import('../server/arena-worker.mjs');
const NativeResponse = global.Response, NativePair = global.WebSocketPair;
// Only the Worker upgrade primitives are simulated. Room lifecycle and the
// authoritative engine run unchanged, with an injected wall clock at boundaries.
class Socket {
  constructor() { this.messages=[]; this.listeners=new Map(); this.closed=null; }
  accept() {}
  send(raw) { this.messages.push(JSON.parse(raw)); }
  addEventListener(name, callback) { this.listeners.set(name,callback); }
  close(code=1000, reason='') { this.closed={code,reason}; this.listeners.get('close')?.({code,reason}); }
}
global.WebSocketPair = class {
  constructor() { const server=new Socket(); this[0]={server}; this[1]=server; }
};
global.Response = class extends NativeResponse {
  constructor(body, init) {
    super(body, init?.status===101 ? {status:200} : init);
    if (init?.status===101) {Object.defineProperty(this,'status',{value:101});this.webSocket=init.webSocket;}
  }
};
after(()=>{global.Response=NativeResponse;global.WebSocketPair=NativePair;});
async function setup(t) {
  const {ArenaRoom}=await workerModule; let now=Date.now();
  const data=new Map(), storage={
    async get(key){return structuredClone(data.get(key));},
    async put(key,value){data.set(key,structuredClone(value));},
    async delete(key){return data.delete(key);},
    async setAlarm(time){this.alarm=time;},
    async deleteAlarm(){this.alarm=null;}
  };
  function create(){
    const room=new ArenaRoom({storage,blockConcurrencyWhile:fn=>fn(),waitUntil:promise=>promise.catch(()=>{})});
    room.now=()=>now;t.after(()=>clearInterval(room.timer));return room;
  }
  const room=create();
  return {room,storage,data,advance(ms){now+=ms;},async restart(old=room){
    await old.pendingCheckpoint;clearInterval(old.timer);
    const next=create();await next.ready;return next;
  }};
}
async function connect(room, query={}, ip='192.0.2.1') {
  const url=new URL('https://example.test/arena');
  for(const [key,value] of Object.entries({assignedRoom:'public-3',name:'SavedRun',brine:'spicy',outfit:'crown',reconnect:'1',...query}))url.searchParams.set(key,value);
  const response=await room.fetch(new Request(url,{headers:{Upgrade:'websocket','CF-Connecting-IP':ip}}));
  clearInterval(room.timer); room.timer=null;
  const socket=response.webSocket?.server;
  return {response,socket,welcome:socket?.messages.find(m=>m.type==='welcome'),state:socket?.messages.find(m=>m.type==='state')};
}
const credentials=welcome=>({resumeToken:welcome.resumeToken,resumeRoom:welcome.resumeRoom});

test('an older public checkpoint restores one hard bot and retains it after refill',async t=>{
  const fixture=await setup(t), first=await connect(fixture.room);
  const initial=[...fixture.room.engine.players.values()].filter(p=>p.bot&&p.profile.hard);
  assert.equal(initial.length,1);
  await fixture.room.pendingCheckpoint;
  const saved=fixture.data.get('arena-checkpoint-v1');
  delete saved.engine.publicRoom;delete saved.engine.hardBotId;
  fixture.data.set('arena-checkpoint-v1',saved);
  const restored=await fixture.restart(), resumed=await connect(restored,credentials(first.welcome));
  assert.equal(resumed.welcome.resumed,true);
  assert.equal(restored.engine.publicRoom,true);
  assert.equal([...restored.engine.players.values()].filter(p=>p.bot&&p.profile.hard).length,1);
  for(let n=0;n<15;n++) restored.engine.addPlayer(`extra-${n}`,{name:'Guest'});
  for(let n=0;n<15;n++) restored.engine.removePlayer(`extra-${n}`);
  assert.equal([...restored.engine.players.values()].filter(p=>p.bot&&p.profile.hard).length,1);
});

test('a process restart recovers a high-mass split run from durable state',async t=>{
  const fixture=await setup(t), {room,advance}=fixture;
  const first=await connect(room), p=room.engine.players.get(first.welcome.id);
  room.engine.time=120;room.engine.tick=2400;p.mass=54809;p.best=54809;p.shieldUntil=140;
  for(let n=0;n<3;n++){p.splitReady=0;room.engine.split(p);}
  advance(1100);room.tick();await room.pendingCheckpoint;
  const committed=structuredClone(p), food=structuredClone(room.engine.food);
  // Kill the process without a close event: only committed storage survives.
  advance(500);const restarted=await fixture.restart();
  const recovered=await connect(restarted,credentials(first.welcome));
  assert.equal(recovered.welcome?.resumed,true,'a fresh room instance forgot an active run');
  assert.equal(recovered.welcome.id,p.id);
  const actual=restarted.engine.players.get(p.id);
  assert.equal(actual.mass,committed.mass);assert.equal(actual.best,committed.best);
  assert.deepEqual(actual.cells,committed.cells);assert.equal(actual.cells.length,8);
  assert.deepEqual(restarted.engine.food,food,'food inventory survives with the run');
  assert.equal(actual.mergeUntil-restarted.engine.time,committed.mergeUntil-room.engine.time);
  assert.ok(recovered.state.tick>=room.engine.tick,'older installed clients need monotonic server ticks');
  actual.cells[0].mass+=3;assert.equal(actual.mass,committed.mass+3,'restored aggregate mass must remain a computed property');
  assert.ok(!JSON.stringify(recovered.state).includes(first.welcome.resumeToken));
});
test('repeated restarts preserve a disconnected deadline instead of renewing it',async t=>{
  const f=await setup(t), owner=await connect(f.room);
  await connect(f.room,{name:'Observer'},'192.0.2.2');
  owner.socket.close();await f.room.pendingCheckpoint;
  f.advance(10000);let restarted=await f.restart();
  assert.equal(restarted.heldSlots,2);
  const observer=await connect(restarted,{name:'New Observer'},'192.0.2.3');
  f.advance(19999);restarted.onMessage(observer.socket,JSON.stringify({type:'ping'}));restarted.tick();
  restarted=await f.restart(restarted);
  assert.ok(restarted.reconnects.has(owner.welcome.resumeToken));
  f.advance(1);
  const expired=await connect(restarted,credentials(owner.welcome));
  assert.equal(expired.socket.messages[0].type,'resume-expired');
});
test('intentional exits and policy rejection stay revoked after a process restart',async t=>{
  for(const input of [{type:'leave'},{type:'setMass',mass:12345}]){
    const f=await setup(t), owner=await connect(f.room);
    f.room.onMessage(owner.socket,JSON.stringify(input));await f.room.pendingCheckpoint;
    assert.equal(f.data.size,0,'the last revoked run must remove its checkpoint');
    assert.equal(f.storage.alarm,null);
    const restarted=await f.restart(), expired=await connect(restarted,credentials(owner.welcome));
    assert.equal(expired.socket.messages[0].type,'resume-expired');
  }
});
test('a cleanup alarm removes expired checkpoint data even if nobody returns',async t=>{
  const f=await setup(t), owner=await connect(f.room);
  owner.socket.close();await f.room.pendingCheckpoint;
  f.advance(30000);const restarted=await f.restart();await restarted.alarm();
  assert.equal(f.data.size,0);assert.equal(f.storage.alarm,null);assert.equal(restarted.heldSlots,0);
});
test('full-room checkpoints fit storage and reserve all returning players without storing IP addresses',async t=>{
  const f=await setup(t), owners=[];
  for(let n=0;n<64;n++){
    const owner=await connect(f.room,{name:`Player${n}`},`192.0.2.${n+1}`);owners.push(owner);
    const p=f.room.engine.players.get(owner.welcome.id);p.mass=800;
    for(let split=0;split<3;split++){p.splitReady=0;f.room.engine.split(p);}
  }
  await f.room.saveCheckpoint();
  const raw=JSON.stringify([...f.data.values()]);
  assert.ok(Buffer.byteLength(raw)<2*1024*1024,'SQLite-backed value limit');
  assert.ok(!raw.includes('192.0.2.'));
  const restarted=await f.restart();assert.equal(restarted.heldSlots,64);
  assert.equal((await connect(restarted)).response.status,503);
  const returned=await connect(restarted,credentials(owners[0].welcome));
  assert.equal(returned.welcome.resumed,true);assert.equal(returned.state.players.find(p=>p.id===returned.welcome.id).cells.length,8);
});
test('checkpoint writes are periodic during play and dead runs remain dead after restart',async t=>{
  const f=await setup(t), owner=await connect(f.room), p=f.room.engine.players.get(owner.welcome.id);
  const original=JSON.stringify([...f.data.values()]);
  p.best=54809;p.cells=[];p.alive=false;p.eatenBy='Hunter';p.diedAt=f.room.engine.time;
  f.advance(999);f.room.tick();assert.equal(JSON.stringify([...f.data.values()]),original);
  f.advance(1);f.room.tick();await f.room.pendingCheckpoint;
  const restarted=await f.restart(), returned=await connect(restarted,credentials(owner.welcome));
  const restored=returned.state.players.find(player=>player.id===p.id);
  assert.equal(restored.alive,false);assert.equal(restored.best,54809);assert.deepEqual(restored.cells,[]);
  assert.equal(restored.eatenBy,'Hunter');assert.equal(restored.mass,0);
});

test('an actively connected high-mass run is not deleted at 30 minutes or after several hours',async t=>{
  const {room,advance}=await setup(t), joined=await connect(room);
  const player=room.engine.players.get(joined.welcome.id);player.mass=729507;player.best=729507;player.x=3000;player.y=600;
  for(let split=0;split<3;split++){player.splitReady=0;room.engine.split(player);}
  player.shieldUntil=100;
  for(const elapsed of [1800001,5*60*60*1000]){
    advance(elapsed);
    room.onMessage(joined.socket,JSON.stringify({type:'ping'}));room.tick();
    assert.equal(joined.socket.closed,null,'run age must never kick an active connection');
    assert.equal(room.engine.players.get(joined.welcome.id),player);
    assert.equal(player.cells.length,8);assert.ok(player.mass>=729507);
    assert.ok(room.reconnects.has(joined.welcome.resumeToken));
  }
});
test('a long-running game can reconnect within 30 seconds regardless of its total age',async t=>{
  const {room,advance}=await setup(t), joined=await connect(room);
  const player=room.engine.players.get(joined.welcome.id);player.mass=729507;player.best=729507;player.x=3000;player.y=600;
  advance(2*60*60*1000);
  // A replacement socket can arrive before the radio closes its old transport.
  const takeover=await connect(room,credentials(joined.welcome));
  assert.equal(takeover.welcome?.resumed,true,'a live two-hour-old run must still resume');
  assert.equal(takeover.welcome.id,player.id);
  takeover.socket.close();advance(29999);
  const restored=await connect(room,credentials(joined.welcome));
  assert.equal(restored.welcome?.resumed,true,'run age must not shorten the disconnect grace period');
  assert.equal(restored.state.players.find(p=>p.id===player.id).mass,729507);
});
test('removing the run-age limit still times out idle transports and expires abandoned reservations',async t=>{
  const {room,advance}=await setup(t), joined=await connect(room);
  advance(15001);room.tick();
  assert.equal(joined.socket.closed.code,1001);assert.equal(room.heldSlots,1);
  assert.equal(room.engine.humans,0);
  advance(29999);
  const restored=await connect(room,credentials(joined.welcome));
  assert.equal(restored.welcome?.resumed,true);
  restored.socket.close();advance(30000);room.tick();
  assert.equal(room.heldSlots,0);assert.equal(room.timer,null);assert.equal(room.reconnects.size,0);
});
test('disconnect holds eight slices, mass and remaining timers then resumes the same identity',async t=>{
  const {room,advance}=await setup(t), first=await connect(room);
  await connect(room,{name:'Observer'},'192.0.2.2');
  room.engine.time=100;
  const p=room.engine.players.get(first.welcome.id);p.mass=240;p.seq=50;
  for(let n=0;n<3;n++){p.splitReady=0;room.engine.split(p);}
  assert.equal(p.cells.length,8);
  p.dashReady=102;p.splitReady=100.4;p.mergeUntil=111;p.lastMeal=99.5;
  const cells=JSON.stringify(p.cells);
  first.socket.close();
  assert.equal(room.heldSlots,1);assert.ok(!room.engine.players.has(p.id));
  assert.equal(room.engine.snapshot().players.some(player=>player.id===p.id),false,'parked runs are outside combat');
  advance(29999);room.engine.time=120;
  const resumed=await connect(room,{...credentials(first.welcome),name:'Changed',brine:'garlic',outfit:'original'});
  assert.equal(resumed.welcome.id,p.id);assert.equal(resumed.welcome.resumed,true);
  assert.equal(room.heldSlots,0);assert.equal(p.mass,240);assert.equal(JSON.stringify(p.cells),cells);
  assert.equal(p.name,'SavedRun');assert.equal(p.brine,'spicy');assert.equal(p.outfit,'crown');
  const state=resumed.state.players.find(player=>player.id===p.id);
  assert.equal(state.merge,11);assert.equal(state.cooldown,2);assert.equal(state.splitCooldown,.4);
  assert.ok(Array.isArray(resumed.state.food),'resume always sends a full inventory');
  assert.ok(room.engine.input(p.id,{type:'input',seq:1,x:1,y:0}),'new connection resets input ordering');
  assert.equal(p.dx,1);assert.equal(JSON.stringify(resumed.state).includes(first.welcome.resumeToken),false,'resume secret must never enter snapshots');
});
test('last disconnected player keeps the room alive only through the 30-second grace window',async t=>{
  const {room,advance}=await setup(t), joined=await connect(room), engine=room.engine;
  joined.socket.close();assert.equal(room.engine,engine);assert.equal(room.heldSlots,1);
  advance(30000);room.tick();
  assert.equal(room.heldSlots,0);assert.notEqual(room.engine,engine);assert.equal(room.timer,null);
  const expired=await connect(room,credentials(joined.welcome));
  assert.deepEqual(expired.socket.messages,[{type:'resume-expired'}]);assert.equal(expired.socket.closed.code,1000);
  assert.equal(room.engine.humans,0,'expired credentials never silently create a fresh run');
});
test('valid credentials replace a stale live socket without duplicate players or late-close removal',async t=>{
  const {room}=await setup(t), first=await connect(room);
  const second=await connect(room,credentials(first.welcome));
  assert.equal(first.socket.closed.code,4001);assert.equal(second.welcome.id,first.welcome.id);
  first.socket.close();assert.equal(room.sessions.size,1);assert.equal(room.engine.humans,1);assert.equal(room.heldSlots,0);
  assert.ok(room.engine.players.has(second.welcome.id));
});
test('explicit leave and protocol violations revoke reconnect credentials immediately',async t=>{
  const {room}=await setup(t);
  for(const [packet,code] of [[{type:'leave'},1000],[{type:'setMass',mass:999999},1008]]){
    const joined=await connect(room);room.onMessage(joined.socket,JSON.stringify(packet));
    assert.equal(joined.socket.closed.code,code);assert.equal(room.heldSlots,0);assert.equal(room.reconnects.has(joined.welcome.resumeToken),false);
    assert.equal((await connect(room,credentials(joined.welcome))).socket.messages[0].type,'resume-expired');
  }
});
test('legacy clients leave immediately and a missing token cannot recover another player',async t=>{
  const {room}=await setup(t), legacy=await connect(room,{reconnect:'0'});
  assert.equal(legacy.welcome.resumeToken,undefined);legacy.socket.close();assert.equal(room.heldSlots,0);
  const owner=await connect(room), impostor=await connect(room,{resumeToken:crypto.randomUUID(),resumeRoom:owner.welcome.resumeRoom});
  assert.equal(impostor.socket.messages[0].type,'resume-expired');assert.equal(room.engine.humans,1);
});
test('a full room reserves a disconnected slot and admits its owner ahead of fresh joins',async t=>{
  const {room,advance}=await setup(t), clients=[];
  for(let n=0;n<64;n++)clients.push(await connect(room,{name:`Player${n}`},`192.0.2.${n+1}`));
  const saved=clients[0];saved.socket.close();assert.equal(room.engine.humans,63);assert.equal(room.heldSlots,1);
  assert.equal((await connect(room,{},'198.51.100.1')).response.status,503);
  const restored=await connect(room,credentials(saved.welcome),'198.51.100.1');
  assert.equal(restored.welcome.id,saved.welcome.id);assert.equal(room.engine.humans,64);
  restored.socket.close();advance(30000);room.expireReservations();
  assert.equal((await connect(room,{},'198.51.100.2')).response.status,101);
});
test('public reconnect routing targets the original room and rejects incomplete credentials',async()=>{
  const {default:worker}=await workerModule, rooms=[];
  const env={ARENAS:{getByName(name){rooms.push(name);return {fetch:async()=>new Response('ok')};}}};
  const token=crypto.randomUUID();
  const response=await worker.fetch(new Request(`https://example.test/arena?resumeToken=${token}&resumeRoom=public-12`,{headers:{Upgrade:'websocket'}}),env);
  assert.equal(response.status,200);assert.deepEqual(rooms,['public-12']);
  for(const query of [`resumeToken=${token}`,`resumeToken=${token}&resumeRoom=public-99`,`resumeToken=player-id&resumeRoom=public-1`]){
    assert.equal((await worker.fetch(new Request(`https://example.test/arena?${query}`,{headers:{Upgrade:'websocket'}}),env)).status,400);
  }
  assert.deepEqual(rooms,['public-12']);
});
