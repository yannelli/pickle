const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const source = fs.readFileSync(require.resolve('../audio.js'), 'utf8');

function client(options = {}) {
  const intervals = new Map(), contexts = [], nodes = [];
  let saved = options.saved || null, timerId = 0;
  class Param {
    constructor() { this.value = 0; }
    setValueAtTime(value) { this.value = value; }
    linearRampToValueAtTime(value) { this.value = value; }
    exponentialRampToValueAtTime(value) { this.value = value; }
    setTargetAtTime(value) { this.value = value; }
  }
  function node() {
    const value = { gain: new Param(), frequency: new Param(), connect() {}, disconnect() {},
      start(time) { this.started = time; }, stop() { this.stopped = true; this.onended?.(); } };
    nodes.push(value); return value;
  }
  class AudioContext {
    constructor() { this.state = 'suspended'; this.sampleRate = 44100; this.currentTime = 0; this.destination = {}; contexts.push(this); }
    async resume() { this.state = 'running'; this.onstatechange?.(); }
    async suspend() { this.state = 'suspended'; this.onstatechange?.(); }
    createGain() { return node(); }
    createOscillator() { return node(); }
    createBufferSource() { return node(); }
    createBiquadFilter() { return node(); }
    createDynamicsCompressor() { return { threshold: new Param(), knee: new Param(), ratio: new Param(), connect() {} }; }
    createBuffer(channels, size) { const data = new Float32Array(size); return { getChannelData: () => data }; }
  }
  const sandbox = { AudioContext: options.unavailable ? undefined : AudioContext,
    localStorage: { getItem: () => saved, setItem: (key, value) => { if (options.blocked) throw Error('storage blocked'); saved = value; } },
    setInterval: fn => { const id = ++timerId; intervals.set(id, fn); return id; }, clearInterval: id => intervals.delete(id) };
  vm.runInNewContext(source, sandbox);
  return { engine: sandbox.LittleDillAudio.create(), contexts, nodes, intervals, saved: () => JSON.parse(saved) };
}

test('audio unlock is lazy and repeated gestures share one context and one music clock', async () => {
  const app = client();
  assert.equal(app.contexts.length, 0);
  await Promise.all([app.engine.unlock(), app.engine.unlock(), app.engine.unlock()]);
  assert.equal(app.contexts.length, 1);
  assert.equal(app.intervals.size, 1);
  app.engine.setActive(false); assert.equal(app.intervals.size, 0);
  assert.equal(app.contexts[0].state, 'suspended');
  app.engine.setActive(true); await Promise.resolve();
  assert.equal(app.intervals.size, 1);
});

test('music and effects mute independently and volume zero survives reload', async () => {
  const app = client(); await app.engine.unlock();
  app.engine.configure({ music: false, volume: 0 });
  assert.equal(app.intervals.size, 0);
  assert.equal(app.saved().volume, 0);
  const count = app.nodes.length;
  await app.engine.play('win'); assert.ok(app.nodes.length > count);
  app.engine.configure({ sfx: false });
  const muted = app.nodes.length;
  await app.engine.play('win'); assert.equal(app.nodes.length, muted);
  app.engine.configure({ music: true }); assert.equal(app.intervals.size, 1);
  const restored = client({ saved: JSON.stringify(app.saved()) });
  assert.equal(restored.engine.preferences.volume, 0);
  assert.equal(restored.engine.preferences.sfx, false);
});

test('hidden audio refuses new effects; interrupted contexts recover without duplicate clocks', async () => {
  const app = client(); await app.engine.unlock();
  app.engine.setActive(false);
  const count = app.nodes.length;
  await app.engine.play('pet'); assert.equal(app.nodes.length, count);
  app.engine.setActive(true); await Promise.resolve();
  app.contexts[0].state = 'interrupted'; app.contexts[0].onstatechange();
  assert.equal(app.intervals.size, 0);
  await app.engine.unlock(); assert.equal(app.intervals.size, 1);
});

test('unavailable audio and blocked storage never prevent gameplay', async () => {
  const missing = client({ unavailable: true });
  assert.equal(await missing.engine.unlock(), false);
  await missing.engine.play('pet'); missing.engine.configure({ music: false });
  const blocked = client({ blocked: true, saved: '{bad json' });
  await blocked.engine.unlock(); blocked.engine.configure({ sfx: false });
  assert.equal(blocked.engine.preferences.sfx, false);
});
