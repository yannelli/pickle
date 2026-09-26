export const BRINES = ['classic', 'garlic', 'spicy'];
export const OUTFITS = ['original', 'sprout', 'bow', 'shades', 'crown', 'party'];
// Pet varieties, matching PickleVariety in the iOS app.
export const VARIETIES = {
  dill: { brine: 'classic', color: '#78954B', light: '#A1B56B', dark: '#527637', shape: 'long' },
  gherkin: { brine: 'classic', color: '#709855', light: '#BAD28C', dark: '#486B37', shape: 'round' },
  garlic: { brine: 'garlic', color: '#98A76D', light: '#D1D99D', dark: '#617C4C', shape: 'crooked' },
  butter: { brine: 'garlic', color: '#B0A44D', light: '#DDCE80', dark: '#877A39', shape: 'round' },
  chili: { brine: 'spicy', color: '#958749', light: '#D2AF73', dark: '#6A693A', shape: 'long' },
  pepper: { brine: 'spicy', color: '#66875D', light: '#A7C18A', dark: '#415C3F', shape: 'crooked' }
};
const SPOTS = [[.42, -.55], [.5, .38], [-.45, .5], [.05, .74]];
export function varietyOf(p) {
  if (Object.hasOwn(VARIETIES, p?.variety || '')) return p.variety;
  return Object.keys(VARIETIES).find(id => VARIETIES[id].brine === p?.brine) || 'dill';
}
export function pickleBody(shape, size, cucumber = false) {
  if (cucumber) return { halfWidth: size * .7, halfHeight: size, lean: 0, round: false };
  if (shape === 'round') return { halfWidth: size * .96, halfHeight: size * .9, lean: 0, round: true };
  return { halfWidth: size * .8, halfHeight: size, lean: shape === 'crooked' ? .16 : 0, round: false };
}
// Happy squint after a bite; tight squint while an unshielded piece big enough to eat this one is in reach.
export function pieceMood(cell, cells, ateAgo = Infinity) {
  if (ateAgo < .35) return 'chomp';
  const threatened = !(cell.shield > 0) && cells.some(other => {
    if (other.ownerID === cell.ownerID || other.shield > 0 || other.mass < cell.mass * 1.22) return false;
    return Math.hypot(other.x - cell.x, other.y - cell.y) <= radius(other.mass) + radius(cell.mass) * .65 + 45;
  });
  return threatened ? 'threatened' : cell.dash > 0 ? 'dash' : 'calm';
}
export function blinking(id, time) {
  const offset = [...String(id || '')].reduce((sum, c) => sum + c.charCodeAt(0), 0) % 40 / 10;
  return time > 0 && (time + offset) % 4.2 < .13;
}
export const clamp = (n, min, max) => Math.max(min, Math.min(max, n));
export function radius(mass) {
  const base = 13 + Math.sqrt(Math.max(0, mass)) * 3.4, excess = Math.max(0, base - 149);
  return base <= 149 ? base : 149 + 260 * excess / (260 + excess);
}
export function viewportBounds(layoutWidth, layoutHeight, visual = null) {
  const positive = (value, fallback) => Number.isFinite(value) && value > 0 ? value : fallback;
  return {
    width: positive(visual?.width, positive(layoutWidth, 320)),
    height: positive(visual?.height, positive(layoutHeight, 568)),
    left: Number.isFinite(visual?.offsetLeft) ? Math.max(0, visual.offsetLeft) : 0,
    top: Number.isFinite(visual?.offsetTop) ? Math.max(0, visual.offsetTop) : 0
  };
}
export function cameraZoom(width, height, mass) {
  const span = Math.max(1, Math.min(width, height));
  // No minimum zoom: large dills retain breathing room on the smallest screen.
  return Math.min(1.08, span / (radius(mass) * 8 + 340));
}
export function playerCells(player) {
  if (!player?.alive) return [];
  if (Array.isArray(player.cells)) return player.cells.filter(cell => typeof cell.id === 'string' && Number.isFinite(cell.x) && Number.isFinite(cell.y) && Number.isFinite(cell.mass) && cell.mass > 0);
  return [{ id: player.id, x: player.x, y: player.y, mass: player.mass }];
}
export function flattenCells(players) {
  return players.flatMap(player => playerCells(player).map(cell => ({ ...player, ...cell, ownerID: player.id, totalMass: player.mass })));
}
export function splitState(player) {
  const cells = playerCells(player), count = cells.length;
  const largest = Math.max(0, ...cells.map(cell => cell.mass)), cooldown = Math.max(0, player?.splitCooldown || 0);
  let reason = 'Launch a little dill';
  if (!player?.alive) reason = 'Respawn to split';
  else if (!Array.isArray(player.cells)) reason = 'Available next round';
  else if (count >= 4) reason = '4 pieces · maximum';
  else if (cooldown > 0) reason = `${cooldown.toFixed(1)}s cooldown`;
  else if (largest < 60) reason = `${Math.ceil(60 - largest)} more mass`;
  return { count, enabled: !!player?.alive && Array.isArray(player.cells) && count < 4 && largest >= 60 && cooldown <= 0, reason, merge: Math.max(0, player?.merge || 0) };
}
export function cameraFrame(width, height, player, insets = {}) {
  const cells = playerCells(player);
  const left = clamp(insets.left || 0, 0, width * .2), right = clamp(insets.right || 0, 0, width * .2);
  const top = clamp(insets.top || 0, 0, height * .42), bottom = clamp(insets.bottom || 0, 0, height * .32);
  const screenX = (left + width - right) / 2, screenY = (top + height - bottom) / 2;
  if (!cells.length) return { x: player?.x || 0, y: player?.y || 0, screenX, screenY, zoom: cameraZoom(width, height, player?.mass || 25) };
  const minX = Math.min(...cells.map(cell => cell.x - radius(cell.mass) * 1.7));
  const maxX = Math.max(...cells.map(cell => cell.x + radius(cell.mass) * 1.7));
  const minY = Math.min(...cells.map(cell => cell.y - radius(cell.mass) * 1.9));
  const maxY = Math.max(...cells.map(cell => cell.y + radius(cell.mass) * 1.9));
  const fit = Math.min(Math.max(1, width - left - right - 28) / Math.max(1, maxX - minX), Math.max(1, height - top - bottom - 40) / Math.max(1, maxY - minY));
  return { x: (minX + maxX) / 2, y: (minY + maxY) / 2, screenX, screenY, zoom: Math.min(cameraZoom(width, height, player.mass), fit) };
}
export function massLabel(value) {
  const mass = Math.max(0, Math.floor(value));
  if (mass < 10000) return String(mass);
  if (mass >= 1e15) return mass.toExponential(1).replace('.0e', 'e').replace('e+', 'e');
  for (const [threshold, suffix] of [[1e12, 'T'], [1e9, 'B'], [1e6, 'M'], [1e3, 'K']]) {
    if (mass >= threshold) return `${(mass / threshold).toFixed(mass < threshold * 100 ? 1 : 0).replace(/\.0$/, '')}${suffix}`;
  }
  return String(mass);
}
export const roomCode = raw => /^[a-z0-9]{6}$/i.test(String(raw || '').trim()) ? String(raw).trim().toUpperCase() : null;
export function direction(x, y) {
  if (!Number.isFinite(x) || !Number.isFinite(y)) return { x: 0, y: 0 };
  const length = Math.max(1, Math.hypot(x, y));
  return { x: x / length, y: y / length };
}
export function playerName(value) { return Array.from(String(value || '').replace(/[\p{C}\u115F\u1160\u2800\u3164\uFFA0]/gu, '').trim()).slice(0, 18).join('') || 'Dilly'; }
export function socketURL(origin, settings, room = null) {
  const url = new URL('/arena', origin); url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
  url.searchParams.set('foodDeltas', '1');
  url.searchParams.set('name', playerName(settings.name));
  url.searchParams.set('brine', BRINES.includes(settings.brine) ? settings.brine : 'classic');
  url.searchParams.set('outfit', OUTFITS.includes(settings.outfit) ? settings.outfit : 'sprout');
  url.searchParams.set('variety', varietyOf(settings));
  if (roomCode(room)) url.searchParams.set('room', roomCode(room));
  return url;
}
export function applyFoodUpdate(previousFood = [], snapshot = {}) {
  // Full snapshots reset inventory, including an intentionally empty garden.
  if (Array.isArray(snapshot.food)) return snapshot.food;
  const removed = Array.isArray(snapshot.foodRemoved) ? snapshot.foodRemoved : [];
  const added = Array.isArray(snapshot.foodAdded) ? snapshot.foodAdded : [];
  if (!removed.length && !added.length) return previousFood;
  const food = new Map(previousFood.map(pellet => [pellet[0], pellet]));
  for (const id of removed) food.delete(id);
  for (const pellet of added) food.set(pellet[0], pellet);
  return [...food.values()];
}
export function shareURL(origin, room = null) {
  const url = new URL('/', origin);
  if (roomCode(room)) url.searchParams.set('room', roomCode(room));
  return url.href;
}
export function interpolate(previous, next, alpha) {
  if (!previous || !next.alive || !previous.alive || Math.hypot(next.x - previous.x, next.y - previous.y) > 400) return next;
  const t = clamp(alpha, 0, 1);
  const result = { ...next, x: previous.x + (next.x - previous.x) * t, y: previous.y + (next.y - previous.y) * t, mass: previous.mass + (next.mass - previous.mass) * t };
  if (Array.isArray(next.cells)) {
    const oldCells = new Map(playerCells(previous).map(cell => [cell.id, cell]));
    result.cells = playerCells(next).map(cell => {
      const old = oldCells.get(cell.id);
      if (!old || Math.hypot(cell.x - old.x, cell.y - old.y) > 400) return cell;
      return { ...cell, x: old.x + (cell.x - old.x) * t, y: old.y + (cell.y - old.y) * t, mass: old.mass + (cell.mass - old.mass) * t };
    });
  }
  return result;
}
// Drawn in world coordinates; screenScale keeps outlines and shields native-sized.
export function drawPickle(ctx, p, x, y, size, time = 0, own = false, screenScale = 1) {
  const ink = '#263E31', peach = '#F1C9B4';
  // The live piece count is the source of truth: even regrouping pieces stay
  // fresh cucumbers until the server has actually combined them into one.
  const cucumber = Array.isArray(p.cells) && p.cells.length > 1;
  const look = VARIETIES[varietyOf(p)], { halfWidth, halfHeight, lean, round } = pickleBody(look.shape, size, cucumber);
  const pixel = 1 / screenScale, mood = p.mood || 'calm';
  ctx.save(); ctx.translate(x, y); ctx.rotate(lean); ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  if (p.dash > 0) {
    ctx.fillStyle = '#D4EB8566'; ctx.beginPath();
    ctx.ellipse(0, 0, halfWidth + 8 * pixel, halfHeight + 8 * pixel, 0, 0, Math.PI * 2); ctx.fill();
  }
  if (p.shield > 0) {
    ctx.strokeStyle = '#FFFFFFE6'; ctx.lineWidth = 2 * pixel; ctx.setLineDash([4 * pixel, 4 * pixel]);
    ctx.beginPath(); ctx.ellipse(0, 0, halfWidth + 7 * pixel, halfHeight + 7 * pixel, 0, 0, Math.PI * 2); ctx.stroke(); ctx.setLineDash([]);
  }
  ctx.fillStyle = '#263E311A'; ctx.beginPath();
  ctx.ellipse(pixel, 5 * pixel, halfWidth, halfHeight, 0, 0, Math.PI * 2); ctx.fill();
  ctx.fillStyle = cucumber ? '#6DA86B' : look.color; ctx.strokeStyle = ink; ctx.lineWidth = (own ? 2.5 : 1.5) * pixel;
  ctx.beginPath();
  if (round) ctx.ellipse(0, 0, halfWidth, halfHeight, 0, 0, Math.PI * 2); else ctx.roundRect(-halfWidth, -halfHeight, halfWidth * 2, halfHeight * 2, halfWidth);
  ctx.fill(); ctx.stroke();
  if (cucumber) {
    ctx.strokeStyle = '#B9D889A6'; ctx.lineWidth = Math.max(pixel, size * .075);
    for (const stripe of [-.35, 0, .35]) {
      ctx.beginPath(); ctx.moveTo(size * stripe, -size * .58);
      ctx.quadraticCurveTo(size * (stripe - .08), 0, size * stripe, size * .62); ctx.stroke();
    }
    if (!p.outfit || p.outfit === 'original') {
      ctx.strokeStyle = ink; ctx.lineWidth = Math.max(pixel, size * .045);
      ctx.beginPath(); ctx.moveTo(0, -size * .98);
      ctx.quadraticCurveTo(-size * .16, -size * 1.18, size * .04, -size * 1.16); ctx.stroke();
    }
  } else {
    ctx.fillStyle = look.dark;
    for (const [sx, sy] of SPOTS) { ctx.beginPath(); ctx.roundRect(sx * halfWidth - size * .065, sy * halfHeight - size * .05, size * .13, size * .1, size * .04); ctx.fill(); }
  }
  ctx.fillStyle = cucumber ? '#FFFFFF4D' : look.light + '99'; ctx.beginPath(); ctx.roundRect(-halfWidth * .68, -halfHeight * .6, halfWidth * .26, halfHeight * .5, 5 * pixel); ctx.fill();
  const eye = Math.max(2 * pixel, size * .075), puff = mood === 'chomp' ? 1.25 : 1;
  const lookX = clamp(p.lookX || 0, -1, 1) * eye * .6, lookY = clamp(p.lookY || 0, -1, 1) * eye * .5;
  ctx.strokeStyle = ink; ctx.lineWidth = Math.max(pixel, size * .04);
  for (const side of [-1, 1]) {
    const ex = side * size * .27, ey = -size * .15 + eye * .35;
    ctx.fillStyle = peach; ctx.beginPath(); ctx.ellipse(side * size * .47, size * .1 + eye * .75, eye * 1.7 * puff, eye * .75 * puff, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = ink; ctx.beginPath();
    if (mood === 'chomp') { ctx.moveTo(ex - eye * 1.1, ey + eye * .5); ctx.quadraticCurveTo(ex, ey - eye * 1.3, ex + eye * 1.1, ey + eye * .5); ctx.stroke(); }
    else if (mood === 'threatened') { ctx.moveTo(ex + side * size * .1, ey - size * .1); ctx.lineTo(ex - side * size * .07, ey); ctx.lineTo(ex + side * size * .1, ey + size * .1); ctx.stroke(); }
    else if (mood === 'calm' && blinking(p.ownerID || p.id, time)) { ctx.moveTo(ex - eye, ey); ctx.lineTo(ex + eye, ey); ctx.stroke(); }
    else { ctx.ellipse(ex + lookX, ey + lookY, eye * 1.1, eye * (mood === 'dash' ? .55 : 1.35), 0, 0, Math.PI * 2); ctx.fill(); }
  }
  ctx.fillStyle = ink; ctx.beginPath();
  if (mood === 'chomp') { ctx.ellipse(0, size * .27, size * .1, size * .085 * (.5 + .5 * Math.abs(Math.sin(time * 18))), 0, 0, Math.PI * 2); ctx.fill(); }
  else if (mood === 'dash') { ctx.moveTo(-size * .12, size * .26); ctx.lineTo(size * .12, size * .26); ctx.stroke(); }
  else if (mood === 'threatened') { ctx.ellipse(0, size * .28, size * .055, size * .07, 0, 0, Math.PI * 2); ctx.fill(); }
  else { ctx.lineWidth = Math.max(pixel, size * .035); ctx.moveTo(-size * .13, size * .19); ctx.quadraticCurveTo(0, size * .42, size * .13, size * .19); ctx.stroke(); }
  // Monochrome accessories share the native SF Symbol silhouette family.
  if (p.outfit && p.outfit !== 'original') {
    ctx.save(); ctx.translate(0, -halfHeight - size * .055); ctx.scale(size * .56 / 24, size * .45 / 24);
    ctx.fillStyle = ink; ctx.strokeStyle = ink; ctx.lineWidth = 2; ctx.lineJoin = 'round';
    if (p.outfit === 'sprout') {
      ctx.beginPath(); ctx.moveTo(-9, 9); ctx.bezierCurveTo(-12, -5, 0, -9, 11, -11); ctx.bezierCurveTo(10, 1, 8, 10, -9, 9); ctx.fill();
      ctx.strokeStyle = '#EDF1E3'; ctx.lineWidth = 1.4; ctx.beginPath(); ctx.moveTo(-7, 7); ctx.lineTo(5, -5); ctx.stroke();
    } else if (p.outfit === 'bow') {
      ctx.fillRect(-10, -3, 20, 13); ctx.fillRect(-12, -7, 24, 5);
      ctx.lineWidth = 2.5; ctx.beginPath(); ctx.ellipse(-4, -10, 4.5, 3, .4, 0, Math.PI * 2); ctx.ellipse(4, -10, 4.5, 3, -.4, 0, Math.PI * 2); ctx.stroke();
      ctx.strokeStyle = '#EDF1E3'; ctx.lineWidth = 1.5; ctx.beginPath(); ctx.moveTo(0, -6); ctx.lineTo(0, 10); ctx.stroke();
    } else if (p.outfit === 'shades') {
      ctx.beginPath(); ctx.roundRect(-12, -3, 10, 9, 3); ctx.roundRect(2, -3, 10, 9, 3); ctx.fill();
      ctx.beginPath(); ctx.moveTo(-12, -3); ctx.lineTo(12, -3); ctx.stroke();
    } else if (p.outfit === 'crown') {
      ctx.beginPath(); ctx.moveTo(-10, 10); ctx.lineTo(-12, -6); ctx.lineTo(-5, 0); ctx.lineTo(0, -11); ctx.lineTo(5, 0); ctx.lineTo(12, -6); ctx.lineTo(10, 10); ctx.closePath(); ctx.fill();
    } else if (p.outfit === 'party') {
      ctx.beginPath(); ctx.moveTo(-12, 12); ctx.lineTo(-5, -7); ctx.lineTo(8, 5); ctx.closePath(); ctx.fill();
      ctx.beginPath(); ctx.moveTo(1, -5); ctx.quadraticCurveTo(3, -11, 8, -11); ctx.moveTo(5, -1); ctx.lineTo(12, -4); ctx.stroke();
      for (const [a, b] of [[0, -11], [10, -7], [11, 2]]) { ctx.beginPath(); ctx.arc(a, b, 1.5, 0, Math.PI * 2); ctx.fill(); }
    }
    ctx.restore();
  }
  ctx.restore();
}
