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
  // Each track owns its arrangement: drum grid, bass style, chord style, lead voice and form.
  const TRACKS = [
    {
      name: 'Brine Time', bpm: 132, chords: CHORDS, lead: LEAD,
      bass: [0, 3, 6, 8, 10, 14], bassStyle: 'walk', bassVoice: 'triangle',
      kick: [0, 6, 8], snare: [4, 12], hats: 1, open: [14],
      pad: 'arp', padVoice: 'square', voice: 'square', leadLength: 1.35, leadLevel: .072, echo: true, swing: .012
    },
    {
      name: 'Dill Disco', bpm: 120,
      chords: [[48, 52, 55, 59], [45, 48, 52, 55], [53, 57, 60, 64], [55, 59, 62, 65]],
      lead: [
        [76, 0, 79, 81, 0, 79, 76, 0, 74, 76, 0, 79, 0, 72, 74, 0],
        [72, 0, 76, 79, 0, 76, 72, 0, 71, 72, 0, 76, 0, 69, 71, 0],
        [77, 0, 81, 84, 0, 81, 79, 0, 77, 79, 0, 81, 0, 76, 77, 0],
        [79, 0, 83, 86, 0, 83, 81, 0, 79, 77, 0, 74, 0, 71, 74, 0]
      ],
      bass: [0, 2, 4, 6, 8, 10, 12, 14], bassStyle: 'octave', bassVoice: 'sawtooth',
      kick: [0, 4, 8, 12], snare: [4, 12], hats: 2, open: [2, 6, 10, 14],
      pad: 'stab', stabs: [2, 6, 10, 14], padVoice: 'sawtooth', voice: 'square', leadLength: 1.1, leadLevel: .06, echo: false, swing: 0
    },
    {
      name: 'Moonlight Marinade', bpm: 88,
      chords: [[57, 60, 64, 67], [53, 57, 60, 64], [48, 52, 55, 59], [55, 59, 62, 65]],
      lead: [
        [81, 0, 0, 0, 79, 0, 76, 0, 0, 0, 72, 0, 76, 0, 0, 0],
        [77, 0, 0, 0, 76, 0, 72, 0, 0, 0, 69, 0, 72, 0, 0, 0],
        [76, 0, 0, 0, 74, 0, 71, 0, 0, 0, 67, 0, 71, 0, 0, 0],
        [74, 0, 0, 0, 71, 0, 69, 0, 0, 0, 67, 0, 71, 0, 74, 0]
      ],
      bass: [0, 8, 12], bassStyle: 'root', bassVoice: 'sine',
      kick: [], snare: [], hats: 4, open: [], hatLevel: .35,
      pad: 'hold', padVoice: 'sine', voice: 'sine', leadLength: 3.6, leadLevel: .11, echo: true, swing: .025
    },
    {
      name: 'Spicy Sprint', bpm: 156,
      chords: [[52, 55, 59, 62], [48, 52, 55, 59], [55, 59, 62, 66], [50, 54, 57, 60]],
      lead: [
        [76, 79, 83, 0, 88, 0, 83, 79, 76, 0, 79, 83, 86, 83, 79, 0],
        [76, 79, 84, 0, 88, 0, 84, 79, 76, 0, 79, 84, 83, 79, 76, 0],
        [79, 83, 86, 0, 90, 0, 86, 83, 79, 0, 83, 86, 88, 86, 83, 0],
        [78, 81, 86, 0, 90, 0, 86, 81, 78, 0, 76, 78, 81, 78, 75, 0]
      ],
      bass: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], bassStyle: 'pulse', bassVoice: 'triangle',
      kick: [0, 6, 8, 10], snare: [4, 12, 15], hats: 2, open: [14],
      pad: 'stab', stabs: [0, 3, 8, 11], padVoice: 'square', voice: 'sawtooth', leadLength: 1.1, leadLevel: .04, echo: false, swing: 0
    }
  ];
  // Bars of intro before the lead enters; a track switch skips it so the hook plays right away.
  const INTRO = 4;
  const validTrack = value => Number.isInteger(value) && value >= 0 && value < TRACKS.length;

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

  const BASS_OFFSETS = {
    walk: beat => beat === 6 || beat === 14 ? 12 : beat === 10 ? 7 : 0,
    octave: beat => beat % 4 === 2 ? 12 : 0,
    root: beat => beat === 12 ? 7 : 0,
    pulse: beat => [0, 0, 7, 0, 12, 0, 7, 10][beat % 8]
  };

  function musicStep(ctx, bus, voices, buffer, step, time, track = 0) {
    const song = TRACKS[track];
    const duration = 60 / song.bpm / 4;
    const bar = Math.floor(step / 16) % 32;
    const beat = step % 16;
    const chord = song.chords[bar % 4];
    const breakdown = bar >= 16 && bar < 20;
    const drop = bar >= 20;
    const at = time + (beat % 2 ? song.swing : 0);
    const note = (pitch, length, volume, type = song.voice, slide) => tone(ctx, bus, voices, pitch, at, length * duration, volume, type, slide);
    const hit = (length, volume, cutoff) => noise(ctx, bus, voices, buffer, at, length, volume, cutoff);
    const drums = !breakdown || beat === 0;

    if (song.bass.includes(beat)) {
      const pitch = chord[0] - 12 + BASS_OFFSETS[song.bassStyle](beat);
      if (song.bassStyle === 'walk') note(pitch, beat === 0 || beat === 8 ? 2.8 : 1.5, .25, song.bassVoice);
      else if (song.bassStyle === 'octave') note(pitch, 1.6, .09, song.bassVoice);
      else if (song.bassStyle === 'root') note(pitch, beat === 12 ? 3.5 : 7.5, .3, song.bassVoice);
      else note(pitch, .85, .24, song.bassVoice);
      if (drop && song.bassStyle !== 'root') note(pitch + 12, .7, .025);
    }

    if (song.pad === 'arp' && beat % 2 === 0) note(chord[(beat / 2 + Math.floor(bar / 4)) % 4] + 12, .7, breakdown ? .065 : .035, song.padVoice);
    if (song.pad === 'stab' && song.stabs.includes(beat)) {
      for (const pitch of chord) note(pitch + 12, breakdown ? 2.4 : 1.1, breakdown ? .03 : .018, song.padVoice);
    }
    if (song.pad === 'hold' && beat === 0) {
      for (const pitch of chord) note(pitch + 12, 15.5, breakdown ? .045 : .03, song.padVoice);
    }

    if (drums) {
      if (song.kick.includes(beat) || (drop && beat === 11 && song.kick.length)) note(47, 1.7, .45, 'sine', 22);
      if (song.snare.includes(beat)) { hit(.12, .16, 1300); note(43, .7, .13, 'triangle'); }
      const level = song.hatLevel ?? 1;
      if (song.open.includes(beat)) hit(.09, .065 * level, 6500);
      else if (beat % song.hats === 0) hit(.028, (beat % 2 ? .035 : .065) * level, 6500);
      if (song.kick.length && bar % 8 === 7 && beat >= 13) hit(.065, .09, 1900);
    }

    if (bar >= INTRO && !breakdown) {
      const pitch = song.lead[bar % 4][beat];
      if (pitch) {
        note(pitch, song.leadLength, song.leadLevel);
        // A quiet, offbeat echo leaves space around the hook.
        if (song.echo) tone(ctx, bus, voices, pitch, at + duration * 3, duration * (song.leadLength > 2 ? 2 : 1), song.leadLevel / 4, song.voice);
        if (drop && beat % 4 === 0) note(pitch + 12, 2.5, .022, 'triangle');
      }
    }
  }

  function create() {
    const KEY = 'little-dill.audio.v1';
    let prefs = { music: true, sfx: true, volume: .45, track: 0 };
    try {
      const stored = JSON.parse(root.localStorage.getItem(KEY));
      if (stored) prefs = { music: stored.music !== false, sfx: stored.sfx !== false, track: validTrack(stored.track) ? stored.track : 0,
        volume: Number.isFinite(stored.volume) ? Math.max(0, Math.min(1, stored.volume)) : .45 };
    } catch { /* Sound preferences are optional. */ }
    let ctx, master, music, effects, buffer, timer, next = 0, step = 0, cue = 0;
    let songBus, retired = [];
    let active = true, resting = false;
    const musicVoices = new Set(), effectVoices = new Set();
    const persist = () => { try { root.localStorage.setItem(KEY, JSON.stringify(prefs)); } catch { /* Keep playing. */ } };
    function reap() {
      retired = retired.filter(run => run.until > ctx.currentTime || (run.bus.disconnect(), false));
    }
    // Fade the current run out over ~60ms instead of cutting every voice, which clicked.
    function stopMusic() {
      clearInterval(timer); timer = null;
      if (songBus) {
        const at = ctx.currentTime;
        songBus.gain.setTargetAtTime(0, at, .012);
        for (const voice of musicVoices) { try { voice.stop(at + .08); } catch { /* Already ended. */ } }
        retired.push({ bus: songBus, until: at + .12 }); songBus = null;
      }
      musicVoices.clear();
    }
    function startMusic() {
      if (!ctx || ctx.state !== 'running' || !active || !prefs.music || timer) return;
      reap();
      songBus = ctx.createGain(); songBus.connect(music);
      next = ctx.currentTime + .04; step = cue; cue = 0;
      const bus = songBus;
      const schedule = () => {
        if (ctx.state !== 'running') return;
        reap();
        if (next < ctx.currentTime) next = ctx.currentTime + .02;
        while (next < ctx.currentTime + .15) {
          musicStep(ctx, bus, musicVoices, buffer, step++, next, prefs.track);
          next += 60 / TRACKS[prefs.track].bpm / 4;
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
      const previousTrack = prefs.track;
      prefs = { ...prefs, ...changes };
      if (!validTrack(prefs.track)) prefs.track = previousTrack;
      persist();
      if (prefs.track !== previousTrack) { cue = INTRO * 16; if (ctx) stopMusic(); }
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
        catch: [77, 81], shuffle: [55, 58], select: [74], blocked: [50, 48], crunch: [45, 41, 38]
      };
      (riffs[name] || riffs.select).forEach((note, index) => {
        tone(ctx, effects, effectVoices, note, now + index * .075, .12, .11, name === 'feed' ? 'triangle' : 'square');
      });
      if (name === 'clean') noise(ctx, effects, effectVoices, buffer, now, .22, .1, 3500);
      if (name === 'crunch') noise(ctx, effects, effectVoices, buffer, now, .14, .16, 900);
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

  const api = Object.freeze({ create, musicStep, makeNoise, STEP, TRACKS });
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.LittleDillAudio = api;
})(globalThis);
