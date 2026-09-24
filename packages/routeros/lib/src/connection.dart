import 'dart:async';
import 'dart:io';

import 'client.dart';
import 'errors.dart';
import 'fingerprint.dart';
import 'protocol.dart';

/// A session with a router over the `api-ssl` service.
///
/// Every command gets its own `.tag`, so several commands, including
/// never-ending ones like `listen` and `monitor-traffic`, can run at once
/// over one connection.
class RouterOsConnection implements RouterClient {
  RouterOsConnection._(this._socket) {
    _socket.listen(
      _onData,
      onError: _onError,
      onDone: _onDone,
      cancelOnError: true,
    );
  }

  /// Default port of the RouterOS `api-ssl` service.
  static const defaultPort = 8729;

  final SecureSocket _socket;
  final _decoder = SentenceDecoder();
  final _commands = <String, _Command>{};
  final _done = Completer<void>();
  var _nextTag = 0;
  var _closed = false;

  /// Completes when the connection closes, for whatever reason.
  Future<void> get done => _done.future;

  /// Returns the certificate the router presents, then disconnects without
  /// sending anything. Used for pairing, before a fingerprint is pinned.
  static Future<X509Certificate> fetchCertificate(
    String host, {
    int port = defaultPort,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final socket = await _open(host, port, timeout);
    final certificate = socket.peerCertificate;
    socket.destroy();
    if (certificate == null) {
      throw const RouterOsException('Router did not present a certificate');
    }
    return certificate;
  }

  /// Connects to [host] and checks its certificate against [pin], a SHA-256
  /// fingerprint, before anything is sent. Throws
  /// [CertificateMismatchException] if it doesn't match.
  static Future<RouterOsConnection> connect(
    String host, {
    required String pin,
    int port = defaultPort,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final socket = await _open(host, port, timeout);
    final certificate = socket.peerCertificate;
    final actual = certificate == null
        ? ''
        : certificateFingerprint(certificate);
    final expected = normalizeFingerprint(pin);
    if (actual != expected) {
      socket.destroy();
      throw CertificateMismatchException(expected: expected, actual: actual);
    }
    return RouterOsConnection._(socket);
  }

  // RouterOS certificates are self-signed, so normal chain validation always
  // fails. The handshake is accepted here and the connection is trusted only
  // after the leaf certificate matches the pinned fingerprint.
  static Future<SecureSocket> _open(
    String host,
    int port,
    Duration timeout,
  ) async {
    try {
      return await SecureSocket.connect(
        host,
        port,
        timeout: timeout,
        onBadCertificate: (_) => true,
      );
    } on SocketException catch (e) {
      throw RouterOsException('Cannot reach $host:$port (${e.message})');
    } on HandshakeException catch (e) {
      throw RouterOsException(
        'TLS handshake with $host:$port failed (${e.message})',
      );
    }
  }

  /// Logs in. The password is sent as-is, which is safe only because the
  /// connection is TLS with a pinned certificate.
  Future<void> login(String user, String password) async {
    try {
      await call('/login', params: {'name': user, 'password': password});
    } on RouterOsTrap catch (e) {
      throw AuthenticationException(e.message);
    }
  }

  /// Runs [command] and returns its `!re` replies once the router sends
  /// `!done`.
  ///
  /// [params] become `=key=value` words. [queries] are passed through as
  /// query words, e.g. `?type=ether`.
  @override
  Future<List<Map<String, String>>> call(
    String command, {
    Map<String, String> params = const {},
    List<String> queries = const [],
  }) => stream(command, params: params, queries: queries).toList();

  /// Runs [command] and emits each `!re` reply as it arrives. For commands
  /// that never finish on their own (`listen`, `monitor-traffic`), cancelling
  /// the subscription sends `/cancel` to the router.
  @override
  Stream<Map<String, String>> stream(
    String command, {
    Map<String, String> params = const {},
    List<String> queries = const [],
  }) {
    final tag = '${_nextTag++}';
    late final StreamController<Map<String, String>> controller;
    controller = StreamController(
      onListen: () {
        if (_closed) {
          controller
            ..addError(const RouterOsException('Connection is closed'))
            ..close();
          return;
        }
        _commands[tag] = _Command(controller);
        _send([
          command,
          for (final param in params.entries) '=${param.key}=${param.value}',
          ...queries,
          '.tag=$tag',
        ]);
      },
      onCancel: () {
        final running = _commands[tag];
        if (running == null || _closed) return;
        running.cancelled = true;
        _send(['/cancel', '=tag=$tag']);
      },
    );
    return controller.stream;
  }

  /// Closes the connection. Running commands end without an error.
  @override
  Future<void> close() async => _shutDown();

  void _send(List<String> words) => _socket.add(encodeSentence(words));

  void _onData(List<int> chunk) {
    final List<List<String>> sentences;
    try {
      sentences = _decoder.add(chunk);
    } on FormatException catch (e) {
      _shutDown(RouterOsException('Malformed reply from router: ${e.message}'));
      return;
    }
    for (final words in sentences) {
      _onReply(Reply.parse(words));
    }
  }

  void _onReply(Reply reply) {
    if (reply.type == '!fatal') {
      _shutDown(
        RouterOsException('Router ended the session: ${reply.fatalMessage}'),
      );
      return;
    }
    final command = _commands[reply.tag];
    if (command == null) return;
    switch (reply.type) {
      case '!re':
        command.controller.add(reply.attributes);
      case '!trap':
        command.trap ??= RouterOsTrap(
          reply.attributes['message'] ?? 'Unknown error',
          category: int.tryParse(reply.attributes['category'] ?? ''),
        );
      case '!done':
        _commands.remove(reply.tag);
        final trap = command.trap;
        if (trap != null && !command.cancelled) {
          command.controller.addError(trap);
        }
        command.controller.close();
    }
  }

  void _onError(Object error) =>
      _shutDown(RouterOsException('Connection error: $error'));

  void _onDone() =>
      _shutDown(const RouterOsException('Router closed the connection'));

  void _shutDown([RouterOsException? reason]) {
    if (_closed) return;
    _closed = true;
    for (final command in _commands.values.toList()) {
      if (reason != null) command.controller.addError(reason);
      command.controller.close();
    }
    _commands.clear();
    _socket.destroy();
    _done.complete();
  }
}

class _Command {
  _Command(this.controller);

  final StreamController<Map<String, String>> controller;
  RouterOsTrap? trap;
  var cancelled = false;
}
