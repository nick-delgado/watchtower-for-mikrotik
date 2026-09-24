# Future Iterations

Ideas deliberately left out of v1 (see [PLAN.md](PLAN.md)). Add new deferred items here.

## Remote access over VPN

Let someone quickly check on their home network from afar, e.g. over WireGuard back to the router.

- v1's connection check (router reachable + certificate matches the pin) already works over a VPN.
  There's no SSID check to get in the way.
- If `api-ssl` is restricted to the LAN subnet, the VPN subnet must be added.
- The router's address may differ over the tunnel; the app may need a "home" and an "away" address.
- Consider polling less often or using lighter streams on mobile data.

## Separate access points

v1 targets a single wireless router that is also the access point and the DHCP server.

- **CAPsMAN:** the Wi-Fi client list lives on the controller.
- **Standalone MikroTik APs:** query each AP for its clients. DHCP leases and ARP still live on
  the router, so a client's name and IP come from a different device than its Wi-Fi details.
- Devices on the legacy `/interface/wireless` package use different menus and field names.

## Multiple routers / sites

v1 supports one router per app install.

## Wired per-client speeds

v1 per-client speeds come from Wi-Fi counters only. Candidates for wired clients: the Kid Control
device table, Torch. Check the CPU cost and whether FastTrack affects the counters. Torch needs the
`sniff` policy, which the v1 read-only group doesn't have.

## Device nicknames

Local, on-phone names for clients (still read-only on the router). Keyed by MAC, but phones use a
private (randomized) MAC per Wi-Fi network, so the same phone can show up with different MACs on
the 2.4 GHz and 5 GHz SSIDs.

## Find the router automatically

Pairing pre-fills MikroTik's default address (`192.168.88.1`). Detecting the phone's default
gateway, or listening for MikroTik's discovery broadcasts (MNDP, UDP 5678, which WinBox uses),
would help routers on other subnets. MNDP needs Apple's multicast entitlement on iOS.

## One-time setup over SSH

Instead of copy-paste commands, the user enters admin credentials once and the app runs the setup
commands over SSH (encrypted, enabled by default). The admin password is used once and never stored.

## History

Graphs beyond "since the app was opened" would need something that collects data while the app is
closed (e.g. a small collector running on the network).
