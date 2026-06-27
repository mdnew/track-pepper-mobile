# TrackPepper — Mobile (iOS)

Flutter iOS app for the family puppy schedule.

**Repo:** [github.com/mdnew/track-pepper-mobile](https://github.com/mdnew/track-pepper-mobile)

## Supabase setup

Run migrations in order from [`supabase/migrations/`](supabase/migrations/) in your Supabase SQL Editor. See the [web repo](https://github.com/mdnew/track-pepper-web) for the same schema — both apps share one backend.

In **Authentication → URL Configuration**, add:
- `com.peppertrack.pepperTrack://reset-password`
- `com.peppertrack.pepperTrack://**`

## Run locally

```bash
cp dart_defines.example.json dart_defines.json
# Edit dart_defines.json with your Supabase URL and anon key
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

In VS Code/Cursor, use the **TrackPepper** launch config.

## 1Password / iOS Password AutoFill

The app uses iOS system Password AutoFill, which 1Password (and other password managers) plug into — no separate 1Password SDK.

**Works out of the box:** tap the email or password field on Sign In / Sign Up; iOS shows saved credentials or your password manager above the keyboard.

**Optional — share credentials with the web app:** add your production domain to `dart_defines.json`:

```json
"PASSWORD_AUTOFILL_DOMAIN": "trackpepper.example.com"
```

Then run `./scripts/configure_password_autofill.sh` (or `./scripts/build_ipa.sh`, which runs it automatically) before building. This enables Apple's Associated Domains so logins saved on web and mobile stay in sync via 1Password.

The web repo serves `/.well-known/apple-app-site-association` for this linkage. In 1Password, enable **Settings → Security → Autofill from 1Password** on iOS.

## TestFlight

See [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md).

```bash
./scripts/build_ipa.sh
```
