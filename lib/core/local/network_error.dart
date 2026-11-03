/// Identifies transport failures for which a previously confirmed local
/// snapshot may be used. Server authorization and validation errors must surface.
bool isOfflineNetworkError(Object error) {
  final type = error.runtimeType.toString().toLowerCase();
  final message = error.toString().toLowerCase();
  if ([
    'socketexception',
    'timeoutexception',
    'handshakeexception',
    'httpexception',
    'clientexception',
  ].any(type.contains)) return true;
  return [
    'failed host lookup',
    'network is unreachable',
    'connection refused',
    'connection reset',
    'connection closed',
    'connection timed out',
    'timed out',
    'xmlhttprequest error',
    'failed to fetch',
    'networkerror',
  ].any(message.contains);
}
