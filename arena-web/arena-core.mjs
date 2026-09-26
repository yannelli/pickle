import { EAT_OVERLAP, drawSmile } from './arena-expression.mjs';
export { EAT_OVERLAP, SMILES, skinSmile, pickupCue } from './arena-expression.mjs';

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
export function pickleBody(shape, size) {
  if (shape === 'round') return { halfWidth: size * .96, halfHeight: size * .9, lean: 0, round: true };
  return { halfWidth: size * .8, halfHeight: size, lean: shape === 'crooked' ? .16 : 0, round: false };
}
// Tight squint when threatened or draining, narrowed eyes while dashing.
export function faceMood(p) {
  if (p.hurt > 0 && p.alive !== false) return 'sad';
  if ((p.drain > 0 || p.threatened && !(p.shield > 0)) && p.alive !== false) return 'threatened';
  return p.dash > 0 ? 'dash' : 'calm';
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
  return players.flatMap(player => {
    const cells = playerCells(player);
    return cells.map(cell => ({ ...player, ...cell, ownerID: player.id, totalMass: player.mass, sliced: cells.length > 1 }));
  });
}
export const cellKey = (ownerID, cellID) => JSON.stringify([ownerID, cellID]);
export function threatenedCellIDs(players) {
  const cells = flattenCells(players).filter(cell => (cell.shield || 0) <= 0).map(cell => ({ ...cell, radius: radius(cell.mass) }));
  const threatened = new Set();
  for (const prey of cells) {
    for (const hunter of cells) {
      if (hunter.ownerID === prey.ownerID || hunter.mass < prey.mass * 1.22) continue;
      const reach = hunter.radius + prey.radius * (1 - EAT_OVERLAP) + 45;
      const dx = hunter.x - prey.x, dy = hunter.y - prey.y;
      if (dx * dx + dy * dy <= reach * reach) { threatened.add(cellKey(prey.ownerID, prey.id)); break; }
    }
  }
  return threatened;
}
export function splitState(player) {
  const cells = playerCells(player), count = cells.length;
  const largest = Math.max(0, ...cells.map(cell => cell.mass)), cooldown = Math.max(0, player?.splitCooldown || 0);
  let reason = 'Launch a little dill';
  if (!player?.alive) reason = 'Respawn to split';
  else if (!Array.isArray(player.cells)) reason = 'Available next round';
  else if (count >= 8) reason = '8 slices · maximum';
  else if (cooldown > 0) reason = `${cooldown.toFixed(1)}s cooldown`;
  else if (largest < 60) reason = `${Math.ceil(60 - largest)} more mass`;
  return { count, enabled: !!player?.alive && Array.isArray(player.cells) && count < 8 && largest >= 60 && cooldown <= 0, reason, merge: Math.max(0, player?.merge || 0) };
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
export function playerName(value) { return Array.from(String(value || '').replace(/[\p{C}]/gu, '').trim()).slice(0, 18).join('') || 'Dilly'; }
const validResumeIdentity = value => !!value && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value.token) && /^(public-(?:[1-9]|1[0-6])|crew-[A-Z0-9]{6})$/.test(value.room);
export function readResumeRecord(value, now = Date.now()) {
  if (!validResumeIdentity(value) || !Number.isFinite(value.deadline) || value.deadline <= now || value.deadline > now + 30000) return null;
  return { token: value.token, room: value.room, deadline: value.deadline };
}
export function refreshResumeRecord(value, now = Date.now()) {
  return validResumeIdentity(value) ? { token: value.token, room: value.room, deadline: now + 30000 } : null;
}
export function resumeFromWelcome(packet, now = Date.now()) {
  if (packet.reconnectGraceSeconds !== 30 || packet.resumeRoom !== packet.room) return null;
  return refreshResumeRecord({ token: packet.resumeToken, room: packet.resumeRoom }, now);
}
export function resumeRetryDelay(attempt, deadline, now = Date.now()) {
  const remaining = deadline - now;
  if (remaining <= 0) return null;
  return Math.min([250, 700, 1500, 2500, 4000][Math.min(Math.max(0, attempt), 4)], remaining);
}
export function socketURL(origin, settings, room = null, resume = null) {
  const url = new URL('/arena', origin); url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
  url.searchParams.set('foodDeltas', '1');
  url.searchParams.set('reconnect', '1');
  url.searchParams.set('name', playerName(settings.name));
  url.searchParams.set('brine', BRINES.includes(settings.brine) ? settings.brine : 'classic');
  url.searchParams.set('outfit', OUTFITS.includes(settings.outfit) ? settings.outfit : 'sprout');
  url.searchParams.set('variety', varietyOf(settings));
  if (roomCode(room)) url.searchParams.set('room', roomCode(room));
  if (resume) {
    if (!validResumeIdentity(resume)) throw new TypeError('Invalid resume credentials.');
    url.searchParams.set('resumeToken', resume.token); url.searchParams.set('resumeRoom', resume.room);
  }
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
  if (url.protocol === 'wss:') url.protocol = 'https:';
  if (url.protocol === 'ws:') url.protocol = 'http:';
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
  // Live split pieces are round pickle cross-sections until actually regrouped.
  const sliced = p.sliced === true || Array.isArray(p.cells) && p.cells.length > 1;
  const look = VARIETIES[varietyOf(p)];
  const { halfWidth, halfHeight, lean, round } = sliced ? { halfWidth: size, halfHeight: size, lean: 0, round: false } : pickleBody(look.shape, size);
  const pixel = 1 / screenScale, mood = faceMood(p);
  ctx.save(); ctx.translate(x, y); ctx.rotate(lean); ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  if (p.dash > 0) {
    ctx.fillStyle = '#D4EB8566'; ctx.beginPath();
    ctx.ellipse(0, 0, halfWidth + 8 * pixel, halfHeight + 8 * pixel, 0, 0, Math.PI * 2); ctx.fill();
  }
  if (p.shield > 0) {
    ctx.strokeStyle = '#FFFFFFE6'; ctx.lineWidth = 2 * pixel; ctx.setLineDash([4 * pixel, 4 * pixel]);
    ctx.beginPath(); ctx.ellipse(0, 0, halfWidth + 7 * pixel, halfHeight + 7 * pixel, 0, 0, Math.PI * 2); ctx.stroke(); ctx.setLineDash([]);
  }
  const outline = p.outline, body = () => {
    if (outline) traceOutline(ctx, outline);
    else { ctx.beginPath(); if (round) ctx.ellipse(0, 0, halfWidth, halfHeight, 0, 0, Math.PI * 2); else ctx.roundRect(-halfWidth, -halfHeight, halfWidth * 2, halfHeight * 2, halfWidth); }
  };
  ctx.fillStyle = '#263E311A'; ctx.save(); ctx.translate(pixel, 5 * pixel); body(); ctx.fill(); ctx.restore();
  ctx.fillStyle = sliced ? '#4D8650' : look.color; ctx.strokeStyle = ink; ctx.lineWidth = (own ? 2.5 : 1.5) * pixel;
  body(); ctx.fill(); ctx.stroke();
  if (p.danger > 0) { ctx.save(); ctx.globalAlpha = clamp(p.danger, 0, 1); ctx.strokeStyle = '#C8553D'; ctx.lineWidth = 3.5 * pixel; ctx.stroke(); ctx.restore(); }
  ctx.save(); body(); ctx.clip();
  if (sliced) {
    ctx.fillStyle = '#D8E8A4'; ctx.beginPath(); ctx.arc(0, 0, size * .82, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#E5EEC0'; ctx.beginPath(); ctx.arc(0, 0, size * .64, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = '#F8F6EDE6';
    for (let n = 0; n < 6; n++) {
      const angle = n * Math.PI / 3;
      ctx.beginPath(); ctx.ellipse(Math.cos(angle) * size * .53, Math.sin(angle) * size * .53, size * .11, size * .045, angle, 0, Math.PI * 2); ctx.fill();
    }
  } else {
    ctx.fillStyle = look.dark;
    for (const [sx, sy] of SPOTS) { ctx.beginPath(); ctx.roundRect(sx * halfWidth - size * .065, sy * halfHeight - size * .05, size * .13, size * .1, size * .04); ctx.fill(); }
    ctx.fillStyle = look.light + '99'; ctx.beginPath(); ctx.roundRect(-halfWidth * .68, -halfHeight * .6, halfWidth * .26, halfHeight * .5, 5 * pixel); ctx.fill();
  }
  ctx.restore();
  const eye = Math.max(2 * pixel, size * .075);
  const lookX = clamp(p.lookX || 0, -1, 1) * eye * .6, lookY = clamp(p.lookY || 0, -1, 1) * eye * .5;
  ctx.strokeStyle = ink; ctx.lineWidth = Math.max(1.5 * pixel, size * .04);
  for (const side of [-1, 1]) {
    const ex = side * size * .27, ey = -size * .15 + eye * .35;
    ctx.fillStyle = peach; ctx.beginPath(); ctx.ellipse(side * size * .47, size * .1 + eye * .75, eye * 1.7, eye * .75, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillStyle = ink; ctx.beginPath();
    if (mood === 'threatened') { ctx.moveTo(ex + side * size * .1, ey - size * .1); ctx.lineTo(ex - side * size * .07, ey); ctx.lineTo(ex + side * size * .1, ey + size * .1); ctx.stroke(); }
    else if (mood === 'sad') { ctx.ellipse(ex, ey + eye * .25, eye, eye * .95, 0, 0, Math.PI * 2); ctx.fill(); ctx.beginPath(); ctx.moveTo(ex - side * eye * .9, ey - eye * 1.5); ctx.lineTo(ex + side * eye, ey - eye * .8); ctx.stroke(); }
    else if (mood === 'calm' && blinking(p.ownerID || p.id, time)) { ctx.moveTo(ex - eye, ey); ctx.lineTo(ex + eye, ey); ctx.stroke(); }
    else { ctx.ellipse(ex + lookX, ey + lookY, eye * 1.1, eye * (mood === 'dash' ? .55 : 1.35), 0, 0, Math.PI * 2); ctx.fill(); }
  }
  ctx.fillStyle = ink; ctx.beginPath();
  if (mood === 'dash') { ctx.moveTo(-size * .12, size * .26); ctx.lineTo(size * .12, size * .26); ctx.stroke(); }
  else if (mood === 'threatened') { ctx.ellipse(0, size * .28, size * .055, size * .07, 0, 0, Math.PI * 2); ctx.fill(); }
  else if (mood === 'sad') { ctx.moveTo(-size * .13, size * .32); ctx.quadraticCurveTo(0, size * .14, size * .13, size * .32); ctx.stroke(); }
  else { ctx.lineWidth = Math.max(pixel, size * .035); drawSmile(ctx, varietyOf(p), size); }
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
const TAU = Math.PI * 2;
// Log-space ease: zooming out keeps new pieces in frame quickly, zooming in settles slowly.
export function easeZoom(current, target, dt) {
  if (!Number.isFinite(current) || current <= 0) return target;
  if (!Number.isFinite(target) || target <= 0 || !(dt > 0)) return current;
  const from = Math.log(current), rate = target < current ? 7 : 2.5;
  return Math.exp(from + (Math.log(target) - from) * (1 - Math.exp(-rate * dt)));
}
// Server eat rule: H eats P once their centers are closer than radius(H) - EAT_OVERLAP * radius(P).
export function killRings(players, ownID) {
  const cells = flattenCells(players).filter(cell => !(cell.shield > 0));
  const mine = cells.filter(cell => cell.ownerID === ownID), rings = [];
  for (const hunter of mine.length ? cells : []) {
    if (hunter.ownerID === ownID) continue;
    let closest = null;
    for (const prey of mine) {
      if (hunter.mass < prey.mass * 1.22) continue;
      const threshold = radius(hunter.mass) - radius(prey.mass) * EAT_OVERLAP, gap = Math.hypot(hunter.x - prey.x, hunter.y - prey.y) - threshold;
      if (!closest || gap < closest.gap) closest = { gap, threshold };
    }
    if (closest && closest.gap < 320) rings.push({ ownerID: hunter.ownerID, cellID: hunter.id, x: hunter.x, y: hunter.y, radius: closest.threshold, alpha: .25 + .65 * clamp(1 - closest.gap / 320, 0, 1) });
  }
  return rings;
}
// Body outline in the piece's own frame: capsule for pickles and slices, ellipse for round varieties.
export function bodyShape(p, size) {
  const sliced = p.sliced === true || Array.isArray(p.cells) && p.cells.length > 1;
  if (sliced) return { hw: size, hh: size, lean: 0, ellipse: false };
  const { halfWidth, halfHeight, lean, round } = pickleBody(VARIETIES[varietyOf(p)].shape, size);
  return { hw: halfWidth, hh: halfHeight, lean, ellipse: round };
}
// Distance from the center to the undeformed outline along a local angle.
export function shapeRadius(shape, angle) {
  const c = Math.abs(Math.cos(angle)), s = Math.abs(Math.sin(angle));
  if (shape.ellipse) return 1 / Math.hypot(c / shape.hw, s / shape.hh);
  const k = Math.max(0, shape.hh - shape.hw);
  if (c > 1e-9 && s * shape.hw / c <= k) return shape.hw / c;
  return s * k + Math.sqrt(Math.max(0, (s * k) ** 2 - k * k + shape.hw * shape.hw));
}
export const membraneSize = screenRadius => clamp(Math.round(screenRadius / 12) * 6, 18, 72);
export function makeMembrane(n) { return { n, acc: new Float64Array(n), dr: new Float64Array(n) }; }
// Resample a membrane to a new point count so a zoom change keeps its current dents.
export function resizeMembrane(m, n) {
  if (m?.n === n) return m;
  const next = makeMembrane(n);
  if (m) for (let i = 0; i < n; i++) { const at = i / n * m.n, j = Math.floor(at), t = at - j; next.dr[i] = m.dr[j % m.n] * (1 - t) + m.dr[(j + 1) % m.n] * t; }
  return next;
}
// Outline radius of a (possibly deformed) body along a local angle.
export function outlineRadius(shape, m, angle) {
  const base = shapeRadius(shape, angle);
  if (!m) return base;
  const at = ((angle / TAU) % 1 + 1) % 1 * m.n, j = Math.floor(at), t = at - j;
  return base + m.dr[j % m.n] * (1 - t) + m.dr[(j + 1) % m.n] * t;
}
function inside(body, x, y) {
  const dx = x - body.x, dy = y - body.y, reach = Math.max(body.shape.hw, body.shape.hh) + 4;
  if (dx * dx + dy * dy > reach * reach) return false;
  const angle = Math.atan2(dy, dx) - body.shape.lean;
  return Math.hypot(dx, dy) < outlineRadius(body.shape, body.m, angle) + 1;
}
// One 60 Hz step of an agar-style membrane: outline points that touch another body or leave the
// garden accelerate inward, neighbours smooth each other, and every point relaxes back to its shape.
const scratchNext = new Float64Array(72), scratchSmooth = new Float64Array(72);
export const MEMBRANE = Object.freeze({ jitter: .15, damping: .6, push: 1.5, dent: .35, bulge: .08, relax: 8 / 9 });
export function stepMembrane(m, body, others, bounds, { jitter = MEMBRANE.jitter, random = Math.random } = {}) {
  const { n, acc, dr } = m, next = n <= 72 ? scratchNext : new Float64Array(n), smooth = n <= 72 ? scratchSmooth : new Float64Array(n);
  for (let i = 0; i < n; i++) acc[i] = clamp((acc[i] + (random() - .5) * jitter) * MEMBRANE.damping, -10, 10);
  for (let i = 0; i < n; i++) smooth[i] = (acc[(i + n - 1) % n] + acc[(i + 1) % n] + 8 * acc[i]) / 10;
  for (let i = 0; i < n; i++) acc[i] = smooth[i];
  const cos = Math.cos(body.shape.lean), sin = Math.sin(body.shape.lean);
  for (let i = 0; i < n; i++) {
    const angle = i / n * TAU, base = shapeRadius(body.shape, angle), r = base + dr[i];
    const lx = Math.cos(angle) * r, ly = Math.sin(angle) * r, x = body.x + lx * cos - ly * sin, y = body.y + lx * sin + ly * cos;
    const touching = (bounds && (x < 0 || y < 0 || x > bounds.width || y > bounds.height)) || others.some(other => other !== body && inside(other, x, y));
    if (touching) { if (acc[i] > 0) acc[i] = 0; acc[i] -= MEMBRANE.push; }
    next[i] = clamp(dr[i] + acc[i], -MEMBRANE.dent * base, MEMBRANE.bulge * base) * MEMBRANE.relax;
  }
  for (let i = 0; i < n; i++) dr[i] = (next[(i + n - 1) % n] + next[(i + 1) % n] + 8 * next[i]) / 10;
  return m;
}
// Local outline points for drawing, in the body's rotated frame.
export function membraneOutline(shape, m) {
  return Array.from({ length: m.n }, (_, i) => {
    const angle = i / m.n * TAU, r = shapeRadius(shape, angle) + m.dr[i];
    return [Math.cos(angle) * r, Math.sin(angle) * r];
  });
}
export function traceOutline(ctx, points) {
  const mid = (a, b) => [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2], n = points.length, start = mid(points[n - 1], points[0]);
  ctx.beginPath(); ctx.moveTo(start[0], start[1]);
  for (let i = 0; i < n; i++) { const end = mid(points[i], points[(i + 1) % n]); ctx.quadraticCurveTo(points[i][0], points[i][1], end[0], end[1]); }
  ctx.closePath();
}
// The field a draining cell sits in: the one whose edge is closest.
export function hazardFor(cell, hazards = []) {
  let nearest = null, nearestGap = Infinity;
  for (const h of hazards) {
    const gap = Math.hypot(cell.x - h.x, cell.y - h.y) - h.r;
    if (gap < nearestGap) { nearest = h; nearestGap = gap; }
  }
  return nearest;
}
// Each droplet leaves the draining cell's edge and reaches the device core every .5 s.
export function drainDroplets(cell, hazard, time, count = 8) {
  const dx = hazard.x - cell.x, dy = hazard.y - cell.y, d = Math.hypot(dx, dy) || 1, ux = dx / d, uy = dy / d;
  const edge = Math.min(radius(cell.mass), d), length = d - edge;
  return Array.from({ length: count }, (_, n) => {
    const phase = ((time / .5 + n / count) % 1 + 1) % 1, along = edge + length * phase * (.6 + .4 * phase);
    const sway = Math.sin(phase * Math.PI) * Math.sin(n * 2.39996) * 9;
    return { x: cell.x + ux * along - uy * sway, y: cell.y + uy * along + ux * sway, r: 4 * Math.min(1, phase * 8) * (1 - .35 * phase) };
  });
}
export function spitFlight(fromX, fromY, x, y, age, duration = .45) {
  const t = clamp(age / duration, 0, 1), ease = 1 - (1 - t) ** 3;
  return { x: fromX + (x - fromX) * ease, y: fromY + (y - fromY) * ease, done: t >= 1 };
}
export function drawDroplet(ctx, x, y, r) {
  ctx.fillStyle = '#9CC26B'; ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill();
  ctx.fillStyle = '#D4EB85'; ctx.beginPath(); ctx.arc(x - r * .32, y - r * .32, r * .38, 0, TAU); ctx.fill();
}
// Deterministic 0..1 noise so every client scatters the same debris.
const grain = n => { const v = Math.sin(n * 127.1 + 311.7) * 43758.5453; return v - Math.floor(v); };
export const HAZARD_KINDS = ['slicer', 'shaker', 'grater'];
export const hazardKind = (h, index = 0) => HAZARD_KINDS.includes(h?.kind) ? h.kind : HAZARD_KINDS[index % HAZARD_KINDS.length];
const INK = '#263E31', STEEL = '#D5DEE1';
// Slices, salt or shreds thin out toward the field edge; there is no drawn boundary.
function drawScatter(ctx, h, kind, seed) {
  ctx.fillStyle = '#FFFFFF';
  for (const [scale, alpha] of [[1, .2], [.6, .22]]) {
    ctx.globalAlpha = alpha; ctx.beginPath();
    for (let n = 0; n <= 40; n++) {
      const a = n / 40 * TAU, r = h.r * scale * (1 + .08 * Math.sin(3 * a + seed) + .05 * Math.sin(5 * a + seed * 2));
      n ? ctx.lineTo(Math.cos(a) * r, Math.sin(a) * r) : ctx.moveTo(Math.cos(a) * r, Math.sin(a) * r);
    }
    ctx.fill();
  }
  const count = kind === 'slicer' ? 30 : kind === 'shaker' ? 56 : 40;
  for (let n = 0; n < count; n++) {
    const a = n * 2.39996 + seed, d = h.r * (.45 + .7 * Math.sqrt((n + .5) / count)), size = 1 + grain(n + seed);
    ctx.globalAlpha = clamp((h.r * 1.16 - d) / (h.r * .42), 0, 1);
    ctx.save(); ctx.translate(Math.cos(a) * d, Math.sin(a) * d); ctx.rotate(grain(n * 3 + seed) * TAU);
    if (kind === 'slicer') {
      const r = 4.5 * size; ctx.lineWidth = 1.2; ctx.strokeStyle = '#263E3166';
      ctx.fillStyle = '#6E9A4A'; ctx.beginPath(); ctx.arc(0, 0, r, 0, TAU); ctx.fill(); ctx.stroke();
      ctx.fillStyle = '#E1ECB5'; ctx.beginPath(); ctx.arc(0, 0, r * .74, 0, TAU); ctx.fill();
      ctx.fillStyle = '#F8F6ED'; for (let k = 0; k < 3; k++) { ctx.beginPath(); ctx.arc(Math.cos(k * 2.1) * r * .35, Math.sin(k * 2.1) * r * .35, r * .12, 0, TAU); ctx.fill(); }
    } else if (kind === 'shaker') {
      const g = 3 + 3 * size; ctx.fillStyle = '#A9BFC5'; ctx.fillRect(-g / 2 + 1.2, -g / 2 + 1.2, g, g); ctx.fillStyle = '#FFFFFF'; ctx.fillRect(-g / 2, -g / 2, g, g); ctx.strokeStyle = '#263E3140'; ctx.lineWidth = .8; ctx.strokeRect(-g / 2, -g / 2, g, g);
    } else {
      const l = 5 + 4 * size; ctx.lineCap = 'round'; ctx.strokeStyle = '#7FA653'; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(-l, 0); ctx.quadraticCurveTo(0, -l * .5, l, 0); ctx.stroke();
      ctx.strokeStyle = '#D6E6A8'; ctx.lineWidth = 1.2; ctx.beginPath(); ctx.moveTo(-l * .7, -.6); ctx.quadraticCurveTo(0, -l * .5, l * .7, -.6); ctx.stroke();
    }
    ctx.restore();
  }
  ctx.globalAlpha = 1;
}
// Watches the nearest pickle, blinks, and opens wide while it drains one.
function drawGadgetFace(ctx, x, y, { time, hungry, lookX, lookY, seed }) {
  const eyeX = clamp(lookX, -1, 1) * 2.4, eyeY = clamp(lookY, -1, 1) * 1.8, blink = time > 0 && (time + seed % 5) % 3.8 < .12;
  ctx.save(); ctx.translate(x, y);
  ctx.fillStyle = '#F1C9B4'; for (const side of [-1, 1]) { ctx.beginPath(); ctx.ellipse(side * 14, 8, 5.5, 3.2, 0, 0, TAU); ctx.fill(); }
  ctx.fillStyle = INK; ctx.strokeStyle = INK; ctx.lineWidth = 2.4; ctx.lineCap = 'round';
  for (const side of [-1, 1]) {
    ctx.beginPath();
    if (blink) { ctx.moveTo(side * 9 - 3.5, -3); ctx.lineTo(side * 9 + 3.5, -3); ctx.stroke(); continue; }
    ctx.ellipse(side * 9 + eyeX, -3 + eyeY, 3.2, hungry ? 4.6 : 3.8, 0, 0, TAU); ctx.fill();
    ctx.fillStyle = '#FFFFFF'; ctx.beginPath(); ctx.arc(side * 9 + eyeX - 1, -4.4 + eyeY, 1.1, 0, TAU); ctx.fill(); ctx.fillStyle = INK;
  }
  ctx.beginPath();
  if (hungry) { ctx.ellipse(0, 9, 3.6, 3 + 1.6 * Math.abs(Math.sin(time * 9)), 0, 0, TAU); ctx.fill(); }
  else { ctx.lineWidth = 2; ctx.arc(-3, 7, 3, .15 * Math.PI, .95 * Math.PI); ctx.moveTo(6, 7.6); ctx.arc(3, 7, 3, .05 * Math.PI, .85 * Math.PI); ctx.stroke(); }
  ctx.restore();
}
function drawSlicer(ctx, face, time, hungry) {
  ctx.save(); ctx.rotate(-.32 + Math.sin(time * 1.4) * .03);
  ctx.strokeStyle = INK; ctx.lineWidth = 3;
  ctx.beginPath(); ctx.moveTo(-40, 24); ctx.lineTo(-46, 44); ctx.moveTo(40, 24); ctx.lineTo(46, 44); ctx.stroke();
  ctx.fillStyle = '#F8F6ED'; ctx.beginPath(); ctx.roundRect(-58, -28, 116, 56, 14); ctx.fill(); ctx.stroke();
  ctx.fillStyle = STEEL; ctx.beginPath(); ctx.moveTo(6, -28); ctx.lineTo(22, -28); ctx.lineTo(30, 28); ctx.lineTo(14, 28); ctx.closePath(); ctx.fill(); ctx.stroke();
  ctx.lineWidth = 1.6; ctx.beginPath(); ctx.moveTo(8, -24);
  for (let n = 1; n <= 10; n++) ctx.lineTo(8 + n * .8 + (n % 2 ? 3 : 0), -24 + n * 4.8);
  ctx.stroke();
  ctx.strokeStyle = '#FFFFFF'; ctx.lineWidth = 2; ctx.beginPath(); ctx.moveTo(20, -22); ctx.lineTo(25, 18); ctx.stroke();
  const slide = hungry ? 18 * Math.sin(time * 10) : 0;
  ctx.strokeStyle = INK; ctx.lineWidth = 3; ctx.fillStyle = '#D4EB85';
  ctx.beginPath(); ctx.roundRect(34 + slide, -20, 18, 40, 7); ctx.fill(); ctx.stroke();
  ctx.beginPath(); ctx.arc(43 + slide, -26, 6, 0, TAU); ctx.fill(); ctx.stroke();
  drawGadgetFace(ctx, -24, 0, face); ctx.restore();
}
function drawShaker(ctx, face, time, hungry) {
  const tilt = hungry ? Math.sin(time * 14) * .22 : .18 + Math.sin(time * 1.5) * .05;
  ctx.save(); ctx.rotate(tilt); ctx.strokeStyle = INK; ctx.lineWidth = 3;
  ctx.fillStyle = '#EEF4F5'; ctx.beginPath(); ctx.roundRect(-28, -30, 56, 78, 20); ctx.fill();
  ctx.save(); ctx.clip(); ctx.fillStyle = '#FFFFFF'; ctx.fillRect(-28, 4, 56, 44);
  ctx.fillStyle = '#D9E6E8'; for (let n = 0; n < 9; n++) ctx.fillRect(-20 + grain(n) * 40, 8 + grain(n + 9) * 34, 2.4, 2.4);
  ctx.restore(); ctx.stroke();
  ctx.strokeStyle = '#FFFFFF'; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(-19, -18); ctx.lineTo(-19, 2); ctx.stroke();
  ctx.strokeStyle = INK; ctx.lineWidth = 3; ctx.fillStyle = STEEL; ctx.beginPath(); ctx.roundRect(-25, -52, 50, 24, 10); ctx.fill(); ctx.stroke();
  ctx.fillStyle = INK; for (const hx of [-12, -4, 4, 12]) { ctx.beginPath(); ctx.arc(hx, -44, 1.8, 0, TAU); ctx.fill(); }
  ctx.fillStyle = '#FFFFFF'; ctx.strokeStyle = '#263E3155'; ctx.lineWidth = .8;
  for (let n = 0; n < (hungry ? 7 : 3); n++) {
    const t = (time * (hungry ? 1.6 : .7) + n / (hungry ? 7 : 3)) % 1, gx = -12 + (n * 8) % 26 + Math.sin(n * 3) * 3;
    ctx.globalAlpha = 1 - t; ctx.beginPath(); ctx.rect(gx - 1.6, -58 - t * 26 - t * t * 10, 3.2, 3.2); ctx.fill(); ctx.stroke();
  }
  ctx.globalAlpha = 1; drawGadgetFace(ctx, 0, -12, face); ctx.restore();
}
function drawGrater(ctx, face, time, hungry) {
  ctx.save(); ctx.translate(hungry ? Math.sin(time * 18) * 2.5 : 0, Math.sin(time * 1.6) * 1.2); ctx.rotate(.08);
  ctx.strokeStyle = INK; ctx.lineWidth = 5; ctx.beginPath(); ctx.moveTo(-15, -52); ctx.bezierCurveTo(-15, -76, 15, -76, 15, -52); ctx.stroke();
  ctx.strokeStyle = '#D4EB85'; ctx.lineWidth = 2; ctx.stroke();
  ctx.strokeStyle = INK; ctx.lineWidth = 3; ctx.fillStyle = STEEL;
  ctx.beginPath(); ctx.moveTo(-28, -54); ctx.lineTo(28, -54); ctx.lineTo(42, 54); ctx.lineTo(-42, 54); ctx.closePath(); ctx.fill(); ctx.stroke();
  ctx.strokeStyle = '#FFFFFF'; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(-22, -46); ctx.lineTo(-33, 44); ctx.stroke();
  ctx.strokeStyle = '#263E31A6'; ctx.lineWidth = 1.8;
  for (let row = 0; row < 4; row++) for (let col = 0; col < 4; col++) {
    const w = 52 + row * 7, x = -w / 2 + (col + .5) * w / 4, y = 12 + row * 11;
    ctx.beginPath(); ctx.arc(x, y - 2, 3.4, .15 * Math.PI, .85 * Math.PI); ctx.stroke();
  }
  drawGadgetFace(ctx, 0, -24, face); ctx.restore();
}
// Drain sound strokes keep time with each gadget's animation: slicer pusher, shaker shakes, grater jiggle.
export const GADGET_STROKE_SECONDS = Object.freeze({ slicer: .32, shaker: .22, grater: .35 });
export function scheduleStrokes(loop, kind, now, horizon = .3) {
  const every = GADGET_STROKE_SECONDS[kind];
  if (!every) return { loop: null, times: [] };
  const next = { kind, next: loop?.kind === kind ? loop.next : now + .01 }, times = [];
  while (next.next < now + horizon) { if (next.next >= now) times.push(next.next); next.next += every; }
  return { loop: next, times };
}
// A kitchen gadget pickles dread: slicer, salt shaker or grater, over its scatter.
export function drawHazard(ctx, h, { kind = hazardKind(h), time = 0, hungry = false, lookX = 0, lookY = 0, droplets = [] } = {}) {
  const seed = [...String(h.id || '')].reduce((sum, c) => sum + c.charCodeAt(0), 0), face = { time, hungry, lookX, lookY, seed };
  ctx.save(); ctx.translate(h.x, h.y); ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  drawScatter(ctx, h, kind, seed);
  for (const drop of droplets) drawDroplet(ctx, drop.x - h.x, drop.y - h.y, drop.r);
  ctx.scale(1.25, 1.25);
  ctx.fillStyle = '#263E3114'; ctx.beginPath(); ctx.ellipse(4, 50, 62, 13, 0, 0, TAU); ctx.fill();
  if (kind === 'shaker') drawShaker(ctx, face, time, hungry);
  else if (kind === 'grater') drawGrater(ctx, face, time, hungry);
  else drawSlicer(ctx, face, time, hungry);
  ctx.restore();
}
