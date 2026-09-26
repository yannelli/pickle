const { test } = require('node:test');
const assert = require('node:assert/strict');
const { webcrypto } = require('node:crypto');
const fs = require('node:fs');
const vm = require('node:vm');
const saves = require('../save-codec.js');
const source = fs.readFileSync(require.resolve('../save-codec.js'), 'utf8');
const pet = { version: 1, fullness: 83.25, happiness: 71.75, energy: 44.5, hygiene: 90,
  ageTicks: 1200, neglect: 0, sleeping: true, sick: false, dead: false, updatedAt: 1789498800000 };
let fixture;
const backup = () => fixture ||= saves.encode(pet);
function freshClient(crypto) {
  const sandbox = { TextEncoder, TextDecoder, btoa, atob, crypto };
  vm.runInNewContext(source, sandbox);
  return sandbox.LittleDillSaves;
}

test('backup round-trips every field with no password and no plaintext stats', async () => {
  const raw = await backup();
  assert.ok(Buffer.byteLength(raw) < saves.MAX_FILE_BYTES);
  assert.ok(!raw.includes('fullness'));
  const restored = await saves.decode(raw);
  assert.deepEqual(restored.pet, pet);
  assert.ok(restored.savedAt > 0 && restored.savedAt <= Date.now());
});

test('a fresh client can open the same file without any local state or credentials', async () => {
  const fresh = freshClient(webcrypto);
  const restored = await fresh.decode(await backup());
  assert.deepEqual(JSON.parse(JSON.stringify(restored.pet)), pet);
});

test('export snapshots the pet before asynchronous encryption', async () => {
  const mutable = { ...pet };
  const encoded = saves.encode(mutable);
  mutable.fullness = 0;
  assert.deepEqual((await saves.decode(await encoded)).pet, pet);
});

test('each export has a fresh IV and ciphertext', async () => {
  const first = JSON.parse(await backup());
  const second = JSON.parse(await saves.encode(pet));
  for (const key of ['iv', 'data']) assert.notEqual(first[key], second[key]);
});

test('native progress survives iOS to web to iOS with a separate snapshot', async () => {
  const native = { coins: 42, outfit: 'crown', unlocked: ['crown'], arcade: { hop: 12, hunt: 3 },
    arcadeCircuit: { day: '2026-09-25', scores: { hop: 12, chop: 30, toss: 8 } },
    arenaEarnings: { day: '2026-09-25', mass: 123456.7, session: 'public-1:player', total: 123456.7 } };
  const first = saves.encode(pet, native);
  native.coins = 0;
  const imported = await saves.decode(await first);
  assert.equal(imported.native.coins, 42);
  imported.pet.fullness = 95;
  const exported = await saves.decode(await saves.encode(imported.pet, imported.native));
  assert.equal(exported.pet.fullness, 95);
  assert.deepEqual(exported.native, imported.native);
  assert.equal(exported.native.arcadeCircuit.scores.toss, 8);
});

test('plain web backups omit native defaults and oversized extras remain readable or fail', async () => {
  assert.equal(Object.hasOwn(await saves.decode(await saves.encode(pet)), 'native'), false);
  const extras = { coins: 40, scores: Array(500).fill({ d: '2026-09-25', s: 100, t: 1800000000000 }), rewardedDays: Array(100).fill('2026-09-25') };
  const compact = await saves.decode(await saves.encode(pet, extras));
  assert.equal(compact.native.coins, 40);
  assert.deepEqual(compact.native.scores, []);
  assert.equal(compact.native.rewardedDays.length, 7);
  await assert.rejects(saves.encode(pet, { custom: 'a'.repeat(5000) }), /download could not/);
});

test('altered ciphertext or IV fail authentication', async () => {
  const raw = await backup();
  for (const field of ['data', 'iv']) {
    const changed = JSON.parse(raw);
    const bytes = Buffer.from(changed[field], 'base64');
    bytes[Math.floor(bytes.length / 2)] ^= 1;
    changed[field] = bytes.toString('base64');
    await assert.rejects(saves.decode(JSON.stringify(changed)), /changed or damaged/);
  }
});

test('rejects plaintext, malformed, oversized and unsupported saves before decryption', async () => {
  await assert.rejects(saves.decode('not json'), /not a readable/);
  await assert.rejects(saves.decode(JSON.stringify(pet)), /not supported/);
  await assert.rejects(saves.decode('x'.repeat(saves.MAX_FILE_BYTES + 1)), /too large/);
  await assert.rejects(saves.decode('🥒'.repeat(5000)), /too large/);
  const envelope = JSON.parse(await backup());
  for (const changes of [{ version: 2 }, { iterations: 1e9 }, { cipher: 'AES-CBC' }, { format: 'other-game' }]) {
    await assert.rejects(saves.decode(JSON.stringify({ ...envelope, ...changes })), /not supported/);
  }
  for (const changes of [{ iv: 'bad!' }, { iv: '' }, { data: 'AA==' }, { iv: Buffer.alloc(16).toString('base64') }]) {
    await assert.rejects(saves.decode(JSON.stringify({ ...envelope, ...changes })), /damaged or incomplete/);
  }
});

test('strictly validates stats, age, timestamps and life flags', () => {
  for (const changes of [{ fullness: 101 }, { energy: -1 }, { happiness: NaN }, { hygiene: Infinity },
    { ageTicks: 1.5 }, { ageTicks: 1e10 }, { neglect: 61 }, { neglect: -1 },
    { updatedAt: 1e100 }, { updatedAt: -1 }, { dead: 'false' }, { dead: true, sleeping: true }, { version: 2 }]) {
    assert.throws(() => saves.validateState({ ...pet, ...changes }), /invalid pickle progress/);
  }
  assert.deepEqual(saves.validateState({ ...pet, extra: '<script>alert(1)</script>' }), pet);
  assert.deepEqual(saves.validateState({ ...pet, dead: true, sleeping: false }), { ...pet, dead: true, sleeping: false });
});

test('authenticated but invalid payloads are rejected after decryption', async () => {
  for (const payload of [{ version: 1, savedAt: Date.now(), pet: { ...pet, fullness: 999 } },
    { version: 1, savedAt: -1, pet }, { version: 2, savedAt: Date.now(), pet }]) {
    const invalidProducer = freshClient({
      getRandomValues: bytes => webcrypto.getRandomValues(bytes),
      subtle: {
        importKey: (...args) => webcrypto.subtle.importKey(...args),
        encrypt: (algorithm, key) => webcrypto.subtle.encrypt(algorithm, key, new TextEncoder().encode(JSON.stringify(payload)))
      }
    });
    await assert.rejects(saves.decode(await invalidProducer.encode(pet)), /invalid pickle progress/);
  }
});

test('insecure browsers get a useful error', async () => {
  const insecure = freshClient(undefined);
  assert.equal(insecure.available(), false);
  await assert.rejects(insecure.encode(pet), /HTTPS or localhost/);
});
