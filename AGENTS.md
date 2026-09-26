# Little Dill contributor guide

## Scope and workflow

- Inspect the branch, worktree status, and diff before editing. Preserve existing work and other worktrees.
- Keep changes within the request. Show a short plan before changes spanning more than three files or multiple subsystems.
- Use existing patterns and dependencies. Ask before adding a dependency.
- Delegate disjoint implementation work for large tasks; keep shared contracts under one owner.
- Run one verification pass covering the changed behavior. After a failure or further edit, rerun the affected checks.
- Report checks that ran and distinguish simulator evidence, device installation, device launch, and physical-device behavior.
- Commit, push, deploy, or publish when authorized. Use Conventional Commit titles such as `feat(arena): ...`, `fix(ios): ...`, and `docs: ...` for commits and PRs.
- Keep replies concise and include changed paths. Use short comments where the code needs explanation.

## Repository map

| Path | Role |
| --- | --- |
| `index.html`, `pet-life.js`, `pet-art.js`, `audio.js` | Browser pet, care scenes, three classic games, synthesized radio |
| `save-codec.js`, `sw.js` | Encrypted backups and PWA cache |
| `server/worker.mjs`, `reminders.js` | Browser push reminders |
| `server/arena-engine.mjs` | Authoritative arena rules, mass, gadgets, and bots |
| `server/arena-worker.mjs` | Matchmaking, sockets, security limits, checkpoints, and recovery |
| `arena-web/` | Dependency-free browser arena, art, expressions, and audio |
| `ios/LittleDill/` | Native SwiftUI app, arena, pet, and six arcade games |
| `ios/project.yml` | XcodeGen project definition; commit the generated Xcode project too |
| `tests/`, `ios/LittleDillTests/`, `ios/LittleDillUITests/` | Web/server, native unit, and native UI checks |
| `tests/fixtures/arena-parity.json` | Shared values checked by JavaScript and Swift tests |
| `website/`, `server/website-worker.mjs` | Official landing site, with a separate deployment |

Read [README.md](README.md) for player behavior and deployment targets, [ios/README.md](ios/README.md) for native workflows, and [docs/INDEX.md](docs/INDEX.md) for the Cloudflare rate-limit references.

## Shared behavior

- Arena clients send intent. The server controls positions, mass, eating, splits, shields, and gadget effects.
- Keep web and iOS geometry, eligibility, protocol decoding, artwork, and sound timing consistent. Update the shared fixture and affected tests when a shared rule changes.
- Current split rules: 60 minimum piece mass, one-second cooldown, eight-piece limit, 12-second regroup timer.
- Eating requires at least 1.22 times the prey's mass and center distance below `hunterRadius - 0.6 * preyRadius`. Membrane deformation is visual; danger outlines use the server geometry.
- The slicer, shaker, and grater halve movement speed. Gadget draining stops at 500 mass per piece. Touching pieces over 2,500 mass split with a two-second gadget cooldown, within the eight-piece cap.
- Gadget leakage is separate from passive decay above 300 mass. Preserve mass accounting and the per-piece drain floor across multiple pieces.
- Keep six variety smiles and the brief sad expression after nonfatal piece loss on both clients.
- Bots have bounded perception and distinct risk profiles. Public bot spawns use weighted masses up to 5,000 and one hard role; crew bots start small. Gadget routes retain their encounter state; rare crossings roll once per encounter.
- New optional snapshot fields need defaults for older clients. Keep protocol 1, full-food snapshots, and `foodDeltas=1` compatibility unless a protocol migration is requested.

## Recovery, security, and saves

- Unexpected disconnects hold runs outside combat for 30 seconds. Resume tokens are secret credentials; player IDs do not authorize recovery.
- Preserve one-second Durable Object checkpoints, paused timers, room identity, monotonic ticks, expiry, and explicit-leave revocation. Active sessions have no fixed age limit.
- Preserve crew join rate limiting, name validation, per-IP connection limits, socket input budgets, and trusted proxy-header checks.
- Native save additions need optional fields or decoding defaults. Preserve the `hop` score key used by Countertop escape.
- Browser `.dill` imports retain the `native` extras through reload and export, including iOS circuit progress. Shared arcade bests merge without discarding native-only fields.
- Reset removes the native recovery copy as well as active progress. Resume credentials stay out of pet backups.
- Successful feeds rotate carrot, strawberry, broccoli, apple, and cheese. Refused feeds do not advance the local sequence; keep web and iOS ordering aligned.

## Native features and audio

- iOS adds Countertop escape, Cuke chop, Jar toss, and the UTC-seeded Daily Circuit. Keep classic games and care rewards aligned with web.
- Retain full-screen boards, compact-phone layouts, Reduce Motion behavior, and accessible controls.
- Native arena controls support swapping sides, a thumbstick dead zone, cooldown displays, and distinct rate-limited haptics.
- Gadget WAV loops come from the web synthesis. Regenerate after changing that synthesis or its stroke timing:

```sh
node ios/scripts/render-gadget-audio.mjs arena-web '/path/to/Chrome executable'
```

- Shared pickup WAVs are generated into both clients. Preserve their quiet cadence and byte parity:

```sh
python3 scripts/render-arena-pickups.py
```

- Native audio honors Silent Mode and cancels loops on exit/background. Keep audible-quality claims separate from waveform and timing checks.

## Checks

There is no frontend build step or package manifest. Use Node 24 for the dependency-free tests:

```sh
node --test tests/*.test.cjs
git diff --check
```

Run affected suites for focused changes; use the full suite when changing shared rules or formats. There is no configured repository-wide linter. Use `node --check` for changed standalone JavaScript and the Xcode build for Swift type checking.

After adding native sources/resources or editing `ios/project.yml`:

```sh
xcodegen generate --spec ios/project.yml
```

Use an available simulator destination for native tests:

```sh
xcodebuild test -project ios/LittleDill.xcodeproj -scheme LittleDill \
  -destination 'platform=iOS Simulator,id=<simulator-UDID>' \
  -derivedDataPath ios/build -only-testing:LittleDillTests
```

UI tests and explicit WebSocket/restart checks are documented in [ios/README.md](ios/README.md#verification). The restart script starts and kills its own local Worker. Scope native builds and GUI work to the user's authorization. Keep temporary harnesses, logs, build products, and credentials out of commits.

## Deployment boundaries

- `wrangler.jsonc` deploys the browser pet and reminder Worker.
- `wrangler.arena.jsonc` deploys the arena engine and `arena-web/` assets together.
- `wrangler.arena-legacy.jsonc` updates the compatibility proxy for older clients.
- The official landing site has a separate Worker. Follow the root README's content-replacement procedure to retain its assets and bindings.
- Bump `CACHE_VERSION` in `sw.js` for pet asset changes. Preserve Durable Object migrations, stored keys, and bindings.
- Validate the intended target with `npx wrangler deploy --dry-run --config <config>`. After an authorized deployment, check served assets and `/health`; do not infer deployed behavior from local source.
