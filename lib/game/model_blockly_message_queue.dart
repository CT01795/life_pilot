/// Coordinates editor readiness without retaining a platform view or Widget.
class ModelBlocklyMessageQueue {
  void Function(Map<String, dynamic>)? _send;
  bool _ready = false;
  bool _requested = false;
  bool _awaitingResponse = false;
  int _nextRequestId = 0;
  int? _pendingRequestId;
  bool _disposed = false;
  int? _maxBlocks;

  void attach(void Function(Map<String, dynamic>) send) {
    if (_disposed) return;
    _send = send;
    _ready = false;
    _requested = _requested || _awaitingResponse;
    _awaitingResponse = false;
    _pendingRequestId = null;
  }

  void markReady() {
    if (_disposed || _send == null || _ready) return;
    _ready = true;
    _sendMaxBlocks();
    if (_requested) requestCommands();
  }

  void setMaxBlocks(int value) {
    if (_disposed) return;
    _maxBlocks = value;
    _sendMaxBlocks();
  }

  void _sendMaxBlocks() {
    if (!_ready || _maxBlocks == null) return;
    _send?.call({'type': 'set_max_blocks', 'maxBlocks': _maxBlocks});
  }

  void requestCommands() {
    if (_disposed || _awaitingResponse) return;
    if (!_ready) {
      _requested = true;
      return;
    }
    _requested = false;
    _awaitingResponse = true;
    _pendingRequestId = ++_nextRequestId;
    _send?.call({'type': 'request_commands', 'requestId': _pendingRequestId});
  }

  bool acceptsResponse(Object? requestId) =>
      !_disposed && _awaitingResponse && requestId == _pendingRequestId;

  bool completeRequest(Object? requestId) {
    if (!acceptsResponse(requestId)) return false;
    _awaitingResponse = false;
    _pendingRequestId = null;
    return true;
  }

  void dispose() {
    _disposed = true;
    _send = null;
    _ready = false;
    _requested = false;
    _awaitingResponse = false;
    _pendingRequestId = null;
  }
}
