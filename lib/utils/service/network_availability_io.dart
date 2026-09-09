import 'dart:io';

Future<bool> hasNetworkConnection() async {
  try {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.any,
    );
    return interfaces.any((interface) => interface.addresses.isNotEmpty);
  } on SocketException {
    return false;
  }
}
