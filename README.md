# TrackPepper — Mobile (iOS)

Flutter iOS app for the family puppy schedule.

**Repo:** [github.com/mdnew/pepper-track-mobile](https://github.com/mdnew/pepper-track-mobile)

## Supabase setup

Run migrations in order from [`supabase/migrations/`](supabase/migrations/) in your Supabase SQL Editor. See the [web repo](https://github.com/mdnew/pepper-track-web) for the same schema — both apps share one backend.

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

## TestFlight

See [`docs/TESTFLIGHT.md`](docs/TESTFLIGHT.md).

```bash
./scripts/build_ipa.sh
```
