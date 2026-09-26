// Explicit local crash test. Requires an existing Wrangler executable; never targets production.
// WRANGLER_BIN=/path/to/wrangler node tests/arena-restart-live.cjs
const assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {mkdtempSync,openSync,closeSync,rmSync,readFileSync}=require('node:fs');
const {tmpdir}=require('node:os');
const {join}=require('node:path');
const {randomBytes}=require('node:crypto');
const cache=mkdtempSync(join(tmpdir(),'little-dill-restart-')), log=join(cache,'worker.log');
const endpoint='ws://127.0.0.1:8795/arena', room=randomBytes(3).toString('hex').toUpperCase();
const clients=[];let server=null;
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(check,label,timeout=20000){const start=Date.now();while(!await check()){if(Date.now()-start>timeout)throw Error(label);await pause(50);}}
async function start(){
  const fd=openSync(log,'a');
  server=spawn(process.env.WRANGLER_BIN||'wrangler',['dev','--config','wrangler.arena.jsonc','--ip','127.0.0.1','--port','8795','--persist-to',cache],{detached:true,stdio:['ignore',fd,fd]});closeSync(fd);
  server.on('error',()=>{});
  await until(async()=>{if(server.exitCode!==null)throw Error('Wrangler exited before startup');try{return (await fetch('http://127.0.0.1:8795/health',{signal:AbortSignal.timeout(500)})).ok;}catch{return false;}},'Wrangler did not start');
}
async function crash(){
  const child=server;server=null;if(!child)return;
  const exited=new Promise(resolve=>child.once('exit',resolve));
  // Kill Wrangler AND workerd without delivering a graceful close to the room.
  process.kill(-child.pid,'SIGKILL');await exited;
}
function connect(resume){
  const url=new URL(endpoint);url.searchParams.set('name','Crash Scout');url.searchParams.set('room',room);url.searchParams.set('reconnect','1');
  if(resume){url.searchParams.set('resumeToken',resume.resumeToken);url.searchParams.set('resumeRoom',resume.resumeRoom);}
  const client={socket:new WebSocket(url),state:null,food:[],welcome:null,closed:false,expired:false};clients.push(client);
  client.socket.addEventListener('error',()=>{});
  client.socket.addEventListener('close',()=>client.closed=true);
  client.socket.addEventListener('message',event=>{const packet=JSON.parse(event.data);if(packet.type==='welcome')client.welcome=packet;if(packet.type==='state'){client.state=packet;if(packet.food)client.food=packet.food;}if(packet.type==='resume-expired')client.expired=true;});
  return client;
}
const me=client=>client.state?.players.find(p=>p.id===client.welcome?.id);
const heartbeat=setInterval(()=>{for(const client of clients)if(client.socket.readyState===WebSocket.OPEN)client.socket.send('{"type":"ping"}');},4000);
(async()=>{
  await start();const owner=connect();await until(()=>owner.state,'join failed');
  let seq=0;
  await until(async()=>{
    assert.equal(owner.closed,false,"scout disconnected before the forced crash");
    const player=me(owner);
    if(player.alive&&player.mass>=60)return true;
    if(!player.alive)owner.socket.send('{"type":"respawn"}');
    else {const food=owner.food.reduce((a,b)=>!a||Math.hypot(b[1]-player.x,b[2]-player.y)<Math.hypot(a[1]-player.x,a[2]-player.y)?b:a,null);const dx=food[1]-player.x,dy=food[2]-player.y,n=Math.hypot(dx,dy)||1;owner.socket.send(JSON.stringify({type:'input',seq:++seq,x:dx/n,y:dy/n}));}
    await pause(50);return false;
  },'scout did not earn split mass',30000);
  owner.socket.send(JSON.stringify({type:'input',seq:++seq,x:0,y:0}));owner.socket.send('{"type":"split"}');
  await until(()=>me(owner)?.cells.length===2,'split failed');
  await pause(1200);const before=me(owner), token=owner.welcome;
  assert.equal(before.alive,true);assert.equal(before.cells.length,2);
  const killedAt=Date.now();await crash();await start();
  const recovered=connect(token);await until(()=>recovered.state||recovered.expired,'resume failed');
  assert.equal(recovered.expired,false);assert.equal(recovered.welcome.resumed,true);assert.equal(recovered.welcome.id,token.id);
  const after=me(recovered);
  assert.deepEqual(after.cells.map(cell=>cell.id),before.cells.map(cell=>cell.id));
  assert.ok(after.mass>=before.mass-9,'restart should restore earned mass from the recent checkpoint');
  assert.ok(recovered.state.tick>owner.state.tick,'server sequence must stay monotonic across restart');
  assert.ok(after.merge>0,'regroup countdown must remain paused during process downtime');
  assert.ok(Date.now()-killedAt<30000);
  recovered.socket.send('{"type":"leave"}');await until(()=>recovered.closed,'explicit exit failed');
  await crash();await start();const revoked=connect(token);await until(()=>revoked.expired,'leave was not durable');
  console.log('PASS: killed the real workerd process; restored identity, earned mass, split cell IDs, timers and monotonic ticks from SQLite; explicit leave remained revoked after another restart.');
})().catch(error=>{console.error(error);console.error(readFileSync(log,'utf8').split('\n').filter(line=>/ERROR|error|checkpoint/i.test(line)).slice(-12).join('\n'));process.exitCode=1;}).finally(async()=>{clearInterval(heartbeat);for(const client of clients)client.socket.close();await crash();rmSync(cache,{recursive:true,force:true});});
