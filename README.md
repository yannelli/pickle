![A smiling little dill with a virtual-pet keychain](assets/illustrations/banner.webp)

# little dill.

A tiny pickle. A big responsibility. Your pocket pickle pet.

Open `index.html` to play, or serve this folder with any static web server. Progress saves in your browser.

## A pickle that fits your life

Put a cucumber into **Classic**, **Garlic**, or **Spicy** brine. After **one real minute**, one of six varieties hatches and you name it. The variety is chosen once and saved; closing or reloading the app does not reroll it. An unnamed hatchling waits safely for you.

**About one check-in a day.** Time passes whether the app is open or closed, using elapsed timestamps rather than active-tab ticks:

| Need | Change over 24 hours | Care |
| --- | --- | --- |
| Food | −36 | Feed adds up to 40 |
| Happiness | −24 | Pet +8; feed +3; clean +4; completed games +10–34 |
| Hygiene | −30 | Clean restores it to 100 |
| Energy | +48 naturally | Naps restore 30/hour; full energy wakes the pickle |

A daily feed, clean, game, and pet is enough even if the game goes badly. A healthy pickle can handle a weekend away. Empty food, happiness, or hygiene must remain neglected for **48 additional hours** before death; low energy alone never kills. Restore every meter to 30 to recover from sickness. There is **no death from old age**.

Baby pickles have a round body and pacifier; young pickles are taller with a leaf; adults reach their full shape; elders wear glasses and changing accessories. Growth happens at **1 day** (young), **3 days** (adult), and **14 days** (elder). Every three days after that brings another of **32 elder forms**, with unique hat/accessory pairings, names, and lines. After the complete collection, elder laps continue indefinitely. Six varieties retain their own colors and shapes throughout life.

Old local saves and encrypted v1 backups migrate automatically, preserving stats, life/death status, and the equivalent growth stage. They receive a new grace period when upgrading from the old rapid-decay model. Existing pickles are named Little Dill.

## Play with your pickle

- **Pet:** tap your pickle or press **P** for +8 happiness every two seconds, without spending energy. **Nap / Wake** or **S** controls sleep. Tapping a sleeping pickle wakes it.
- **Care:** **1 / 2 / 3** operate the three physical buttons.
- **Arcade:** entry costs 6 energy; completed games award 10–34 happiness, including a participation reward. Results show the actual gain, capped at 100. Replay directly or choose another game. Best scores stay in this browser, separately from pet backups.
  - **Heart hunt:** track the heart through three increasingly busy jar shuffles.
  - **Dill says:** repeat a growing sequence of shapes and notes across five levels.
  - **Brine catch:** use a tap, 1/2/3, or arrow keys to catch hearts, dodge salt, and build a streak over twelve drops.
- Games pause while the page is hidden or a save preview is open. **Esc**, Games, or Back ends the current game without a completion reward.

## Gentle push reminders

Reminders are **off by default** and permission is requested only after pressing **Enable reminders**. They work through the Push API and a Cloudflare Durable Object alarm even when the app is closed; browser timers are not used to simulate background delivery.

- Send only when a care check-in is due, at most once per 24 hours and once per care visit.
- Quiet hours: **10pm–9am in the device's time zone**, including daylight-saving changes. The time zone refreshes on your next visit.
- Ignoring a reminder does not cause repeated daily nudges. A new care visit rearms it.
- Notifications are silent, replace the same notification tag, and open the app when tapped. Delivery still follows OS notification settings and requires connectivity.
- **Turn reminders off** unsubscribes on the device and deletes the server schedule. **Send a test** is an explicit, rate-limited test delivery.
- iPhone/iPad users must first add the app to their Home Screen and open it there. Unsupported browsers and static-only hosts show a clear unavailable message.

The server stores a push endpoint, a hash of the subscription authorization secret, and delivery timing/time zone. Pet names, stats, and save files stay on the device. Inactive server records expire after 30 days; expired push endpoints are removed on a 404/410 response. VAPID keys are generated once in private Durable Object storage. No manually copied secret keys or new packages are needed.

## Pickle radio

**Brine Time** is an original, locally synthesized 132 BPM chiptune: triangle bass, square-wave arpeggios and melody, synthesized kick, noise snare and hats, a breakdown, and a layered final section in a 32-bar loop. No audio files, network services, libraries, or licensed tracks are required.

Audio starts after a tap or keypress. Independent **Music** and **SFX** switches and a shared volume slider are remembered in this browser. Feeding, cleaning, petting, sleep/wake, notes, catches, misses, and wins have distinct cues. Music softens while the pickle sleeps; all audio pauses when the page is hidden. Care and games also work when Web Audio or browser storage is unavailable.

## Save your pickle

- **Autosave:** progress saves locally after care actions and every three seconds while playing, with another save when the page is hidden. Existing saves still work. Browser data is specific to the browser and site address; clearing it removes the local save.
- **Download save:** one click creates an encrypted `.dill` file. No password or account is needed. Keep the file to move your progress between browsers or devices.
- **Import save:** select the file, check the saved age, condition and stats, then choose **Restore this pickle**. The current pickle stays intact until confirmation. **Undo import** restores it during the same page visit.
- Files are processed on the device and never uploaded. Imports apply the same daily elapsed-time behavior as local restores and preserve the name, variety, and hatch/growth timestamps. If storage is blocked, file backups still work when browser encryption is available.

Backup files use browser-native [AES-256-GCM authenticated encryption](https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/encrypt#supported_algorithms) with a fresh random IV for every export. Imports reject unsupported formats, invalid progress, oversized files and altered encrypted contents.

The app includes a stable format key so files transfer across devices without passwords. This is protection against casual file editing, not private storage or cheat-proof progress: the key is available in the client, and a determined player can modify the app or forge a save. Local autosave remains browser-local JSON for compatibility. Offline saves also cannot prevent restoring an older legitimate backup.

Encrypted backups require Web Crypto support in a secure context (HTTPS or localhost; local-file support depends on the browser). For local development, use `python3 -m http.server 4178 --bind 127.0.0.1` and open `http://127.0.0.1:4178`.

Run the dependency-free gameplay, audio, and save tests with Node 24:

```sh
node --test tests/*.test.cjs
```

## Install as an app

The page is an installable PWA: `site.webmanifest` supplies the identity and icons, and `sw.js` caches the app shell so the installed app opens offline. Chrome and Edge show an **Install little dill** button on the page; Safari on iPhone and iPad uses Share, then Add to Home Screen. Installation needs HTTPS or localhost.

`sw.js` serves pages network-first with a cached fallback, and assets from cache while refreshing in the background. There is no build step, so bump `CACHE_VERSION` in `sw.js` with each deploy to drop the old cache on installed devices.

## Web assets

[Browse the asset gallery](assets/preview.html) · [Asset guide and generation prompts](assets/README.md)

Includes an illustrated banner, transparent mascot sticker, outlined SVG logos, app icons, favicons, an Apple touch icon, and a 1200 × 630 OG image. The page includes Open Graph and Twitter card metadata and a web app manifest.

## Deploy

No frontend build step. The repo root contains the offline app; `server/worker.mjs` supplies the optional reminder API.

**Cloudflare Workers** (static assets, config in `wrangler.jsonc`, uploads filtered by `.assetsignore`):

```sh
npx wrangler deploy
```

The first deploy also creates the `PushKeys` and `Reminder` SQLite Durable Object namespaces from the migration in `wrangler.jsonc`. Keep those namespaces and the stored signing key across updates so subscriptions continue working. `/api/*` bypasses the service-worker cache, and server files are excluded from static assets.

Or connect the repository in the Cloudflare dashboard under Workers & Pages and set the deploy command to `npx wrangler deploy`. Preview locally with `npx wrangler dev`.

**Vercel (offline app only; reminders need the Cloudflare backend)** (uploads filtered by `.vercelignore`): import the repository in the Vercel dashboard with framework preset "Other" and no build command, or run:

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

Tests cover daily care, weekend absences, continuous neglect, indefinite life with daily care, all elder boundaries, all varieties, migration and encrypted saves, arcade rewards, audio lifecycle, VAPID signature verification, time zones/DST, reminder deduplication, cancellation, expired subscriptions, and API input boundaries. For a real push delivery check, deploy over HTTPS, enable reminders from a supported browser/Home Screen app, and press **Send a test**.
