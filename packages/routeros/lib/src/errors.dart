/// Base class for errors raised by the RouterOS client.
class RouterOsException implements Exception {
  const RouterOsException(this.message);

  final String message;

  @override
  String toString() => 'RouterOsException: $message';
}

/// The router rejected a command (a `!trap` reply).
class RouterOsTrap extends RouterOsException {
  const RouterOsTrap(super.message, {this.category});

  /// RouterOS error category (0–7), when the router sent one.
  /// 2 means the command was interrupted, e.g. by `/cancel`.
  final int? category;

  @override
  String toString() => 'RouterOsTrap: $message';
}

/// The router refused the user name or password.
class AuthenticationException extends RouterOsException {
  const AuthenticationException(super.message);
}

/// The router's certificate doesn't match the pinned fingerprint.
/// Nothing was sent to the router.
class CertificateMismatchException extends RouterOsException {
  const CertificateMismatchException({
    required this.expected,
    required this.actual,
  }) : super('Router certificate does not match the pinned fingerprint');

  final String expected;
  final String actual;
}
