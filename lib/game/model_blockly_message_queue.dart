/// Coordinates editor readiness without retaining a platform view or Widget.
class ModelBlocklyMessageQueue {
  void Function(Map<String, dynamic>)? _send;
  bool _ready = false;
  bool _requested = false;
  bool _awaitingResponse = false;
  bool _disposed = false;
  int? _maxBlocks;

  void attach(void Function(Map<String, dynamic>) send) {
    if (_disposed) return;
    _send = send;
    _ready = false;
    _requested = _requested || _awaitingResponse;
    _awaitingResponse = false;
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
    _send?.call({'type': 'request_commands'});
  }

  bool completeRequest() {
    if (_disposed || !_awaitingResponse) return false;
    _awaitingResponse = false;
    return true;
  }

  void dispose() {
    _disposed = true;
    _send = null;
    _ready = false;
    _requested = false;
    _awaitingResponse = false;
  }
}
