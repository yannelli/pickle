// Explicit local/production check. The test earns mass and only sends normal inputs.
const assert=require('node:assert/strict');
const {randomBytes}=require('node:crypto');
const endpoint=process.argv[2]||'ws://127.0.0.1:8794/arena';
const room=randomBytes(3).toString('hex').toUpperCase(), clients=[];
const pause=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(check,label,timeout=15000){const start=Date.now();while(!check()){if(Date.now()-start>timeout)throw Error(label);await pause(25);}}
function connect(name,resume=null){
  const url=new URL(endpoint);url.searchParams.set('name',name);url.searchParams.set('room',room);url.searchParams.set('reconnect','1');
  if(resume){url.searchParams.set('resumeToken',resume.resumeToken);url.searchParams.set('resumeRoom',resume.resumeRoom);}
  const c={socket:new WebSocket(url),welcome:null,state:null,expired:false,closed:false,food:[]};clients.push(c);
  c.socket.addEventListener('message',event=>{const p=JSON.parse(event.data);if(p.type==='welcome')c.welcome=p;if(p.type==='resume-expired')c.expired=true;if(p.type==='state'){c.state=p;if(p.food)c.food=p.food;}});
  c.socket.addEventListener('close',()=>c.closed=true);return c;
}
const heartbeat=setInterval(()=>{for(const c of clients)if(c.socket.readyState===WebSocket.OPEN)c.socket.send(JSON.stringify({type:'ping'}));},4000);
(async()=>{
  const owner=connect('Reconnect Scout'),observer=connect('Reconnect Witness');
  await until(()=>owner.state&&observer.state,'clients did not join');
  const start=Date.now();let seq=0;
  while(Date.now()-start<20000){
    const me=owner.state.players.find(p=>p.id===owner.welcome.id);
    if(me.alive&&me.mass>=60){owner.socket.send(JSON.stringify({type:'input',seq:++seq,x:0,y:0}));owner.socket.send(JSON.stringify({type:'split'}));break;}
    if(!me.alive)owner.socket.send(JSON.stringify({type:'respawn'}));
    else {const nearest=owner.food.reduce((a,b)=>!a||Math.hypot(b[1]-me.x,b[2]-me.y)<Math.hypot(a[1]-me.x,a[2]-me.y)?b:a,null);const dx=nearest[1]-me.x,dy=nearest[2]-me.y,n=Math.hypot(dx,dy)||1;owner.socket.send(JSON.stringify({type:'input',seq:++seq,x:dx/n,y:dy/n}));}
    await pause(100);
  }
  await until(()=>owner.state.players.find(p=>p.id===owner.welcome.id)?.cells.length===2,'scout must earn mass and split');
  const before=owner.state.players.find(p=>p.id===owner.welcome.id),credentials=owner.welcome;
  owner.socket.close();
  await until(()=>!observer.state.players.some(p=>p.id===credentials.id),'disconnected run must be held outside combat');
  const expiring=connect('Expiry Scout');await until(()=>expiring.welcome,'expiry client welcome');expiring.socket.close();
  await until(()=>!observer.state.players.some(p=>p.id===expiring.welcome.id),'second run must be held');
  const heldAt=Date.now();
  const impostor=connect('Wrong Secret',{...credentials,resumeToken:credentials.id});
  await until(()=>impostor.expired,'a player ID must not grant reconnect access');
  await pause(Math.max(0,heldAt+26500-Date.now()));
  const recovered=connect('Changed Name',credentials);await until(()=>recovered.state,'run did not recover within grace');
  assert.equal(recovered.welcome.resumed,true);assert.equal(recovered.welcome.id,credentials.id);
  assert.equal(recovered.welcome.resumeRoom,credentials.resumeRoom);
  const after=recovered.state.players.find(p=>p.id===credentials.id);
  assert.equal(after.name,before.name);assert.ok(after.mass>=before.mass);assert.deepEqual(after.cells.map(c=>c.id),before.cells.map(c=>c.id));
  assert.ok(after.merge>10,'regroup timer must remain paused while disconnected');
  recovered.socket.send(JSON.stringify({type:'input',seq:1,x:1,y:0}));
  recovered.socket.send(JSON.stringify({type:'leave'}));await until(()=>recovered.closed,'explicit leave must close');
  const left=connect('Already Left',credentials);await until(()=>left.expired,'explicit leave must revoke recovery');
  await pause(Math.max(0,heldAt+31200-Date.now()));
  const tooLate=connect('Too Late',expiring.welcome);await until(()=>tooLate.expired,'expired run must not resume');
  assert.equal(tooLate.welcome,null,'expiry must not silently create a fresh player');
  console.log('PASS: earned split run recovered after26.5s with identity/mass/cells/timer intact; private room preserved; playerID cannot hijack; explicit leave revoked;31.2s expiry refused.');
})().catch(error=>{console.error(error);process.exitCode=1;}).finally(()=>{clearInterval(heartbeat);for(const c of clients){if(c.socket.readyState===WebSocket.OPEN)c.socket.send(JSON.stringify({type:'leave'}));c.socket.close();}});
