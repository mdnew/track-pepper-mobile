# TestFlight distribution

Build and upload the iOS app from this repo.

## Prerequisites

- Apple Developer Program membership ($99/year)
- Xcode installed
- App Store Connect access

## One-time setup

### 1. App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. **My Apps → + → New App**
3. Platform: iOS
4. Name: **TrackPepper**
5. Bundle ID: `com.peppertrack.pepper_track` (create in Developer portal if needed)
6. SKU: `pepper-track`

### 2. Xcode signing

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select **Runner** target → **Signing & Capabilities**
3. Team: your Apple Developer team
4. Bundle Identifier: `com.peppertrack.pepper_track`
5. Enable **Automatically manage signing**

### 3. App icon (optional but recommended)

Replace icons in `ios/Runner/Assets.xcassets/AppIcon.appiconset/` with a paw-themed 1024×1024 source image. Use a tool like [appicon.co](https://appicon.co) to generate all sizes.

## Build and upload

### Release build with Supabase credentials

Ensure `dart_defines.json` exists (see README), then from the repo root:

```bash
./scripts/build_ipa.sh
```

Or manually:

```bash
flutter build ipa --release --dart-define-from-file=dart_defines.json
```

The IPA is written to `build/ios/ipa/`.

### Upload via Xcode (alternative)

1. `flutter build ios --release --dart-define-from-file=dart_defines.json`
2. Open `ios/Runner.xcworkspace`
3. **Product → Archive**
4. **Distribute App → App Store Connect → Upload**

### Upload via command line

```bash
xcrun altool --upload-app -f build/ios/ipa/pepper_track.ipa \
  -t ios -u YOUR_APPLE_ID -p YOUR_APP_SPECIFIC_PASSWORD
```

Or use **Transporter** app from the Mac App Store.

## Invite family

1. In App Store Connect → your app → **TestFlight**
2. Wait for build processing (~5–15 min)
3. **Internal Testing** (up to 100 testers on your team) — fastest, no review
   - Or **External Testing** — requires brief Beta App Review, up to 10,000 testers
4. Add testers by email; they install the **TestFlight** app and accept the invite

## Share household invite code separately

TestFlight gets the app on their phone. The **PEPPER-XXXX** household invite code is created inside the app by whoever sets up the household first — share that via text/iMessage so others can join the same schedule.

## Re-uploading

TestFlight builds expire after 90 days. Re-run `flutter build ipa` and upload a new build monthly (or when you ship fixes).

## Keep Supabase awake

Free Supabase projects pause after 7 days without traffic. Daily app use prevents this. If you're away, set a weekly GitHub Action to `GET` your Supabase REST endpoint.
