// Brine jars, bounties, run goals and recaps. Kept free of arena-core imports
// because arena-core re-exports this module.
export const JAR = Object.freeze({ warnSeconds: 10, lingerSeconds: 8, radius: 260 });
export const EVENT_COLORS = Object.freeze({ ring: '#C8E06B99', ringFill: '#C8E06B26', mapJar: '#C8E06B', glass: '#D9EEF0', brine: '#7FA34A', lid: '#8C6A3C', bounty: '#F2C14E', ink: '#263E31' });
const finite = Number.isFinite;
const validGoal = goal => Array.isArray(goal) && typeof goal[0] === 'string' && finite(goal[1]) && finite(goal[2]);

export function goalLabel([kind, target] = []) {
  const n = finite(target) ? target : 0;
  if (kind === 'eat') return `Crunch ${n} pickle${n === 1 ? '' : 's'}`;
  if (kind === 'mass') return `Reach ${n} mass`;
  if (kind === 'survive') return n > 0 && n % 60 === 0 ? `Survive ${n / 60} min` : `Survive ${n}s`;
  if (kind === 'food') return `Eat ${n} pellets`;
  if (kind === 'jar') return 'Touch a jar spill';
  return 'Bonus goal';
}
export const goalDone = goal => validGoal(goal) && goal[2] >= goal[1];
export const goalProgress = ([, target, progress]) => `${Math.min(progress, target)}/${target}`;

export function eventState(snapshot, ownID) {
  const jar = snapshot?.jar, players = Array.isArray(snapshot?.players) ? snapshot.players : [];
  const own = players.find(player => player && player.id === ownID);
  const run = Array.isArray(own?.run) && own.run.length >= 4 && own.run.slice(0, 4).every(finite) ? own.run.slice(0, 4) : null;
  return {
    jar: jar && finite(jar.x) && finite(jar.y) && finite(jar.warn) ? { x: jar.x, y: jar.y, warn: Math.max(0, jar.warn) } : null,
    bounty: typeof snapshot?.bounty === 'string' && snapshot.bounty ? snapshot.bounty : null,
    goals: Array.isArray(own?.goals) ? own.goals.filter(validGoal).map(([kind, target, progress]) => [kind, target, progress]) : [],
    goalsDone: finite(own?.goalsDone) ? Math.max(0, Math.floor(own.goalsDone)) : 0,
    run
  };
}
export const jarSpilled = (previous, next) => Boolean(previous && next && previous.warn > 0 && next.warn === 0);

export function recapStats(own) {
  const { run, goals } = eventState({ players: own ? [own] : [] }, own?.id);
  if (!run) return null;
  const [peak, kills, seconds, rank] = run;
  return { peak, rank, kills, seconds, goalsDone: goals.filter(goalDone).length, goalsTotal: goals.length };
}
export const clockLabel = seconds => { const s = Math.max(0, Math.floor(seconds)); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; };
export function recapRows(stats, formatMass = String) {
  return [
    ['PEAK MASS', formatMass(stats.peak)], ['BEST RANK', stats.rank > 0 ? `#${stats.rank}` : '—'], ['CRUNCHES', String(stats.kills)],
    ['TIME ALIVE', clockLabel(stats.seconds)], ['GOALS', `${stats.goalsDone}/${stats.goalsTotal}`]
  ];
}

// World-space jar: the dashed ring pulses 3..6 screen px each second while warning.
export function drawJar(ctx, jar, { zoom = 1, time = 0, spilledFor = Infinity } = {}) {
  const warning = jar.warn > 0, tau = Math.PI * 2;
  ctx.save();
  if (!warning) { ctx.fillStyle = EVENT_COLORS.ringFill; ctx.beginPath(); ctx.arc(jar.x, jar.y, JAR.radius, 0, tau); ctx.fill(); }
  ctx.strokeStyle = EVENT_COLORS.ring; ctx.lineWidth = (warning ? 4.5 + 1.5 * Math.sin(time * tau) : 3) / zoom;
  ctx.setLineDash([18 / zoom, 12 / zoom]); ctx.beginPath(); ctx.arc(jar.x, jar.y, JAR.radius, 0, tau); ctx.stroke(); ctx.setLineDash([]);
  const tip = warning ? 0 : Math.min(1, spilledFor / .6), level = warning ? .7 : .7 * (1 - Math.min(1, spilledFor / 1.2));
  const wobble = warning && jar.warn < 3 ? Math.sin(time * 14) * .07 : 0;
  ctx.translate(jar.x, jar.y); ctx.rotate(wobble + tip * Math.PI * .5);
  ctx.lineWidth = 3; ctx.strokeStyle = EVENT_COLORS.ink; ctx.lineJoin = 'round';
  ctx.fillStyle = EVENT_COLORS.glass; ctx.beginPath(); ctx.roundRect(-30, -36, 60, 76, 14); ctx.fill();
  if (level > 0) {
    ctx.save(); ctx.clip(); ctx.fillStyle = EVENT_COLORS.brine; ctx.fillRect(-30, 40 - 76 * level, 60, 76 * level); ctx.restore();
  }
  ctx.beginPath(); ctx.roundRect(-30, -36, 60, 76, 14); ctx.stroke();
  ctx.fillStyle = EVENT_COLORS.lid; ctx.beginPath(); ctx.roundRect(-25, -49, 50, 15, 4); ctx.fill(); ctx.stroke();
  ctx.strokeStyle = '#FFFFFFB3'; ctx.lineWidth = 4; ctx.lineCap = 'round'; ctx.beginPath(); ctx.moveTo(-18, -24); ctx.lineTo(-18, 18); ctx.stroke();
  ctx.restore();
}
// Screen-space three-point crown whose base sits 1.25 radii above the piece center.
export function drawBountyCrown(ctx, x, y, width) {
  const w = width, h = w * .62;
  ctx.save(); ctx.translate(x, y); ctx.fillStyle = EVENT_COLORS.bounty; ctx.strokeStyle = EVENT_COLORS.ink; ctx.lineWidth = Math.max(1.2, w / 14); ctx.lineJoin = 'round';
  ctx.beginPath(); ctx.moveTo(-w / 2, 0); ctx.lineTo(-w / 2, -h); ctx.lineTo(-w / 4, -h * .45); ctx.lineTo(0, -h); ctx.lineTo(w / 4, -h * .45); ctx.lineTo(w / 2, -h); ctx.lineTo(w / 2, 0); ctx.closePath();
  ctx.fill(); ctx.stroke(); ctx.restore();
}
export const bountyCrownWidth = screenRadius => Math.max(14, Math.min(30, screenRadius * .55));
export function drawMapJar(map, jar, mapX, mapY, mapRadius, time = 0) {
  map.fillStyle = EVENT_COLORS.mapJar; map.strokeStyle = EVENT_COLORS.mapJar; map.lineWidth = 1;
  if (jar.warn > 0) {
    map.beginPath(); map.arc(mapX, mapY, 2.5, 0, Math.PI * 2); map.fill();
    map.beginPath(); map.arc(mapX, mapY, 3.5 + 4 * (time % 1), 0, Math.PI * 2); map.stroke();
  } else { map.beginPath(); map.arc(mapX, mapY, Math.max(3, mapRadius), 0, Math.PI * 2); map.fill(); }
}
