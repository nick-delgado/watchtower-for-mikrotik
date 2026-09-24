# Watchtower for MikroTik

A monitoring-first, read-only mobile app (iOS and Android) for a MikroTik home router: live
internet bandwidth, Wi-Fi clients with per-client speeds, and the router log.

Early development. See [PLAN.md](PLAN.md) for scope, decisions and phases, [FUTURE.md](FUTURE.md)
for deferred ideas, and [RELEASE.md](RELEASE.md) for release concerns.

## Layout

- `lib/`: the Flutter app
- `packages/routeros/`: pure-Dart RouterOS API client (TLS with certificate pinning), plus the
  probe and anonymizer tools
- `assets/demo/router.json`: anonymized capture from a real router, used by demo mode and tests

## Development

```sh
flutter pub get
flutter run                       # pair with your router, or try the demo
flutter test
(cd packages/routeros && dart test)
```

`integration_test/pairing_test.dart` pairs with a real router end to end. See "Development
environment" in PLAN.md for the command.

## Probing a router

Set up the router with the commands in PLAN.md ("Onboarding and security flow"). The probe reads
the read-only user's password from `WATCHTOWER_PASSWORD` or the macOS Keychain item
`watchtower-router`.

```sh
cd packages/routeros
dart run bin/probe.dart                  # shows the certificate fingerprint, sends nothing
dart run bin/probe.dart --pin <sha256>   # full probe; raw capture goes to probe-output/
dart run bin/anonymize.dart probe-output/<capture>.json ../../assets/demo/router.json
```

Raw captures contain private network data and are git-ignored. Only commit anonymized fixtures,
and read through them before committing.

## License

GPL-3.0. See [LICENSE](LICENSE).
