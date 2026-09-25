# Cloudflare Workers Rate Limiting binding

Created: 2026-09-23
Last updated: 2026-09-23

## What it is

A Worker binding that counts calls per key and reports whether a key is over its limit. The Worker calls `env.NAME.limit({ key })` and gets `{ success }`. `success` is `false` once the key exceeds `limit` calls within `period` seconds.

## Config used

`wrangler.arena.jsonc`:

```jsonc
"ratelimits": [{ "name": "CREW_JOINS", "namespace_id": "2101", "simple": { "limit": 10, "period": 60 } }]
```

`server/arena-worker.mjs` calls `env.CREW_JOINS.limit({ key: ip })` before it forwards a crew-room (`?room=`) WebSocket join to a Durable Object. `ip` is the resolved client IP: `X-Arena-Client-IP` from the legacy proxy when `X-Arena-Proxy-Secret` matches `ARENA_PROXY_SECRET`, else `CF-Connecting-IP`. A refused join returns 429 `{"error":"Too many private rooms. Try again in a minute."}`. Public matchmaking skips the check. When the binding is absent (unit tests, `wrangler.arena-legacy.jsonc`), the Worker skips the check.

`wrangler deploy --dry-run -c wrangler.arena.jsonc` with Wrangler 4.137.0 lists `env.CREW_JOINS (10 requests/60s) Rate Limit`.

## Limits and behavior

- `simple` is the only supported type. `simple.period` accepts `10` or `60` seconds.
- `namespace_id` is a positive integer written as a string, unique within the Cloudflare account. Bindings with the same `namespace_id` share counters for a key, across Workers on the same account.
- Counters are local to the Cloudflare location running the Worker. Each key has a separate limit per location.
- Cloudflare describes the API as permissive and eventually consistent. It is not an accurate accounting system.
- `limit()` reads cached in-memory counters on the host and does not wait on a network request.
- The binding requires Wrangler 4.36.0 or later.
- Cloudflare recommends keys such as API keys, user IDs, or routes over IP addresses, since many users share one IP. The arena has no accounts, so it keys on IP. Players behind one NAT share 10 crew joins per minute per Cloudflare location.

## When to use

Use it to cap abuse-prone actions per key at the edge: here, creation of crew-room Durable Objects. Use a Durable Object or database counter when the count must be exact or global.

## Sources

- https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/ (page last updated 2026-04-23, fetched 2026-09-23)
- Context7 `/llmstxt/developers_cloudflare_workers_llms-full_txt`, section "Rate Limiting" (Wrangler 4.36.0 requirement, shared `namespace_id` counters)
