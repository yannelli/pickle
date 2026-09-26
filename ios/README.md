# Little Dill for iOS

A native SwiftUI pet with **Brine Royale**, a real online survival arena shared with the browser client at **https://arena.littledill.app**. The official site is **https://littledill.app**. Collect food, grow, absorb smaller pickles, and dash out of trouble. Server-controlled bots fill quiet gardens and give up slots as people join.

## Run the app

Open `LittleDill.xcodeproj`, choose **LittleDill**, select an iPhone or iPad simulator, and press Run. Targets iOS 17+. No third-party packages are needed.

The committed Xcode project is ready to use. If `project.yml` changes, regenerate it with XcodeGen:

```sh
xcodegen generate --spec ios/project.yml
```

For a physical iPhone or iPad, select your Apple development team in Signing & Capabilities and a unique bundle identifier if required. Build and install through Xcode or `xcodebuild` and `xcrun devicectl`. Device installation, successful launch, gameplay checks, and TestFlight distribution are separate verification steps.

## Brine Royale

- **Real shared matches:** clients connect to a public HTTPS/WebSocket service. Movement, growth, eating, protection, dash costs, and respawns are calculated by one authoritative simulation per room.
- **Public matchmaking:** up to 64 human players per room. Full gardens spill into the next public room, up to 16 public rooms in this initial configuration.
- **Quiet-room opponents:** each garden fills to 32 participants. Bots have varied awareness/intelligence/risk profiles and independently forage, flee, chase, dash, split, and respawn. Public gardens seed varied starting masses up to 5,000, weighted toward small pickles, and include one harder opponent. Crew-room bots start small. Gadget encounters include curiosity, retreat, detours, and a rare committed crossing. Joining humans replace bots one-for-one. The UI shows total participants and names without bot badges; the protocol retains opponent types.
- **Private crew rooms:** create a six-character code, share it, or join a friend's code from the Friends tab. `https://arena.littledill.app/?room=ABC123` opens the installed native app through Universal Links, or the browser arena. Legacy `littledill://arena?room=ABC123` links remain supported.
- **Larger garden, fast starts:** the world is 6,000 × 4,500 units, 6.25 times its previous area. Its 3,375 pellets preserve food density: 3 mass normally or 9 for peach bonus snacks. Every human spawn/respawn gets a nearby food trail. Thirty seeded food-only regression journeys reach 100 mass in under ten seconds; real combat and steering affect this.
- **Controls:** drag the thumbstick to move; Swap changes its side and remembers the choice. A center dead zone and curved response control steering. Dash requires 35 mass, costs 5, and has a four-second cooldown. Buttons show availability and cooldowns; the HUD shows mass, rank, participants, and a minimap. Native haptics distinguish steering, dash, split, food, nearby threats, bites, gadgets, regrouping, and death.
- **Arena coins:** collect 1,000 mass from food or absorbed opponents to earn one closet coin, up to 1,000 coins for 1,000,000 collected mass per UTC day. The HUD shows today's coins. Fractional progress and the last credited total survive saves, backups, and reconnects; starting mass and split/regroup changes earn nothing.
- **Consistent artwork:** native and web share six upright silhouettes: classic dill, stubby gherkin, pear-shaped garlic, round butter bean, tapered chili, and ribbed pepper. Each keeps its color, smile, and accessories. Split pieces use the same cucumber body on both clients. Losing a piece gives the survivor a sad face for 15 seconds, with a server-selected 25% chance of one small tear. Threats get a red body outline; contact membranes dent without changing collision geometry. Zoom eases between sizes. The native arena and arcade use the full screen.
- **Efficient updates:** clients opt into `foodDeltas=1` for a full food inventory on join, then ordered removal/upsert updates at the original 5 Hz cadence. Legacy clients continue receiving full food snapshots.
- **No mass ceiling:** food and absorbed players continue adding mass beyond 1,600. Large bodies grow more gradually to keep the garden navigable; movement remains usable and both cameras adapt to their size. Best runs save without the old ceiling.
- **Split and regroup:** at 60 mass in a piece, tap Split to launch a half forward. Eligible pieces can split again after one second, up to eight total. Split pieces turn into fresh green cucumbers with pale stripes, keeping their faces and accessories. They share steering and automatically pull back together after 12 seconds; splitting again restarts that timer. Once one piece remains, its original pickle shape and brine color return. Mass is conserved. Each piece eats and can be eaten independently; losing the final piece ends the run. Rankings and bests use total mass, with one decay allowance and one dash cost per player.
- **Kitchen gadgets:** a slicer, salt shaker, and grater slow touching pieces to half speed. Drained mass becomes food around the gadget. Draining stops at 500 mass per piece; touching pieces over 2,500 mass split automatically, with a two-second gadget split cooldown and eight-piece limit. Ground scatter marks each gadget's area without a bordered field. Each gadget has its own animation, sound, and native haptic rhythm.
- **Gentle decay:** mass up to 300 never decays. Eating restarts an eight-second grace period; afterward only mass above 300 decays, at 0.1% per second of that excess. A 1,000-mass pickle loses less than 5% in a quiet minute.
- **Survival:** a hunter must have at least 1.22 times the prey's mass, and their center distance must be below `hunterRadius - 0.6 * preyRadius`. Fresh spawns are protected for four seconds and cannot eat players while protected. After being eaten, respawn after two seconds. The pet in your Nest is unaffected.
- **Rejoining:** unexpected disconnects reserve the run for 30 seconds outside combat. Resume restores identity, mass, pieces, room, and paused timers using a secret reconnect token. Clients retain the token across reloads or app relaunches; expired recovery asks for a fresh join. Explicit exit revokes recovery. One-second Durable Object checkpoints preserve recoverable runs across server restarts, and active sessions have no fixed time limit.

The arena is a casual anonymous game. Native wardrobe ownership and pet progress are local; there is no account, cross-device inventory, permanent online ranking, or paid economy.

## Browser play

Open https://arena.littledill.app. The web client connects to the same rooms and server rules as iOS. Use WASD/arrow keys or mouse steering on desktop, or the thumbstick on touch screens; press Space or tap Dash. Press E or tap Split to launch pieces; the status below the controls shows the regroup countdown. Share a friend-room link to meet across platforms. Enable sound with the speaker button. Four quiet pickup clips rotate with reduced volume and frequency during continuous collection; losing a piece or being eaten plays a crunch.

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

The native app requires `wss://`. Local Node integration tests support `ws://127.0.0.1:8788/arena` without changing the app's transport security. Rooms simulate at 20 Hz and broadcast at 10 Hz; food updates at 5 Hz. The native Canvas interpolates snapshots at display frame rate. Simulation stops when the last human disconnects; recovery reservations expire after 30 seconds. Transports time out after 15 seconds without input or heartbeats. Checkpoints run once per second and on session changes. Live rooms consume Worker/Durable Object resources; account quotas still apply.

The server accepts bounded direction inputs and monotonic sequence numbers rather than client positions or scores. It rejects unknown messages, applies a per-socket input budget, and limits each room to eight connections per source IP. These are initial abuse controls, not a claim of complete production anti-cheat or global abuse protection.

## The rest of your pickle's world

- Pet care follows the browser rules in `../pet-life.js`. Put a cucumber in Classic, Garlic, or Spicy brine; one of 6 varieties hatches after 1 real minute, even with the app closed, and you name it. Pickles grow from baby (under 1 day) to young, teen (a new stereotype each day from day 3), adult (day 7), and elder (day 14, a new one of 32 forms every 3 days).
- Feed adds 40 food, Pet adds 8 happiness every 2 seconds, Clean restores hygiene, and Nap/Wake controls sleep. Needs drain by real elapsed time; a food, happiness, or hygiene meter left empty for 48 more hours ends the pickle's life. Daily care awards 5 coins per action once each day.
- The Nest mirrors the web moods (happy, hungry, sick, sleeping, scared), idle acts (hop, look, stretch, wiggle, turn), content vibes (shades, lounge, book, campfire), the mess pile, a profile card, and the elder club collection. Hold the pickle to find the eat-your-pickle secret; Restart starts a new egg and keeps coins and outfits.
- Play opens the full-screen pet arcade: Heart hunt, Dill says, and Brine catch from the web, plus iOS-only Countertop escape (run through seeded kitchen scenery, jump varied kitchen obstacles, and build dill streaks), Cuke chop (swipe cucumbers, spare your pickle), and Jar toss (pull back and fling your pickle into a jar). Play wakes a napping pickle and opens the menu for free. Starting a game costs 6 energy; completed games award 10 to 34 happiness. Countertop escape keeps the saved `hop` score key and reserves haptic feedback for milestones and collisions.
- The iOS Daily Circuit uses UTC-date seeds for Countertop escape, Cuke chop, and Jar toss. Each contributes up to 100 points; completing all three unlocks medal scoring. Progress persists across launches, and replay improves each day's best. It uses the regular arcade entry and reward rules.
- Care has distinct layered cartoon scenes: chewing and crumbs, stroking and hearts, shower/foam/bubbles, and a moonlit blanket with breathing. Feeding rotates through carrot, strawberry, broccoli, apple, and cheese using the same sequence as web; successful feeds advance the saved local sequence. Controls remain beside the visible scene after tapping, including on compact phones. Repeat actions restart cleanly.
- Care, dash, bites, respawns, and games have distinct sounds. Native gadget loops are rendered from the web synthesis; pickup WAVs are identical across platforms. Settings → Sound effects persists across launches; native sounds honor Silent Mode and mix with music. Old saves default to sounds enabled without losing progress.
- Play **Daily Crunch**, three six-second precision rounds with a shared UTC-date seed. Earn up to 300 points and 25 coins for the first completion that day. Replay to improve your personal best.
- Play **Pass the Pickle** with 2–4 people sharing one phone, including turn handoffs, rankings, and joint winners. This mode and the daily game work offline.
- Unlock 18 outfits with earned coins, including two free looks. Arena players on web and iOS see the same equipped accessories. No purchases or ads.
- Share a rendered PNG pet/score card using the native share sheet. Daily links use `littledill://challenge/YYYY-MM-DD`. Custom-scheme links require the installed app; they do not install it. Arena invitations use HTTPS Universal Links and fall back to browser play. Daily challenge links still require the installed app. No App Store listing is configured yet.

## Data and privacy

Pet progress, outfits, daily scores, arcade bests, and arena personal best are stored in this app's UserDefaults container under `little-dill.native.v1`. Version 1 native saves migrate to the browser pet format on launch. There is no cloud sync.

Settings → Backups exports and imports the browser's encrypted `.dill` files (AES-256-GCM, same format key as `../save-codec.js`). A browser backup opens in the app and an app backup opens in the browser. App backups carry coins, outfits, scores, circuit progress, and settings in a `native` field that the browser preserves through import, reload, and export. Shared arcade bests merge during browser export. Import previews age, condition, and stats before confirmation; Undo import restores the previous pickle during the same session. Opening a `.dill` file from Files, Mail, or AirDrop shows the same preview. Out-of-range progress is repaired with import limits; an unreadable save starts a new egg and retains the first recovery copy for export. Erasing progress requires confirmation and removes that recovery copy.

Online arenas send the chosen pet name, appearance, and movement intent to the server. Other people in the same room see names, positions, appearance, mass, and scores. The server uses source IPs to limit concurrent connections. Temporary world state and reconnect records are checkpointed in Durable Object SQLite storage; recovery records expire and empty rooms clear their checkpoint. Reconnect tokens stay in local app/browser storage and are excluded from pet backups. Hosting-provider operational metadata is governed by the hosting account's configuration. There is no chat, contact upload, tracking, or analytics SDK.

`PrivacyInfo.xcprivacy` declares app-local UserDefaults and monotonic time for precision rounds. The app does not request camera, microphone, contacts, location, push, or photo-library permission. Sharing uses system-provided destinations. Reduced Motion keeps blinking and fades and drops the pet's loops and acts; essential arena/game motion remains functional. VoiceOver labels and directional actions are available for the arena thumbstick.

## Verification

```sh
# Rules and web regression tests (dependency-free Node 24).
node --test tests/*.test.cjs

# Integration against real WebSocket clients and room instances.
node tests/arena-live.cjs ws://127.0.0.1:8788/arena
node tests/arena-live.cjs wss://arena.littledill.app/arena
node tests/arena-split-live.cjs wss://arena.littledill.app/arena
node tests/arena-reconnect-live.cjs ws://127.0.0.1:8788/arena

# Local crash/restart check; starts its own Worker on port 8795.
WRANGLER_BIN=/path/to/wrangler node tests/arena-restart-live.cjs

# Native model and UI tests; replace the simulator destination as needed.
xcodebuild -project ios/LittleDill.xcodeproj -scheme LittleDill \
  -destination 'platform=iOS Simulator,name=Little Dill iPhone' \
  -derivedDataPath ios/build CODE_SIGNING_ALLOWED=NO test
```

The explicit live tests check matchmaking, room isolation, synchronized state, eight-piece splitting, reconnect expiry, token ownership, and process restart recovery. Unit suites cover arena rules, bot encounters, feeding variety, sound scheduling, controls, circuit scoring, save round trips, and the shared `tests/fixtures/arena-parity.json` values. Native UI journeys cover care, games, control layout, and arena joining; screenshots remain in `.xcresult` attachments. State which suites and device checks were run when reporting a build.

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
| `ArcadeGames.swift`, `ArcadeViews.swift` | Heart hunt, Dill says, Brine catch, and the shared `ArcadePlay` session |
| `ArcadeArt.swift`, `ArcadeHop.swift`, `HopScenery.swift`, `ArcadeChop.swift`, `ArcadeChopBoard.swift`, `ArcadeToss.swift`, `ArcadeTossBoard.swift` | Countertop escape, Cuke chop, Jar toss |
| `ArcadeCircuit.swift`, `ArcadeCircuitView.swift` | Seeded daily action-game scores and medals |
| `BackupViews.swift` | Backup export, import, preview, and opening `.dill` files |
| `Design.swift` | Palette, components, vector character, animated garden |
| `CareScene.swift`, `FeedFood.swift` | Care scenes, feeding sequence, food art, and bite timing |
| `DillAudio.swift` | Original PCM effects and silent-mode-aware native playback |
| `LittleDillApp.swift` | Navigation, ticking, deep links |
| `GameViews.swift` | Daily challenge, pass-and-play, timing, results |
| `CollectionViews.swift` | Wardrobe, settings, image sharing |
| `ArenaClient.swift` | Secure WebSocket session, input loop, state decoding |
| `ArenaView.swift` | Interpolated native arena, controls, HUD, respawns |
| `ArenaControls.swift`, `ArenaFeedback.swift` | Swappable controls, cooldown displays, native haptics |
| `ArenaExpression.swift`, `ArenaResume.swift` | Skin smiles, pickup cadence, persisted reconnect credentials |
| `FriendsView.swift` | Public arena entry, private-room invitations |
| `../server/arena-engine.mjs` | Authoritative simulation and bot AI |
| `../server/arena-worker.mjs` | Matchmaking, sockets, room lifecycle, input limits |

Platform references: [Cloudflare Durable Object WebSockets](https://developers.cloudflare.com/durable-objects/best-practices/websockets/), [Apple URLSessionWebSocketTask](https://developer.apple.com/documentation/foundation/urlsessionwebsockettask), [SwiftUI ImageRenderer](https://developer.apple.com/documentation/swiftui/imagerenderer).
