# Nearby Share (Flutter, Android)

Offline file sharing between two nearby Android phones using Google's Nearby Connections
(`nearby_connections`). No server, no account, no internet permission.

## Setup

Requires Flutter (stable), Android SDK, and **two physical Android phones** (emulators have no usable Bluetooth/Wi-Fi Direct).

```bash
unzip nearby_share_overlay.zip && cd nearby_share_overlay
./setup.sh            # creates ../nearby_share, copies the sources in, sets minSdk 26, runs flutter pub get
cd ../nearby_share
flutter run           # once per phone (or: flutter build apk --release, then install on both)
```

Manual alternative (Windows): run
`flutter create --org com.nearbyshare --project-name nearby_share --platforms=android nearby_share`,
copy `lib/`, `pubspec.yaml`, `AndroidManifest.xml` and `MainActivity.kt` over the generated files
(keep the paths), set `minSdk = 26` in `android/app/build.gradle(.kts)`, then `flutter pub get`.

## How it works

- Receiver taps **Receive** -> advertises. Sender taps **Send** -> discovers -> taps a device.
- Both phones show the Nearby authentication code; each user must confirm. Any second connection attempt is auto-rejected.
- Sender sends an `offer` (names + sizes) as a bytes payload. Receiver sees an accept/reject screen.
- On accept, files are sent **one at a time** as file payloads (streamed by the plugin, never loaded into memory).
  Receiver maps the k-th incoming file to the k-th name in the offer, moves it out of the plugin temp file,
  and saves it to `Downloads/Nearby Share/Received` via MediaStore (Android 10+, no storage permission).
  Android 9 and below: app-specific external storage.
- Receiver replies `complete` (saved/failed counts); sender only shows "Files Sent" once that arrives.
- Cancel, reject, peer cancel, link loss (with Bluetooth/Wi-Fi-off detection), deleted files and storage errors all end in a clear result screen.

## Structure

```
lib/
  main.dart, app/ (app, routes, theme), theme/ (colors, typography, spacing)
  core/ (constants, errors, permissions enum, utils)
  models/ (device, file, transfer history item, wire protocol)
  services/ nearby_service (ONLY file touching the plugin), permission, file, storage, system (Kotlin channel)
  providers/ nearby (connection), transfer (send/receive state machine), history, settings   <- Provider
  screens/ home, discovery, connection, file_picker, sending, receiving, history, settings
  widgets/
android/.../MainActivity.kt   Bluetooth/Wi-Fi state, enable prompts, device name, MediaStore save, open Downloads
```

## Permissions (only what the Android version needs)

| Android | Requested at runtime |
|---|---|
| 13+ (API 33+) | Nearby devices (Bluetooth scan/advertise/connect + Nearby Wi-Fi) |
| 12 / 12L (API 31-32) | Bluetooth scan/advertise/connect (+ Location on API 31) |
| 11 and below | Location (and Location services on) |

No storage permission. No INTERNET permission in the release manifest.

## Testing checklist (two phones)

1. Both: open app -> grant permissions. Phone B: Receive. Phone A: Send -> B appears -> Connect.
2. Codes match on both -> accept on both -> A picks files (try 1 image, 1 large video, 5 mixed) -> B accepts.
3. Check progress, speed, ETA; files appear in Downloads/Nearby Share/Received; history on both.
4. Failure paths: turn Bluetooth off mid-transfer; walk away; cancel from each side; reject the request;
   delete a picked file before pressing Send; deny a permission twice (Open Settings flow).

## Known limitations / next steps

- Transfers are only guaranteed while the app is in the foreground (screen is kept awake). A foreground service
  (+ POST_NOTIFICATIONS) would allow background transfers and completion notifications.
- `file_picker` copies picked files to app cache before sending, so very large files need matching free space and a short wait.
- Light theme only; Android only.
- Not compiled in the authoring environment: run `flutter analyze` first. If `nearby_connections` changed an API name,
  the fix is confined to `lib/services/nearby_service.dart`.
- If devices don't discover each other on Android 12+, remove `android:usesPermissionFlags="neverForLocation"`
  from `BLUETOOTH_SCAN` in the manifest and also request Location (change `sdk <= 31` to `sdk <= 33` in `permission_service.dart`).
