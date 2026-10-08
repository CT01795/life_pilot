import 'dart:async';

class AuthSessionFailure {
  const AuthSessionFailure({required this.source, this.statusCode, this.code});

  final String source;
  final int? statusCode;
  final String? code;
}

/// Reports authentication failures from every shared network client.
///
/// Keeping the classifier here prevents individual feature services from
/// having to duplicate session-expiry handling or accidentally forgetting it.
class AuthSessionGuard {
  AuthSessionGuard._();

  static final StreamController<AuthSessionFailure> _controller =
      StreamController<AuthSessionFailure>.broadcast();

  static Stream<AuthSessionFailure> get failures => _controller.stream;

  static void reportHttpFailure({
    required String source,
    required int statusCode,
    String? responseBody,
  }) {
    final normalizedBody = responseBody?.toLowerCase() ?? '';
    final code = _matchedCode(normalizedBody);
    if (statusCode != 401 && code == null) return;

    _controller.add(
      AuthSessionFailure(source: source, statusCode: statusCode, code: code),
    );
  }

  static String? _matchedCode(String message) {
    const codes = <String>[
      'user_not_found',
      'session_not_found',
      'invalid_jwt',
      'user_banned',
    ];
    for (final code in codes) {
      if (message.contains(code)) return code;
    }
    if (message.contains('user from sub claim in jwt does not exist')) {
      return 'user_not_found';
    }
    if (message.contains('user not found')) return 'user_not_found';
    if (message.contains('session not found')) return 'session_not_found';
    return null;
  }
}
