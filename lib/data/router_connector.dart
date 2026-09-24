import 'dart:async';
import 'dart:io';

import 'package:routeros/routeros.dart';

import 'paired_router.dart';

/// What pairing shows about the router's certificate.
class CertificateInfo {
  const CertificateInfo({
    required this.fingerprint,
    required this.subject,
    required this.issuer,
  });

  factory CertificateInfo.of(X509Certificate certificate) => CertificateInfo(
    fingerprint: certificateFingerprint(certificate),
    subject: certificate.subject,
    issuer: certificate.issuer,
  );

  /// SHA-256, lowercase hex.
  final String fingerprint;
  final String subject;
  final String issuer;
}

abstract interface class RouterConnector {
  /// Reads the router's certificate without sending anything else.
  Future<CertificateInfo> fetchCertificate(
    String host, {
    int port = RouterOsConnection.defaultPort,
  });

  /// Connects with the pinned certificate and logs in.
  Future<RouterClient> connect(PairedRouter config);
}

class RouterOsConnector implements RouterConnector {
  const RouterOsConnector();

  static const _loginTimeout = Duration(seconds: 10);

  @override
  Future<CertificateInfo> fetchCertificate(
    String host, {
    int port = RouterOsConnection.defaultPort,
  }) async => CertificateInfo.of(
    await RouterOsConnection.fetchCertificate(host, port: port),
  );

  @override
  Future<RouterClient> connect(PairedRouter config) async {
    final connection = await RouterOsConnection.connect(
      config.host,
      port: config.port,
      pin: config.pin,
    );
    try {
      await connection
          .login(config.user, config.password)
          .timeout(_loginTimeout);
      return connection;
    } catch (_) {
      await connection.close();
      rethrow;
    }
  }
}
