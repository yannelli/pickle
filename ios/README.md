# Little Dill for iOS

A native SwiftUI pet with **Brine Royale**, a real online survival arena shared with the browser client at **https://arena.littledill.app**. The official site is **https://littledill.app**. Collect food, grow, absorb smaller pickles, and dash out of trouble. Server-controlled bots fill quiet gardens and give up slots as people join.

## Run the app

Open `LittleDill.xcodeproj`, choose **LittleDill**, select an iPhone or iPad simulator, and press Run. Targets iOS 17+. No third-party packages are needed.

The committed Xcode project is ready to use. If `project.yml` changes, regenerate it with XcodeGen:

```sh
xcodegen generate --spec ios/project.yml
```

For a physical iPhone or iPad, select your Apple development team in Signing & Capabilities and a unique bundle identifier if required. A signed Release build was installed over the local network on an iPhone 16 Pro Max running iOS 27.2 on September 17, 2026; launch and the welcome screen were verified on the device. TestFlight and App Store submission have not been performed.

## Brine Royale

- **Real shared matches:** clients connect to a public HTTPS/WebSocket service. Movement, growth, eating, protection, dash costs, and respawns are calculated by one authoritative simulation per room.
- **Public matchmaking:** up to 64 human players per room. Full gardens spill into the next public room, up to 16 public rooms in this initial configuration.
- **Quiet-room opponents:** each garden fills to 32 participants. Simulated opponents use varied, unique everyday handles, independently forage, flee larger opponents, chase smaller ones, dash, split, and respawn. Joining humans replace them one-for-one. The UI shows total participants and names without bot badges; the protocol retains opponent types.
- **Private crew rooms:** create a six-character code, share it, or join a friend's code from the Friends tab. `https://arena.littledill.app/?room=ABC123` opens the installed native app through Universal Links, or the browser arena. Legacy `littledill://arena?room=ABC123` links remain supported.
- **Larger garden, fast starts:** the world is 6,000 × 4,500 units, 6.25 times its previous area. Its 3,375 pellets preserve food density: 3 mass normally or 9 for peach bonus snacks. Every human spawn/respawn gets a nearby food trail. Thirty seeded food-only regression journeys reach 100 mass in under ten seconds; real combat and steering affect this.
- **Controls:** drag the left thumbstick to move; tap Dash after reaching 35 mass. A dash costs 5 mass and has a four-second cooldown. The live HUD shows mass, rank, total participants, and a minimap.
- **Consistent artwork:** native and web share flat capsule silhouettes, brine colors, faces, circular food, dashed shields, and lime dash halos. Faint 900-unit garden regions, leaf motifs, and sector labels add scale while leaving the playfield clear.
- **Efficient updates:** clients opt into `foodDeltas=1` for a full food inventory on join, then ordered removal/upsert updates at the original 5 Hz cadence. Legacy clients continue receiving full food snapshots.
- **No mass ceiling:** food and absorbed players continue adding mass beyond 1,600. Large bodies grow more gradually to keep the garden navigable; movement remains usable and both cameras adapt to their size. Best runs save without the old ceiling.
- **Split and regroup:** at 60 mass in a piece, tap Split to launch a half forward. Eligible pieces can split again after one second, up to four total. Split pieces turn into fresh green cucumbers with pale stripes, keeping their faces and accessories. They share steering and automatically pull back together after 12 seconds; splitting again restarts that timer. Once only one piece remains, its original pickle shape and brine color return. Mass is conserved. Each piece eats and can be eaten independently; only losing the final piece ends the run. Rankings and bests use total mass, with one decay allowance and one dash cost per player.
- **Gentle decay:** mass up to 300 never decays. Eating restarts an eight-second grace period; afterward only mass above 300 decays, at 0.1% per second of that excess. A 1,000-mass pickle loses less than 5% in a quiet minute.
- **Survival:** a pickle must be at least 22% larger to absorb another. Fresh spawns are protected for four seconds and cannot eat players while protected. After being eaten, respawn after two seconds. The pet in your Nest is unaffected.
- **Rejoining:** losing connectivity presents a retry; returning from the background offers a fresh spawn. Session-best mass saves on death, leaving, or backgrounding. Live session progress is ephemeral; rejoining starts at 25 mass.

The arena is a casual anonymous game. Native wardrobe ownership and pet progress are local; there is no account, cross-device inventory, permanent online ranking, or paid economy.

## Browser play

Open https://arena.littledill.app. The web client connects to the same rooms and server rules as iOS. Use WASD/arrow keys or mouse steering on desktop, or the thumbstick on touch screens; press Space or tap Dash. Press E or tap Split to launch pieces; the status below the controls shows the regroup countdown. Share a friend-room link to meet across platforms. Browser sound starts off and can be enabled with the speaker button. Normal food pickups have no sound or burst effects.

`../arena-web/` contains the dependency-free HTML, CSS, Canvas client, and shared geometry helpers. Wrangler uploads these assets alongside the arena Worker; the existing site at `littledill.app` and pet at `play.littledill.app` retain their own deployments.

## Live backend and deployment

`Info.plist` → `ArenaServerURL` configures the secure WebSocket endpoint:

- Health: `https://arena.littledill.app/health`
- Game: `wss://arena.littledill.app/arena`

The original preview account has been claimed and verified through authenticated Cloudflare access. The primary deployment now lives in the account owning `littledill.app`. The original `little-dill-arena.veil-shear.workers.dev` endpoint forwards to the primary arena so older installs share the same rooms. `../wrangler.arena-legacy.jsonc` preserves that compatibility deployment. Claim tokens are not stored in the repository.

The arena is a separate Worker, configured by `../wrangler.arena.jsonc`. It does not replace the existing browser game's Worker or its push-reminder objects. It uses the existing Wrangler toolchain and Cloudflare Durable Objects, with no new npm dependencies.

From the repository root:

```sh
# Authenticate to your own Cloudflare account for permanent hosting.
npx wrangler login
npx wrangler deploy --config wrangler.arena.jsonc
# Only when updating compatibility routing for older installed apps:
npx wrangler deploy --config wrangler.arena-legacy.jsonc

# Run the actual Worker and Durable Object locally.
npx wrangler dev --config wrangler.arena.jsonc --port 8788
```

The native app requires `wss://`. Local Node integration tests support `ws://127.0.0.1:8788/arena` without changing the app's transport security. Rooms simulate at 20 Hz and broadcast at 10 Hz; food updates at 5 Hz. The native Canvas interpolates snapshots at display frame rate. Simulation stops when the last human leaves. Bots do not keep abandoned rooms alive. Sessions time out after 15 seconds without input or 30 minutes total. Live active rooms consume Worker/Durable Object resources; account quotas still apply.

The server accepts bounded direction inputs and monotonic sequence numbers rather than client positions or scores. It rejects unknown messages, applies a per-socket input budget, and limits each room to eight connections per source IP. These are initial abuse controls, not a claim of complete production anti-cheat or global abuse protection.

## The rest of your pickle's world

- Pet care follows the browser rules in `../pet-life.js`. Put a cucumber in Classic, Garlic, or Spicy brine; one of 6 varieties hatches after 1 real minute, even with the app closed, and you name it. Pickles grow from baby (under 1 day) to young, teen (a new stereotype each day from day 3), adult (day 7), and elder (day 14, a new one of 32 forms every 3 days).
- Feed adds 40 food, Pet adds 8 happiness every 2 seconds, Clean restores hygiene, and Nap/Wake controls sleep. Needs drain by real elapsed time; a food, happiness, or hygiene meter left empty for 48 more hours ends the pickle's life. Daily care awards 5 coins per action once each day.
- The Nest mirrors the web moods (happy, hungry, sick, sleeping, scared), idle acts (hop, look, stretch, wiggle, turn), content vibes (shades, lounge, book, campfire), the mess pile, a profile card, and the elder club collection. Hold the pickle to find the eat-your-pickle secret; Restart starts a new egg and keeps coins and outfits.
- Play opens the pet arcade: Heart hunt, Dill says, and Brine catch. Entry costs 6 energy; completed games award 10 to 34 happiness.
- Care has distinct layered cartoon scenes: chewing and crumbs, stroking and hearts, shower/foam/bubbles, and a moonlit blanket with breathing. Controls remain beside the visible scene after tapping, including on compact phones. Repeat actions restart cleanly.
- Original synthesized PCM sound effects accompany care, dash, eating/respawns, and challenge results. Ordinary food pickups are quiet and have no burst effects. Settings → Sound effects persists across launches; native sounds honor Silent Mode and mix with music. Old saves default to sounds enabled without losing progress.
- Play **Daily Crunch**, three six-second precision rounds with a shared UTC-date seed. Earn up to 300 points and 25 coins for the first completion that day. Replay to improve your personal best.
- Play **Pass the Pickle** with 2–4 people sharing one phone, including turn handoffs, rankings, and joint winners. This mode and the daily game work offline.
- Unlock six outfits with earned coins, including two free looks. No purchases or ads.
- Share a rendered PNG pet/score card using the native share sheet. Daily links use `littledill://challenge/YYYY-MM-DD`. Custom-scheme links require the installed app; they do not install it. Arena invitations use HTTPS Universal Links and fall back to browser play. Daily challenge links still require the installed app. No App Store listing is configured yet.

## Data and privacy

Pet progress, outfits, daily scores, arcade bests, and arena personal best are stored in this app's UserDefaults container under `little-dill.native.v1`. Version 1 native saves migrate to the browser pet format on launch. There is no cloud sync.

Settings → Backups exports and imports the browser's encrypted `.dill` files (AES-256-GCM, same format key as `../save-codec.js`). A browser backup opens in the app and an app backup opens in the browser. App backups carry coins, outfits, scores, and settings in an extra `native` field that the browser ignores. Import shows the saved age, condition, and stats before **Restore this pickle**; **Undo import** restores the previous pickle during the same session. Opening a `.dill` file from Files, Mail, or AirDrop shows the same preview. Invalid saves are preserved under a recovery key. Erasing progress requires confirmation.

Online arenas send the chosen pet name, appearance, and movement intent to the server. Other people in the same room see names, positions, appearance, mass, and scores. The server uses source IPs in memory to limit concurrent connections. Live world/session data is temporary and is not written to a database; the room clears when its last human leaves. Hosting-provider operational metadata is governed by the hosting account's configuration. There is no chat, contact upload, tracking, or analytics SDK.

`PrivacyInfo.xcprivacy` declares app-local UserDefaults and monotonic time for precision rounds. The app does not request camera, microphone, contacts, location, push, or photo-library permission. Sharing uses system-provided destinations. Reduced Motion keeps blinking and fades and drops the pet's loops and acts; essential arena/game motion remains functional. VoiceOver labels and directional actions are available for the arena thumbstick.

## Verification

```sh
# Rules and web regression tests (dependency-free Node 24).
node --test tests/*.test.cjs

# Integration against real WebSocket clients and room instances.
node tests/arena-live.cjs ws://127.0.0.1:8788/arena
node tests/arena-live.cjs wss://arena.littledill.app/arena
node tests/arena-split-live.cjs wss://arena.littledill.app/arena

# Native model and UI tests; replace the simulator destination as needed.
xcodebuild -project ios/LittleDill.xcodeproj -scheme LittleDill \
  -destination 'platform=iOS Simulator,name=Little Dill iPhone' \
  -derivedDataPath ios/build CODE_SIGNING_ALLOWED=NO test
```

The explicit live test checks public matchmaking, private-room sharing/isolation, identical ticks across clients, remote movement, rejection of forged state, disconnect removal, and bot refill. Unit tests cover the authoritative simulation's eating, protection, bots, respawns, input bounds, movement, and economy. Native journeys exercise adoption, care, wardrobe purchases, relaunch persistence, image sharing, solo/party games, and joining and steering in the public online arena. Native screenshots are retained in `.xcresult` attachments; selected captures are in `evidence/`.

Online UI tests require the configured server to be available. Debug-only `--ui-testing --reset` arguments isolate test progress from a normal user's local pet. Release builds ignore these arguments.

## Source map

| File | Responsibility |
| --- | --- |
| `PetLife.swift` | Swift port of the browser pet rules (`pet-life.js`) |
| `DillBackup.swift` | `.dill` backup codec shared with the browser |
| `DillModel.swift` | Native save, care actions, economy, daily course, links |
| `DillStore.swift` | Persistence, ticking, backups, and undo |
| `NurseryView.swift` | Brine choice, hatching, naming |
| `NestView.swift`, `NestProfile.swift`, `NestText.swift` | Meters, care controls, messages, profile, elder club |
| `PetLooks.swift`, `PetArtData.swift`, `PetArtShapes.swift` | Varieties, stages, teen and elder hats and props |
| `PetMotion.swift`, `PetStage.swift` | Moods, idle acts, vibes, animation clock |
| `ArcadeGames.swift`, `ArcadeViews.swift` | Heart hunt, Dill says, Brine catch |
| `BackupViews.swift` | Backup export, import, preview, and opening `.dill` files |
| `Design.swift` | Palette, components, vector character, animated garden |
| `CareScene.swift` | Action-specific cartoon props, expressions, and animation timing |
| `DillAudio.swift` | Original PCM effects and silent-mode-aware native playback |
| `LittleDillApp.swift` | Navigation, ticking, deep links |
| `GameViews.swift` | Daily challenge, pass-and-play, timing, results |
| `CollectionViews.swift` | Wardrobe, settings, image sharing |
| `ArenaClient.swift` | Secure WebSocket session, input loop, state decoding |
| `ArenaView.swift` | Interpolated native arena, controls, HUD, respawns |
| `FriendsView.swift` | Public arena entry, private-room invitations |
| `../server/arena-engine.mjs` | Authoritative simulation and bot AI |
| `../server/arena-worker.mjs` | Matchmaking, sockets, room lifecycle, input limits |

Platform references: [Cloudflare Durable Object WebSockets](https://developers.cloudflare.com/durable-objects/best-practices/websockets/), [Apple URLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask), [SwiftUI ImageRenderer](https://developer.apple.com/documentation/swiftui/imagerenderer).
