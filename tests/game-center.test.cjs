const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

test('Game Center leaderboard IDs match between the setup script and the app', async () => {
  const { leaderboards } = await import('../ios/scripts/game-center.mjs');
  const swift = fs.readFileSync(require.resolve('../ios/LittleDill/GameCenter.swift'), 'utf8');
  const appIds = [...swift.matchAll(/case [^\n]*/g)].flatMap((line) => [...line[0].matchAll(/"(ld\.[a-z.]+)"/g)].map((match) => match[1]));
  assert.deepEqual(appIds.sort(), leaderboards.map((board) => board.id).sort());
  const games = ['hunt', 'memory', 'catch', 'hop', 'chop', 'toss'];
  for (const game of games) assert.ok(appIds.includes(`ld.arcade.${game}`), game);
});
