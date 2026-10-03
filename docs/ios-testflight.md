# GitHub TestFlight releases

Created: 2026-10-02. Last updated: 2026-10-02.

The TestFlight workflow builds `com.littledill.ios` for team `2P58V89SR7`. Pull requests and pushes to `main` run JavaScript tests and native unit tests without release secrets. A `v*` tag runs those checks, signs and validates an IPA, uploads it, waits for processing, saves testing notes, and assigns an external group. Manual dispatch on a branch stops after validation; dispatch on a version tag releases it.

## One-time setup

Configure these repository secrets in `yannelli/pickle`. Use an App Store Connect team API key authorized for this app and beta review operations.

| Secret | Value |
| --- | --- |
| `APPLE_API_KEY` | API key ID |
| `APPLE_API_ISSUER` | Issuer UUID |
| `APPLE_API_KEY_BASE64` | Base64 contents of `AuthKey_<key-id>.p8` |
| `IOS_CERTIFICATE` | Base64 Apple Distribution `.p12`, including its private key and certificate chain |
| `IOS_CERTIFICATE_PASSWORD` | Password for the `.p12` |
| `IOS_MOBILE_PROVISION` | Base64 manual App Store provisioning profile for this app and certificate |

The profile must enable Associated Domains for `applinks:arena.littledill.app`. The workflow checks profile expiry, team, app identifier, distribution type, and the matching signing identity before archiving. Credentials are decoded into a private runner directory, imported into a temporary keychain, and removed in the cleanup step.

Set the optional repository variable `TESTFLIGHT_GROUP` to an existing external group name; the default is `Public Beta`. Create an internal testing group before the external group. Complete beta review contact details, feedback email, any required demo credentials, and the app's encryption compliance information in App Store Connect. The automation does not create groups or answer encryption questions. Add testers or enable the group's public invitation link.

Upload secret values through standard input. Substitute approved file paths and identifiers; keep secret values out of shell history and repository files:

```sh
gh secret set APPLE_API_KEY --repo yannelli/pickle
gh secret set APPLE_API_ISSUER --repo yannelli/pickle
base64 -i "$asc_key_file" | gh secret set APPLE_API_KEY_BASE64 --repo yannelli/pickle
base64 -i "$distribution_p12" | gh secret set IOS_CERTIFICATE --repo yannelli/pickle
gh secret set IOS_CERTIFICATE_PASSWORD --repo yannelli/pickle < "$p12_password_file"
base64 -i "$app_store_profile" | gh secret set IOS_MOBILE_PROVISION --repo yannelli/pickle
gh secret list --repo yannelli/pickle
```

Protect release tags and restrict who can change workflows or manually dispatch them. Manual branch validation uses distribution credentials. GitHub-hosted `macos-26` runners use the explicitly selected Xcode 26.3 installation; the committed Xcode project supplies the build inputs. No XcodeGen install or project regeneration occurs during CI.

## Release a version

1. Set `MARKETING_VERSION` in `ios/project.yml`, then run `xcodegen generate --spec ios/project.yml` and include the generated project in the version change.
2. Write tester instructions in `docs/testflight/<version>.md`. Use the full version for prereleases, such as `1.0.0-beta.1`. Notes plus the generated Little Dill version/build prefix must fit within 4,000 characters.
3. Commit the intended revision. Push a matching tag such as `v1.0.0` or `v1.0.0-beta.1` when a TestFlight upload is intended. `alpha.N`, `beta.N`, and `rc.N` suffixes are supported, starting at 1. The tag's base version must equal the project version.
4. Inspect the TestFlight workflow summary and download its `LittleDill-<version>-<build>` artifact. It contains the exact validated/uploaded IPA and `SHA256SUMS`.

The build number is one greater than the highest existing build or build-upload record across all pages and versions. `IOS_BUILD_NUMBER_MIN` optionally sets a positive integer floor when recovering from uploads that Apple has not exposed yet. App-wide concurrency serializes release runs across tags. Coordinate manual uploads with CI; GitHub's concurrency queue can replace pending runs when several releases are queued.

Rerunning a release creates a new build number. To retry just distribution for an already accepted build, use the original version and build with the API credentials in the environment:

```sh
node ios/scripts/distribute-testflight.mjs --version 1.0.0 --build 25
```

Notes, automatic notifications, group membership, and beta review submission are idempotent for the selected build. The script waits up to 30 minutes for processing and export-compliance review, and fails on missing compliance, invalid processing, expiry, or rejected review. It stops after submitting review and verifying notes, group membership, notifications, and Apple's returned state. External availability is confirmed by `IN_BETA_TESTING`; waiting for Apple's human review is a separate gate.

## Local checks and release evidence

```sh
node --test tests/*.test.cjs
python3 tests/ios_signing_test.py
bash -n ios/scripts/release.sh
node ios/scripts/release-config.mjs
node ios/scripts/distribute-testflight.mjs --version 1.0.0 --build 1 --check-notes
git diff --check
```

Native unit tests run in the Checks workflow. Signing setup, archive/export, embedded entitlements, signer/profile agreement, Apple validation, upload acceptance, processing, and external distribution are separate release steps. The IPA's version and build are verified after export; Xcode's automatic build-number rewriting is disabled. GitHub release publishing and App Store production submission are outside this workflow.

## References

Consult these when changing runner selection, signing, upload lookup, or beta distribution:

- [GitHub macOS 26 runner software](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
- [GitHub signing certificates and runner cleanup](https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications)
- [GitHub concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency)
- [Apple build uploads for an app](https://developer.apple.com/documentation/appstoreconnectapi/get-v1-apps-_id_-builduploads)
- [Apple API tokens](https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests)
- [Apple external testing](https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers)
- [Apple beta build localizations](https://developer.apple.com/documentation/appstoreconnectapi/beta-build-localizations)
- [Apple beta review submission](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-betaappreviewsubmissions)

Adapted from `/Users/ryanyannelli/Documents/IOS_CICD_GUIDE.md` and the referenced Oxbit API helpers. No additional package dependencies are required; local workflow-contract tests use Ruby's bundled YAML parser.
