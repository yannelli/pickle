const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('piece loss shows sadness over danger until the server timer expires', async () => {
  const { faceMood } = await import('../arena-web/arena-core.mjs');
  assert.equal(faceMood({ hurt: 2.4, drain: 1, threatened: true, dash: .5 }), 'sad');
  assert.equal(faceMood({ hurt: .1 }), 'sad');
  assert.equal(faceMood({ hurt: 0 }), 'calm');
  assert.equal(faceMood({ hurt: 0, threatened: true }), 'threatened');
  assert.equal(faceMood({ hurt: 2, alive: false }), 'calm');
  assert.equal(faceMood({}), 'calm');
});

test('every skin draws a distinct mouth and unknown skins keep the default', async () => {
  const { SMILES, skinSmile, drawSmile } = await import('../arena-web/arena-expression.mjs');
  const shapes = Object.keys(SMILES).map(variety => {
    const calls = [];
    const context = new Proxy({ lineWidth: 1 }, {
      get: (target, key) => key in target ? target[key] : (...args) => calls.push([key, ...args]),
      set: (target, key, value) => { target[key] = value; return true; }
    });
    drawSmile(context, variety, 60);
    return JSON.stringify(calls);
  });
  assert.equal(new Set(shapes).size, 6);
  assert.equal(skinSmile('unreleased'), skinSmile('dill'));
});

test('dense food collection stays quiet and does not queue delayed pickup sounds', async () => {
  const { pickupCue } = await import('../arena-web/arena-expression.mjs');
  const heard = [];
  let previous = null;
  for (let frame = 0; frame < 600; frame++) {
    const cue = pickupCue(previous, frame / 60);
    if (cue) { heard.push(cue); previous = cue; }
  }
  assert.ok(heard.length >= 20 && heard.length <= 26);
  assert.ok(heard.slice(5).every(cue => cue.volume < heard[0].volume));
  assert.deepEqual(heard.slice(0, 5).map(cue => cue.index), [0, 1, 2, 3, 0]);
  assert.equal(pickupCue(previous, 20).volume, .7);
});

test('web and iOS use identical soft pickup recordings', () => {
  const hashes = new Set();
  for (let index = 0; index < 4; index++) {
    const filename = `arena-pickup-${index}.wav`;
    const web = fs.readFileSync(path.join(__dirname, '../arena-web/audio', filename));
    const native = fs.readFileSync(path.join(__dirname, '../ios/LittleDill/Audio', filename));
    assert.deepEqual(web, native);
    assert.equal(web.toString('ascii', 0, 4), 'RIFF');
    assert.equal(web.readUInt32LE(24), 24000);
    const pcm = Array.from({ length: (web.length - 44) / 2 }, (_, n) => web.readInt16LE(44 + n * 2) / 32768);
    const peak = Math.max(...pcm.map(Math.abs));
    assert.ok(peak > .01 && peak < .05);
    assert.equal(pcm[0], 0);
    assert.ok(Math.abs(pcm.at(-1)) < .0001);
    hashes.add(require('node:crypto').createHash('sha256').update(web).digest('hex'));
  }
  assert.equal(hashes.size, 4);
});
