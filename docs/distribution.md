# Distributing TelepromptMe

This project is set up to ship as a standalone macOS app outside the Mac App Store.

## Target distribution profile

- Platform: macOS
- Architecture: Apple Silicon (`arm64`)
- Minimum OS: macOS 26.0
- Distribution channel: direct download
- Standard distribution: `Developer ID Application` + notarization
- Optional quick-share build: unsigned/ad-hoc local export

## One-time setup in Xcode

1. Open `TelepromptMe.xcodeproj` from the repository root.
2. Select the `TelepromptMe` target.
3. In `Signing & Capabilities`, choose your Apple Developer team.
4. Keep `Automatically manage signing` enabled.
5. For release exports, make sure Xcode can use your `Developer ID Application` certificate.

The project already has Hardened Runtime enabled, which is required for notarization.

## One-time notarization credential setup

Store a notarytool keychain profile once on your Mac:

```bash
xcrun notarytool store-credentials "TelepromptMeNotary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "YOUR_APP_SPECIFIC_PASSWORD"
```

Alternative authentication with an App Store Connect API key also works, but the packaging script below expects a keychain profile name.

## Build and package

The packaging script supports two modes:

- `unsigned`: quick direct sharing for trusted testers
- `developer-id`: proper user-facing distribution

### Unsigned quick-share build

This mode does not require an Apple Developer membership. It is useful for sending the app to a friend who can manually bypass Gatekeeper.

```bash
chmod +x scripts/package-macos.sh
./scripts/package-macos.sh unsigned
```

Output:

- `build/distribution/dist/TelepromptMe-unsigned-macOS.zip`

Important:

- This is not the standard public distribution path.
- Your recipient will likely see an "unidentified developer" warning.
- They may need to open the app via Finder `Open` or approve it in System Settings.

### Developer ID signed build

This is the standard outside-the-App-Store distribution flow.

From the repo root:

```bash
APPLE_TEAM_ID="YOUR_TEAM_ID" \
NOTARY_PROFILE="TelepromptMeNotary" \
./scripts/package-macos.sh developer-id
```

If you want to export a signed app without notarizing it yet, omit `NOTARY_PROFILE`:

```bash
APPLE_TEAM_ID="YOUR_TEAM_ID" ./scripts/package-macos.sh developer-id
```

## Output

The script writes artifacts to:

- `build/distribution/export/developer-id/TelepromptMe.app`
- `build/distribution/dist/TelepromptMe-developer-id-macOS.zip`

For unsigned mode, the app bundle stays inside the archive and the shareable artifact is:

- `build/distribution/dist/TelepromptMe-unsigned-macOS.zip`

If notarization is enabled, the app is stapled before the final zip is created.

## What the script does

1. Archives the app in `Release`.
2. Either exports it with the `developer-id` method or reuses the archived app bundle for unsigned sharing.
3. Creates a distributable zip containing the `.app`.
4. Optionally submits the Developer ID zip to Apple notarization.
5. Staples the notarization ticket to the app.
6. Rebuilds the zip so the stapled app is what you share.

## Recommended sharing flow

For normal distribution, send the final signed zip file:

- `build/distribution/dist/TelepromptMe-developer-id-macOS.zip`

Your recipient should:

1. Download the zip.
2. Unzip it.
3. Drag `TelepromptMe.app` into `/Applications`.
4. Launch it normally.

If the app was Developer ID signed and notarized, it should open like a standard downloaded Mac app without the "unidentified developer" workflow.

For quick trusted sharing, you can instead send:

- `build/distribution/dist/TelepromptMe-unsigned-macOS.zip`

Expect a manual Gatekeeper bypass on the recipient Mac for that unsigned build.
