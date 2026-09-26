import { BRINES, OUTFITS, VARIETIES, varietyOf, clamp, radius, viewportBounds, cameraFrame, playerCells, flattenCells, cellKey, threatenedCellIDs, splitState, massLabel, roomCode, direction, playerName, socketURL, applyFoodUpdate, readResumeRecord, refreshResumeRecord, resumeFromWelcome, resumeRetryDelay, shareURL, interpolate, drawPickle, easeZoom, killRings, bodyShape, membraneSize, resizeMembrane, stepMembrane, membraneOutline, hazardFor, drainDroplets, spitFlight, drawDroplet, drawHazard, hazardKind, scheduleStrokes, pickupCue } from './arena-core.mjs';

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
const resumeStorageKey = 'little-dill.arena.resume.v1';
const resumeWriter = globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random()}`;
let storedResume = null, loadedResumeText = null, writtenResumeText = null;
try { loadedResumeText = localStorage.getItem(resumeStorageKey); storedResume = JSON.parse(loadedResumeText); } catch { /* In-memory reconnect still works. */ }
let resumeSession = readResumeRecord(storedResume), resumeWritten = 0, retryAttempt = 0, retryTimer = null, graceTimer = null, suspended = document.hidden;
let requestedRoom = roomCode(new URL(location.href).searchParams.get('room'));
let socket = null, generation = 0, ownID = null, state = null, previous = new Map(), arrived = 0, lastPacket = 0;
let phase = 'lobby', overlayMode = '', sequence = 0, inputTimer = null, connectTimer = null, toastTimer = null;
let movement = { x: 0, y: 0 }, pointer = null, keys = new Set(), stickPointer = null, ownPrevious = null;
let threatened = new Set(), membranes = new Map(), membraneClock = 0, spits = new Map();
let width = innerWidth, height = innerHeight, camera = { x: 1200, y: 900 }, zoom = null, lastFrame = performance.now();
let viewCenter = { x: width / 2, y: height / 2 }, cameraInsets = {};
let audio = null, audioOut = null, noiseBuffer = null, drainLoop = null, pickupState = null, pickupBuffers = [], pickupLoading = null, leaderboardSignature = '', lastSavedBest = settings.best;

function notify(message) { $('toast').textContent = message; $('toast').hidden = false; clearTimeout(toastTimer); toastTimer = setTimeout(() => { $('toast').hidden = true; }, 3500); }
function audioOutput() {
  if (!audioOut) {
    const compressor = audio.createDynamicsCompressor();
    compressor.threshold.value = -18; compressor.knee.value = 10; compressor.ratio.value = 4; compressor.attack.value = .003; compressor.release.value = .15;
    audioOut = audio.createGain(); audioOut.gain.value = .9; audioOut.connect(compressor); compressor.connect(audio.destination);
    noiseBuffer = audio.createBuffer(1, audio.sampleRate, audio.sampleRate);
    const samples = noiseBuffer.getChannelData(0); for (let i = 0; i < samples.length; i++) samples[i] = Math.random() * 2 - 1;
  }
  return audioOut;
}
function envelope(at, peak, attack, length) {
  const gain = audio.createGain();
  gain.gain.setValueAtTime(.0001, at); gain.gain.exponentialRampToValueAtTime(peak, at + attack); gain.gain.exponentialRampToValueAtTime(.0001, at + length);
  gain.connect(audioOutput()); return gain;
}
function tone(type, from, to, at, length, peak) {
  const osc = audio.createOscillator(); osc.type = type;
  osc.frequency.setValueAtTime(from, at); osc.frequency.exponentialRampToValueAtTime(to, at + length);
  osc.connect(envelope(at, peak, Math.min(.012, length / 4), length)); osc.start(at); osc.stop(at + length + .02);
}
function burst(at, length, peak, { type, frequency, sweep = frequency, q = 1, attack = .003 }) {
  const source = audio.createBufferSource(), filter = audio.createBiquadFilter();
  source.buffer = noiseBuffer; filter.type = type; filter.Q.value = q;
  filter.frequency.setValueAtTime(frequency, at); if (sweep !== frequency) filter.frequency.exponentialRampToValueAtTime(sweep, at + length);
  source.connect(filter); filter.connect(envelope(at, peak, attack, length)); source.start(at, Math.random() * .5, length + .02);
}
const random = (min, max) => min + Math.random() * (max - min);
const sounds = {
  crunch(at) {
    for (const [n, offset] of [0, .045, .095, .15].slice(0, Math.random() < .5 ? 3 : 4).entries()) burst(at + offset, random(.035, .06), .22 * .8 ** n, { type: 'bandpass', frequency: random(1800, 3200), q: 1.2, attack: .002 });
    tone('sine', 120, 55, at, .12, .18);
  },
  gulp(at) { tone('sine', 300, 120, at, .14, .14); burst(at, .012, .08, { type: 'highpass', frequency: 2500 }); },
  dash(at) { burst(at, .25, .2, { type: 'bandpass', frequency: 600, sweep: 2400, q: 1.1, attack: .05 }); },
  split(at) { for (const offset of [0, .035]) burst(at + offset, .015, .1, { type: 'highpass', frequency: 4000 }); tone('sine', 900, 500, at, .06, .08); },
  regroup(at) { tone('sine', 420, 620, at, .12, .07); },
  join(at) { tone('triangle', 523, 523, at, .14, .06); tone('triangle', 784, 784, at + .09, .18, .06); },
  respawn(at) { tone('triangle', 587, 587, at, .14, .06); tone('triangle', 880, 880, at + .09, .18, .06); }
};
function sound(kind) {
  if (!settings.sound || !audio || audio.state !== 'running') return;
  if (kind === 'nibble') {
    const cue = pickupCue(pickupState, audio.currentTime);
    if (!cue || !pickupBuffers[cue.index]) return;
    pickupState = cue;
    const source = audio.createBufferSource(), gain = audio.createGain();
    source.buffer = pickupBuffers[cue.index]; gain.gain.value = cue.volume;
    source.connect(gain); gain.connect(audioOutput()); source.start(audio.currentTime + .005);
    return;
  }
  if (sounds[kind]) { audioOutput(); sounds[kind](audio.currentTime + .005); }
}
const gadgetStrokes = {
  slicer(at) { burst(at, .09, .09, { type: 'bandpass', frequency: 5200, sweep: 2400, q: 2.5, attack: .01 }); tone('triangle', 2400, 2250, at + .07, .06, .025); tone('sine', 190, 120, at + .09, .045, .06); },
  shaker(at) { for (let n = 0; n < 10; n++) burst(at + random(0, .07), .006, random(.03, .06), { type: 'highpass', frequency: 5000 }); tone('triangle', 1800, 1700, at + .01, .02, .012); },
  grater(at) { for (let n = 0; n < 14; n++) burst(at + n * .012, .01, .05 * (1 - n / 20), { type: 'bandpass', frequency: 2000 + n * 110, q: 2 }); }
};
function drainSound(kind) {
  if (!settings.sound || audio?.state !== 'running') { drainLoop = null; return; }
  audioOutput();
  const { loop, times } = scheduleStrokes(drainLoop, kind, audio.currentTime);
  drainLoop = loop; for (const at of times) gadgetStrokes[kind](at);
}
function stopDrain() { drainLoop = null; }
function unlockAudio() {
  if (!settings.sound) return;
  try {
    audio ||= new (window.AudioContext || window.webkitAudioContext)(); audio.resume().catch(() => {});
    pickupLoading ||= Promise.all([0, 1, 2, 3].map(async index => {
      const response = await fetch(`./audio/arena-pickup-${index}.wav`);
      if (!response.ok) throw new Error('Pickup audio unavailable');
      return audio.decodeAudioData(await response.arrayBuffer());
    })).then(buffers => { pickupBuffers = buffers; }).catch(() => { pickupLoading = null; });
  } catch { settings.sound = false; updateSound(); }
}
function updateSound() { document.querySelectorAll('.sound-toggle').forEach(button => { button.setAttribute('aria-pressed', String(settings.sound)); button.setAttribute('aria-label', `Turn sound ${settings.sound ? 'off' : 'on'}`); button.title = `Sound ${settings.sound ? 'on' : 'off'}`; }); }
document.querySelectorAll('.sound-toggle').forEach(button => button.addEventListener('click', () => { settings.sound = !settings.sound; save(); updateSound(); unlockAudio(); if (settings.sound) sound('join'); else stopDrain(); }));
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

function send(message) { if (socket?.readyState === WebSocket.OPEN) { try { socket.send(JSON.stringify(message)); } catch { disconnected('The garden connection dropped. Restoring your run…'); } } }
function clearMovement() { keys.clear(); pointer = null; stickPointer = null; movement = { x: 0, y: 0 }; $('stick').style.transform = ''; if (socket?.readyState === WebSocket.OPEN) send({ type: 'input', seq: sequence++, x: 0, y: 0 }); }
function stopSocket() {
  generation++; clearInterval(inputTimer); clearTimeout(connectTimer); inputTimer = null; connectTimer = null;
  // Detach before resetting intent: a failing send must never re-enter cleanup.
  const old = socket; socket = null; clearMovement(); stopDrain();
  if (old) { old.onopen = old.onmessage = old.onerror = old.onclose = null; try { old.close(1000, 'Taking a breather.'); } catch { /* Already closed. */ } }
}
function persistResume(force = false) {
  if (!resumeSession || !force && Date.now() - resumeWritten < 1000) return;
  const payload = JSON.stringify({ ...resumeSession, writer: resumeWriter });
  try { localStorage.setItem(resumeStorageKey, payload); writtenResumeText = payload; resumeWritten = Date.now(); } catch { /* Keep credentials in memory. */ }
}
function clearResume() {
  // Delete only this tab's exact record; another tab may now own the token.
  // Consume cleanup authority so repeated calls cannot delete its record.
  const ownedRecord = writtenResumeText || loadedResumeText;
  writtenResumeText = null; loadedResumeText = null; storedResume = null;
  resumeSession = null; resumeWritten = 0;
  try { if (ownedRecord && localStorage.getItem(resumeStorageKey) === ownedRecord) localStorage.removeItem(resumeStorageKey); } catch { /* Storage may be unavailable. */ }
}
function cancelRecovery() { clearTimeout(retryTimer); clearInterval(graceTimer); retryTimer = null; graceTimer = null; retryAttempt = 0; }
function releaseRun() {
  const held = readResumeRecord(resumeSession);
  // Intentional exits relinquish the held run, even while the main socket retries.
  if (socket?.readyState === WebSocket.OPEN) { try { socket.send(JSON.stringify({ type: 'leave' })); } catch { /* It may already be offline. */ } }
  else if (held && navigator.onLine) {
    try {
      const release = new WebSocket(socketURL(location.origin, settings, requestedRoom, held));
      const timeout = setTimeout(() => release.close(), 2000);
      release.onopen = () => { try { release.send(JSON.stringify({ type: 'leave' })); } catch { /* It disconnected during release. */ } finally { release.close(1000, 'Left the garden.'); } };
      release.onclose = () => clearTimeout(timeout); release.onerror = () => { clearTimeout(timeout); release.close(); };
    } catch { /* An offline held run expires at its existing deadline. */ }
  }
  cancelRecovery(); clearResume(); stopSocket();
}
function overlay(mode, title, message) {
  overlayMode = mode; $('overlay').hidden = false; $('overlay-title').textContent = title; $('overlay-message').textContent = message;
  $('overlay-kicker').textContent = { joining: 'FRESH FROM THE JAR', reconnecting: 'HOLD THAT DILL', disconnected: 'A LITTLE BREATHER', dead: 'YOU WERE A PRETTY BIG DILL', leave: 'HEADING OUT?' }[mode] || '';
  $('overlay-action').hidden = mode === 'joining'; $('overlay-action').disabled = false;
  $('overlay-action').textContent = mode === 'leave' ? 'Keep playing' : mode === 'dead' ? 'One more crunch' : mode === 'reconnecting' ? 'Reconnect now' : 'Start a fresh run';
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
  releaseRun(); requestedRoom = roomCode(room); ownID = null; state = null; previous.clear(); threatened.clear(); membranes.clear(); spits.clear(); ownPrevious = null; sequence = 0; leaderboardSignature = ''; zoom = null;
  phase = 'joining'; $('lobby').hidden = true; $('game').hidden = false; document.body.style.overflow = 'hidden';
  $('room-badge').hidden = !requestedRoom; $('room-badge').textContent = requestedRoom ? `FRIEND ROOM · ${requestedRoom}` : '';
  $('population').textContent = 'Finding your garden…'; $('mass').textContent = '25'; $('rank').textContent = '—'; $('best').textContent = '25'; $('leaders').replaceChildren(); $('protection').hidden = true;
  $('split').disabled = true; $('cell-count').textContent = '1 / 8 slices'; $('merge-note').textContent = '60 mass per slice to split';
  overlay('joining', 'Finding your garden.', requestedRoom ? `Getting room ${requestedRoom} ready for your crew.` : 'Your little dill is on the way.'); resize();
  history.replaceState(null, '', shareURL(location.origin, requestedRoom));
  connectSocket();
}
function connectSocket(resume = null) {
  stopSocket(); sequence = 0;
  const token = generation; let welcomed = false, firstState = true; lastPacket = performance.now();
  try { socket = new WebSocket(socketURL(location.origin, settings, requestedRoom, resume)); } catch { disconnected('We couldn’t reach the garden. Check your connection and try again.'); return; }
  const timeout = resume ? Math.min(5000, Math.max(1, resume.deadline - Date.now())) : 10000;
  connectTimer = setTimeout(() => { if (token === generation) disconnected('The garden is taking a while to answer.'); }, timeout);
  socket.onmessage = event => {
    if (token !== generation) return;
    let packet; try { packet = JSON.parse(event.data); } catch { return; }
    lastPacket = performance.now();
    if (packet.type === 'resume-expired') { endRecovery('The server could not restore this run. Your best is saved.'); return; }
    if (packet.type === 'welcome') {
      if (packet.protocol !== 1 || typeof packet.id !== 'string') { endRecovery('This garden has been updated. Refresh this page to play.'); return; }
      if (resume && packet.resumed !== true) { releaseRun(); endRecovery('That run could not be restored. You can choose a fresh start.'); return; }
      const credentials = resumeFromWelcome(packet);
      if (resume && (!credentials || credentials.token !== resume.token || credentials.room !== resume.room)) { endRecovery('That run could not be restored. You can choose a fresh start.'); return; }
      welcomed = true; ownID = packet.id;
      resumeSession = credentials && resume ? { ...credentials, deadline: resume.deadline } : credentials;
      persistResume(true); return;
    }
    if (packet.type !== 'state' || !welcomed || !ownID || !Array.isArray(packet.players) || !Number.isFinite(packet.width) || !Number.isFinite(packet.height)) return;
    const own = packet.players.find(player => player.id === ownID); if (!own) return;
    if (!firstState && state && packet.tick <= state.tick) return;
    const entering = firstState; firstState = false;
    previous = new Map((state?.players || []).map(player => [player.id, player]));
    packet.food = applyFoodUpdate(state?.food || [], packet);
    packet.hazards = Array.isArray(packet.hazards) ? packet.hazards : [];
    state = packet; arrived = performance.now();
    trackSpit(packet, entering); pruneMembranes(packet);
    threatened = threatenedCellIDs(packet.players);
    resumeSession = refreshResumeRecord(resumeSession); persistResume();
    if (entering) { clearTimeout(connectTimer); cancelRecovery(); phase = 'playing'; hideOverlay(); if (!resume) sound('join'); canvas.tabIndex = 0; canvas.focus({ preventScroll: true }); }
    if (!own.alive && (ownPrevious?.alive || entering)) { clearMovement(); if (ownPrevious?.alive && !resume) sound('crunch'); overlay('dead', 'A delicious little disaster.', `${own.eatenBy || 'Another dill'} got the last crunch. Your next big moment starts small.`); }
    if (ownPrevious && !ownPrevious.alive && own.alive) { hideOverlay(); sound('respawn'); zoom = null; }
    if (ownPrevious?.alive && own.alive) feedingSounds(own, ownPrevious, packet.players);
    if (own.dash > 0 && !(ownPrevious?.dash > 0)) sound('dash');
    const drained = own.alive ? playerCells(own).find(cell => cell.drain > 0) : null, field = drained && hazardFor(drained, packet.hazards);
    if (field) drainSound(hazardKind(field, packet.hazards.indexOf(field))); else stopDrain();
    if (own.best > settings.best) { settings.best = Math.floor(own.best); if (settings.best >= lastSavedBest + 10 || !own.alive) { save(); lastSavedBest = settings.best; } }
    ownPrevious = own; updateHUD(own);
  };
  socket.onclose = event => {
    if (token !== generation || phase === 'lobby') return;
    if (event.code === 4001) { endRecovery('This run continued on another connection. You can start a new run here.'); return; }
    if (event.code === 1008) { endRecovery('The connection needs a fresh start. Choose a new run when you’re ready.'); return; }
    disconnected('Your garden connection dropped. Restoring your run…');
  };
  // Error is followed by close; preserve its code so a takeover never retries.
  socket.onerror = () => {};
  inputTimer = setInterval(() => {
    if (performance.now() - lastPacket > 8000 && phase === 'playing') { disconnected('The garden stopped responding. Restoring your run…'); return; }
    if (phase === 'playing') send({ type: 'input', seq: sequence++, ...movement });
  }, 50);
}
function trackSpit(packet, entering) {
  const live = new Set();
  for (const [id, x, y, value] of packet.food) {
    if (value !== 4) continue;
    live.add(id);
    if (spits.has(id)) continue;
    const source = entering ? null : packet.hazards.find(h => Math.hypot(x - h.x, y - h.y) < h.r + 200);
    spits.set(id, source ? { t0: arrived, x: source.x, y: source.y } : null);
  }
  for (const id of spits.keys()) if (!live.has(id)) spits.delete(id);
}
function pruneMembranes(packet) {
  const present = new Set(packet.players.flatMap(player => playerCells(player).map(cell => cellKey(player.id, cell.id))));
  for (const key of membranes.keys()) if (!present.has(key)) membranes.delete(key);
}
function preyVanished(mine, players) {
  const remaining = new Set(players.flatMap(player => playerCells(player).map(cell => cellKey(player.id, cell.id))));
  return [...previous.values()].some(player => player.id !== ownID && playerCells(player).some(cell => !remaining.has(cellKey(player.id, cell.id)) && mine.some(own => Math.hypot(own.x - cell.x, own.y - cell.y) < radius(own.mass) + radius(cell.mass))));
}
function feedingSounds(own, before, players) {
  const cells = playerCells(own), earlier = playerCells(before), ids = new Set(cells.map(cell => cell.id)), change = own.mass - before.mass;
  const lost = earlier.filter(cell => !ids.has(cell.id)).reduce((sum, cell) => sum + cell.mass, 0);
  // Regrouping keeps the merged mass; an eaten piece takes it away.
  if ((own.hurt || 0) > (before.hurt || 0) + .2 || lost > 0 && change < -1 && -change >= lost * .5) { sound('crunch'); return; }
  else if (cells.length < earlier.length) sound('regroup');
  else if (cells.length > earlier.length) sound('split');
  if (own.kills > before.kills || change >= 8 && preyVanished(earlier, players)) sound('gulp');
  else if (change >= 2) sound('nibble');
}
function endRecovery(message) {
  stopSocket(); cancelRecovery(); clearResume(); phase = 'disconnected'; save();
  $('population').textContent = 'Disconnected'; overlay('disconnected', 'A fresh little start.', message);
}
function updateRecovery() {
  if (phase !== 'reconnecting') return;
  const live = readResumeRecord(resumeSession);
  if (!live) { endRecovery('Your 30-second reconnect window has ended. Start a fresh run when you’re ready.'); return; }
  const remaining = Math.ceil((live.deadline - Date.now()) / 1000);
  $('population').textContent = `Reconnecting · ${remaining}s`;
  $('overlay-message').textContent = `${suspended ? 'Return to restore your run' : navigator.onLine ? 'Restoring your exact run' : 'Waiting for your internet connection'} · ${remaining}s remaining.`;
  $('overlay-action').disabled = suspended || !navigator.onLine || socket !== null;
}
function scheduleResume(immediate = false) {
  clearTimeout(retryTimer); retryTimer = null;
  if (phase !== 'reconnecting' || suspended || !navigator.onLine || socket) return;
  const live = readResumeRecord(resumeSession);
  if (!live) { updateRecovery(); return; }
  const delay = immediate ? 0 : resumeRetryDelay(retryAttempt++, live.deadline);
  if (delay === null) { updateRecovery(); return; }
  retryTimer = setTimeout(() => {
    retryTimer = null;
    if (phase !== 'reconnecting' || suspended || !navigator.onLine) return;
    const credentials = readResumeRecord(resumeSession);
    if (!credentials) { updateRecovery(); return; }
    connectSocket(credentials); updateRecovery();
  }, delay);
}
function disconnected(message) {
  if (phase === 'lobby' || phase === 'disconnected') return;
  stopSocket(); save();
  if (!readResumeRecord(resumeSession)) { endRecovery(message + ' Choose a fresh run to play again.'); return; }
  persistResume(true); phase = 'reconnecting';
  overlay('reconnecting', 'Hold that dill.', message); updateRecovery();
  if (!graceTimer) graceTimer = setInterval(updateRecovery, 250);
  scheduleResume();
}
function restoreStoredRun() {
  const live = readResumeRecord(resumeSession);
  if (!live) return;
  requestedRoom = live.room.startsWith('crew-') ? live.room.slice(5) : null;
  $('lobby').hidden = true; $('game').hidden = false; document.body.style.overflow = 'hidden';
  $('room-badge').hidden = !requestedRoom; $('room-badge').textContent = requestedRoom ? `FRIEND ROOM · ${requestedRoom}` : '';
  history.replaceState(null, '', shareURL(location.origin, requestedRoom));
  phase = 'reconnecting'; disconnected('Restoring your saved run…'); resize(); scheduleResume(true);
}
function leave() { releaseRun(); phase = 'lobby'; save(); $('game').hidden = true; $('lobby').hidden = false; document.body.style.overflow = ''; hideOverlay(); state = null; ownPrevious = null; refreshLobby(); $('play').focus({ preventScroll: true }); }
$('leave').addEventListener('click', () => { clearMovement(); overlay('leave', 'Still a little hungry?', 'Your dill stays in the garden while you decide. Leaving starts a fresh run next time.'); });
$('overlay-back').addEventListener('click', leave);
$('overlay-action').addEventListener('click', () => { unlockAudio(); if (overlayMode === 'dead') { send({ type: 'respawn' }); $('overlay-action').disabled = true; } else if (overlayMode === 'leave') { hideOverlay(); canvas.focus({ preventScroll: true }); } else if (overlayMode === 'reconnecting') scheduleResume(true); else join(requestedRoom); });
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
  $('split-note').textContent = splitting.enabled ? '60+ mass per slice' : splitting.reason;
  $('split').setAttribute('aria-label', splitting.enabled ? 'Split forward into pickle slices; regroup automatically after 12 seconds' : `Split unavailable: ${splitting.reason}`);
  $('cell-count').textContent = `${splitting.count} / 8 slices`;
  $('merge-note').textContent = splitting.count > 1 ? splitting.merge > 0 ? `Regroup in ${Math.ceil(splitting.merge)}s` : 'Regrouping automatically…' : '60 mass per slice to split';
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
function pauseConnection() { if (['playing', 'joining', 'reconnecting'].includes(phase)) { persistResume(true); disconnected('Holding your dill while you’re away…'); } }
function returnToConnection() {
  suspended = document.hidden;
  if (phase === 'reconnecting') { updateRecovery(); scheduleResume(true); }
}
document.addEventListener('visibilitychange', () => { suspended = document.hidden; if (suspended) pauseConnection(); else returnToConnection(); });
window.addEventListener('pagehide', () => { suspended = true; pauseConnection(); save(); });
window.addEventListener('pageshow', returnToConnection);
window.addEventListener('offline', () => { if (phase !== 'lobby') disconnected('You’re offline. Waiting to restore your run…'); });
window.addEventListener('online', () => { if (phase === 'reconnecting') { updateRecovery(); scheduleResume(true); } });

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
    drawPickle(preview, { ...settings, threatened: false, x: 0, y: 0 }, 0, 0, 126, t); preview.restore();
  } else {
    ctx.clearRect(0, 0, width, height); ctx.fillStyle = '#E7ECD9'; ctx.fillRect(0, 0, width, height);
    if (state) {
      const alpha = clamp((now - arrived) / 100, 0, 1), players = state.players.map(p => interpolate(previous.get(p.id), p, alpha));
      const own = players.find(p => p.id === ownID), alive = players.filter(p => p.alive), cells = flattenCells(alive);
      if (own) {
        const frame = cameraFrame(width, height, own, cameraInsets);
        camera = { x: frame.x, y: frame.y }; viewCenter = { x: frame.screenX, y: frame.screenY };
        zoom = easeZoom(zoom, frame.zoom, dt);
      }
      ctx.save(); ctx.translate(viewCenter.x, viewCenter.y); ctx.scale(zoom, zoom); ctx.translate(-camera.x, -camera.y);
      ctx.fillStyle = '#EDF1E3'; roundedRect(ctx, 0, 0, state.width, state.height, 30 / zoom); ctx.fill();
      const left = Math.max(0, camera.x - viewCenter.x / zoom), top = Math.max(0, camera.y - viewCenter.y / zoom), right = Math.min(state.width, camera.x + (width - viewCenter.x) / zoom), bottom = Math.min(state.height, camera.y + (height - viewCenter.y) / zoom);
      drawGarden(left, top, right, bottom);
      ctx.strokeStyle = '#263E3109'; ctx.lineWidth = 1 / zoom; ctx.beginPath();
      for (let x = Math.floor(left / 90) * 90; x <= right; x += 90) { ctx.moveTo(x, top); ctx.lineTo(x, bottom); }
      for (let y = Math.floor(top / 90) * 90; y <= bottom; y += 90) { ctx.moveTo(left, y); ctx.lineTo(right, y); } ctx.stroke();
      ctx.strokeStyle = '#263E312E'; ctx.lineWidth = 3 / zoom; ctx.setLineDash([6 / zoom, 8 / zoom]); roundedRect(ctx, 0, 0, state.width, state.height, 30 / zoom); ctx.stroke(); ctx.setLineDash([]);
      const time = reducedMotion.matches ? 0 : now / 1000;
      for (const [id, landedX, landedY, value] of state.food) {
        const flight = value === 4 && !reducedMotion.matches ? spits.get(id) : null;
        const { x, y } = flight && now - flight.t0 < 450 ? spitFlight(flight.x, flight.y, landedX, landedY, (now - flight.t0) / 1000) : { x: landedX, y: landedY };
        if (x < left - 15 || x > right + 15 || y < top - 15 || y > bottom + 15) continue;
        if (value === 4) { drawDroplet(ctx, x, y, 6); continue; }
        const bonus = value >= 9, r = bonus ? 8 : 5;
        ctx.fillStyle = bonus ? '#F1C9B4' : ['#A6BF70', '#D1BC74', '#A4B8A0'][id % 3];
        ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
        if (bonus) { ctx.strokeStyle = '#F1C9B459'; ctx.lineWidth = 2 / zoom; ctx.beginPath(); ctx.arc(x, y, r + 2 / zoom, 0, Math.PI * 2); ctx.stroke(); }
      }
      const streams = new Map();
      for (const cell of cells) if (cell.drain > 0) { const field = hazardFor(cell, state.hazards); if (field) streams.set(field, [...streams.get(field) || [], cell]); }
      for (const [index, h] of state.hazards.entries()) {
        if (h.x + h.r * 1.2 < left || h.x - h.r * 1.2 > right || h.y + h.r * 1.2 < top || h.y - h.r * 1.2 > bottom) continue;
        const draining = streams.get(h) || [], nearest = cells.reduce((best, cell) => { const d = Math.hypot(cell.x - h.x, cell.y - h.y); return d < h.r + 320 && d < (best?.d ?? Infinity) ? { cell, d } : best; }, null);
        const look = nearest ? direction(nearest.cell.x - h.x, nearest.cell.y - h.y) : { x: 0, y: 0 };
        drawHazard(ctx, h, { kind: hazardKind(h, index), time, hungry: draining.length > 0, lookX: look.x, lookY: look.y, droplets: draining.flatMap(cell => drainDroplets(cell, h, time)) });
      }
      const visiblePlayers = [], latest = new Map(state.players.map(player => [player.id, player]));
      const danger = new Map(own?.alive ? killRings(alive, ownID).map(ring => [cellKey(ring.ownerID, ring.cellID), ring.alpha]) : []);
      const bodies = [];
      for (const p of cells.sort((a, b) => a.mass - b.mass)) {
        const r = radius(p.mass); if (p.x + r < left - 60 || p.x - r > right + 60 || p.y + r < top - 60 || p.y - r > bottom + 60) continue;
        const key = cellKey(p.ownerID, p.id), m = resizeMembrane(membranes.get(key), membraneSize(r * zoom));
        membranes.set(key, m); bodies.push({ p, r, x: p.x, y: p.y, shape: bodyShape(p, r), m });
      }
      membraneClock = Math.min(membraneClock + dt, 4 / 60);
      for (; membraneClock >= 1 / 60; membraneClock -= 1 / 60) {
        for (const body of bodies) {
          const reach = Math.max(body.shape.hw, body.shape.hh);
          const near = bodies.filter(other => other !== body && Math.hypot(other.x - body.x, other.y - body.y) < reach + Math.max(other.shape.hw, other.shape.hh) + 8);
          stepMembrane(body.m, body, near, { width: state.width, height: state.height }, { jitter: reducedMotion.matches ? 0 : undefined });
        }
      }
      for (const { p, r, shape, m } of bodies) {
        p.threatened = threatened.has(cellKey(p.ownerID, p.id));
        const before = previous.get(p.ownerID), after = latest.get(p.ownerID);
        const heading = before && after ? direction((after.x - before.x) / 4, (after.y - before.y) / 4) : { x: 0, y: 0 };
        p.lookX = heading.x; p.lookY = heading.y; p.danger = danger.get(cellKey(p.ownerID, p.id)) || 0; p.outline = membraneOutline(shape, m);
        drawPickle(ctx, p, p.x, p.y, r, time, p.ownerID === ownID, zoom);
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
  map.fillStyle = '#D5DEE1'; map.strokeStyle = '#263E3199'; map.lineWidth = .8;
  for (const h of state.hazards) { map.beginPath(); map.roundRect(h.x / state.width * 160 - 3, h.y / state.height * 120 - 3, 6, 6, 1.5); map.fill(); map.stroke(); }
  for (const p of players) { map.fillStyle = p.ownerID === ownID ? '#263E31' : '#F1C9B4'; map.beginPath(); map.arc(p.x / state.width * 160, p.y / state.height * 120, p.ownerID === ownID ? 3.5 : 2, 0, Math.PI * 2); map.fill(); }
  if (own?.alive) { map.strokeStyle = '#405c3480'; map.lineWidth = .6; map.strokeRect((camera.x - viewCenter.x / zoom) / state.width * 160, (camera.y - viewCenter.y / zoom) / state.height * 120, width / zoom / state.width * 160, height / zoom / state.height * 120); }
}
refreshLobby(); updateSound(); resize(); requestAnimationFrame(render);
if (resumeSession) restoreStoredRun();
else if (storedResume) {
  $('lobby').hidden = true; $('game').hidden = false; document.body.style.overflow = 'hidden';
  endRecovery('Your previous reconnect window has ended. Start a fresh run when you’re ready.'); resize();
}
