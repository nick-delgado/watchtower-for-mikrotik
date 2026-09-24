import 'package:routeros/routeros.dart';

/// How to reach and sign in to the paired router.
class PairedRouter {
  const PairedRouter({
    required this.host,
    this.port = RouterOsConnection.defaultPort,
    this.user = defaultUser,
    required this.password,
    required this.pin,
  });

  factory PairedRouter.fromJson(Map<String, Object?> json) => PairedRouter(
    host: json['host']! as String,
    port: json['port'] as int? ?? RouterOsConnection.defaultPort,
    user: json['user'] as String? ?? defaultUser,
    password: json['password']! as String,
    pin: json['pin']! as String,
  );

  /// MikroTik's default LAN address.
  static const defaultHost = '192.168.88.1';

  /// The read-only user the setup commands create.
  static const defaultUser = 'watchtower';

  final String host;
  final int port;
  final String user;
  final String password;

  /// SHA-256 fingerprint of the router's certificate, pinned when pairing.
  final String pin;

  PairedRouter withPin(String pin) => PairedRouter(
    host: host,
    port: port,
    user: user,
    password: password,
    pin: pin,
  );

  Map<String, Object?> toJson() => {
    'host': host,
    'port': port,
    'user': user,
    'password': password,
    'pin': pin,
  };
}
