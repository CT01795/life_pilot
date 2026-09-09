import 'dart:js_interop';

@JS('navigator.onLine')
external bool? get _navigatorOnline;

Future<bool> hasNetworkConnection() async => _navigatorOnline ?? true;
