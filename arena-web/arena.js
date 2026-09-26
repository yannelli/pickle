import { BRINES, OUTFITS, VARIETIES, varietyOf, pieceMood, clamp, radius, viewportBounds, cameraFrame, playerCells, flattenCells, splitState, massLabel, roomCode, direction, playerName, socketURL, applyFoodUpdate, shareURL, interpolate, drawPickle } from './arena-core.mjs';

const $ = id => document.getElementById(id);
const canvas = $('arena'), ctx = canvas.getContext('2d'), map = $('minimap').getContext('2d');
const preview = $('preview').getContext('2d'), reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
const storageKey = 'little-dill.arena.v1';
let settings = { name: 'Dilly', brine: 'classic', outfit: 'sprout', variety: 'dill', sound: false, best: 0 };
try { const saved = JSON.parse(localStorage.getItem(storageKey)); if (saved && typeof saved === 'object') settings = { ...settings, ...saved }; } catch { /* Storage is optional, including private browsing. */ }
settings.name = playerName(settings.name); settings.brine = BRINES.includes(settings.brine) ? settings.brine : 'classic';
settings.outfit = OUTFITS.includes(settings.outfit) ? settings.outfit : 'sprout'; settings.best = Number.isFinite(settings.best) ? Math.max(0, Math.floor(settings.best)) : 0;
settings.sound = settings.sound === true;
const pickVariety = brine => { const pair = Object.keys(VARIETIES).filter(id => VARIETIES[id].brine === brine); return pair[Math.floor(Math.random() * pair.length)]; };
if (VARIETIES[varietyOf(settings)].brine !== settings.brine || varietyOf(settings) !== settings.variety) settings.variety = pickVariety(settings.brine);
const save = () => { try { localStorage.setItem(storageKey, JSON.stringify(settings)); } catch { /* Play without persistence. */ } };
let requestedRoom = roomCode(new URL(location.href).searchParams.get('room'));
let socket = null, generation = 0, ownID = null, state = null, previous = new Map(), ateAt = new Map(), arrived = 0, lastPacket = 0;
let phase = 'lobby', overlayMode = '', sequence = 0, inputTimer = null, connectTimer = null, toastTimer = null;
let movement = { x: 0, y: 0 }, pointer = null, keys = new Set(), stickPointer = null, ownPrevious = null;
let width = innerWidth, height = innerHeight, camera = { x: 1200, y: 900 }, zoom = 1, lastFrame = performance.now();
let viewCenter = { x: width / 2, y: height / 2 }, cameraInsets = {};
let audio = null, leaderboardSignature = '', lastSavedBest = settings.best;

function notify(message) { $('toast').textContent = message; $('toast').hidden = false; clearTimeout(toastTimer); toastTimer = setTimeout(() => { $('toast').hidden = true; }, 3500); }
function sound(kind) {
  if (!settings.sound || !audio || audio.state !== 'running') return;
  const now = audio.currentTime;
  const notes = { absorb: [680, 980], split: [360, 720], regroup: [620, 420], dash: [460, 150], death: [240, 110], join: [440, 660], respawn: [520, 780] }[kind] || [440, 660];
  const osc = audio.createOscillator(), gain = audio.createGain(); osc.type = kind === 'dash' ? 'triangle' : 'sine';
  osc.frequency.setValueAtTime(notes[0], now); osc.frequency.exponentialRampToValueAtTime(notes[1], now + .12);
  gain.gain.setValueAtTime(.0001, now); gain.gain.exponentialRampToValueAtTime(.09, now + .015); gain.gain.exponentialRampToValueAtTime(.0001, now + .18);
  osc.connect(gain); gain.connect(audio.destination); osc.start(now); osc.stop(now + .2);
}
function unlockAudio() {
  if (!settings.sound) return;
  try { audio ||= new (window.AudioContext || window.webkitAudioContext)(); audio.resume().catch(() => {}); } catch { settings.sound = false; updateSound(); }
}
function updateSound() { document.querySelectorAll('.sound-toggle').forEach(button => { button.setAttribute('aria-pressed', String(settings.sound)); button.setAttribute('aria-label', `Turn sound ${settings.sound ? 'off' : 'on'}`); button.title = `Sound ${settings.sound ? 'on' : 'off'}`; }); }
document.querySelectorAll('.sound-toggle').forEach(button => button.addEventListener('click', () => { settings.sound = !settings.sound; save(); updateSound(); unlockAudio(); if (settings.sound) sound('join'); }));
function refreshLobby() {
  $('name').value = settings.name; $('outfit').value = settings.outfit;
  document.querySelectorAll('.brine').forEach(button => { const selected = button.dataset.brine === settings.brine; button.classList.toggle('selected', selected); button.setAttribute('aria-pressed', String(selected)); });
  $('personal-best').hidden = settings.best === 0; $('lobby-best').textContent = massLabel(settings.best); $('lobby-best').title = settings.best.toLocaleString();
  $('play-label').textContent = requestedRoom ? `Join friend room ${requestedRoom}` : 'Let’s get pickled';
  $('public-room').hidden = !requestedRoom;
  if (requestedRoom) $('room-code').value = requestedRoom;
}
document.querySelectorAll('.brine').forEach(button => button.addEventListener('click', () => { settings.name = playerName($('name').value); settings.brine = button.dataset.brine; settings.variety = pickVariety(settings.brine); save(); refreshLobby(); }));
$('outfit').addEventListener('change', () => { settings.outfit = $('outfit').value; save(); });
$('name').addEventListener('change', () => { settings.name = playerName($('name').value); save(); });
$('join-form').addEventListener('submit', event => { event.preventDefault(); join(requestedRoom); });
$('create-room').addEventListener('click', () => {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789', bytes = crypto.getRandomValues(new Uint8Array(6));
  join(Array.from(bytes, value => alphabet[value % alphabet.length]).join(''));
});
$('show-room').addEventListener('click', () => { $('room-form').hidden = !$('room-form').hidden; if (!$('room-form').hidden) $('room-code').focus(); });
$('public-room').addEventListener('click', () => join(null));
$('room-form').addEventListener('submit', event => { event.preventDefault(); const code = roomCode($('room-code').value); $('room-error').textContent = code ? '' : 'Use the six letters or digits from your friend’s room.'; if (code) join(code); });

function send(message) { if (socket?.readyState === WebSocket.OPEN) { try { socket.send(JSON.stringify(message)); } catch { disconnected('The garden connection dropped. Jump back in.'); } } }
function clearMovement() { keys.clear(); pointer = null; stickPointer = null; movement = { x: 0, y: 0 }; $('stick').style.transform = ''; if (socket?.readyState === WebSocket.OPEN) send({ type: 'input', seq: sequence++, x: 0, y: 0 }); }
function stopSocket() {
  generation++; clearInterval(inputTimer); clearTimeout(connectTimer); inputTimer = null; connectTimer = null;
  // Detach before resetting intent: a failing send must never re-enter cleanup.
  const old = socket; socket = null; clearMovement();
  if (old) { old.onopen = old.onmessage = old.onerror = old.onclose = null; try { old.close(1000, 'Taking a breather.'); } catch { /* Already closed. */ } }
}
function overlay(mode, title, message) {
  overlayMode = mode; $('overlay').hidden = false; $('overlay-title').textContent = title; $('overlay-message').textContent = message;
  $('overlay-kicker').textContent = { joining: 'FRESH FROM THE JAR', disconnected: 'A LITTLE BREATHER', dead: 'YOU WERE A PRETTY BIG DILL', leave: 'HEADING OUT?' }[mode] || '';
  $('overlay-action').hidden = mode === 'joining'; $('overlay-action').disabled = false;
  $('overlay-action').textContent = mode === 'leave' ? 'Keep playing' : mode === 'dead' ? 'One more crunch' : 'Jump back in';
  $('run-result').hidden = mode !== 'dead'; $('share-run').hidden = mode !== 'dead';
  $('overlay-back').textContent = mode === 'leave' ? 'Leave this garden' : 'Back to the garden gate';
  // One dialog remains focusable while the live controls are unavailable.
  for (const element of [$('arena'), ...document.querySelectorAll('.game-header button'), $('dash'), $('split')]) element.inert = true;
  (mode === 'joining' ? $('overlay-back') : $('overlay-action')).focus({ preventScroll: true });
}
function hideOverlay() { $('overlay').hidden = true; overlayMode = ''; for (const element of [$('arena'), ...document.querySelectorAll('.game-header button'), $('dash'), $('split')]) element.inert = false; }
function join(room) {
  settings.name = playerName($('name').value); settings.outfit = $('outfit').value; save(); unlockAudio();
  // Dismiss Safari’s keyboard before measuring the live viewport. Resize events
  // keep following it while the keyboard and browser chrome finish animating.
  document.activeElement?.blur();
  stopSocket(); requestedRoom = roomCode(room); ownID = null; state = null; previous.clear(); ateAt.clear(); ownPrevious = null; sequence = 0; leaderboardSignature = ''; zoom = 1;
  phase = 'joining'; $('lobby').hidden = true; $('game').hidden = false; document.body.style.overflow = 'hidden';
  $('room-badge').hidden = !requestedRoom; $('room-badge').textContent = requestedRoom ? `FRIEND ROOM · ${requestedRoom}` : '';
  $('population').textContent = 'Finding your garden…'; $('mass').textContent = '25'; $('rank').textContent = '—'; $('best').textContent = '25'; $('leaders').replaceChildren(); $('protection').hidden = true;
  $('split').disabled = true; $('cell-count').textContent = '1 / 4 pieces'; $('merge-note').textContent = '60 mass per piece to split';
  overlay('joining', 'Finding your garden.', requestedRoom ? `Getting room ${requestedRoom} ready for your crew.` : 'Your little dill is on the way.'); resize();
  history.replaceState(null, '', shareURL(location.origin, requestedRoom));
  const token = generation; lastPacket = performance.now();
  try { socket = new WebSocket(socketURL(location.origin, settings, requestedRoom)); } catch { disconnected('We couldn’t reach the garden. Check your connection and try again.'); return; }
  connectTimer = setTimeout(() => { if (token === generation && phase === 'joining') disconnected('The garden is taking a while to answer. Try joining again.'); }, 10000);
  socket.onmessage = event => {
    if (token !== generation) return;
    let packet; try { packet = JSON.parse(event.data); } catch { return; }
    lastPacket = performance.now();
    if (packet.type === 'welcome') { if (packet.protocol !== 1 || typeof packet.id !== 'string') { disconnected('This garden has been updated. Refresh this page to play.'); return; } ownID = packet.id; return; }
    if (packet.type !== 'state' || !ownID || !Array.isArray(packet.players) || !Number.isFinite(packet.width) || !Number.isFinite(packet.height)) return;
    const own = packet.players.find(player => player.id === ownID); if (!own) return;
    if (state && packet.tick <= state.tick) return;
    previous = new Map((state?.players || []).map(player => [player.id, player]));
    packet.food = applyFoodUpdate(state?.food || [], packet);
    state = packet; arrived = performance.now();
    for (const player of packet.players) if (player.mass > (previous.get(player.id)?.mass ?? Infinity) + .5) ateAt.set(player.id, arrived);
    if (phase === 'joining') { clearTimeout(connectTimer); phase = 'playing'; hideOverlay(); sound('join'); canvas.tabIndex = 0; canvas.focus({ preventScroll: true }); }
    if (ownPrevious?.alive && !own.alive) { clearMovement(); sound('death'); overlay('dead', 'A delicious little disaster.', `${own.eatenBy || 'Another dill'} got the last crunch. Your next big moment starts small.`); }
    if (ownPrevious && !ownPrevious.alive && own.alive) { hideOverlay(); sound('respawn'); }
    if (ownPrevious?.alive && own.alive && own.kills > ownPrevious.kills) sound('absorb');
    if (ownPrevious?.alive && own.alive && playerCells(own).length > playerCells(ownPrevious).length) sound('split');
    if (ownPrevious?.alive && own.alive && own.mass >= ownPrevious.mass - .5 && playerCells(own).length < playerCells(ownPrevious).length) sound('regroup');
    if (own.dash > 0 && !(ownPrevious?.dash > 0)) sound('dash');
    if (own.best > settings.best) { settings.best = Math.floor(own.best); if (settings.best >= lastSavedBest + 10 || !own.alive) { save(); lastSavedBest = settings.best; } }
    ownPrevious = own; updateHUD(own);
  };
  socket.onclose = event => { if (token === generation && phase !== 'lobby') disconnected(event.code === 1008 ? 'The connection needs a fresh start. Jump back into the garden.' : 'Your connection to the garden ended. Rejoin for a fresh start.'); };
  socket.onerror = () => { if (token === generation) disconnected('We couldn’t reach the garden. Check your connection and try again.'); };
  inputTimer = setInterval(() => {
    if (performance.now() - lastPacket > 8000 && phase === 'playing') { disconnected('The garden stopped responding. Rejoin to keep playing.'); return; }
    if (phase === 'playing') send({ type: 'input', seq: sequence++, ...movement });
  }, 50);
}
function disconnected(message) { if (phase === 'lobby' || phase === 'disconnected') return; stopSocket(); phase = 'disconnected'; save(); $('population').textContent = 'Disconnected'; overlay('disconnected', 'Lost in the brine.', message); }
function leave() { stopSocket(); phase = 'lobby'; save(); $('game').hidden = true; $('lobby').hidden = false; document.body.style.overflow = ''; hideOverlay(); state = null; ownPrevious = null; refreshLobby(); $('play').focus({ preventScroll: true }); }
$('leave').addEventListener('click', () => { clearMovement(); overlay('leave', 'Still a little hungry?', 'Your dill stays in the garden while you decide. Leaving starts a fresh run next time.'); });
$('overlay-back').addEventListener('click', leave);
$('overlay-action').addEventListener('click', () => { unlockAudio(); if (overlayMode === 'dead') { send({ type: 'respawn' }); $('overlay-action').disabled = true; } else if (overlayMode === 'leave') { hideOverlay(); canvas.focus({ preventScroll: true }); } else join(requestedRoom); });
async function share(run = false) {
  const best = state?.players.find(p => p.id === ownID)?.best || settings.best;
  const data = { title: 'Little Dill · Brine Royale', text: run ? `I grew a ${best}-mass dill in Brine Royale. Think you can out-crunch me?` : requestedRoom ? `You’re invited to my pickle garden. Room ${requestedRoom}. Web & iPhone welcome!` : 'Little pickle. Big appetite. Come play Brine Royale with me!', url: shareURL(location.origin, requestedRoom) };
  try { if (navigator.share) { await navigator.share(data); return; } if (navigator.clipboard?.writeText) { await navigator.clipboard.writeText(`${data.text}\n${data.url}`); notify(requestedRoom ? `Invite copied · room ${requestedRoom}` : 'Garden link copied. Send a little trouble.'); return; } } catch (error) { if (error.name === 'AbortError') return; }
  // A selectable dialog remains usable on browsers without a clipboard API.
  window.prompt('Copy your garden invite:', `${data.text}\n${data.url}`);
}
$('invite').addEventListener('click', () => share()); $('share-run').addEventListener('click', () => share(true));
function updateHUD(own) {
  const ranked = state.players.filter(p => p.alive).sort((a, b) => b.mass - a.mass || a.id.localeCompare(b.id));
  $('mass').textContent = massLabel(own.mass); $('mass').title = `${Math.floor(own.mass).toLocaleString()} mass`; $('rank').textContent = own.alive ? `#${ranked.findIndex(p => p.id === ownID) + 1}` : '—'; $('best').textContent = massLabel(own.best); $('best').title = `${own.best.toLocaleString()} best mass`;
  $('population').textContent = `${state.players.length} in the garden · ${requestedRoom ? 'friends' : 'public'}`;
  $('protection').hidden = !own.alive || own.shield <= 0 || overlayMode !== '';
  $('dash').disabled = !own.alive || own.mass < 35 || own.cooldown > 0 || phase !== 'playing';
  $('dash-note').textContent = own.cooldown > 0 ? `${own.cooldown.toFixed(1)}s` : own.mass < 35 ? `${Math.ceil(35 - own.mass)} more mass` : '−5 mass · escape!';
  const splitting = splitState(own);
  $('split').disabled = !splitting.enabled || phase !== 'playing';
  $('split-note').textContent = splitting.enabled ? '60+ mass per piece' : splitting.reason;
  $('split').setAttribute('aria-label', splitting.enabled ? 'Split forward; pieces regroup automatically after 12 seconds' : `Split unavailable: ${splitting.reason}`);
  $('cell-count').textContent = splitting.count > 1 ? `${splitting.count} / 4 cucumbers` : `${splitting.count} / 4 pieces`;
  $('merge-note').textContent = splitting.count > 1 ? splitting.merge > 0 ? `Regroup in ${Math.ceil(splitting.merge)}s` : 'Regrouping automatically…' : '60 mass per piece to split';
  if (!own.alive && overlayMode === 'dead') { $('run-best').textContent = massLabel(own.best); $('run-best').title = own.best.toLocaleString(); $('run-kills').textContent = massLabel(own.kills); $('overlay-action').disabled = own.respawn > 0; $('overlay-action').textContent = own.respawn > 0 ? `Fresh pickle in ${Math.ceil(own.respawn)}…` : 'One more crunch'; }
  const leaders = ranked.slice(0, 5), signature = leaders.map(p => `${p.id}:${Math.floor(p.mass)}`).join('|');
  if (signature !== leaderboardSignature) {
    leaderboardSignature = signature; $('leaders').replaceChildren(...leaders.map(p => { const row = document.createElement('li'), name = document.createElement('span'), score = document.createElement('b'); name.className = 'leader-name'; name.textContent = p.id === ownID ? 'you' : p.name; score.textContent = massLabel(p.mass); score.title = Math.floor(p.mass).toLocaleString(); if (p.id === ownID) row.className = 'you'; row.append(name, score); return row; }));
  }
}
function steer() {
  if (phase !== 'playing' || overlayMode || !ownPrevious?.alive) { movement = { x: 0, y: 0 }; return; }
  if (stickPointer !== null) return;
  const x = Number(keys.has('d') || keys.has('arrowright')) - Number(keys.has('a') || keys.has('arrowleft'));
  const y = Number(keys.has('s') || keys.has('arrowdown')) - Number(keys.has('w') || keys.has('arrowup'));
  if (x || y) movement = direction(x, y);
  else if (pointer) { const dx = pointer.x - viewCenter.x, dy = pointer.y - viewCenter.y, length = Math.hypot(dx, dy); movement = length < 20 ? { x: 0, y: 0 } : direction(dx / 75, dy / 75); }
  else movement = { x: 0, y: 0 };
}
function dash() { if (phase !== 'playing' || overlayMode || $('dash').disabled) return; unlockAudio(); if (Math.hypot(movement.x, movement.y) < .1) { notify('Move your dill, then dash.'); return; } send({ type: 'input', seq: sequence++, ...movement }); send({ type: 'dash' }); }
$('dash').addEventListener('pointerdown', event => { event.preventDefault(); dash(); });
$('dash').addEventListener('click', event => { if (event.detail === 0) dash(); });
function split() {
  if (phase !== 'playing' || overlayMode || $('split').disabled || !splitState(ownPrevious).enabled) return;
  unlockAudio(); send({ type: 'input', seq: sequence++, ...movement }); send({ type: 'split' });
  $('split').disabled = true; // The next authoritative snapshot supplies cooldown and pieces.
}
$('split').addEventListener('pointerdown', event => { event.preventDefault(); split(); });
$('split').addEventListener('click', event => { if (event.detail === 0) split(); });
canvas.addEventListener('pointermove', event => { if (event.pointerType === 'mouse') { const rect = canvas.getBoundingClientRect(); pointer = { x: event.clientX - rect.left, y: event.clientY - rect.top }; steer(); } });
canvas.addEventListener('pointerleave', () => { pointer = null; steer(); });
canvas.addEventListener('pointerdown', () => unlockAudio());
function moveStick(event) {
  const rect = $('joystick').getBoundingClientRect(), max = rect.width * .31;
  const dx = event.clientX - rect.left - rect.width / 2, dy = event.clientY - rect.top - rect.height / 2;
  movement = direction(dx / max, dy / max); $('stick').style.transform = `translate(${movement.x * max}px, ${movement.y * max}px)`;
}
$('joystick').addEventListener('pointerdown', event => { if (phase !== 'playing' || overlayMode) return; event.preventDefault(); unlockAudio(); stickPointer = event.pointerId; $('joystick').setPointerCapture(event.pointerId); pointer = null; moveStick(event); });
$('joystick').addEventListener('pointermove', event => { if (stickPointer === event.pointerId) moveStick(event); });
for (const type of ['pointerup', 'pointercancel', 'lostpointercapture']) $('joystick').addEventListener(type, event => { if (stickPointer === event.pointerId) { stickPointer = null; movement = { x: 0, y: 0 }; $('stick').style.transform = ''; } });
window.addEventListener('keydown', event => {
  if (phase !== 'playing' || /INPUT|SELECT|TEXTAREA/.test(event.target.tagName)) return;
  if (overlayMode) { if (event.key === 'Tab') { const focusable = [...$('overlay').querySelectorAll('button:not([hidden]):not(:disabled)')]; const first = focusable[0], last = focusable.at(-1); if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); } else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); } } return; }
  if (['w','a','s','d','arrowup','arrowleft','arrowdown','arrowright'].includes(event.key.toLowerCase())) { event.preventDefault(); keys.add(event.key.toLowerCase()); pointer = null; steer(); }
  if (event.code === 'Space') { event.preventDefault(); if (!event.repeat) dash(); }
  if (event.code === 'KeyE') { event.preventDefault(); if (!event.repeat) split(); }
  if (event.key === 'Escape') { clearMovement(); overlay('leave', 'Still a little hungry?', 'Leaving starts a fresh run next time. Your best dill is saved.'); }
});
window.addEventListener('keyup', event => { keys.delete(event.key.toLowerCase()); steer(); });
window.addEventListener('blur', clearMovement);
document.addEventListener('visibilitychange', () => { if (document.hidden && (phase === 'playing' || phase === 'joining')) disconnected('The game paused while you were away. Jump back in with a fresh dill.'); });
window.addEventListener('pagehide', () => { if (phase !== 'lobby') disconnected('Ready for another round? Rejoin the garden.'); save(); });
window.addEventListener('offline', () => { if (phase !== 'lobby') disconnected('You’re offline. Reconnect to the internet, then jump back in.'); });

function resize() {
  const bounds = viewportBounds(innerWidth, innerHeight, window.visualViewport);
  width = bounds.width; height = bounds.height;
  const game = $('game');
  for (const [key, value] of Object.entries(bounds)) game.style.setProperty(`--viewport-${key}`, `${value}px`);
  game.dataset.short = String(height < 450); game.dataset.tiny = String(width < 280);
  const dpr = Math.min((devicePixelRatio || 1) * (window.visualViewport?.scale || 1), 3);
  const bitmapWidth = Math.round(width * dpr), bitmapHeight = Math.round(height * dpr);
  if (canvas.width !== bitmapWidth || canvas.height !== bitmapHeight) {
    canvas.width = bitmapWidth; canvas.height = bitmapHeight;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }
  measurePlayArea();
}
function measurePlayArea() {
  if (phase === 'lobby') return;
  const bounds = $('game').getBoundingClientRect(), top = document.querySelector('.game-top').getBoundingClientRect(), bottom = document.querySelector('.game-controls').getBoundingClientRect();
  cameraInsets = { top: top.bottom - bounds.top, bottom: bounds.bottom - bottom.top, left: 12, right: 12 };
}
new ResizeObserver(measurePlayArea).observe(document.querySelector('.game-controls'));
new ResizeObserver(measurePlayArea).observe(document.querySelector('.game-top'));
window.addEventListener('resize', resize);
window.visualViewport?.addEventListener('resize', resize);
window.visualViewport?.addEventListener('scroll', resize);
function roundedRect(context, x, y, w, h, r) { context.beginPath(); context.roundRect(x, y, w, h, r); }
function render(now) {
  const dt = Math.min(.05, (now - lastFrame) / 1000); lastFrame = now;
  if (phase === 'lobby') {
    preview.clearRect(0, 0, 560, 480); const t = reducedMotion.matches ? 0 : now / 1000;
    preview.save(); preview.translate(280, 263 + Math.sin(t * 2) * 5); preview.rotate(Math.sin(t * 1.3) * .065);
    drawPickle(preview, { ...settings, x: 0, y: 0 }, 0, 0, 126, t); preview.restore();
  } else {
    ctx.clearRect(0, 0, width, height); ctx.fillStyle = '#E7ECD9'; ctx.fillRect(0, 0, width, height);
    if (state) {
      const alpha = clamp((now - arrived) / 100, 0, 1), players = state.players.map(p => interpolate(previous.get(p.id), p, alpha));
      const own = players.find(p => p.id === ownID), alive = players.filter(p => p.alive), cells = flattenCells(alive);
      if (own) {
        const frame = cameraFrame(width, height, own, cameraInsets);
        camera = { x: frame.x, y: frame.y }; viewCenter = { x: frame.screenX, y: frame.screenY };
        // Zoom out immediately to contain newly launched pieces; ease back in as they regroup.
        zoom = frame.zoom < zoom ? frame.zoom : zoom + (frame.zoom - zoom) * Math.min(1, dt * 4);
      }
      ctx.save(); ctx.translate(viewCenter.x, viewCenter.y); ctx.scale(zoom, zoom); ctx.translate(-camera.x, -camera.y);
      ctx.fillStyle = '#EDF1E3'; roundedRect(ctx, 0, 0, state.width, state.height, 30 / zoom); ctx.fill();
      const left = Math.max(0, camera.x - viewCenter.x / zoom), top = Math.max(0, camera.y - viewCenter.y / zoom), right = Math.min(state.width, camera.x + (width - viewCenter.x) / zoom), bottom = Math.min(state.height, camera.y + (height - viewCenter.y) / zoom);
      drawGarden(left, top, right, bottom);
      ctx.strokeStyle = '#263E3109'; ctx.lineWidth = 1 / zoom; ctx.beginPath();
      for (let x = Math.floor(left / 90) * 90; x <= right; x += 90) { ctx.moveTo(x, top); ctx.lineTo(x, bottom); }
      for (let y = Math.floor(top / 90) * 90; y <= bottom; y += 90) { ctx.moveTo(left, y); ctx.lineTo(right, y); } ctx.stroke();
      ctx.strokeStyle = '#263E312E'; ctx.lineWidth = 3 / zoom; ctx.setLineDash([6 / zoom, 8 / zoom]); roundedRect(ctx, 0, 0, state.width, state.height, 30 / zoom); ctx.stroke(); ctx.setLineDash([]);
      for (const [id, x, y, value] of state.food) {
        if (x < left - 15 || x > right + 15 || y < top - 15 || y > bottom + 15) continue;
        const bonus = value >= 9, r = bonus ? 8 : 5;
        ctx.fillStyle = bonus ? '#F1C9B4' : ['#A6BF70', '#D1BC74', '#A4B8A0'][id % 3];
        ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
        if (bonus) { ctx.strokeStyle = '#F1C9B459'; ctx.lineWidth = 2 / zoom; ctx.beginPath(); ctx.arc(x, y, r + 2 / zoom, 0, Math.PI * 2); ctx.stroke(); }
      }
      const visiblePlayers = [], latest = new Map(state.players.map(player => [player.id, player]));
      for (const p of cells.sort((a, b) => a.mass - b.mass)) {
        const r = radius(p.mass); if (p.x + r < left - 60 || p.x - r > right + 60 || p.y + r < top - 60 || p.y - r > bottom + 60) continue;
        const before = previous.get(p.ownerID), after = latest.get(p.ownerID);
        const heading = before && after ? direction((after.x - before.x) / 4, (after.y - before.y) / 4) : { x: 0, y: 0 };
        const mood = pieceMood(p, cells, (now - (ateAt.get(p.ownerID) ?? -Infinity)) / 1000);
        drawPickle(ctx, { ...p, mood, lookX: heading.x, lookY: heading.y }, p.x, p.y, r, reducedMotion.matches ? 0 : now / 1000, p.ownerID === ownID, zoom);
        visiblePlayers.push(p);
      }
      ctx.restore(); drawLabels(visiblePlayers); drawMap(cells, own); steer();
    }
  }
  requestAnimationFrame(render);
}
function drawGarden(left, top, right, bottom) {
  // The native arena uses these same fixed landmarks. They never affect movement.
  const tile = 900, leafOffsets = [[160, 230], [690, 640], [330, 750]];
  ctx.save(); roundedRect(ctx, 0, 0, state.width, state.height, 30 / zoom); ctx.clip();
  const firstColumn = Math.max(0, Math.floor(left / tile)), lastColumn = Math.min(Math.ceil(state.width / tile) - 1, Math.floor(right / tile));
  const firstRow = Math.max(0, Math.floor(top / tile)), lastRow = Math.min(Math.ceil(state.height / tile) - 1, Math.floor(bottom / tile));
  for (let column = firstColumn; column <= lastColumn; column++) {
    for (let row = firstRow; row <= lastRow; row++) {
      const x = column * tile, y = row * tile;
      ctx.globalAlpha = .22; ctx.fillStyle = (column + row) % 2 === 0 ? '#DDE7CC' : '#D9E3D3';
      ctx.beginPath(); ctx.ellipse(x + 450, y + 450, 330, 240, 0, 0, Math.PI * 2); ctx.fill();
      leafOffsets.forEach(([dx, dy], index) => {
        ctx.save(); ctx.translate(x + dx, y + dy); ctx.rotate(((column * 37 + row * 53 + index * 71) % 180) * Math.PI / 180);
        ctx.globalAlpha = .055; ctx.fillStyle = '#263E31'; ctx.beginPath();
        ctx.moveTo(-21, 0); ctx.quadraticCurveTo(0, -18, 21, 0); ctx.quadraticCurveTo(0, 18, -21, 0); ctx.fill();
        ctx.globalAlpha = .06; ctx.strokeStyle = '#263E31'; ctx.lineWidth = 1; ctx.beginPath(); ctx.moveTo(-18, 0); ctx.lineTo(18, 0); ctx.stroke(); ctx.restore();
      });
      ctx.globalAlpha = .13; ctx.fillStyle = '#263E31'; ctx.font = `500 ${11 / zoom}px 'Avenir Next', system-ui, sans-serif`; ctx.textAlign = 'left'; ctx.textBaseline = 'top';
      ctx.fillText(`${String.fromCharCode(65 + column)}${row + 1}`, x + 30, y + 40);
    }
  }
  ctx.globalAlpha = .065; ctx.strokeStyle = '#263E31'; ctx.lineWidth = 1 / zoom; ctx.beginPath();
  for (let x = Math.ceil(left / tile) * tile; x <= right; x += tile) { ctx.moveTo(x, top); ctx.lineTo(x, bottom); }
  for (let y = Math.ceil(top / tile) * tile; y <= bottom; y += tile) { ctx.moveTo(left, y); ctx.lineTo(right, y); }
  ctx.stroke(); ctx.restore();
}
function drawLabels(players) {
  // Screen-space text stays legible even when a huge dill zooms the world out.
  const fontSize = 11, maxLabelWidth = Math.min(150, Math.max(70, width * .42));
  // One name on the largest visible piece avoids a pile of identical labels.
  const largestPieces = new Map();
  for (const cell of players) if (!largestPieces.has(cell.ownerID) || cell.mass > largestPieces.get(cell.ownerID).mass) largestPieces.set(cell.ownerID, cell);
  for (const p of [...largestPieces.values()].sort((a, b) => Number(a.ownerID === ownID) - Number(b.ownerID === ownID))) {
    const x = (p.x - camera.x) * zoom + viewCenter.x;
    const y = (p.y - camera.y + radius(p.mass)) * zoom + viewCenter.y + 14;
    ctx.font = `${p.ownerID === ownID ? 750 : 600} ${fontSize}px 'Avenir Next', system-ui, sans-serif`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    let name = p.ownerID === ownID ? 'you' : p.name, label = name;
    while (ctx.measureText(label).width > maxLabelWidth && name.length > 1) { name = Array.from(name).slice(0, -1).join(''); label = `${name}…`; }
    ctx.fillStyle = '#263E31'; ctx.fillText(label, x, y);
  }
}
function drawMap(players, own) {
  map.clearRect(0, 0, 160, 120); map.fillStyle = '#e9eed7'; roundedRect(map, 0, 0, 160, 120, 5); map.fill();
  map.strokeStyle = '#b2c090'; map.lineWidth = .8; map.strokeRect(1, 1, 158, 118);
  for (const p of players) { map.fillStyle = p.ownerID === ownID ? '#263E31' : '#F1C9B4'; map.beginPath(); map.arc(p.x / state.width * 160, p.y / state.height * 120, p.ownerID === ownID ? 3.5 : 2, 0, Math.PI * 2); map.fill(); }
  if (own?.alive) { map.strokeStyle = '#405c3480'; map.lineWidth = .6; map.strokeRect((camera.x - viewCenter.x / zoom) / state.width * 160, (camera.y - viewCenter.y / zoom) / state.height * 120, width / zoom / state.width * 160, height / zoom / state.height * 120); }
}
refreshLobby(); updateSound(); resize(); requestAnimationFrame(render);
