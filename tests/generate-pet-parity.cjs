// Regenerates tests/fixtures/pet-parity.json from pet-life.js. The JS and Swift parity tests read it.
const fs = require('node:fs');
const path = require('node:path');
const life = require('../pet-life.js');

const NOW = 1800000000000, H = life.HOUR, D = life.DAY;
const base = { bornAt: NOW - 3 * D, hygiene: 95, energy: 90, sleeping: false, dead: false };
const living = changes => ({ ...life.fresh(NOW), phase: 'living', name: 'Parity', brinedAt: NOW - life.HATCH_MS, hatchAt: NOW, bornAt: NOW, ...changes });

const rolls = [];
function roll(name, pet, day, hour, food) {
  const state = living({ ...base, ...pet });
  if (state.dead) state.diedAt = NOW;
  life.rollWish(state, { now: NOW, day, hour, food });
  rolls.push({ name, pet: { ...base, ...pet }, now: NOW, day, hour, food, wish: state.wish ?? null, wishes: state.wishes ?? null });
}
roll('morning slot opens at nine', {}, '2027-01-15', 9, 'apple');
roll('quiet before nine', {}, '2027-01-15', 8, 'apple');
roll('quiet from ten at night', {}, '2027-01-15', 22, 'apple');
roll('asleep', { sleeping: true }, '2027-01-15', 12, 'apple');
roll('dead', { dead: true }, '2027-01-15', 12, 'apple');
roll('second slot waits for three', { wishes: { day: '2027-01-15', count: 1 } }, '2027-01-15', 14, 'apple');
roll('second slot at three', { wishes: { day: '2027-01-15', count: 1 } }, '2027-01-15', 15, 'apple');
roll('daily cap', { wishes: { day: '2027-01-15', count: 2 } }, '2027-01-15', 18, 'apple');
roll('new day resets the count', { wishes: { day: '2027-01-14', count: 2 } }, '2027-01-15', 10, 'broccoli');
roll('clock rollback', { wishes: { day: '2027-01-16', count: 1 } }, '2027-01-15', 10, 'apple');
roll('active wish stays', { wish: { kind: 'pet', target: '', issuedAt: NOW - H, expiresAt: NOW + 5 * H }, wishes: { day: '2027-01-15', count: 1 } }, '2027-01-15', 16, 'apple');
roll('expired wish clears before the next slot', { wish: { kind: 'pet', target: '', issuedAt: NOW - 6 * H, expiresAt: NOW }, wishes: { day: '2027-01-15', count: 1 } }, '2027-01-15', 16, 'cheese');
for (let i = 0; i < 12; i++) roll('needy pickle seed ' + i, { bornAt: NOW - 3 * D + i * 1000, hygiene: 50, energy: 30 }, '2027-01-15', 11, life.FOODS[i % 5]);
for (let i = 0; i < 6; i++) roll('healthy pickle seed ' + i, { bornAt: NOW - 3 * D + i * 1000 }, '2027-02-0' + (i + 1), 12, 'carrot');

const scrapbook = [];
function page(name, pet, now, streak) {
  const state = living(pet);
  const result = life.scrapbook(state, now, streak);
  scrapbook.push({ name, pet: { hatchAt: state.hatchAt, bornAt: state.bornAt, dead: state.dead, diedAt: state.diedAt, ...(state.events ? { events: state.events } : {}) },
    now, streak, moments: result.moments, unlocked: result.unlocked, stickers: result.stickers.filter(s => s.earned).map(s => s.days),
    album: result.album.filter(s => s.unlocked).map(s => [s.id, s.at]) });
}
page('half a day', {}, NOW + D / 2, 0);
page('young at one day', { bornAt: NOW + 30000, events: { game: NOW + H } }, NOW + D + 30000, 3);
page('teen', { events: { wish: NOW + 2 * D, game: NOW + 2 * D } }, NOW + 3 * D, 6);
page('adult', {}, NOW + 7 * D, 7);
page('first elder', { events: { arena: NOW + 8 * D, game: NOW + H, wish: NOW + 9 * D } }, NOW + 14 * D, 14);
page('third elder', {}, NOW + 20 * D, 29);
page('full album', {}, NOW + (14 + 3 * 31) * D, 30);
page('second lap', {}, NOW + 300 * D, 100);
page('died an adult', { dead: true, diedAt: NOW + 10 * D }, NOW + 40 * D, 2);

const visits = [];
function visit(name, streak, lastVisitDay, day, yesterday) {
  const record = { streak, lastVisitDay };
  const changed = life.visit(record, day, yesterday);
  visits.push({ name, streak, lastVisitDay, day, yesterday, changed, after: record });
}
visit('first visit', 0, '', '2027-01-15', '2027-01-14');
visit('same day', 4, '2027-01-15', '2027-01-15', '2027-01-14');
visit('next day', 4, '2027-01-14', '2027-01-15', '2027-01-14');
visit('missed a day', 9, '2027-01-13', '2027-01-15', '2027-01-14');
visit('clock rollback', 4, '2027-01-16', '2027-01-15', '2027-01-14');
visit('month boundary', 29, '2027-02-28', '2027-03-01', '2027-02-28');
visit('limit', life.MAX_STREAK, '2027-01-14', '2027-01-15', '2027-01-14');
visit('malformed day', 3, 'yesterday', '2027-01-15', '2027-01-14');

const texts = [['feed', 'apple'], ['clean', ''], ['pet', ''], ['play', 'memory'], ['nap', '']]
  .map(([kind, target]) => ({ wish: { kind, target, issuedAt: 0, expiresAt: 1 }, text: life.wishText({ kind, target }) }));
const fixture = {
  favorites: life.FAVORITES, favoriteBonus: life.FAVORITE_BONUS, foods: life.FOODS, foodNames: life.FOOD_NAMES, games: life.GAMES, gameNames: life.GAME_NAMES,
  wish: { kinds: life.WISH_KINDS, ms: life.WISH_MS, perDay: life.WISHES_PER_DAY, happiness: life.WISH_HAPPINESS, coins: life.WISH_COINS, hours: life.WISH_HOURS, quietHour: life.QUIET_HOUR },
  wishTexts: texts, moments: life.MOMENTS, streakStickers: life.STREAK_STICKERS, maxStreak: life.MAX_STREAK, rolls, scrapbook, visits
};
const output = JSON.stringify(fixture, null, 1) + '\n';
if (require.main === module) fs.writeFileSync(path.join(__dirname, 'fixtures', 'pet-parity.json'), output);
module.exports = { output };
