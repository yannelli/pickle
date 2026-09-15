const { test } = require('node:test');
const assert = require('node:assert/strict');
const service = import('../server/reminders.mjs');
const worker = import('../server/worker.mjs');
const DAY = 86400000, HOUR = 3600000;
const NOW = Date.parse('2026-09-15T15:00:00Z'); // 11am in New York.
const subscription = { endpoint: 'https://fcm.googleapis.com/fcm/send/example', keys: { auth: 'a'.repeat(22), p256dh: 'B'.repeat(87) } };
function fixture() {
  const data = new Map();
  const storage = { nextAlarm: null,
    async get(key) { return structuredClone(data.get(key)); }, async put(key, value) { data.set(key, structuredClone(value)); },
    async setAlarm(time) { this.nextAlarm = time; }, async deleteAlarm() { this.nextAlarm = null; }, async deleteAll() { data.clear(); } };
  return { storage, blockConcurrencyWhile: fn => fn() };
}
function request(body = {}, method = 'PUT') {
  return new Request('https://reminder/', { method, body: JSON.stringify({ subscription, dueAt: NOW + 4 * HOUR, cycleAt: NOW, timeZone: 'America/New_York', subject: 'https://pickle.ryanyannelli.workers.dev/', ...body }) });
}

test('quiet hours defer evening/morning reminders and handle daylight-saving changes', async () => {
  const { quietUntil, validTimezone } = await service;
  assert.equal(quietUntil(NOW, 'America/New_York'), NOW);
  for (const time of ['2026-09-16T03:00:00Z', '2026-11-01T05:30:00Z', '2027-03-14T06:30:00Z']) {
    const due = quietUntil(Date.parse(time), 'America/New_York');
    const hour = new Intl.DateTimeFormat('en', { timeZone: 'America/New_York', hour: 'numeric', hourCycle: 'h23' }).format(due);
    assert.equal(Number(hour), 9);
  }
  assert.equal(validTimezone('not-a-zone'), false);
});

test('push endpoints cannot target arbitrary hosts, ports, credentials, or redirects', async () => {
  const { validEndpoint } = await service;
  for (const endpoint of [subscription.endpoint, 'https://web.push.apple.com/Q123', 'https://updates.push.services.mozilla.com/wpush/v2/123']) assert.equal(validEndpoint(endpoint), true);
  for (const endpoint of ['http://fcm.googleapis.com/x', 'https://127.0.0.1/', 'https://fcm.googleapis.com.evil.test/x', 'https://fcm.googleapis.com:444/x', 'https://user@fcm.googleapis.com/x', 'https://evil.test/?next=https://web.push.apple.com']) assert.equal(validEndpoint(endpoint), false);
});

test('VAPID signatures verify and expire, and durable public keys exclude private material', async () => {
  const { authorization, PushKeys } = await service;
  const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
  const jwk = await crypto.subtle.exportKey('jwk', pair.privateKey);
  const auth = await authorization(jwk, subscription.endpoint, 'https://pickle.ryanyannelli.workers.dev/', NOW);
  const [token, key] = auth.slice(8).split(', k=');
  const [header, body, signature] = token.split('.');
  const payload = JSON.parse(Buffer.from(body, 'base64url'));
  assert.equal(payload.aud, 'https://fcm.googleapis.com');
  assert.equal(payload.exp, NOW / 1000 + 43200);
  assert.equal(await crypto.subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, pair.publicKey, Buffer.from(signature, 'base64url'), Buffer.from(header + '.' + body)), true);
  assert.equal(Buffer.from(key, 'base64url').length, 65);
  const ctx = fixture(); const keys = new PushKeys(ctx);
  const result = await (await keys.fetch(new Request('https://keys/'))).json();
  assert.deepEqual(Object.keys(result), ['publicKey']);
  const restarted = new PushKeys(ctx);
  assert.deepEqual(await (await restarted.fetch(new Request('https://keys/'))).json(), result);
});

test('one delivery per care visit, at most once a day, survives duplicate alarms and restarts', async t => {
  const { Reminder } = await service;
  let now = NOW;
  t.mock.method(Date, 'now', () => now);
  const ctx = fixture(); let sends = 0;
  const reminder = new Reminder(ctx, {});
  reminder.deliver = async () => { sends++; return new Response('', { status: 201 }); };
  const response = await reminder.fetch(request()); assert.equal(response.status, 200);
  now = ctx.storage.nextAlarm;
  await reminder.alarm(); await reminder.alarm(); assert.equal(sends, 1);
  now += HOUR;
  await reminder.fetch(request()); await reminder.alarm(); assert.equal(sends, 1, 'unchanged care does not nag again');
  await reminder.fetch(request({ cycleAt: now, dueAt: now + HOUR }));
  assert.ok(ctx.storage.nextAlarm >= NOW + 4 * HOUR + DAY);
  const restarted = new Reminder(ctx, {}); restarted.deliver = reminder.deliver;
  now = ctx.storage.nextAlarm; await restarted.alarm(); assert.equal(sends, 2);
});

test('unsubscribe verifies the subscription and cancels pending alarms', async t => {
  const { Reminder } = await service; t.mock.method(Date, 'now', () => NOW);
  const ctx = fixture(); const reminder = new Reminder(ctx, {});
  await reminder.fetch(request());
  const forbidden = await reminder.fetch(request({ subscription: { ...subscription, keys: { ...subscription.keys, auth: 'b'.repeat(22) } } }, 'DELETE'));
  assert.equal(forbidden.status, 403);
  assert.ok(ctx.storage.nextAlarm);
  assert.equal((await reminder.fetch(request({}, 'DELETE'))).status, 200);
  assert.equal(ctx.storage.nextAlarm, null); assert.equal(await ctx.storage.get('reminder'), undefined);
});

test('expired subscriptions are deleted and delivery failures never retry-spam', async t => {
  const { Reminder } = await service; let now = NOW; t.mock.method(Date, 'now', () => now);
  for (const gone of [true, false]) {
    now = NOW;
    const ctx = fixture(), reminder = new Reminder(ctx, {}); let sends = 0;
    reminder.deliver = async () => { sends++; if (!gone) throw Error('network down'); return new Response('', { status: 410 }); };
    await reminder.fetch(request()); now = ctx.storage.nextAlarm;
    await reminder.alarm(); await reminder.alarm(); assert.equal(sends, 1);
    if (gone) assert.equal(await ctx.storage.get('reminder'), undefined);
  }
});

test('test notifications require an existing subscription and are throttled', async t => {
  const { Reminder } = await service; t.mock.method(Date, 'now', () => NOW);
  const reminder = new Reminder(fixture(), {});
  reminder.deliver = async () => new Response('', { status: 201 });
  assert.equal((await reminder.fetch(request({ test: true }))).status, 409);
  await reminder.fetch(request());
  assert.equal((await reminder.fetch(request({ test: true }))).status, 200);
  assert.equal((await reminder.fetch(request({ test: true }))).status, 429);
});

test('API rejects cross-origin and malformed requests before reaching storage', async () => {
  const { default: api } = await worker;
  const url = 'https://pickle.ryanyannelli.workers.dev/api/reminders';
  const body = JSON.stringify({ subscription, dueAt: NOW, cycleAt: NOW, timeZone: 'America/New_York' });
  assert.equal((await api.fetch(new Request(url, { method: 'PUT', headers: { Origin: 'https://evil.test', 'Content-Type': 'application/json' }, body }), {})).status, 403);
  assert.equal((await api.fetch(new Request(url, { method: 'PUT', headers: { Origin: new URL(url).origin, 'Content-Type': 'application/json' }, body: '{}' }), {})).status, 400);
  let forwarded = false;
  const result = await api.fetch(new Request(url, { method: 'PUT', headers: { Origin: new URL(url).origin, 'Content-Type': 'application/json' }, body }), {
    REMINDERS: { getByName: id => ({ fetch: async req => { forwarded = id.length === 43 && req.method === 'PUT'; return Response.json({ enabled: true }); } }) }
  });
  assert.equal(result.status, 200); assert.equal(forwarded, true);
});
