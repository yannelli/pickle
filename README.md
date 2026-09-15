![A smiling little dill with a virtual-pet keychain](assets/illustrations/banner.webp)

# little dill.

A tiny pickle. A big responsibility. Your pocket pickle pet.

Open `index.html` to play, or serve this folder with any static web server. Progress saves in your browser.

## Play with your pickle

- **Pet:** tap your pickle or press **P** for +8 happiness every two seconds. This costs no energy, so even a tired or unhappy pickle can recover. Use the separate **Nap / Wake** button or **S** to rest. Tapping a sleeping pickle wakes it.
- **Care:** Feed adds up to 22 food and 3 happiness; Clean restores hygiene and adds 4 happiness. Full/clean pickles suggest another activity. **1 / 2 / 3** operate the three physical buttons.
- **Arcade:** Play opens three games. Entry costs 6 energy; completed games award 10–34 happiness, including a participation reward. Results show the actual happiness gained (capped at 100). Replay directly or choose another game. Each game's best score stays in this browser, separately from pet backups.
  - **Heart hunt:** track the heart through three increasingly busy jar shuffles.
  - **Dill says:** repeat a growing sequence of shapes and notes across five levels. Shapes and numbered pads work with sound off.
  - **Brine catch:** choose a lane with a tap, 1/2/3, or arrow keys. Catch hearts, dodge salt, and build a streak for extra points over twelve drops.
- Active games pause while the page is hidden or a save preview is open. Returning resumes the remaining timers; closing a game with **Esc**, Games, or Back ends it without a completion reward. Care still follows the normal away-time rules.

## Pickle radio

**Brine Time** is an original, locally synthesized 132 BPM chiptune: triangle bass, square-wave arpeggios and melody, synthesized kick, noise snare and hats, a breakdown, and a layered final section in a 32-bar loop. No audio files, network services, libraries, or licensed tracks are required.

Audio starts after a tap or keypress. Independent **Music** and **SFX** switches and a shared volume slider are remembered in this browser. Feeding, cleaning, petting, sleep/wake, notes, catches, misses, and wins have distinct cues. Music softens while the pickle sleeps; all audio pauses when the page is hidden. Care and games also work when Web Audio or browser storage is unavailable.

## Save your pickle

- **Autosave:** progress saves locally after care actions and every three seconds while playing, with another save when the page is hidden. Existing saves still work. Browser data is specific to the browser and site address; clearing it removes the local save.
- **Download save:** one click creates an encrypted `.dill` file. No password or account is needed. Keep the file to move your progress between browsers or devices.
- **Import save:** select the file, check the saved age, condition and stats, then choose **Restore this pickle**. The current pickle stays intact until confirmation. **Undo import** restores it during the same page visit.
- Files are processed on the device and never uploaded. Imports apply the same capped 15-minute away-time behavior as local restores. If storage is blocked, file backups still work when browser encryption is available.

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

No build step. The repo root is the site.

**Cloudflare Workers** (static assets, config in `wrangler.jsonc`, uploads filtered by `.assetsignore`):

```sh
npx wrangler deploy
```

Or connect the repository in the Cloudflare dashboard under Workers & Pages and set the deploy command to `npx wrangler deploy`. Preview locally with `npx wrangler dev`.

**Vercel** (uploads filtered by `.vercelignore`): import the repository in the Vercel dashboard with framework preset "Other" and no build command, or run:

```sh
npx vercel
```

Once the public URL is known, follow the deployment notes in the asset guide to finish the sharing URLs.
