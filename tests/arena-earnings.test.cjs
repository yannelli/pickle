const { test } = require('node:test');
const assert = require('node:assert/strict');
const arena = import('../server/arena-engine.mjs');

function seeded(seed = 19) {
  return () => { seed = (Math.imul(seed,1664525)+1013904223)>>>0; return seed/4294967296; };
}

async function setup() {
  const { ArenaEngine, ...api } = await arena;
  const engine = new ArenaEngine({random:seeded()}), player = engine.addPlayer('human',{name:'Player'});
  for (const [id,p] of engine.players) if (p.bot) engine.players.delete(id);
  engine.food=[];
  return {engine,player,ArenaEngine,...api};
}

test('joining, movement, and forged input do not earn mass',async()=>{
  const {engine,player,parseIntent,RULES}=await setup();
  assert.equal(player.mass,RULES.startMass);
  assert.equal(player.earnedMass,0);
  assert.equal(engine.snapshot(false).players.find(p=>p.id===player.id).earnedMass,0);
  const intent=parseIntent('{"type":"input","seq":1,"x":1,"y":0,"mass":9000,"earnedMass":9000}');
  assert.equal('earnedMass' in intent,false);
  assert.equal(engine.input(player.id,intent),true);
  engine.step(.1);
  assert.equal(player.earnedMass,0);
});

test('food and absorbed opponent mass credit exactly what the player collects',async()=>{
  const {engine,player}=await setup();
  engine.food=[{id:1,x:player.x,y:player.y,value:9}];
  engine.makeFood=()=>({id:engine.nextFood++,x:5000,y:4000,value:3});
  engine.step(0);
  assert.equal(player.mass,34);
  assert.equal(player.earnedMass,9);
  const prey=engine.addPlayer('prey',{name:'Prey'});
  for(const [id,p] of engine.players)if(p.bot)engine.players.delete(id);
  engine.food=[];player.mass=100;prey.mass=25;
  player.x=prey.x=1000;player.y=prey.y=1000;
  player.shieldUntil=prey.shieldUntil=0;
  engine.step(0);
  assert.equal(prey.alive,false);
  assert.equal(player.mass,117.5);
  assert.equal(player.earnedMass,26.5);
  assert.equal(prey.earnedMass,0);
  assert.equal(engine.snapshot(false).players.find(p=>p.id===player.id).earnedMass,26.5);
});

test('splits, regrouping, death, respawn, and recovery preserve earned mass',async()=>{
  const {engine,player,ArenaEngine,restorePlayer,RULES}=await setup();
  engine.food=[{id:1,x:player.x,y:player.y,value:9}];
  engine.makeFood=()=>({id:engine.nextFood++,x:5000,y:4000,value:3});
  engine.step(0);
  player.mass=240;engine.food=[];
  assert.equal(engine.split(player),true);
  assert.equal(player.mass,240);assert.equal(player.earnedMass,9);
  engine.time=player.mergeUntil;
  for(const cell of player.cells){cell.x=1000;cell.y=1000;cell.vx=cell.vy=0;}
  engine.regroup(player,0);
  assert.equal(player.cells.length,1);assert.equal(player.earnedMass,9);
  player.dx=1;engine.dash(player);
  assert.equal(player.earnedMass,9);
  player.alive=false;player.diedAt=engine.time-3;player.cells=[];
  assert.equal(engine.respawn(player),true);
  assert.equal(player.mass,RULES.startMass);assert.equal(player.earnedMass,9);
  assert.equal(engine.snapshot(false).players.find(p=>p.id===player.id).earnedMass,9);
  assert.equal(restorePlayer(structuredClone(player)).earnedMass,9);
  const checkpoint=engine.checkpoint();
  assert.equal(new ArenaEngine({checkpoint}).players.get(player.id).earnedMass,9);
  delete checkpoint.players.find(p=>p.id===player.id).earnedMass;
  const old=new ArenaEngine({checkpoint});
  assert.equal(old.players.get(player.id).earnedMass,0);
  assert.equal(old.snapshot(false).players.find(p=>p.id===player.id).earnedMass,0);
});
