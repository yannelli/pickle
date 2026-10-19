const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const life = require('../pet-life.js');
const saves = require('../save-codec.js');
const fixture = require('./fixtures/pet-parity.json');
const NOW = 1800000000000, H = life.HOUR, D = life.DAY;
const DAY = '2027-01-15';
function living(changes = {}) {
  return { ...life.fresh(NOW), phase: 'living', name: 'Sir Crunch', bornAt: NOW - 3 * D, brinedAt: NOW - 3 * D - life.HATCH_MS, hatchAt: NOW - 3 * D, ...changes };
}
const roll = (pet, hour, changes = {}) => life.rollWish(pet, { now: NOW, day: DAY, hour, food: 'broccoli', ...changes });

test('the shared parity fixture matches pet-life.js', () => {
  assert.equal(fs.readFileSync(require.resolve('./fixtures/pet-parity.json'), 'utf8'), require('./generate-pet-parity.cjs').output,
    'run node tests/generate-pet-parity.cjs after changing a shared pet rule');
  assert.deepEqual(Object.keys(fixture.favorites), life.VARIETIES.map(variety => variety.id));
  for (const { food, game } of Object.values(fixture.favorites)) { assert.ok(life.FOODS.includes(food)); assert.ok(life.GAMES.includes(game)); }
  assert.deepEqual(new Set(Object.values(fixture.favorites).map(item => item.food)), new Set(life.FOODS), 'every food is somebody’s favorite');
});

test('wishes wait for a living, awake, named pickle outside quiet hours', () => {
  for (const hour of [0, 8, 22, 23]) assert.equal(roll(living(), hour), null, 'quiet hour ' + hour);
  assert.equal(roll(living({ sleeping: true }), 12), null);
  assert.equal(roll(living({ dead: true, diedAt: NOW }), 12), null);
  assert.equal(roll({ ...life.fresh(NOW), phase: 'naming' }, 12), null);
  const pet = living();
  const wish = roll(pet, 9);
  assert.ok(wish);
  assert.deepEqual(pet.wishes, { day: DAY, count: 1 });
  assert.equal(wish.expiresAt - wish.issuedAt, 6 * H);
  assert.deepEqual(roll(structuredClone(living()), 9), wish, 'the roll is deterministic');
});

test('a pickle makes at most two wishes a day, one at a time, the second after 3pm', () => {
  const pet = living();
  const first = roll(pet, 10);
  assert.equal(roll(pet, 16), null, 'an active wish blocks a new one');
  assert.deepEqual(pet.wish, first);
  pet.wish.expiresAt = NOW; // expired
  assert.equal(roll(pet, 14), null);
  assert.equal(pet.wish, undefined, 'expired wishes clear');
  const second = roll(pet, 15);
  assert.ok(second);
  assert.deepEqual(pet.wishes, { day: DAY, count: 2 });
  delete pet.wish;
  assert.equal(roll(pet, 18), null, 'the daily cap holds');
  assert.ok(roll(pet, 10, { day: '2027-01-16' }), 'a new local day reopens wishes');
  assert.equal(roll(living({ wishes: { day: '2027-01-16', count: 1 } }), 12), null, 'a clock rollback cannot reopen a day');
});

test('clean and nap wishes need a reason; feed wishes ask for the next rotation food; play names a shared game', () => {
  const kinds = new Set(), healthy = new Set();
  for (let i = 0; i < 40; i++) {
    const needy = living({ bornAt: NOW - 3 * D + i * 1000, hygiene: 50, energy: 30 });
    const wish = roll(needy, 11, { food: 'apple' });
    kinds.add(wish.kind);
    if (wish.kind === 'feed') assert.equal(wish.target, 'apple');
    else if (wish.kind === 'play') assert.ok(life.GAMES.includes(wish.target));
    else assert.equal(wish.target, '');
    healthy.add(roll(living({ bornAt: NOW - 3 * D + i * 1000 }), 11).kind);
  }
  assert.deepEqual([...kinds].sort(), ['clean', 'feed', 'nap', 'pet', 'play']);
  assert.deepEqual([...healthy].sort(), ['feed', 'pet', 'play'], 'hygiene 95 and energy 90 rule out clean and nap');
});

test('granting a wish adds 10 happiness once, records the first wish, and play needs the named game', () => {
  const pet = living({ happiness: 50, wish: { kind: 'play', target: 'hunt', issuedAt: NOW, expiresAt: NOW + 6 * H } });
  assert.equal(life.grantWish(pet, 'play', 'memory', NOW + H), null);
  assert.equal(life.grantWish(pet, 'feed', '', NOW + H), null);
  assert.equal(life.grantWish(pet, 'play', 'hunt', NOW + H), 10);
  assert.equal(pet.happiness, 60); assert.equal(pet.wish, undefined); assert.deepEqual(pet.events, { wish: NOW + H });
  assert.equal(life.grantWish(pet, 'play', 'hunt', NOW + H), null, 'a granted wish is gone');
  const late = living({ happiness: 95, events: { wish: NOW - D }, wish: { kind: 'feed', target: 'carrot', issuedAt: NOW, expiresAt: NOW + 6 * H } });
  assert.equal(life.grantWish(late, 'feed', '', NOW + 6 * H), null, 'expired wishes cannot be granted');
  late.wish.expiresAt = NOW + 7 * H - 1;
  late.wish.issuedAt = NOW + H;
  assert.equal(life.grantWish(late, 'feed', '', NOW + 2 * H), 5, 'feed wishes match by kind; happiness caps at 100');
  assert.deepEqual(late.events, { wish: NOW - D }, 'the first wish date stays');
});

test('the scrapbook derives stage dates and the elder album from bornAt', () => {
  const pet = living({ bornAt: NOW, hatchAt: NOW - 5000 });
  const ids = at => life.scrapbook(pet, at).moments.map(moment => moment.id);
  assert.deepEqual(ids(NOW + D - 1), ['hatch', 'name']);
  assert.deepEqual(ids(NOW + 7 * D), ['hatch', 'name', 'young', 'teen', 'adult']);
  const elder = life.scrapbook(pet, NOW + 14 * D);
  assert.deepEqual(elder.moments.slice(2).map(moment => [moment.id, (moment.at - NOW) / D]), [['young', 1], ['teen', 3], ['adult', 7], ['elder', 14]]);
  assert.equal(elder.album.length, 32);
  for (const [days, unlocked] of [[13, 0], [14, 1], [16.9, 1], [17, 2], [20, 3], [14 + 31 * 3, 32], [500, 32]]) {
    const page = life.scrapbook(pet, NOW + days * D);
    assert.equal(page.unlocked, unlocked, days + ' days');
    assert.equal(page.album.filter(slot => slot.unlocked).length, unlocked);
  }
  assert.equal(life.scrapbook(pet, NOW + 20 * D).album[2].at, NOW + 20 * D);
  const stored = living({ bornAt: NOW, events: { game: NOW + H, arena: NOW + 2 * D } });
  assert.deepEqual(life.scrapbook(stored, NOW + 2 * D).moments.map(moment => moment.id), ['hatch', 'name', 'game', 'young', 'arena']);
  assert.deepEqual(life.scrapbook(pet, NOW, 14).stickers, [{ days: 3, earned: true }, { days: 7, earned: true }, { days: 14, earned: true }, { days: 30, earned: false }]);
  assert.deepEqual(life.scrapbook(life.fresh(NOW), NOW).moments, []);
});

test('the browser streak follows the iOS visit rule', () => {
  const record = { streak: 0, lastVisitDay: '' };
  assert.equal(life.visit(record, '2027-01-15', '2027-01-14'), true); assert.equal(record.streak, 1);
  assert.equal(life.visit(record, '2027-01-15', '2027-01-14'), false); assert.equal(record.streak, 1);
  life.visit(record, '2027-01-16', '2027-01-15'); assert.equal(record.streak, 2);
  life.visit(record, '2027-01-18', '2027-01-17'); assert.equal(record.streak, 1);
  assert.equal(life.visit(record, '2027-01-17', '2027-01-16'), false, 'a clock rollback keeps the streak');
  const capped = { streak: Number.MAX_SAFE_INTEGER, lastVisitDay: '2027-01-14' };
  life.visit(capped, '2027-01-15', '2027-01-14'); assert.equal(capped.streak, life.MAX_STREAK);
  const local = life.localTime(new Date(2027, 2, 1, 10).getTime());
  assert.deepEqual(local, { day: '2027-03-01', yesterday: '2027-02-28', hour: 10 });
});

test('wishes and scrapbook events survive validation and backups; malformed or missing fields still load', async () => {
  const pet = living({ wish: { kind: 'feed', target: 'cheese', issuedAt: NOW, expiresAt: NOW + 6 * H }, wishes: { day: DAY, count: 1 },
    events: { game: NOW - H, wish: NOW - 2 * H, arena: NOW - 3 * H } });
  assert.deepEqual(life.validate(JSON.parse(JSON.stringify(pet))), pet);
  assert.deepEqual((await saves.decode(await saves.encode(pet))).pet, pet);
  const old = living();
  const restored = (await saves.decode(await saves.encode(old))).pet;
  assert.deepEqual(restored, old);
  for (const key of ['wish', 'wishes', 'events']) assert.equal(key in restored, false);
  for (const [key, value] of [['wish', { kind: 'dance', target: '', issuedAt: NOW, expiresAt: NOW + H }], ['wish', { kind: 'feed', target: 'pizza', issuedAt: NOW, expiresAt: NOW + H }],
    ['wish', { kind: 'pet', target: '', issuedAt: NOW, expiresAt: NOW + 7 * H }], ['wishes', { day: '15/01/2027', count: 1 }], ['wishes', { day: DAY, count: 3 }],
    ['events', { game: -1 }], ['events', []], ['wish', 'feed']]) {
    assert.equal(key in life.validate({ ...old, [key]: value }), false, key + ' ' + JSON.stringify(value));
  }
  assert.deepEqual(life.validate({ ...old, events: { game: NOW, party: NOW, wish: 1.5 } }).events, { game: NOW });
});
