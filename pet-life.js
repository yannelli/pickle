(function (root) {
  'use strict';
  const HOUR = 3600000, DAY = 24 * HOUR, HATCH_MS = 60000;
  const STATS = ['fullness', 'happiness', 'energy', 'hygiene'];
  const RATES = { fullness: 1.5, happiness: 1, hygiene: 1.25 };
  const VARIETIES = [
    { id: 'dill', name: 'Classic Dill', brine: 'classic', color: '#78954b', light: '#a1b56b', dark: '#527637', shape: 'long' },
    { id: 'gherkin', name: 'Tiny Gherkin', brine: 'classic', color: '#709855', light: '#bad28c', dark: '#486b37', shape: 'gherkin' },
    { id: 'garlic', name: 'Garlic Goblin', brine: 'garlic', color: '#98a76d', light: '#d1d99d', dark: '#617c4c', shape: 'pear' },
    { id: 'butter', name: 'Butter Bean', brine: 'garlic', color: '#b0a44d', light: '#ddce80', dark: '#877a39', shape: 'round' },
    { id: 'chili', name: 'Chili Dill', brine: 'spicy', color: '#958749', light: '#d2af73', dark: '#6a693a', shape: 'tapered' },
    { id: 'pepper', name: 'Pepper Punk', brine: 'spicy', color: '#66875d', light: '#a7c18a', dark: '#415c3f', shape: 'ribbed' }
  ];
  // Each elder has its own silhouette/accessory pairing as well as a title.
  const ELDERS = [
    ['grandill', 'Grandill', 'Back in my brine, jars were uphill both ways.', 'cap', 'cane'],
    ['retired-dj', 'DJ Dill Senior', 'Still dropping beets. Mostly by accident.', 'headphones', 'record'],
    ['tax-wizard', 'Tax Wizard', 'Claims the jar as a home office.', 'wizard', 'scroll'],
    ['lawn-lord', 'Lawn Lord', 'Get off my garnish.', 'sunhat', 'rake'],
    ['soup-oracle', 'Soup Oracle', 'Foresees a 90% chance of soup.', 'turban', 'bowl'],
    ['disco', 'Disco Gherkin', 'The knees say no. The groove says yes.', 'afro', 'record'],
    ['admiral', 'Admiral Brine', 'Has never left the bath.', 'captain', 'anchor'],
    ['professor', 'Professor Crunch', 'Tenure in advanced sitting.', 'mortarboard', 'book'],
    ['couch-duke', 'Duke of Couch', 'Rules from a very soft throne.', 'crown', 'mug'],
    ['pickle-cowboy', 'Dill With No Name', 'This jar ain’t big enough for two lids.', 'cowboy', 'cane'],
    ['tea-gossip', 'Tea Goblin', 'Spills the tea. Blames the saucer.', 'bonnet', 'mug'],
    ['space-grandpa', 'Space Grandill', 'One small step. One loud knee.', 'antenna', 'planet'],
    ['yoga', 'Flexible in Theory', 'Downward dill. Upward groan.', 'headband', 'flower'],
    ['pirate', 'Captain Picklebeard', 'The treasure was the snacks we ate.', 'pirate', 'anchor'],
    ['detective', 'Inspector Gherkin', 'The missing sock was in the jar.', 'deerstalker', 'lens'],
    ['influencer', 'Granfluencer', 'Link in brine-o.', 'sunglasses', 'phone'],
    ['goth', 'Goth Grandill', 'It was never a phase, cucumber.', 'witch', 'flower'],
    ['billionaire', 'Brine Baron', 'Owns three jars. Calls it an empire.', 'top', 'coin'],
    ['mushroom', 'Mushroom Uncle', 'A fun guy with questionable stories.', 'mushroom', 'cane'],
    ['chef', 'Chef Al Dente', 'Too many cooks. Just enough pickle.', 'chef', 'bowl'],
    ['knight', 'Sir Crunch-a-Lot', 'Defender of the afternoon nap.', 'helmet', 'shield'],
    ['weather', 'Weather Dill', 'Can feel rain in the brine.', 'rainhat', 'umbrella'],
    ['punk', 'Punkle', 'Anarchy, but after breakfast.', 'mohawk', 'record'],
    ['gardener', 'Compost Philosopher', 'Everything is a salad if you believe.', 'sunhat', 'flower'],
    ['accountant', 'Count Pickula', 'One receipt. Two receipts. Ah ah ah.', 'vampire', 'book'],
    ['zen', 'The Big Chill', 'Has achieved inner peas.', 'halo', 'bowl'],
    ['magician', 'The Great Dilldini', 'Makes an entire afternoon disappear.', 'top', 'wand'],
    ['artist', 'Vincent Van Gherkin', 'Still in the green period.', 'beret', 'palette'],
    ['royal', 'Her Royal Brineness', 'We are not a-mused. We are a-pickled.', 'crown', 'scepter'],
    ['timekeeper', 'Father Thyme', 'Late to everything. Including aging.', 'wizard', 'clock'],
    ['cosmic', 'Cosmic Cucumber', 'Knows the universe is mostly snack space.', 'antenna', 'wand'],
    ['eternal', 'The Eternal Dill', 'Best before: absolutely never.', 'halo', 'infinity']
  ].map(([id, name, quip, hat, prop], index) => ({ id, name, quip, hat, prop, accent: ['#718449', '#8b754a', '#65785f', '#8e8460'][index % 4] }));
  // Teens pick a new stereotype every day between day 3 and day 7, starting from a per-pickle offset.
  const TEENS = [
    ['nerd', 'Nerd', 'Actually, it’s a cucurbit.', 'nerdglasses', 'book'],
    ['emo', 'Emo', 'Nobody understands brine like I do.', 'fringe', 'journal'],
    ['jock', 'Jock', 'Do you even lift, jar?', 'backcap', 'ball'],
    ['skater', 'Skater', 'Kickflip. Wipeout. Repeat.', 'beanie', 'skateboard'],
    ['gamer', 'Gamer', 'One more round. Six more rounds.', 'headset', 'controller'],
    ['theater', 'Theater Kid', 'The whole jar is a stage.', 'beret', 'masks'],
    ['band', 'Band Kid', 'This one time, at brine camp...', 'shako', 'trumpet'],
    ['prep', 'Prep', 'Early decision. Extra brine.', 'mortarboard', 'phone']
  ].map(([id, name, quip, hat, prop], index) => ({ id, name, quip, hat, prop, accent: ['#5b6f8a', '#3d3d47', '#8a5b5b', '#6f7f4a'][index % 4] }));
  const FOODS = ['carrot', 'strawberry', 'broccoli', 'apple', 'cheese'];
  const FOOD_NAMES = { carrot: 'carrot', strawberry: 'strawberry', broccoli: 'broccoli', apple: 'apple slice', cheese: 'cheese wedge' };
  const GAMES = ['hunt', 'memory', 'catch'];
  const GAME_NAMES = { hunt: 'Heart hunt', memory: 'Dill says', catch: 'Brine catch' };
  const FAVORITES = {
    dill: { food: 'strawberry', game: 'catch' }, gherkin: { food: 'carrot', game: 'memory' },
    garlic: { food: 'broccoli', game: 'hunt' }, butter: { food: 'cheese', game: 'memory' },
    chili: { food: 'apple', game: 'hunt' }, pepper: { food: 'carrot', game: 'catch' }
  };
  const FAVORITE_BONUS = 4;
  const WISH_KINDS = ['feed', 'clean', 'pet', 'play', 'nap'];
  const WISH_MS = 6 * HOUR, WISHES_PER_DAY = 2, WISH_HAPPINESS = 10, WISH_COINS = 5;
  // Slot n opens at WISH_HOURS[n] local time; quiet hours run from QUIET_HOUR to WISH_HOURS[0].
  const WISH_HOURS = [9, 15], QUIET_HOUR = 22;
  const STAGE_DAYS = [['young', 1], ['teen', 3], ['adult', 7], ['elder', 14]];
  const EVENTS = ['game', 'wish', 'arena'];
  const MOMENTS = { hatch: 'Hatched from the brine', name: 'Got a name', young: 'Grew up: young pickle', teen: 'Became a teen',
    adult: 'All grown up', elder: 'Joined the elder club', game: 'First arcade game', wish: 'First wish granted', arena: 'First arena run' };
  const STREAK_STICKERS = [3, 7, 14, 30];
  const MAX_STREAK = 100000;
  const clamp = value => Math.max(0, Math.min(100, value));
  const timestamp = value => Number.isSafeInteger(value) && value >= 0 && value <= 8640000000000000;
  const isDay = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value);
  const isObject = value => !!value && typeof value === 'object' && !Array.isArray(value);
  function cleanWish(value) {
    if (!isObject(value) || !WISH_KINDS.includes(value.kind) || typeof value.target !== 'string' ||
      value.target !== (value.kind === 'feed' ? (FOODS.includes(value.target) ? value.target : null) :
        value.kind === 'play' ? (GAMES.includes(value.target) ? value.target : null) : '') ||
      !timestamp(value.issuedAt) || !timestamp(value.expiresAt) || value.expiresAt <= value.issuedAt ||
      value.expiresAt - value.issuedAt > WISH_MS) return undefined;
    return { kind: value.kind, target: value.target, issuedAt: value.issuedAt, expiresAt: value.expiresAt };
  }
  function cleanWishes(value) {
    if (!isObject(value) || !isDay(value.day) || !Number.isSafeInteger(value.count) || value.count < 0 || value.count > WISHES_PER_DAY) return undefined;
    return { day: value.day, count: value.count };
  }
  function cleanEvents(value) {
    if (!isObject(value)) return undefined;
    const events = Object.fromEntries(EVENTS.filter(key => timestamp(value[key])).map(key => [key, value[key]]));
    return Object.keys(events).length ? events : undefined;
  }
  // Optional shared fields are dropped when malformed so one bad value cannot block a whole save.
  function withOptionals(pet, value) {
    for (const [key, clean] of [['wish', cleanWish], ['wishes', cleanWishes], ['events', cleanEvents]]) {
      const cleaned = clean(value[key]);
      if (cleaned) pet[key] = cleaned;
    }
    return pet;
  }
  function fresh(now = Date.now()) {
    return { version: 2, phase: 'new', name: '', variety: 'dill', brine: 'classic', brinedAt: 0, hatchAt: 0, bornAt: 0,
      fullness: 90, happiness: 85, energy: 90, hygiene: 95, sleeping: false, sick: false, dead: false,
      neglectMs: 0, diedAt: 0, lastCareAt: now, updatedAt: now };
  }
  function validate(value) {
    if (!value || value.version !== 2 || !['new', 'brining', 'naming', 'living'].includes(value.phase) ||
      typeof value.name !== 'string' || [...value.name].length > 24 || /[\p{Cc}\p{Cf}]/u.test(value.name) ||
      (value.phase === 'living' && !value.name.trim()) || !VARIETIES.some(v => v.id === value.variety) ||
      !['classic', 'garlic', 'spicy'].includes(value.brine) || !STATS.every(key => Number.isFinite(value[key]) && value[key] >= 0 && value[key] <= 100) ||
      !['brinedAt', 'hatchAt', 'bornAt', 'lastCareAt', 'updatedAt', 'diedAt'].every(key => timestamp(value[key])) ||
      !Number.isFinite(value.neglectMs) || value.neglectMs < 0 || value.neglectMs > 48 * HOUR ||
      !['sleeping', 'sick', 'dead'].every(key => typeof value[key] === 'boolean') || (value.dead && value.sleeping) ||
      (value.phase !== 'living' && (value.dead || value.sleeping || value.sick)) || (value.dead && value.diedAt < value.bornAt) ||
      (value.phase !== 'new' && value.hatchAt < value.brinedAt) || (value.phase === 'living' && value.bornAt > value.updatedAt) ||
      (value.eaten !== undefined && (typeof value.eaten !== 'boolean' || (value.eaten && !value.dead)))) {
      throw new Error('This file contains invalid pickle progress.');
    }
    const pet = Object.fromEntries(Object.keys(fresh()).map(key => [key, value[key]]));
    if (value.eaten) pet.eaten = true;
    return withOptionals(pet, value);
  }
  function restore(value, now = Date.now()) {
    if (value?.version === 2) return validate(value);
    if (!value || value.version !== 1 || !STATS.every(key => Number.isFinite(value[key]) && value[key] >= 0 && value[key] <= 100) ||
      !['ageTicks', 'neglect', 'updatedAt'].every(key => Number.isFinite(value[key]) && value[key] >= 0) ||
      !['sleeping', 'sick', 'dead'].every(key => typeof value[key] === 'boolean')) throw new Error('Unreadable pickle save.');
    // Keep existing growth and stats, and give old rapid-decay saves a fresh grace period.
    const age = value.ageTicks >= 600 ? 14 * DAY : value.ageTicks >= 100 ? 7 * DAY : value.ageTicks >= 10 ? DAY : 0;
    return { ...fresh(now), ...Object.fromEntries(STATS.map(key => [key, value[key]])), phase: 'living', name: 'Little Dill',
      bornAt: Math.max(0, now - age), brinedAt: Math.max(0, now - age - HATCH_MS), hatchAt: Math.max(0, now - age),
      sleeping: value.sleeping && !value.dead, sick: value.sick, dead: value.dead, diedAt: value.dead ? now : 0 };
  }
  function brine(pet, kind, now = Date.now(), random = Math.random()) {
    if (pet.phase !== 'new' || !['classic', 'garlic', 'spicy'].includes(kind)) return false;
    const choices = VARIETIES.filter(v => v.brine === kind);
    Object.assign(pet, { phase: 'brining', brine: kind, variety: choices[Math.min(1, Math.floor(Math.max(0, random) * 2))].id,
      brinedAt: now, hatchAt: now + HATCH_MS, updatedAt: now });
    return true;
  }
  function name(pet, text, now = Date.now()) {
    const cleaned = String(text).normalize('NFC').trim().replace(/\s+/g, ' ');
    if (pet.phase !== 'naming' || !cleaned || [...cleaned].length > 24 || /[\p{Cc}\p{Cf}]/u.test(cleaned)) return false;
    Object.assign(pet, { phase: 'living', name: cleaned, bornAt: now, lastCareAt: now, updatedAt: now });
    return true;
  }
  function assess(pet) {
    if (pet.phase !== 'living' || pet.dead) return;
    if (Math.min(pet.fullness, pet.happiness, pet.hygiene) <= 8) pet.sick = true;
    if (Object.keys(RATES).every(key => pet[key] > 0)) pet.neglectMs = 0;
    if (STATS.every(key => pet[key] >= 30)) pet.sick = false;
  }
  function advance(pet, now = Date.now()) {
    // A backward wall-clock adjustment must not count the same hours twice.
    if (now <= pet.updatedAt) return pet;
    if (pet.phase === 'brining' && now >= pet.hatchAt) pet.phase = 'naming';
    if (pet.phase !== 'living' || pet.dead) { pet.updatedAt = now; return pet; }
    const elapsed = now - pet.updatedAt;
    const emptyAfter = Math.min(...Object.entries(RATES).map(([key, rate]) => pet[key] / rate * HOUR));
    if (emptyAfter > 0) pet.neglectMs = 0;
    const untilDeath = emptyAfter + 48 * HOUR - pet.neglectMs;
    const duration = Math.min(elapsed, untilDeath);
    const hours = duration / HOUR;
    const recoveryHours = Math.max(0, 30 - pet.energy) / (pet.sleeping ? 30 : 2);
    if (recoveryHours <= hours && Object.entries(RATES).every(([key, rate]) => pet[key] - rate * recoveryHours >= 30)) pet.sick = false;
    for (const [key, rate] of Object.entries(RATES)) pet[key] = clamp(pet[key] - rate * hours);
    pet.energy = clamp(pet.energy + hours * (pet.sleeping ? 30 : 2));
    if (pet.energy >= 100) pet.sleeping = false;
    pet.neglectMs = Math.min(48 * HOUR, pet.neglectMs + Math.max(0, duration - emptyAfter));
    assess(pet);
    if (pet.neglectMs >= 48 * HOUR) { pet.dead = true; pet.sleeping = false; pet.diedAt = Math.round(pet.updatedAt + duration); }
    pet.updatedAt = now;
    return pet;
  }
  function age(pet, now = Date.now()) { return pet.phase === 'living' ? Math.max(0, (pet.dead ? pet.diedAt : Math.max(now, pet.updatedAt)) - pet.bornAt) : 0; }
  function stage(pet, now = Date.now()) {
    if (pet.phase !== 'living') return pet.phase;
    const days = age(pet, now) / DAY;
    return days < 1 ? 'baby' : days < 3 ? 'young' : days < 7 ? 'teen' : days < 14 ? 'adult' : 'elder';
  }
  function teen(pet, now = Date.now()) {
    if (stage(pet, now) !== 'teen') return null;
    const day = Math.floor((age(pet, now) - 3 * DAY) / DAY);
    const offset = Math.floor(pet.bornAt / 1000) % TEENS.length;
    return { ...TEENS[(offset + day) % TEENS.length], day };
  }
  function elder(pet, now = Date.now()) {
    if (stage(pet, now) !== 'elder') return null;
    const number = Math.floor((age(pet, now) - 14 * DAY) / (3 * DAY));
    return { ...ELDERS[number % ELDERS.length], number, unlocked: Math.min(ELDERS.length, number + 1), lap: Math.floor(number / ELDERS.length) + 1 };
  }
  function nextCareAt(pet, now = Date.now()) {
    const hours = Math.min(...Object.entries(RATES).map(([key, rate]) => Math.max(0, pet[key] - 55) / rate));
    return now + Math.max(2, hours) * HOUR;
  }
  const pad = (value, size = 2) => String(value).padStart(size, '0');
  const dayKey = date => pad(date.getFullYear(), 4) + '-' + pad(date.getMonth() + 1) + '-' + pad(date.getDate());
  function localTime(now = Date.now()) {
    const date = new Date(now);
    return { day: dayKey(date), yesterday: dayKey(new Date(date.getFullYear(), date.getMonth(), date.getDate() - 1)), hour: date.getHours() };
  }
  function dayNumber(day) {
    const [year, month, date] = day.split('-').map(Number);
    return year * 372 + (month - 1) * 31 + date - 1;
  }
  function favorite(variety) { return FAVORITES[variety] || FAVORITES.dill; }
  function activeWish(pet, now = Date.now()) {
    return pet.phase === 'living' && !pet.dead && pet.wish && now < pet.wish.expiresAt ? pet.wish : null;
  }
  // `day` and `hour` are the device's local calendar day and hour; `food` is the next food in the feeding rotation.
  function rollWish(pet, { now = Date.now(), day, hour, food }) {
    if (pet.wish && !activeWish(pet, now)) delete pet.wish;
    if (pet.phase !== 'living' || pet.dead || pet.sleeping || pet.wish || !pet.name.trim() || !isDay(day)) return null;
    if (pet.wishes && pet.wishes.day > day) return null;
    const count = pet.wishes?.day === day ? pet.wishes.count : 0;
    if (count >= WISHES_PER_DAY || hour < WISH_HOURS[count] || hour >= QUIET_HOUR) return null;
    const kinds = WISH_KINDS.filter(kind => kind === 'clean' ? pet.hygiene < 80 : kind === 'nap' ? pet.energy < 50 : true);
    const seed = Math.floor(pet.bornAt / 1000) + dayNumber(day) * 7 + count * 3;
    const kind = kinds[seed % kinds.length];
    const target = kind === 'feed' ? (FOODS.includes(food) ? food : FOODS[0]) : kind === 'play' ? GAMES[Math.floor(seed / kinds.length) % GAMES.length] : '';
    pet.wish = { kind, target, issuedAt: now, expiresAt: now + WISH_MS };
    pet.wishes = { day, count: count + 1 };
    return pet.wish;
  }
  function recordEvent(pet, event, now = Date.now()) {
    if (pet.phase !== 'living' || !EVENTS.includes(event) || timestamp(pet.events?.[event])) return false;
    pet.events = { ...pet.events, [event]: now };
    return true;
  }
  // Feed wishes match by kind; play wishes need the named game. Returns the happiness added, or null.
  function grantWish(pet, kind, target = '', now = Date.now()) {
    const wish = activeWish(pet, now);
    if (!wish || wish.kind !== kind || (kind === 'play' && wish.target !== target)) return null;
    delete pet.wish;
    const before = pet.happiness;
    pet.happiness = clamp(before + WISH_HAPPINESS);
    recordEvent(pet, 'wish', now);
    return Math.round(pet.happiness - before);
  }
  function wishText(wish) {
    return { feed: 'a ' + FOOD_NAMES[wish.target], clean: 'a bubble bath', pet: 'a little pet', play: 'a round of ' + GAME_NAMES[wish.target], nap: 'a cozy nap' }[wish.kind];
  }
  function scrapbook(pet, now = Date.now(), streak = 0) {
    const stickers = STREAK_STICKERS.map(days => ({ days, earned: streak >= days }));
    if (pet.phase !== 'living') return { moments: [], album: [], unlocked: 0, stickers };
    const reached = age(pet, now);
    const moments = [{ id: 'hatch', at: pet.hatchAt }, { id: 'name', at: pet.bornAt }];
    for (const [id, days] of STAGE_DAYS) if (reached >= days * DAY) moments.push({ id, at: pet.bornAt + days * DAY });
    for (const id of EVENTS) if (timestamp(pet.events?.[id])) moments.push({ id, at: pet.events[id] });
    moments.sort((a, b) => a.at - b.at);
    const unlocked = elder(pet, now)?.unlocked || 0;
    const album = ELDERS.map((form, index) => ({ id: form.id, day: 14 + index * 3, at: pet.bornAt + (14 + index * 3) * DAY, unlocked: index < unlocked }));
    return { moments, album, unlocked, stickers };
  }
  // The iOS visit streak: a new local day extends it when the last visit was yesterday, otherwise restarts at 1.
  function visit(record, day, yesterday) {
    const last = isDay(record.lastVisitDay) ? record.lastVisitDay : '';
    const streak = Number.isSafeInteger(record.streak) ? Math.max(0, Math.min(MAX_STREAK, record.streak)) : 0;
    if (!isDay(day) || day <= last) return false;
    record.streak = last === yesterday ? Math.min(streak, MAX_STREAK - 1) + 1 : 1;
    record.lastVisitDay = day;
    return true;
  }
  const api = Object.freeze({ HOUR, DAY, HATCH_MS, STATS, RATES, VARIETIES, ELDERS, TEENS, FOODS, FOOD_NAMES, GAMES, GAME_NAMES, FAVORITES, FAVORITE_BONUS,
    WISH_KINDS, WISH_MS, WISHES_PER_DAY, WISH_HAPPINESS, WISH_COINS, WISH_HOURS, QUIET_HOUR, STAGE_DAYS, MOMENTS, STREAK_STICKERS, MAX_STREAK,
    fresh, validate, restore, brine, name, assess, advance, age, stage, teen, elder, nextCareAt,
    localTime, favorite, activeWish, rollWish, recordEvent, grantWish, wishText, scrapbook, visit });
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.LittleDillLife = api;
})(globalThis);
