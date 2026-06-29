# App Store submission

Upload TrackPepper to App Store Connect for TestFlight and public App Store release.

## Current app settings

| Setting | Value |
|---------|-------|
| App name | TrackPepper |
| Bundle ID | `com.mnew.trackPepper` |
| Team ID | `C3KU8N9LA6` |
| Version | 1.0.0 (build 1) |

## 1. One-time App Store Connect setup

1. Go to [App Store Connect](https://appstoreconnect.apple.com) and sign in with **mdnew@yahoo.com**
2. **Apps → + → New App**
   - Platform: **iOS**
   - Name: **TrackPepper**
   - Primary language: **English (U.S.)**
   - Bundle ID: **com.mnew.trackPepper** (create in [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) first if it is not listed)
   - SKU: **pepper-track**
   - User access: **Full Access**
3. In **App Information**, set category to **Lifestyle** (or Productivity)
4. In **Pricing and Availability**, choose **Free**

## 2. Supabase redirect URLs

In Supabase → **Authentication → URL Configuration**, add:

- `com.mnew.trackPepper://reset-password`
- `com.mnew.trackPepper://**`

## 3. Build the IPA

From the repo root:

```bash
./scripts/build_ipa.sh
```

Output: `build/ios/ipa/track_pepper.ipa`

## 4. Upload the build

Pick one method:

### Option A: Xcode Organizer (recommended)

1. Open the archive (after `./scripts/build_ipa.sh`):

   ```bash
   open build/ios/archive/Runner.xcarchive
   ```

2. In **Organizer**, select the archive → **Distribute App**
3. **App Store Connect** → **Upload** → follow prompts
4. Wait 5–15 minutes for processing in App Store Connect

### Option B: Transporter app

1. Install [Transporter](https://apps.apple.com/us/app/transporter/id1450874784) from the Mac App Store
2. Sign in with your Apple ID
3. Drag `build/ios/ipa/track_pepper.ipa` into Transporter → **Deliver**

## 5. TestFlight (optional, before public release)

1. App Store Connect → **TrackPepper → TestFlight**
2. Select the uploaded build when processing finishes
3. **Internal Testing** → add testers by email (no review required)

## 6. App Store listing (required for public release)

In App Store Connect → **TrackPepper → App Store** tab, create version **1.0.0** and fill in:

| Field | Suggestion |
|-------|------------|
| **Subtitle** | Shared pet care schedule |
| **Description** | TrackPepper helps families stay on the same page for puppy and kitten care. Share a daily schedule for feedings, potty breaks, naps, and training. Check tasks off as you go and see progress on a calendar, synced in real time across phones and the web. |
| **Keywords** | puppy,kitten,pet,dog,cat,schedule,family |
| **Support URL** | https://beamish-blini-c39baf.netlify.app |
| **Privacy Policy URL** | https://beamish-blini-c39baf.netlify.app/privacy |
| **Screenshots** | Required: 6.7" iPhone (1290×2796). Capture from your phone or Simulator |
| **App icon** | 1024×1024 PNG (no transparency) |

### App Privacy questionnaire

Declare data collected:

- **Contact info:** email address (account creation)
- **User content:** pet names, schedules, completion data
- **Usage data:** Firebase Analytics (product interaction)
- **Linked to user:** yes, for account functionality
- **Used for tracking:** no (unless you enable ad tracking later)

### Review information

- **Sign-in required:** Yes
- **Demo account:** create a test account in Supabase and provide email + password for Apple reviewers
- **Notes:** "TrackPepper is a shared household pet schedule. Sign in, create or join a household with an invite code, then use the Today tab to check off scheduled tasks."

## 7. Submit for review

1. Attach the processed build to version 1.0.0
2. Answer export compliance: **uses standard encryption only** (HTTPS)
3. Click **Add for Review** → **Submit to App Review**

Review usually takes 1–3 days.

## Re-uploading a new build

Bump the build number in `pubspec.yaml` (e.g. `1.0.0+2`), then:

```bash
./scripts/build_ipa.sh
```

Upload again via Organizer or Transporter.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Bundle ID unavailable | It may be registered on another team; use `com.mnew.trackPepper` on your personal team |
| Missing compliance | App Store Connect → app → **App Privacy** and **Export Compliance** |
| Build not appearing | Wait 15 min; check email for Apple processing errors |
| Invalid binary | Open archive in Organizer and read the upload log |
| **Upload Symbols Failed** (`objective_c.framework`) | Known Flutter/Dart issue. Often a **warning only** — check App Store Connect; the build may still process. To avoid it on the next build, `pubspec.yaml` pins `objective_c: 9.1.0` via `dependency_overrides`; run `./scripts/build_ipa.sh` and upload again. Or in Organizer, uncheck **Upload your app's symbols** (you lose Apple-side symbolication for that framework only). |
