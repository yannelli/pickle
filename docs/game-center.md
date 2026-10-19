# Game Center

Created: 2026-10-19
Last updated: 2026-10-19

The iOS app signs in to Game Center at launch and posts personal bests to eight leaderboards. Scores are posted only after sign-in; stored bests are posted once per launch so scores from before Game Center still count.

| Leaderboard ID | Score |
| --- | --- |
| `ld.arena.mass` | Brine Royale best mass |
| `ld.daily` | Daily crunch, 0 to 300 |
| `ld.arcade.<game>` | Arcade bests for `hunt`, `memory`, `catch`, `hop`, `chop`, `toss` |

## Setup

- `ios/scripts/game-center.mjs` enables the `GAME_CENTER` App ID capability and creates any missing leaderboards with en-US names. Run it with `APPLE_API_KEY`, `APPLE_API_ISSUER`, and `APPLE_API_KEY_PATH` set. It skips existing leaderboards.
- `ios/LittleDill/LittleDill.entitlements` sets `com.apple.developer.game-center`. `ios/scripts/signing-profile.py` rejects profiles and IPAs without it.
- Enabling the capability invalidates existing App Store profiles. Create a new profile and update `IOS_MOBILE_PROVISION` ([ios-testflight.md](ios-testflight.md)).
- Leaderboards must be attached to an App Store version before App Review. TestFlight builds use the sandbox Game Center and see leaderboards before release.

## API notes (iOS 27 SDK)

- `GKGameCenterViewController` is deprecated from iOS 26. The app opens leaderboards with `GKAccessPoint.shared.trigger(state: .leaderboards)`, available from iOS 14.
- `GKLeaderboard.submitScore(_:context:player:leaderboardIDs:completionHandler:)` posts to several leaderboards at once; `BEST_SCORE` leaderboards keep the highest value.
- UI tests launched with `--ui-testing` skip authentication.

## References

- [Game Center authentication](https://developer.apple.com/documentation/gamekit/authenticating-a-player)
- [GKAccessPoint](https://developer.apple.com/documentation/gamekit/gkaccesspoint)
- [App Store Connect API: Game Center leaderboards](https://developer.apple.com/documentation/appstoreconnectapi/game-center-leaderboards)
- [App Store Connect API: bundle ID capabilities](https://developer.apple.com/documentation/appstoreconnectapi/bundle-id-capabilities)
