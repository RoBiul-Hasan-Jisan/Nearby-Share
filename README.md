#  Nearby Share

**Offline, peer-to-peer file sharing for Android — plus a Wi-Fi bridge to any PC.**
No account. No server. No internet connection required for the core flow.

---

##  Motivation

Sending a file between two phones sitting next to each other shouldn't need
an internet connection, a cloud upload, an account, or a cable. Most "share"
options either:

- route the file through a third-party server (privacy + speed cost), or
- depend on both people having the same chat app / cloud account, or
- only work between phones from the same manufacturer.

**Nearby Share** solves this with Google's own **Nearby Connections API**
(Bluetooth for discovery/handshake, Wi-Fi Direct/hotspot for the actual
transfer), which works **fully offline, phone-to-phone, regardless of
manufacturer**, with a mandatory verification code so you can't be tricked
into pairing with the wrong device.

The one real gap in that model is the **desktop**: Google's Nearby
Connections API is Android/Play-Services-only, so a Windows/macOS/Linux
machine can never speak that protocol. Rather than bolt on a heavyweight
companion desktop app, this project adds a second, independent transfer
path — **Share with PC** — a tiny local HTTP server the phone runs on the
same Wi-Fi network, opened from any ordinary browser. Two transports, one
app, each used where it actually works.

##  Features

| | |
|---|---|
|       | Phone-to-phone transfer over Bluetooth + Wi-Fi Direct, no internet |
|   | Mandatory on-screen verification code before any data moves |
|   | Multi-file batches, streamed to disk (never fully loaded into memory) |
|   | **Share with PC** — QR code / URL opens a page on any desktop browser to download from, or upload to, the phone over Wi-Fi |
|   | Local transfer history (sent + received, from either transport) |
|   | Granular Android-version-aware runtime permission handling, with clear "Bluetooth is off" / "Wi-Fi is off" / "permission denied" recovery screens |
|   | Clean Material 3 UI, light theme |

## 3. Architecture

The app is a standard Flutter **layered architecture** with
[`provider`](https://pub.dev/packages/provider) for state management —
no Bloc/Riverpod ceremony, just `ChangeNotifier`s that own one concern each.

```
 UI (screens/widgets)
        │  watches / calls
        ▼
 Providers (state + orchestration)   NearbyProvider · TransferProvider · PcShareProvider · HistoryProvider · SettingsProvider
        │  calls
        ▼
 Services (I/O, platform, protocol)  NearbyService · PcShareService · StorageService · FileService · PermissionService · SystemService
        │  wraps
        ▼
 Platform                            nearby_connections plugin · dart:io HttpServer · Android MethodChannel (Kotlin) · permission_handler
```


**Rule of thumb enforced by the folder layout:** only one file per external
integration point ever touches it directly —

- `services/nearby_service.dart` is the *only* file that imports
  `nearby_connections`.
- `services/pc_share_service.dart` is the *only* file that opens a socket.
- `android/.../MainActivity.kt` is the *only* native code, reached through
  one `MethodChannel` (`services/system_service.dart`) for things Dart can't
  do alone: querying/enabling Bluetooth, reading the Wi-Fi/location toggle,
  a friendly device name, and saving a received file via `MediaStore`.

Everything above that line — providers, screens, widgets — is plain,
testable Dart/Flutter with no plugin-specific types leaking through.

### Why two separate transfer engines?

| | Nearby Connections (phone ↔ phone) | Local HTTP server (phone ↔ PC) |
|---|---|---|
| Transport | Bluetooth (handshake) + Wi-Fi Direct/hotspot (data) | Plain Wi-Fi LAN, TCP |
| Discovery | Automatic (advertise/discover) | Manual — user opens the shown URL / scans the QR code |
| Trust model | Mandatory shared verification code | Implicit — anyone who can reach that URL on the LAN can connect, so it's opt-in and stoppable per session |
| Where it runs | `services/nearby_service.dart` → `NearbyProvider` → `TransferProvider` | `services/pc_share_service.dart` → `PcShareProvider` |
| Client needed | The same app, on both phones | *None* — any browser |

They deliberately don't share a state machine: forcing them into one
generic "transfer" abstraction would have made both harder to reason about
for very little reuse (the only thing they actually share is the file
model and the history list they both write to).

##  How it works

###  Phone → phone (Nearby Connections)

1. **Receiver** taps *Receive* → starts **advertising**.
   **Sender** taps *Send* → starts **discovering** → taps a device found.
2. Nearby Connections runs its handshake and both phones display the same
   **verification code**; each person must confirm it on their screen.
   Any second, unexpected connection attempt is auto-rejected — the app only
   ever talks to one peer at a time.
3. Once connected, the sender transmits a small `offer` control message
   (JSON, `models/protocol_message.dart`) listing file names and sizes.
   The receiver sees an accept/reject screen.
4. On accept, files are sent **one at a time** as Nearby "file payloads",
   streamed by the plugin — never buffered fully in memory. The receiver
   matches the *k*-th incoming file to the *k*-th name in the offer, then
   hands it to `StorageService`, which saves it to
   `Downloads/Nearby Share/Received` via `MediaStore` (Android 10+, no
   storage permission needed) or app-specific storage on Android 9-.
5. The receiver replies with a `complete` message (saved/failed counts).
   The sender only shows "Files Sent" once that arrives — so success is
   confirmed by the *destination*, not assumed by the sender.
6. Cancellation (either side), rejection, a lost link (with Bluetooth/Wi-Fi
   state detection), a file deleted mid-flow, or a storage error all land on
   a clear, specific result screen — nothing fails silently.

State for all of this lives in two providers:
`NearbyProvider` (discovery, advertising, the connection/verification
handshake) and `TransferProvider` (the offer/accept/send/receive state
machine once a link exists).

###  Phone → PC (Share with PC)

1. From the home screen, tap **Share with PC** → **Start**.
   `PcShareService` checks the phone's Wi-Fi is on, finds its local IPv4
   address (preferring the `wlan` interface over any VPN/mobile interface),
   and binds a plain `dart:io HttpServer` on that address.
2. The screen shows that address as a **QR code and a tap-to-copy URL**.
   Open it in *any* browser on a computer on the **same Wi-Fi network** —
   no companion app, no account, nothing installed on the PC.
3. That page is generated on the fly by the phone and lists whichever files
   you picked with **Add** — each is a plain download link, streamed
   straight off disk with the right `Content-Type` / `Content-Disposition`.
4. The same page has a plain HTML upload form. A file selected there is
   POSTed as `multipart/form-data`, parsed with the `mime` package,
   streamed straight to a staging file (never loaded whole into memory),
   then handed to the *same* `StorageService.publish()` used by the
   Nearby-Connections flow — so it lands in the same
   `Downloads/Nearby Share/Received` folder and the same transfer history,
   just tagged with the peer name `PC (Wi-Fi)`.
5. Leaving the screen calls `stop()`, which closes the socket and clears the
   shared-file list — nothing keeps listening once you're not looking at it.

Because the whole thing is one self-contained HTTP server with an inlined
HTML/CSS page, it needs **no extra native code and no desktop build at
all** — the `windows/`, `macos/`, `linux/` folders in this repo are just
Flutter's default desktop scaffolding and are not part of this feature.

##  Permissions

Requested at runtime, and only what that Android version actually needs:

| Android version | Requested |
|---|---|
| 13+ (API 33+) | "Nearby devices" (Bluetooth scan/advertise/connect + Nearby Wi-Fi devices) |
| 12 / 12L (API 31–32) | Bluetooth scan/advertise/connect *(+ Location, still required by Google on API 31)* |
| 11 and below | Location, plus the Location **services** toggle being on |

Declared in the manifest, no runtime prompt needed:

- `INTERNET` — required by Android for *any* socket, including the
  **incoming** one `PcShareService` listens on for "Share with PC". No data
  ever leaves the local network through it.
- No storage permission is ever requested (`MediaStore` / app-specific
  storage cover both save paths).

`services/permission_service.dart` is the single place that decides which
permissions to ask for based on `SDK_INT`, and `widgets/requirements_gate.dart`
is the single place that turns "not ready yet" into the right screen
(*Allow* / *Open Settings* / *Turn on Bluetooth* / *Turn on Wi-Fi*).

##  Project structure

```
lib/
├── main.dart                    Composition root: builds every service/provider once, wires MultiProvider
├── app/
│   ├── app.dart                 MaterialApp + theme + routing
│   ├── routes.dart               Named routes
│   └── theme.dart                 ThemeData
├── theme/                        Design tokens: colors.dart, typography.dart, spacing.dart
├── core/
│   ├── constants/app_constants.dart   Service id, timeouts, ports, history limits…
│   ├── errors/app_exception.dart       User-facing exception type
│   ├── permissions/requirement_issue.dart  enum: what's currently blocking Nearby
│   └── utils/                    file_type_utils, format_utils (bytes/ETA/dates), dialogs
├── models/
│   ├── device_model.dart         A discovered Nearby endpoint
│   ├── file_model.dart           One file in a transfer (name, size, path, progress)
│   ├── protocol_message.dart     The tiny offer/accept/reject/cancel/complete wire protocol
│   └── transfer_model.dart       One row of transfer history (either transport)
├── services/                     Talk to the outside world; no UI, no state ownership
│   ├── nearby_service.dart        ONLY file touching the `nearby_connections` plugin
│   ├── pc_share_service.dart      ONLY file opening a socket (the "Share with PC" HTTP server)
│   ├── permission_service.dart    Which permissions to request, per SDK_INT
│   ├── file_service.dart          File picking (via `file_picker`)
│   ├── storage_service.dart       Where a received file ends up (MediaStore / app storage)
│   └── system_service.dart        Bridges to the Kotlin MethodChannel
├── providers/                     ChangeNotifiers — the app's actual state
│   ├── nearby_provider.dart       Discovery / advertising / connection handshake
│   ├── transfer_provider.dart     Offer → accept → send/receive state machine
│   ├── pc_share_provider.dart     "Share with PC" server lifecycle + shared-file list
│   ├── history_provider.dart      Persisted transfer history (SharedPreferences)
│   └── settings_provider.dart     Device name, preferences
├── screens/                       One folder per flow: home, discovery, connection,
│                                    file_picker, sending, receiving, pc_share, history, settings
└── widgets/                       Shared UI: app_card, file_card, device_card, transfer_tile/progress,
                                     requirements_gate, verification_view, result_view, empty_state…

android/app/src/main/kotlin/.../MainActivity.kt   The one native file: Bluetooth/Wi-Fi
                                                   state + enable prompts, device name,
                                                   MediaStore save, "open Downloads"
```

## Tech stack

- **Flutter** (Dart ≥ 3.3) — UI + app logic
- [`nearby_connections`](https://pub.dev/packages/nearby_connections) — Google Nearby Connections wrapper
- [`provider`](https://pub.dev/packages/provider) — state management
- [`permission_handler`](https://pub.dev/packages/permission_handler) — runtime permissions
- [`file_picker`](https://pub.dev/packages/file_picker) — picking files to send/share
- [`path_provider`](https://pub.dev/packages/path_provider) / [`path`](https://pub.dev/packages/path) — filesystem paths
- [`shared_preferences`](https://pub.dev/packages/shared_preferences) — local history/settings persistence
- [`wakelock_plus`](https://pub.dev/packages/wakelock_plus) — keep the screen on during a transfer
- [`mime`](https://pub.dev/packages/mime) — multipart parsing for PC → phone uploads
- [`qr_flutter`](https://pub.dev/packages/qr_flutter) — QR code for the PC-share URL
- Plain `dart:io HttpServer` — the PC-share web server, no framework needed
- Kotlin (`MainActivity.kt`) — the one native bridge, via a single `MethodChannel`

##  Getting started

Requires Flutter (stable) and the Android SDK. The Nearby-Connections flow
needs **two physical Android phones** (emulators have no usable
Bluetooth/Wi-Fi Direct); "Share with PC" only needs one phone and any
computer on the same Wi-Fi network.

```bash
flutter pub get
flutter run              # install on a phone (repeat per phone for the Nearby flow)
# or
flutter build apk --release
```

> Reinstalling after pulling changes to this repo? Uninstall the previous
> build first if the application ID ever changed — Android treats a
> different `applicationId` as a different app and won't auto-update over it.

##  Testing checklist

**Phone ↔ phone**
1. Both phones: open app → grant permissions. Phone B: *Receive*. Phone A: *Send* → B appears → connect.
2. Codes match on both → accept on both → A picks files (mix sizes/types) → B accepts.
3. Check progress/speed/ETA; files land in `Downloads/Nearby Share/Received`; history updates on both.
4. Failure paths: Bluetooth off mid-transfer, walking out of range, cancelling from either side, rejecting the request, deleting a picked file before sending, denying a permission twice (→ *Open Settings* flow).

**Phone ↔ PC**
1. Phone: *Share with PC* → *Start* → confirm the QR/URL appears.
2. PC (same Wi-Fi): open the URL → confirm the file list matches what's shared.
3. Download a file from the PC; upload a file from the PC → confirm it lands in `Downloads/Nearby Share/Received` and in history as `PC (Wi-Fi)`.
4. Leave the phone screen → confirm the URL stops responding (server closed).

##  Known limitations / next steps

- Nearby-Connections transfers need the app in the foreground (screen kept
  awake). A foreground service (+ `POST_NOTIFICATIONS`) would allow
  background transfers and completion notifications.
- `file_picker` copies picked files to app cache before sending, so very
  large files need matching free space and a short wait.
- "Share with PC" trusts anyone who can reach the shown URL on the local
  network for the life of that session — reasonable for a home/office Wi-Fi,
  not intended for shared/public networks. Stopping the session (leaving the
  screen) immediately closes it.
- Light theme only; mobile (Android) only — the desktop-platform folders in
  this repo are Flutter scaffolding, not a second client.
- If two phones stop discovering each other on Android 12+, check
  `android:usesPermissionFlags="neverForLocation"` on `BLUETOOTH_SCAN` in the
  manifest and the `sdk <= 31` cutoff in `permission_service.dart` first —
  that's almost always the cause.


