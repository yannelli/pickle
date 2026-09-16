const assert = require('node:assert/strict');
const fs = require('node:fs/promises');
const path = require('node:path');
const life = require('../pet-life.js');
const saves = require('../save-codec.js');

async function main() {
  const now = Date.now();
  const directory = path.join(__dirname, 'fixtures', 'saves');
  const fixtures = [];
  const living = (days, changes = {}) => {
    const bornAt = now - days * life.DAY;
    return { ...life.fresh(now), phase: 'living', name: 'Test Dill',
      brinedAt: bornAt - life.HATCH_MS, hatchAt: bornAt, bornAt, ...changes };
  };
  const add = (file, description, pet, expected) => fixtures.push({ file, description, pet, expected });

  add('new', 'Choose a brine.', life.fresh(now), { phase: 'new' });
  const brining = life.fresh(now);
  life.brine(brining, 'classic', now, 0);
  add('brining', 'Hatches 1 minute after generation.', brining, { phase: 'brining' });
  const naming = life.fresh(now - life.HATCH_MS);
  life.brine(naming, 'classic', now - life.HATCH_MS, 0);
  life.advance(naming, now);
  add('naming', 'Unnamed hatchling, ready to name.', naming, { phase: 'naming' });

  for (const [stage, days] of [['baby', 0], ['young', 1], ['adult', 3]]) {
    add(stage, `${days} days old.`, living(days), { stage });
  }
  for (const [file, index] of [['elder-first', 0], ['elder-last', life.ELDERS.length - 1],
    ['elder-second-lap', life.ELDERS.length]]) {
    const days = 14 + index * 3;
    const form = life.ELDERS[index % life.ELDERS.length];
    add(file, `${form.name}, ${days} days old.`, living(days),
      { stage: 'elder', elder: form.id, lap: Math.floor(index / life.ELDERS.length) + 1 });
  }
  for (const variety of life.VARIETIES.filter(value => value.id !== 'dill')) {
    add(`variety-${variety.id}`, `${variety.name}, adult.`,
      living(3, { variety: variety.id, brine: variety.brine, name: variety.name }),
      { stage: 'adult', variety: variety.id });
  }

  add('sleeping', 'Adult asleep with 10 energy.', living(3, { sleeping: true, energy: 10 }),
    { sleeping: true, energy: 10 });
  add('low-energy', 'Adult awake with 0 energy; arcade entry is unavailable.', living(3, { energy: 0 }),
    { energy: 0, dead: false });
  add('sick', 'Adult with 5 food; feed to recover.', living(3, { fullness: 5, sick: true }),
    { sick: true, dead: false });
  add('near-death', 'Empty food; 1 hour remains before death at generation.',
    living(3, { fullness: 0, sick: true, neglectMs: 47 * life.HOUR }),
    { sick: true, dead: false, neglectMs: 47 * life.HOUR });
  const dead = living(3, { fullness: 0, sick: true, neglectMs: 48 * life.HOUR, dead: true, diedAt: now });
  add('dead', 'Adult dead from neglect.', dead, { dead: true, sick: true });
  add('eaten', 'Adult after eating confirmation.', living(3, { dead: true, eaten: true, diedAt: now }),
    { dead: true, eaten: true });
  add('legacy-v1', 'Encrypted v1 save; imports as a living elder named Little Dill.',
    { version: 1, fullness: 70, happiness: 60, energy: 50, hygiene: 80, ageTicks: 700,
      neglect: 20, sleeping: false, sick: false, dead: false, updatedAt: now - life.DAY },
    { version: 2, stage: 'elder', name: 'Little Dill', neglectMs: 0, dead: false });

  await fs.mkdir(directory, { recursive: true });
  for (const fixture of fixtures) {
    const raw = await saves.encode(fixture.pet);
    assert.ok(Buffer.byteLength(raw) < saves.MAX_FILE_BYTES);
    const decoded = await saves.decode(raw);
    assert.deepEqual(decoded.pet, fixture.pet);
    const restored = life.advance(life.restore(decoded.pet, now), now);
    for (const [key, value] of Object.entries(fixture.expected)) {
      const actual = key === 'stage' ? life.stage(restored, now)
        : key === 'elder' ? life.elder(restored, now).id
        : key === 'lap' ? life.elder(restored, now).lap : restored[key];
      assert.equal(actual, value, `${fixture.file}: ${key}`);
    }
    await fs.writeFile(path.join(directory, `${fixture.file}.dill`), raw + '\n');
  }

  const guide = [
    '# Test saves',
    '',
    `Generated: ${new Date(now).toISOString()}`,
    '',
    '1. Open the app over HTTPS or localhost.',
    '2. Choose Import save and select a `.dill` file from this folder.',
    '3. Check the preview, then choose Restore this pickle.',
    '',
    'Imports replace the current pickle. Undo import restores it during the same page visit.',
    '',
    'Saves use real elapsed time. Regenerate before testing to reset ages, care conditions, and countdowns:',
    '',
    '```sh',
    'node tests/generate-saves.cjs',
    '```',
    '',
    'Run the command from the repository root with Node 24. It overwrites the generated saves in this folder.',
    '',
    '| File | Starting condition |',
    '| --- | --- |',
    ...fixtures.map(({ file, description }) => `| [${file}.dill](${file}.dill) | ${description} |`),
    '',
    'The baby, young, adult, and elder saves use Classic Dill. The variety files cover the other 5 varieties.',
    ''
  ].join('\n');
  await fs.writeFile(path.join(directory, 'README.md'), guide);
  console.log(`Generated and verified ${fixtures.length} saves in ${directory}`);
}

main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
