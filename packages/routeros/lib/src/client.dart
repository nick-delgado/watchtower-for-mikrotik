/// What the app needs from a logged-in router session.
///
/// Implemented by [RouterOsConnection] for real routers, and by fakes that
/// replay recorded data (demo mode, tests).
abstract interface class RouterClient {
  /// Runs [command] and returns its replies once the router is done.
  ///
  /// [params] become `=key=value` words and [queries] are passed through as
  /// query words, e.g. `?type=ether`.
  Future<List<Map<String, String>>> call(
    String command, {
    Map<String, String> params = const {},
    List<String> queries = const [],
  });

  /// Runs [command] and emits each reply as it arrives. Cancelling the
  /// subscription stops commands that never finish on their own (`listen`,
  /// `monitor-traffic`).
  Stream<Map<String, String>> stream(
    String command, {
    Map<String, String> params = const {},
    List<String> queries = const [],
  });

  /// Ends the session.
  Future<void> close();

  /// Completes when the session ends, whether through [close] or because
  /// the connection dropped.
  Future<void> get done;
}
