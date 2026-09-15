(function (root) {
  'use strict';

  const STEP = 60 / 132 / 4;
  const frequency = note => 440 * 2 ** ((note - 69) / 12);
  // Brine Time: an original 32-bar loop in D minor. A sparse intro opens into
  // syncopated bass + a pulse lead, breaks down, then returns with a high harmony.
  const CHORDS = [[50, 53, 57, 60], [46, 50, 53, 57], [53, 57, 60, 64], [48, 52, 55, 58]];
  const LEAD = [
    [74, 0, 77, 0, 81, 79, 77, 0, 74, 0, 72, 74, 0, 77, 0, 72],
    [70, 0, 74, 77, 0, 74, 0, 72, 70, 0, 69, 70, 0, 74, 77, 0],
    [72, 0, 77, 0, 81, 0, 84, 81, 79, 0, 77, 79, 0, 81, 0, 77],
    [79, 0, 76, 0, 72, 74, 76, 0, 79, 0, 82, 79, 0, 76, 72, 73]
  ];

  function tone(ctx, bus, voices, note, time, duration, volume, type = 'square', slide) {
    const oscillator = ctx.createOscillator();
    const envelope = ctx.createGain();
    oscillator.type = type;
    oscillator.frequency.setValueAtTime(frequency(note), time);
    if (slide !== undefined) oscillator.frequency.exponentialRampToValueAtTime(frequency(slide), time + duration);
    envelope.gain.setValueAtTime(0, time);
    envelope.gain.linearRampToValueAtTime(volume, time + .004);
    envelope.gain.linearRampToValueAtTime(volume * .55, time + duration * .55);
    envelope.gain.exponentialRampToValueAtTime(.0001, time + duration);
    oscillator.connect(envelope); envelope.connect(bus);
    voices.add(oscillator);
    oscillator.onended = () => { voices.delete(oscillator); oscillator.disconnect(); envelope.disconnect(); };
    oscillator.start(time); oscillator.stop(time + duration + .015);
  }

  function noise(ctx, bus, voices, buffer, time, duration, volume, cutoff) {
    const source = ctx.createBufferSource();
    const filter = ctx.createBiquadFilter();
    const envelope = ctx.createGain();
    source.buffer = buffer;
    filter.type = 'highpass'; filter.frequency.value = cutoff;
    envelope.gain.setValueAtTime(volume, time);
    envelope.gain.exponentialRampToValueAtTime(.0001, time + duration);
    source.connect(filter); filter.connect(envelope); envelope.connect(bus);
    voices.add(source);
    source.onended = () => { voices.delete(source); source.disconnect(); filter.disconnect(); envelope.disconnect(); };
    source.start(time); source.stop(time + duration);
  }

  function makeNoise(ctx) {
    const buffer = ctx.createBuffer(1, ctx.sampleRate * .3, ctx.sampleRate);
    const data = buffer.getChannelData(0);
    let seed = 12345;
    for (let i = 0; i < data.length; i++) {
      seed ^= seed << 13; seed ^= seed >>> 17; seed ^= seed << 5;
      data[i] = (seed >>> 0) / 2147483648 - 1;
    }
    return buffer;
  }

  function musicStep(ctx, bus, voices, buffer, step, time) {
    const bar = Math.floor(step / 16) % 32;
    const beat = step % 16;
    const chord = CHORDS[bar % 4];
    const breakdown = bar >= 16 && bar < 20;
    const drop = bar >= 20;
    const at = time + (beat % 2 ? .012 : 0);
    const note = (pitch, length, volume, type = 'square', slide) => tone(ctx, bus, voices, pitch, at, length * STEP, volume, type, slide);
    if ([0, 3, 6, 8, 10, 14].includes(beat)) {
      const pitch = chord[0] - 12 + (beat === 6 || beat === 14 ? 12 : beat === 10 ? 7 : 0);
      note(pitch, beat === 0 || beat === 8 ? 2.8 : 1.5, .25, 'triangle');
      if (drop) note(pitch + 12, .7, .025);
    }
    if (beat % 2 === 0) note(chord[(beat / 2 + Math.floor(bar / 4)) % 4] + 12, .7, breakdown ? .065 : .035);
    if (!breakdown || beat === 0) {
      if ([0, 6, 8].includes(beat) || (drop && beat === 11)) note(47, 1.7, .45, 'sine', 22);
      if (beat === 4 || beat === 12) {
        noise(ctx, bus, voices, buffer, at, .12, .16, 1300);
        note(43, .7, .13, 'triangle');
      }
      noise(ctx, bus, voices, buffer, at, beat === 14 ? .09 : .028, beat % 2 ? .035 : .065, 6500);
      if (bar % 8 === 7 && beat >= 13) noise(ctx, bus, voices, buffer, at, .065, .09, 1900);
    }
    if (bar >= 4 && !breakdown) {
      const pitch = LEAD[bar % 4][beat];
      if (pitch) {
        note(pitch, 1.35, .072);
        // A quiet, offbeat echo leaves space around the hook.
        tone(ctx, bus, voices, pitch, at + STEP * 3, STEP, .018);
        if (drop && beat % 4 === 0) note(pitch + 12, 2.5, .022, 'triangle');
      }
    }
  }

  function create() {
    const KEY = 'little-dill.audio.v1';
    let prefs = { music: true, sfx: true, volume: .45 };
    try {
      const stored = JSON.parse(root.localStorage.getItem(KEY));
      if (stored) prefs = { music: stored.music !== false, sfx: stored.sfx !== false,
        volume: Number.isFinite(stored.volume) ? Math.max(0, Math.min(1, stored.volume)) : .45 };
    } catch { /* Sound preferences are optional. */ }
    let ctx, master, music, effects, buffer, timer, next = 0, step = 0;
    let active = true, resting = false;
    const musicVoices = new Set(), effectVoices = new Set();
    const persist = () => { try { root.localStorage.setItem(KEY, JSON.stringify(prefs)); } catch { /* Keep playing. */ } };
    function stopMusic() {
      clearInterval(timer); timer = null;
      for (const voice of musicVoices) { try { voice.stop(); } catch { /* Already ended. */ } }
      musicVoices.clear();
    }
    function startMusic() {
      if (!ctx || ctx.state !== 'running' || !active || !prefs.music || timer) return;
      next = ctx.currentTime + .04; step = 0;
      const schedule = () => {
        if (ctx.state !== 'running') return;
        if (next < ctx.currentTime) next = ctx.currentTime + .02;
        while (next < ctx.currentTime + .15) {
          musicStep(ctx, music, musicVoices, buffer, step++, next);
          next += STEP;
        }
      };
      schedule(); timer = setInterval(schedule, 25);
    }
    async function unlock() {
      try {
        const Audio = root.AudioContext || root.webkitAudioContext;
        if (!Audio || !active) return false;
        if (!ctx) {
          ctx = new Audio();
          master = ctx.createGain(); music = ctx.createGain(); effects = ctx.createGain();
          const limiter = ctx.createDynamicsCompressor();
          limiter.threshold.value = -8; limiter.knee.value = 12; limiter.ratio.value = 8;
          master.gain.value = prefs.volume;
          music.gain.value = resting ? .32 : .7;
          effects.gain.value = prefs.sfx ? .7 : 0;
          music.connect(master); effects.connect(master); master.connect(limiter); limiter.connect(ctx.destination);
          buffer = makeNoise(ctx);
          ctx.onstatechange = () => { if (ctx.state === 'running') startMusic(); else stopMusic(); };
        }
        if (ctx.state !== 'running') await ctx.resume();
        startMusic(); return ctx.state === 'running';
      } catch { return false; }
    }
    function configure(changes) {
      prefs = { ...prefs, ...changes }; persist();
      if (!ctx) return;
      master.gain.setTargetAtTime(prefs.volume, ctx.currentTime, .02);
      effects.gain.setTargetAtTime(prefs.sfx ? .7 : 0, ctx.currentTime, .01);
      if (prefs.music) startMusic(); else stopMusic();
    }
    async function play(name, pitch = 0) {
      if (!prefs.sfx || !active) return;
      if (!await unlock() || !prefs.sfx || !active) return;
      const now = ctx.currentTime + .01;
      const riffs = {
        feed: [55, 62, 67], clean: [79, 86, 91], pet: [74, 77, 81],
        sleep: [74, 69, 62], wake: [62, 69, 74], start: [62, 65, 69, 74],
        win: [74, 77, 81, 86], miss: [62, 60], tap: [72 + pitch * 4],
        catch: [77, 81], shuffle: [55, 58], select: [74], blocked: [50, 48]
      };
      (riffs[name] || riffs.select).forEach((note, index) => {
        tone(ctx, effects, effectVoices, note, now + index * .075, .12, .11, name === 'feed' ? 'triangle' : 'square');
      });
      if (name === 'clean') noise(ctx, effects, effectVoices, buffer, now, .22, .1, 3500);
    }
    function setActive(value) {
      active = value;
      if (!ctx) return;
      if (active) { unlock(); }
      else {
        stopMusic();
        for (const voice of effectVoices) { try { voice.stop(); } catch { /* Already ended. */ } }
        effectVoices.clear();
        ctx.suspend().catch(() => {});
      }
    }
    function setResting(value) {
      if (resting === value) return;
      resting = value;
      if (music) music.gain.setTargetAtTime(resting ? .32 : .7, ctx.currentTime, .2);
    }
    return { unlock, play, configure, setActive, setResting, get preferences() { return { ...prefs }; } };
  }

  const api = Object.freeze({ create, musicStep, makeNoise, STEP });
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.LittleDillAudio = api;
})(globalThis);
