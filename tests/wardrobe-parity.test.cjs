const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('all 18 wardrobe IDs survive arena join and appear in the web selector', async () => {
  const server = await import('../server/arena-engine.mjs');
  const web = await import('../arena-web/arena-core.mjs');
  const engine = new server.ArenaEngine();
  const html = fs.readFileSync(path.join(__dirname, '../arena-web/index.html'), 'utf8');
  const model = fs.readFileSync(path.join(__dirname, '../ios/LittleDill/DillModel.swift'), 'utf8');
  const cases = model.split('enum Outfit:')[1].split('var id:')[0];
  const native = [...cases.matchAll(/case ([^\n]+)/g)].flatMap(match => match[1].split(',').map(id => id.trim()));
  assert.equal(server.OUTFITS.length, 18);
  assert.deepEqual(web.OUTFITS, server.OUTFITS);
  assert.deepEqual(native, server.OUTFITS);
  for (const outfit of server.OUTFITS) {
    const url = web.socketURL('https://arena.littledill.app', { outfit });
    const player = engine.addPlayer(`wardrobe-${outfit}`, { outfit: url.searchParams.get('outfit') });
    assert.equal(player.outfit, outfit);
    assert.ok(html.includes(`value="${outfit}"`));
  }
  const saved = new server.ArenaEngine({ checkpoint: engine.checkpoint() });
  for (const outfit of server.OUTFITS) assert.equal(saved.players.get(`wardrobe-${outfit}`).outfit, outfit);
});
