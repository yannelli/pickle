import { PushKeys, Reminder, digest, json, validEndpoint, validTimezone } from './reminders.mjs';
export { PushKeys, Reminder };
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (!url.pathname.startsWith('/api/')) return env.ASSETS.fetch(request);
    if (url.pathname === '/api/reminders/config' && request.method === 'GET') {
      return env.PUSH_KEYS.getByName('v1').fetch(new Request('https://keys/public'));
    }
    if (url.pathname !== '/api/reminders' || !['PUT', 'DELETE'].includes(request.method)) return json({ error: 'Not found.' }, 404);
    if (request.headers.get('Origin') !== url.origin || !request.headers.get('Content-Type')?.startsWith('application/json')) return json({ error: 'Invalid request origin.' }, 403);
    if (Number(request.headers.get('Content-Length')) > 4096) return json({ error: 'Request too large.' }, 413);
    let body;
    try {
      const text = await request.text();
      if (text.length > 4096) return json({ error: 'Request too large.' }, 413);
      body = JSON.parse(text);
    } catch { return json({ error: 'Invalid request.' }, 400); }
    const sub = body?.subscription;
    if (!sub || !validEndpoint(sub.endpoint) || !/^[A-Za-z0-9_-]{22}={0,2}$/.test(sub.keys?.auth || '') ||
      !/^[A-Za-z0-9_-]{87}={0,2}$/.test(sub.keys?.p256dh || '')) return json({ error: 'Invalid push subscription.' }, 400);
    if (request.method === 'PUT' && !body.test && (!Number.isSafeInteger(body.dueAt) || !Number.isSafeInteger(body.cycleAt) || body.cycleAt <= 0 || !validTimezone(body.timeZone))) return json({ error: 'Invalid reminder schedule.' }, 400);
    const id = await digest(sub.endpoint);
    return env.REMINDERS.getByName(id).fetch(new Request('https://reminder/', {
      method: request.method, body: JSON.stringify({ ...body, subject: (env.PUBLIC_ORIGIN || url.origin) + '/' })
    }));
  }
};
