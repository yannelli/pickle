// Explicit live split/merge smoke test. The player earns all mass using ordinary inputs.
const assert = require('node:assert/strict');
const { randomBytes } = require('node:crypto');
const endpoint = process.argv[2] || 'ws://127.0.0.1:8788/arena';
async function attempt() {
  const room = randomBytes(3).toString('hex').toUpperCase(), sockets = [];
  let meID, ownState, peerState, food = [], seq = 0, phase = 0, splitAt = 0, peakCells = 0, sawSameCells = false, secondSplitRequested = false;
  const started = Date.now();
  function connect(name, receive) {
    const url = new URL(endpoint); url.searchParams.set('room',room); url.searchParams.set('name',name);
    const ws = new WebSocket(url); sockets.push(ws); ws.addEventListener('message',event=>receive(JSON.parse(event.data))); return ws;
  }
  const player = connect('Split Scout',data=>{if(data.type==='welcome')meID=data.id;if(data.type==='state'){ownState=data;if(data.food)food=data.food;}});
  const peer = connect('Split Witness',data=>{if(data.type==='state')peerState=data;});
  try {
    while(Date.now()-started<70000) {
      await new Promise(resolve=>setTimeout(resolve,50));
      if(player.readyState!==WebSocket.OPEN||!meID||!ownState)continue;
      const me = ownState.players.find(p=>p.id===meID); if(!me)continue;
      if(!me.alive)throw new Error('Scout was eaten during the live match; retry in a fresh room.');
      assert.ok(Array.isArray(me.cells),'Server must publish authoritative cells');
      peakCells=Math.max(peakCells,me.cells.length);
      const observed=peerState?.players.find(p=>p.id===meID);
      if(me.cells.length===4&&observed?.cells.length===4&&me.cells.map(c=>c.id).sort().join()===observed.cells.map(c=>c.id).sort().join())sawSameCells=true;
      const anchor=me.cells.reduce((a,b)=>a.mass>b.mass?a:b);
      const closest=food.reduce((a,b)=>!a||Math.hypot(b[1]-anchor.x,b[2]-anchor.y)<Math.hypot(a[1]-anchor.x,a[2]-anchor.y)?b:a,null);
      let dx=(closest?.[1]??anchor.x)-anchor.x,dy=(closest?.[2]??anchor.y)-anchor.y;
      const threats=ownState.players.filter(p=>p.id!==meID&&p.alive).flatMap(p=>p.cells).filter(c=>me.cells.some(piece=>c.mass>piece.mass*1.18&&Math.hypot(c.x-piece.x,c.y-piece.y)<500));
      if(threats.length){dx=0;dy=0;for(const threat of threats){const x=me.x-threat.x,y=me.y-threat.y,d=Math.max(1,Math.hypot(x,y));dx+=x/d/d;dy+=y/d/d;}if(me.x<250)dx+=.007;if(me.x>ownState.width-250)dx-=.007;if(me.y<250)dy+=.007;if(me.y>ownState.height-250)dy-=.007;}
      const length=Math.hypot(dx,dy)||1; player.send(JSON.stringify({type:'input',seq:++seq,x:dx/length,y:dy/length}));
      if(peer.readyState===WebSocket.OPEN)peer.send(JSON.stringify({type:'input',seq,x:0,y:0}));
      if(phase===0&&me.mass>=240){player.send(JSON.stringify({type:'split'}));phase=1;}
      else if(phase===1&&me.cells.length===2&&me.splitCooldown===0&&!secondSplitRequested){player.send(JSON.stringify({type:'split'}));secondSplitRequested=true;}
      if(phase===1&&me.cells.length===4){phase=2;splitAt=ownState.time;assert.ok(me.merge>10);}
      else if(phase===2&&me.cells.length<4&&ownState.time-splitAt<11.7)throw new Error('A piece was eaten before regroup; retry in a fresh room.');
      if(phase===2&&me.cells.length===1){assert.ok(sawSameCells,'Peer must see the same four cell IDs');assert.ok(ownState.time-splitAt>=11.7,'No early merge');assert.equal(me.merge,0);console.log(`PASS: earned mass, split 1→2→4, peer saw identical cells, regrouped to 1 after ${(ownState.time-splitAt).toFixed(1)}s; peak ${peakCells} cells.`);return;}
    }
    throw new Error(`Timed out in phase ${phase}, peak ${peakCells} cells.`);
  } finally {for(const socket of sockets)socket.close();}
}
(async()=>{for(let n=1;n<=3;n++){try{return await attempt();}catch(error){if(n===3)throw error;console.log(`Match ${n}: ${error.message}`);}}})().catch(error=>{console.error(error);process.exitCode=1;});
