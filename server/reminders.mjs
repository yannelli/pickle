const HOUR = 3600000, DAY = 24 * HOUR;
const encoder = new TextEncoder();
export const json = (value, status = 200) => Response.json(value, { status, headers: { 'Cache-Control': 'no-store' } });
export const base64url = bytes => btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
export const digest = async text => base64url(await crypto.subtle.digest('SHA-256', encoder.encode(text)));

export function validEndpoint(value) {
  try {
    const url = new URL(value);
    // Only browser push services, never arbitrary URLs or redirect targets.
    return value.length <= 2048 && url.protocol === 'https:' && !url.username && !url.password && !url.port && !url.hash &&
      (url.hostname === 'fcm.googleapis.com' || url.hostname === 'updates.push.services.mozilla.com' ||
       url.hostname.endsWith('.push.apple.com') || url.hostname === 'web.push.apple.com' || url.hostname.endsWith('.notify.windows.com'));
  } catch { return false; }
}
export function validTimezone(value) {
  try { if (typeof value !== 'string' || value.length > 80) return false; new Intl.DateTimeFormat('en', { timeZone: value }).format(); return true; } catch { return false; }
}
export function quietUntil(time, timeZone) {
  const formatter = new Intl.DateTimeFormat('en-US', { timeZone, hour: 'numeric', hourCycle: 'h23' });
  let candidate = time;
  for (let i = 0; i < 100; i++, candidate += 15 * 60000) {
    const hour = Number(formatter.format(new Date(candidate)));
    if (hour >= 9 && hour < 22) return candidate;
  }
  return candidate;
}
export async function authorization(jwk, endpoint, subject, now = Date.now()) {
  const key = await crypto.subtle.importKey('jwk', jwk, { name: 'ECDSA', namedCurve: 'P-256' }, false, ['sign']);
  const header = base64url(encoder.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const payload = base64url(encoder.encode(JSON.stringify({ aud: new URL(endpoint).origin, exp: Math.floor(now / 1000) + 12 * 3600, sub: subject })));
  const token = header + '.' + payload;
  const signature = base64url(await crypto.subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, encoder.encode(token)));
  const raw = new Uint8Array(65); raw[0] = 4;
  for (const [offset, value] of [[1, jwk.x], [33, jwk.y]]) raw.set(Uint8Array.from(atob(value.replace(/-/g, '+').replace(/_/g, '/')), char => char.charCodeAt(0)), offset);
  return 'vapid t=' + token + '.' + signature + ', k=' + base64url(raw);
}

// Keys are created once inside private Durable Object storage, never shipped as assets.
export class PushKeys {
  constructor(ctx) {
    this.ctx = ctx;
    this.ready = ctx.blockConcurrencyWhile(async () => {
      this.jwk = await ctx.storage.get('key');
      if (!this.jwk) {
        const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign', 'verify']);
        this.jwk = await crypto.subtle.exportKey('jwk', pair.privateKey);
        await ctx.storage.put('key', this.jwk);
      }
    });
  }
  async fetch(request) {
    await this.ready;
    if (request.method === 'GET') {
      const auth = await authorization(this.jwk, 'https://fcm.googleapis.com', 'https://pickle.ryanyannelli.workers.dev/');
      return json({ publicKey: auth.split(', k=')[1] });
    }
    const { endpoint, subject } = await request.json();
    return json({ authorization: await authorization(this.jwk, endpoint, subject) });
  }
}

export class Reminder {
  constructor(ctx, env) { this.ctx = ctx; this.env = env; }
  async fetch(request) {
    // Serialize updates with alarm delivery so a cancellation cannot race a send.
    return this.ctx.blockConcurrencyWhile(async () => {
      const body = await request.json();
      const now = Date.now();
      const record = await this.ctx.storage.get('reminder');
      const authHash = await digest(body.subscription.keys.auth);
      if (record && record.authHash !== authHash) return json({ error: 'This subscription could not be verified.' }, 403);
      if (request.method === 'DELETE') {
        await this.ctx.storage.deleteAlarm(); await this.ctx.storage.deleteAll(); return json({ enabled: false });
      }
      if (body.test) {
        if (!record) return json({ error: 'Enable reminders first.' }, 409);
        if (now - (record.lastTest || 0) < 60000) return json({ error: 'Give your last test a minute to arrive.' }, 429);
        record.lastTest = now;
        await this.ctx.storage.put('reminder', record);
        const response = await this.deliver(record);
        return response.ok ? json({ sent: true }) : json({ error: 'The push service could not deliver the test. Try enabling reminders again.' }, 502);
      }
      const lastSent = record?.lastSent || 0;
      const cycleAt = Math.min(now, body.cycleAt);
      const dueAt = quietUntil(Math.max(now + 2 * HOUR, Math.min(now + 7 * DAY, body.dueAt), lastSent + DAY), body.timeZone);
      const next = { endpoint: body.subscription.endpoint, authHash, timeZone: body.timeZone, subject: body.subject,
        dueAt, cycleAt, sentCycle: record?.sentCycle || 0, lastSent, lastTest: record?.lastTest || 0,
        expiresAt: now + 30 * DAY };
      await this.ctx.storage.put('reminder', next);
      // One nudge per care visit. Ignoring it never creates a daily nag loop.
      await this.ctx.storage.setAlarm(cycleAt > next.sentCycle ? dueAt : next.expiresAt);
      return json({ enabled: true, dueAt: cycleAt > next.sentCycle ? dueAt : null });
    });
  }
  async deliver(record) {
    const signed = await this.env.PUSH_KEYS.getByName('v1').fetch(new Request('https://keys/sign', {
      method: 'POST', body: JSON.stringify({ endpoint: record.endpoint, subject: record.subject })
    }));
    const token = await signed.json();
    // Empty Web Push messages carry no user data and need no payload encryption.
    // The service worker supplies the local, fixed notification text.
    return fetch(record.endpoint, { method: 'POST', redirect: 'error', headers: {
      Authorization: token.authorization, TTL: '900', Urgency: 'low', Topic: 'little-dill-care', 'Content-Length': '0'
    }, signal: AbortSignal.timeout(10000) });
  }
  async alarm() {
    return this.ctx.blockConcurrencyWhile(async () => {
      const record = await this.ctx.storage.get('reminder');
      const now = Date.now();
      if (!record) return;
      if (now >= record.expiresAt) { await this.ctx.storage.deleteAll(); return; }
      if (record.cycleAt <= record.sentCycle) { await this.ctx.storage.setAlarm(record.expiresAt); return; }
      const due = quietUntil(Math.max(record.dueAt, record.lastSent + DAY, now), record.timeZone);
      if (due > now + 1000) { await this.ctx.storage.setAlarm(due); return; }
      // Persist before the network call: alarm retries must not double-notify.
      record.lastSent = now; record.sentCycle = record.cycleAt;
      await this.ctx.storage.put('reminder', record);
      await this.ctx.storage.setAlarm(record.expiresAt);
      try {
        const response = await this.deliver(record);
        if (response.status === 404 || response.status === 410) { await this.ctx.storage.deleteAlarm(); await this.ctx.storage.deleteAll(); }
      } catch { /* A missed reminder is preferable to retry spam. A care visit rearms it. */ }
    });
  }
}
