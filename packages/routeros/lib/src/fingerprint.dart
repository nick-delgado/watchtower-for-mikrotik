import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// SHA-256 of the certificate's DER bytes, as lowercase hex.
String certificateFingerprint(X509Certificate certificate) =>
    sha256.convert(certificate.der).toString();

/// Strips separators and case, so fingerprints copied from openssl,
/// RouterOS (`/certificate print detail`) or the app compare equal.
String normalizeFingerprint(String fingerprint) =>
    fingerprint.replaceAll(RegExp('[^0-9A-Fa-f]'), '').toLowerCase();

/// Formats a fingerprint as colon-separated uppercase bytes (`AB:CD:…`).
String formatFingerprint(String fingerprint) {
  final hex = normalizeFingerprint(fingerprint).toUpperCase();
  return [
    for (var i = 0; i < hex.length; i += 2)
      hex.substring(i, min(i + 2, hex.length)),
  ].join(':');
}
