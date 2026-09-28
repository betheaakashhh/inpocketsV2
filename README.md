# InPockets — Flutter customer app

<!-- readme-sync-bot:toc:start -->
## Table of Contents

- [1. Run the backend](#1-run-the-backend)
- [2. Turn this folder into a runnable Flutter project](#2-turn-this-folder-into-a-runnable-flutter-project)
- [3. Add camera permission strings](#3-add-camera-permission-strings)
- [4. Point the app at your backend and run](#4-point-the-app-at-your-backend-and-run)
- [What's built](#whats-built)
- [Known gaps to close before this is investor-demo-ready](#known-gaps-to-close-before-this-is-investor-demo-ready)
- [Architecture notes](#architecture-notes)
- [📋 Recommended Sections Checklist](#-recommended-sections-checklist)
<!-- readme-sync-bot:toc:end -->

This is the borrower-facing mobile app for InPockets, built against the real
`inpockets-main` FastAPI backend (phone+OTP auth, onboarding, PAN/KYC/identity
verification, loan applications). It talks to real endpoints — there is no
mock data layer.

This folder contains `lib/` and `pubspec.yaml` only. It is **not** a fully
scaffolded Flutter project yet (no `android/`, `ios/`, etc.) — the sandbox
this was built in has no network access to the Flutter/Dart tooling, so
`flutter create` could not be run here. You'll generate that scaffolding
in step 2 below; it takes one command.

## 1. Run the backend

From the `inpockets-main` backend repo:

```bash
docker compose up -d          # Postgres + Redis
# apply migrations (see the backend's own README for the exact alembic command)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Leave every provider on `development` in `.env` (the default) for now —
that's enough to exercise the whole app except for two steps noted below.

## 2. Turn this folder into a runnable Flutter project

```bash
cd inpockets_app
flutter create --project-name inpockets --org com.inpockets .
flutter pub get
```

`flutter create .` fills in `android/`, `ios/`, etc. **around** the existing
`lib/` and `pubspec.yaml` without touching them — this is the standard way
to retrofit native scaffolding onto hand-written Dart source.

## 3. Add camera permission strings

The Identity Verification step uses the device camera. Add:

**`ios/Runner/Info.plist`** — inside the outermost `<dict>`:
```xml
<key>NSCameraUsageDescription</key>
<string>InPockets uses your camera to verify your identity.</string>
```

**`android/app/src/main/AndroidManifest.xml`** — usually not required for
`image_picker`'s camera intent, but add this if you hit a permission error
on a specific device, just above `<application ...>`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

## 4. Point the app at your backend and run

```bash
# Android emulator (10.0.2.2 is the emulator's alias for your host machine)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

# iOS simulator
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000

# Physical device — use your computer's LAN IP, both on the same Wi-Fi
flutter run --dart-define=API_BASE_URL=http://192.168.1.23:8000
```

Omit `--dart-define` entirely and it defaults to the Android-emulator URL
(see `lib/core/config/app_config.dart`).

## What's built

- **Auth**: phone entry → OTP verify (6-box animated input, resend cooldown,
  shake-on-error) → session persisted in Keychain/Keystore, silent refresh
  on the 15-minute access-token expiry, single-flight so parallel requests
  never double-refresh.
- **Onboarding**: Profile → PAN → KYC (DigiLocker-style consent link,
  auto-polls status) → Identity (real selfie capture via the camera) →
  celebratory completion screen. The step tracker, routing guard, and
  every transition mirror the backend's actual state machine — including
  which side (client vs. server) is responsible for each step advance.
- **Home dashboard**, **loan application** (amount slider + tenure chips →
  review sheet → submit), **loan list + detail with an animated status
  timeline**, a **documents** viewer, and **profile + device-session
  management** (list/revoke sessions, logout).
- A small hand-built animation system used throughout: tap-scale buttons,
  a shimmer skeleton loader, staggered fade/slide-in entrances, and a
  `CustomPainter` success-checkmark — no Lottie/asset dependencies to break.

## Known gaps to close before this is investor-demo-ready

These are backend limitations I found while building, not app bugs —
flagged here (and at the exact line in code) rather than papered over:

1. **KYC and Identity Verification never auto-complete with the stock
   `development` providers.** `DevelopmentKYCProvider.get_status` always
   returns `PENDING`; `DevelopmentIdentityVerificationProvider.submit_capture`
   always returns `PROCESSING`. This is correct behavior for stubs, but it
   means a fresh local backend gets stuck after PAN. To walk the full flow
   locally, either wire in a real KYC/identity vendor, or temporarily edit
   those two dev-provider files to return `VERIFIED` for testing.
2. **There's no customer-facing endpoint to upload a brand-new document.**
   `DocumentService.store_document` (creates a new document family) exists
   but isn't exposed via any route in `app/api/v1/documents.py` — only
   "add a version to an existing family" is. The selfie capture screen
   (`identity_verification_screen.dart`, see the file-level comment) sends
   only an opaque reference string today; the image itself isn't persisted
   anywhere. Add a route for this before launch.
3. **No pricing/EMI data exists yet** (interest rate, fees, repayment
   schedule) — the loan application API only accepts an amount and a
   tenure. The app deliberately shows no invented interest/EMI numbers;
   it says pricing is "confirmed after review." Wire this up once the
   backend has a real pricing endpoint.
4. **`gender` on the profile has no enforced enum** in the schema I could
   read — confirm accepted values with the backend team and adjust
   `_genderOptions` in `profile_form_screen.dart` if needed.
5. Loan amount bounds (₹1,000–₹5,00,000) in `validators.dart` are a
   client-side UX guard only, not a backend-enforced rule — tune them once
   product/risk sets real limits.

## Architecture notes

No code generation (no `build_runner`/`freezed`/`riverpod_generator`) —
everything is hand-written so nothing can fail to generate on your
machine. State management is Riverpod (StateNotifier/AsyncValue), routing
is `go_router` with a Riverpod-driven auth+onboarding redirect guard, and
networking is a single Dio client (`lib/core/network/api_client.dart`)
that every repository shares.

<!-- readme-sync-bot:checklist:start -->
## 📋 Recommended Sections Checklist

_The bot can't write these automatically — they need your judgment, not a diff. This list updates itself as you add them:_

- [ ] License
- [ ] Author / Contact
- [ ] Contributing Guidelines
- [ ] Acknowledgements
- [ ] Testing
- [ ] Deployment
<!-- readme-sync-bot:checklist:end -->
