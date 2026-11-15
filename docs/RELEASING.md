# Releasing

## Cut a release
1. Make sure `main` is green.
2. Bump `version:` in `pubspec.yaml` (`0.2.0+2`: the name, then the build number, which must always go up).
3. Move the `[Unreleased]` notes in `CHANGELOG.md` under the new version with today's date.
4. Merge that as a `chore: release v0.2.0` pull request.
5. Tag it: `git tag v0.2.0 && git push origin v0.2.0`.
6. The **Release** workflow tests, builds the signed APK and publishes it under Releases.

## Signing
Android only installs an update over an existing app if both are signed with the same key. Lose the key and every phone has to uninstall (and lose its data) to get the next version, so the key is kept in two places off GitHub.

The workflow needs two repository secrets (Settings → Secrets and variables → Actions):

| Secret | What |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The release keystore (`pantry-release.jks`), base64 encoded. |
| `ANDROID_KEYSTORE_PASSWORD` | Its password (store and key share it; the key alias is `pantry`). |

If either is missing, the Release workflow stops at its first step with an error saying so. It never falls back to a debug key.

To build a signed APK locally:

```sh
PANTRY_KEYSTORE_PATH=/path/to/pantry-release.jks PANTRY_KEYSTORE_PASSWORD=… flutter build apk --release
```
