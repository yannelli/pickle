![A smiling little dill with a virtual-pet keychain](assets/illustrations/banner.webp)

# little dill.

Raise a pickle pet in your browser.

Open `index.html` to play, or serve this folder with any static web server. Progress saves in your browser.

A native iPhone and iPad app now lives in [`ios/`](ios/README.md), with **Brine Royale**, a real online survival arena with shared worlds and server-controlled bots, plus collectible outfits, animated care, sound effects, daily challenges, pass-and-play, and shareable scorecards. Open `ios/LittleDill.xcodeproj` to run it. The browser arena at [arena.littledill.app](https://arena.littledill.app) shares its live rooms with iOS; its dependency-free source lives in `arena-web/`. The official site is [littledill.app](https://littledill.app). It now features a dedicated Brine Royale section and direct arena links. The arena supports 64 players per room in a 6,000 × 4,500 garden, with matching web/iOS artwork, split/regroup, and quiet-room opponents.

The official landing site uses the separate `pickle-website` Worker. Its current response layer is preserved in `server/website-worker.mjs`; it adds the arena feature to the existing site assets. Deploy that module using Cloudflare’s Worker **content replacement** endpoint (`PUT /accounts/{account}/workers/scripts/pickle-website/content`, multipart `main_module: worker.js`) to preserve the deployed assets, routes, and `GAME_URL` binding. The root `wrangler.jsonc` deploys the separate browser pet, not the official landing site.

## Raise your pickle

Put a cucumber into Classic, Garlic, or Spicy brine. After 1 real minute, one of 6 varieties hatches and you name it. The app chooses and saves the variety once; closing or reloading the app does not change it. An unnamed hatchling waits safely for you.

Your pickle needs care about once a day. The app calculates elapsed time from timestamps, so time passes while the app is open or closed:

| Need | Change over 24 hours | Care |
| --- | --- | --- |
| Food | −36 | Feed adds up to 40 |
| Happiness | −24 | Pet +8; feed +3; clean +4; completed games +10 to 34 |
| Hygiene | −30 | Clean restores it to 100 |
| Energy | +48 naturally | Naps restore 30/hour; full energy wakes the pickle |

A daily feed, clean, game, and pet is enough even if the game goes badly. A healthy pickle can handle a weekend away. Food, happiness, or hygiene must stay empty for 48 more hours before the pickle dies. Low energy alone does not kill it. Restore every meter to 30 to recover from sickness. Pickles do not die of old age.

Baby pickles have a round body and pacifier. Young pickles are taller with a leaf, adults reach their full shape, and elders wear glasses and changing accessories. Pickles become young at 1 day, adults at 3 days, and elders at 14 days. Every 3 days after that, your pickle takes another of 32 elder forms, each with its own hat and accessory pairing, name, and lines. After all 32 forms, the cycle repeats indefinitely. All 6 varieties keep their own colors and shapes throughout life.

The app automatically migrates old local saves and encrypted v1 backups to a separate v2 local-save key. This prevents older open tabs from overwriting the new save. Migration preserves stats, life/death status, and the equivalent growth stage. Pickles receive a new grace period when upgrading from the old rapid-decay model. Existing pickles receive the name Little Dill.

## Play with your pickle

- Pet: tap your pickle or press P for +8 happiness every 2 seconds, without spending energy. Nap / Wake or S controls sleep. Tapping a sleeping pickle wakes it.
- Care: 1 / 2 / 3 operate the 3 physical buttons.
- Arcade: entry costs 6 energy. Completed games award 10 to 34 happiness, including a participation reward. Results show the actual gain, capped at 100. Replay or choose another game. Best scores stay in this browser, separately from pet backups.
  - Heart hunt: track the heart through 3 increasingly busy jar shuffles.
  - Dill says: repeat a growing sequence of shapes and notes across 5 levels.
  - Brine catch: use a tap, 1/2/3, or arrow keys to catch hearts, dodge salt, and build a streak over 12 drops.
- Do not eat your pickle. Type a certain three-letter word or hold your pickle down for a moment, and the app asks you to reconsider. Twice.
- Games pause while the page is hidden or a save preview is open. **Esc**, Games, or Back ends the current game without a completion reward.

## Push reminders

Reminders are off by default. The app requests permission after you press **Enable reminders**. The Push API and a Cloudflare Durable Object alarm deliver reminders even when the app is closed.

- Reminders arrive when care is due, at most once per 24 hours and once per care visit.
- Quiet hours: 10pm to 9am in the device's time zone, including daylight-saving changes. The app refreshes the time zone on your next visit.
- Ignoring a reminder does not trigger repeated daily reminders. Your next care visit enables another reminder.
- Notifications are silent, replace the same notification tag, and open the app when tapped. Delivery still follows OS notification settings and requires connectivity.
- **Turn reminders off** unsubscribes on the device and deletes the server schedule. **Send a test** sends a rate-limited test notification.
- On iPhone or iPad, add the app to your Home Screen and open it there first. Unsupported browsers and static-only hosts show an unavailable message.

The server stores a push endpoint, a hash of the subscription authorization secret, and the delivery schedule and time zone. Pet names, stats, and save files stay on the device. Inactive server records expire after 30 days. The server removes expired push endpoints after a 404/410 response. It generates VAPID keys once in private Durable Object storage. You do not need to copy secret keys or install new packages.

## Pickle radio

**Brine Time** is an original 132 BPM chiptune synthesized on your device. The 32-bar loop includes triangle bass, square-wave arpeggios and melody, synthesized kick, noise snare and hats, a breakdown, and a layered final section. It requires no audio files, network services, libraries, or licensed tracks.

Audio starts after a tap or keypress. The browser remembers the separate **Music** and **SFX** switches and shared volume slider. Feeding, cleaning, petting, sleep/wake, notes, catches, misses, and wins have distinct sounds. Music softens while the pickle sleeps, and all audio pauses when the page is hidden. Care and games also work when Web Audio or browser storage is unavailable.

## Save your pickle

- **Autosave:** the app saves progress locally after care actions, every 3 seconds while playing, and when the page is hidden. Existing saves still work. Browser data is specific to the browser and site address; clearing it removes the local save.
- **Download save:** click to create an encrypted `.dill` file without a password or account. Keep the file to move your progress between browsers or devices.
- **Import save:** select the file, check the saved age, condition and stats, then choose **Restore this pickle**. The current pickle stays intact until confirmation. **Undo import** restores it during the same page visit.
- The app processes files on the device without uploading them. Imports account for elapsed time the same way local restores do. They preserve the name, variety, and hatch/growth timestamps. If storage is blocked, file backups still work when browser encryption is available.

Backup files use browser-native [AES-256-GCM authenticated encryption](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/encrypt#supported_algorithms) with a fresh random IV for every export. Imports reject unsupported formats, invalid progress, oversized files and altered encrypted contents.

The app includes a stable format key so files transfer across devices without passwords. Encryption protects against casual file editing. The key is available in the client, so it does not provide private storage or prevent a player from modifying the app or forging a save. Local autosave uses browser-local JSON for compatibility. Players can also restore an older legitimate backup.

Encrypted backups require Web Crypto support in a secure context (HTTPS or localhost; local-file support depends on the browser). For local development, use `python3 -m http.server 4178 --bind 127.0.0.1` and open `http://127.0.0.1:4178`.

Run the dependency-free gameplay, audio, and save tests with Node 24:

```sh
node --test tests/*.test.cjs
```

## Install as an app

You can install the page as a progressive web app (PWA). Installation requires HTTPS or localhost. In Chrome or Edge, use the **Install little dill** button on the page. In Safari on iPhone or iPad, choose Share, then Add to Home Screen. `site.webmanifest` supplies the identity and icons, and `sw.js` caches the app shell so the installed app opens offline.

`sw.js` requests pages from the network and falls back to the cache. It serves assets from the cache while refreshing them in the background. There is no build step. Update `CACHE_VERSION` in `sw.js` with each deploy to remove the old cache on installed devices.

## Web assets

[Browse the asset gallery](assets/preview.html) · [Asset guide and generation prompts](assets/README.md)

The assets include an illustrated banner, transparent mascot sticker, outlined SVG logos, app icons, favicons, an Apple touch icon, and a 1200 × 630 OG image. The page includes Open Graph and Twitter card metadata and a web app manifest.

## Deploy

Deployment requires no frontend build step. The repo root contains the offline app, and `server/worker.mjs` supplies the optional reminder API.

**Cloudflare Workers** (static assets, config in `wrangler.jsonc`, uploads filtered by `.assetsignore`):

```sh
npx wrangler deploy
```

The first deploy also creates the `PushKeys` and `Reminder` SQLite Durable Object namespaces from the migration in `wrangler.jsonc`. Keep those namespaces and the stored signing key across updates so subscriptions continue working. `/api/*` bypasses the service-worker cache. Static assets exclude server files.

Or connect the repository in the Cloudflare dashboard under Workers & Pages and set the deploy command to `npx wrangler deploy`. Preview locally with `npx wrangler dev`.

**Vercel:** the offline app works on Vercel; reminders require the Cloudflare backend. `.vercelignore` filters uploads. Import the repository in the Vercel dashboard with framework preset "Other" and no build command, or run:

```sh
npx vercel
```

Once the public URL is known, follow the deployment notes in the asset guide to finish the sharing URLs.

## Validation

```sh
node --test tests/*.test.cjs
npx wrangler deploy --dry-run
npx wrangler dev
```

Tests cover daily care, weekend absences, continuous neglect, indefinite life with daily care, all elder boundaries, all varieties, migration and encrypted saves, arcade rewards, audio lifecycle, VAPID signature verification, time zones/DST, reminder deduplication, cancellation, expired subscriptions, and API input boundaries. To check push delivery, deploy over HTTPS, enable reminders from a supported browser or Home Screen app, and press **Send a test**.
