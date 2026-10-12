const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('all 36 wardrobe IDs survive arena join and appear in the web selector', async () => {
  const server = await import('../server/arena-engine.mjs');
  const web = await import('../arena-web/arena-core.mjs');
  const engine = new server.ArenaEngine();
  const html = fs.readFileSync(path.join(__dirname, '../arena-web/index.html'), 'utf8');
  const model = fs.readFileSync(path.join(__dirname, '../ios/LittleDill/DillModel.swift'), 'utf8');
  const cases = model.split('enum Outfit:')[1].split('var id:')[0];
  const native = [...cases.matchAll(/case ([^\n]+)/g)].flatMap(match => match[1].split(',').map(id => id.trim()));
  assert.equal(server.OUTFITS.length, 36);
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
test('every drawn wardrobe look paints with known colours and bots skip premium looks', async () => {
  const server = await import('../server/arena-engine.mjs');
  const { WARDROBE_IDS, WARDROBE_LOOKS, drawWardrobe } = await import('../arena-web/arena-wardrobe.mjs');
  const premium = ['viking', 'tiara', 'jester', 'unicorn', 'phoenix', 'emperor'];
  assert.deepEqual(server.OUTFITS.slice(-6), premium);
  assert.deepEqual(server.BOT_OUTFITS, server.OUTFITS.slice(0, -6));
  globalThis.Path2D ??= class { ellipse() {} roundRect() {} };
  const painted = [], ctx = new Proxy({}, { get: (target, key) => key in target ? target[key] : () => {}, set: (target, key, value) => { if (key === 'fillStyle' || key === 'strokeStyle') painted.push(value); target[key] = value; return true; } });
  for (const id of WARDROBE_IDS) {
    assert.ok(WARDROBE_LOOKS[id]?.parts.length, id);
    assert.equal(drawWardrobe(ctx, id), true, id);
  }
  assert.ok(painted.every(colour => /^#[0-9A-Fa-f]{6}$/.test(colour)), 'every fill and stroke resolves to a hex colour');
  const engine = new server.ArenaEngine({ publicRoom: true });
  engine.addPlayer('human', { name: 'Dilly' });
  const bots = [...engine.players.values()].filter(p => p.bot);
  assert.ok(bots.length > 6 && bots.every(bot => !premium.includes(bot.outfit)));
});
