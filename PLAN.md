# Watchtower for MikroTik — Project Plan

A quick, monitoring-first, **read-only** mobile app (iOS + Android) for a home MikroTik
wireless router. It is not a configuration tool — MikroTik's official app covers that.

Deferred ideas live in [FUTURE.md](FUTURE.md). Release-phase concerns live in [RELEASE.md](RELEASE.md).

## Project identity

| | |
|---|---|
| App name | Watchtower for MikroTik (name under review, see RELEASE.md) |
| App / bundle ID | `sh.nickd.watchtower` (iOS bundle ID and Android application ID) |
| Publisher | Nick Delgado |

## v1 scope

- **Features**
  - Live internet (WAN) bandwidth graph
  - Wi-Fi client list with details (name, IP, MAC, SSID/band, signal, rates, uptime)
  - Live per-client speeds, so it's easy to go from overall usage to who is using it
  - Live router log viewer
- **Topology:** a single wireless router that is also the access point and the DHCP server.
  Reference device: **hAP ax³** on RouterOS **7.24.4** (`wifi-qcom` package → `/interface/wifi` menu).
- **One router** per app install.
- **RouterOS v7 only.** Developed against 7.24.4. The minimum supported version will be confirmed
  in Phase 0 (at least 7.13, where the `/interface/wifi` menu appeared).
- **Live data only** while the app is in the foreground. No history.
- **Out of scope for v1:** separate access points / CAPsMAN, remote access, multiple routers,
  wired per-client speeds, any configuration changes (see FUTURE.md).

## Decisions

| Topic | Decision | Why |
|---|---|---|
| Framework | Flutter / Dart | TLS certificate pinning and raw TCP sockets are in Dart's standard library |
| Router protocol | Native RouterOS API over TLS (`api-ssl`, TCP 8729) | Router pushes updates (`listen`, `monitor-traffic`) over one connection; REST is polling-only with a 60 s request cap |
| Transport security | Self-signed certificate on the router, pinned in the app on first use (TOFU) | Plain `api`/`www` send the password in cleartext; `api-ssl` without a certificate needs anonymous-DH ciphers that mobile TLS stacks reject |
| Credentials | Dedicated read-only user (`read` + `api` policies only) | Admin credentials never stored on the phone; no `sensitive` policy means Wi-Fi passphrases etc. are hidden |
| "Am I home?" gate | Show data when the router answers at its saved address **and** its certificate matches the pin. No SSID check | No location permission needed; works on every SSID the router serves (2.4 GHz, 5 GHz) and over Ethernet; will work over a VPN later |
| Graphs | Internet (WAN) and per-client Wi-Fi, live-only | Matches the "overall, then per-client" flow |
| Per-client scope | Wi-Fi clients only in v1 | Wi-Fi driver counters are reliable; wired per-client is in FUTURE.md |
| Router setup | Copy-paste command block with Copy / Share buttons | Simple and transparent; SSH-assisted setup is in FUTURE.md |
| Demo mode | Visible "Try demo" option using recorded data | Needed for app store review; also lets people try it without a router |

## Architecture

```
packages/routeros/  Pure-Dart API client: sentence encoding, login, .tag multiplexing,
                    listen/cancel, TLS with pinned-fingerprint verification. No Flutter
                    deps, tested with `dart test`. bin/probe.dart is the Phase 0 tool.
lib/data/           Repositories turning API replies into typed models and streams
                    (SystemInfo, TrafficSample, WifiClient, LogEntry); rate calculation.
lib/app/            Flutter UI and state management (Riverpod).
test/fixtures/      Recorded router responses replayed by a fake transport for UI
                    development, tests, and demo mode.
```

Raw probe captures (`probe-output/`, git-ignored) contain private network data: MACs, hostnames,
IPs, serial number, logs. Anything committed as a fixture must be anonymized first.

### Data sources (validated in Phase 0 on 7.24.4)

| Feature | RouterOS source | Mechanism |
|---|---|---|
| Router summary | `/system/identity`, `/system/resource`, `/system/routerboard` | On connect, then periodic |
| WAN interface | Members of the `WAN` interface list; fallback: default route's interface; user override in settings | On connect |
| Internet graph | `/interface/monitor-traffic` on the WAN interface | Streamed, 1 sample/s |
| Wi-Fi clients | `/interface/wifi/registration-table` (includes `ssid` and `band`) | Poll every ~2 s |
| Per-client speeds | Registration table's own `tx-bits-per-second` / `rx-bits-per-second` | Same poll |
| Names / IPs | `/ip/dhcp-server/lease` + `/ip/arp`, joined by MAC | `listen` |
| Logs | `/log/print` for the backlog, then `/log/listen` | Streamed |

Notes:
- **Directions (confirmed with a controlled download):** on WAN, `rx` = download and `tx` = upload.
  In the registration table, `tx-bits-per-second` and `bytes[0]` are router → client (the client's
  download); `rx-*` and `bytes[1]` are the client's upload.
- Use the router's per-client rate fields, not byte-counter deltas. The `bytes` counters only
  refresh every ~4 s, so deltas over 2 s polls alternate between 0 and double the real rate.
- `tx-rate` / `rx-rate` are the Wi-Fi link speeds in bit/s (e.g. `1080900000`), not throughput.
- Per-client speeds come from the Wi-Fi driver, so they count **all** of a device's Wi-Fi
  traffic, including local traffic (e.g. casting to a TV), not only internet traffic.
- `/log/listen` also emits `.dead=yes` events when old entries rotate out of the log buffer
  (1000 lines by default); drop them. Log `time` is `YYYY-MM-DD HH:MM:SS` in the router's local
  time, so relative times ("2 min ago") must use the router's clock, not the phone's.
- `/interface/wifi/registration-table/listen` returned no events over 20 s with no joins or leaves.
  Check that it reports connects/disconnects in Phase 4; if it does, it can replace polling for
  the list itself.
- The read-only user sees `security.passphrase` masked, so excluding `sensitive` works.
- Lifecycle: connect when the app comes to the foreground; cancel all streams and disconnect
  when it goes to the background. Each screen subscribes only to what it displays.

## Onboarding and security flow

1. The app explains what's needed and generates a strong random password for the read-only user.
   Letters and digits only, since the RouterOS terminal treats `$` and `?` specially even inside quotes.
2. It shows a copy-paste command block (password embedded) with Copy and Share buttons. The user
   runs it in the router's terminal (WinBox, WebFig, or SSH).
3. Router address is pre-filled with the phone's default gateway (usually `192.168.88.1`), editable.
4. The app connects to port 8729, shows the certificate's SHA-256 fingerprint, and the user
   confirms it. The app pins it.
5. Credentials and the pin are stored in the Keychain / Keystore (`flutter_secure_storage`).
6. On every connection: TLS handshake → fingerprint must match the pin → only then send the login.
   On a mismatch: stop, explain, and offer a re-pair flow.

Router setup commands (validated on the hAP ax³, 7.24.4):

```
/certificate add name=watchtower-ca common-name=watchtower-ca days-valid=3650 key-usage=key-cert-sign,crl-sign
/certificate sign watchtower-ca
/certificate add name=watchtower common-name=watchtower days-valid=3650 key-usage=digital-signature,key-encipherment,tls-server
/certificate sign watchtower ca=watchtower-ca
/ip service set api-ssl certificate=watchtower disabled=no
/user group add name=watchtower-ro policy=read,api
/user add name=watchtower group=watchtower-ro password="<generated>"
```

- A certificate without `key-cert-sign` can't sign itself. On 7.24.4, `/certificate sign watchtower`
  alone fails with `CA not found`, so we create a small local CA and sign the server certificate with it.
- The app pins the server certificate (`watchtower`), which is what port 8729 presents.
- `days-valid=3650` so the user never has to regenerate the certificate (a new certificate
  means a new fingerprint and a re-pair). The app trusts the pin, not the dates.
- Signing takes a few seconds, so paste the lines one at a time. SSH-assisted setup (FUTURE.md) would avoid this.
- The default firewall already blocks `api-ssl` from the WAN side. Restricting the service to the
  LAN subnet (`/ip service set api-ssl address=...`) is optional; revisit when adding VPN access.

### Mobile OS permissions

- **iOS:** Local Network prompt (`NSLocalNetworkUsageDescription`). No location permission and no
  Wi-Fi-info entitlement, because we don't read the SSID.
- **Android:** `INTERNET`, plus the runtime `ACCESS_LOCAL_NETWORK` permission. We target
  Android 17 (API 37), so this is required from day one.

## Phases

0. **Phase 0: test on the hAP ax³.** Run the setup commands. A small Dart command-line script connects over
   `api-ssl` with pinning, logs in as the read-only user, dumps each data source, and streams
   `monitor-traffic` and `/log/listen`. Save the responses as fixtures.
   Runs from the dev Mac, which is on the router's network. Needs only the Dart SDK (bundled with
   Flutter), not Xcode.
   **Done 2026-09-24:** setup commands, the `read,api` group, TLS pinning, every data source and
   all three streams confirmed; findings are in "Data sources" above. Still open: the minimum
   RouterOS version (only 7.24.4 tested; CHR can cover older versions for non-Wi-Fi features),
   and turning raw captures into anonymized fixtures (Phase 1).
1. **Skeleton.** Flutter project, lints, CI (GitHub Actions: analyze + test), `routeros` client,
   fake transport.
2. **Onboarding and connection.** Setup commands, address, fingerprint pinning, secure storage,
   permission prompts, connection gate.
3. **Dashboard.** Router summary + live internet graph.
4. **Wi-Fi clients.** List (name, IP, SSID/band, signal, live speed), detail screen, per-client graph.
5. **Logs.** Live view, topic filter, search.
6. **Hardening and beta.** Lifecycle, reconnect with backoff, error states, accessibility, dark mode,
   demo mode; TestFlight and Play internal testing. Then work through RELEASE.md.

## Development environment

Installed on the dev Mac (2026-09-23): Flutter 3.47.5 / Dart 3.13.4 and Android Studio
(both via Homebrew), and Xcode 27.0.

A free Apple ID is enough to run dev builds on your own iPhone (profiles expire after 7 days).
TestFlight and the App Store need the paid Apple Developer Program.

Test devices: an iPhone on iOS 26.6 and an Android phone on Android 17.

For router testing: the hAP ax³ is the reference device. MikroTik's free virtual router (CHR) runs
on Apple Silicon and is useful for automated tests of non-Wi-Fi features, but it has no Wi-Fi.
