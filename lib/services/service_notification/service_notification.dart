export '../platforms/notification_stub.dart'
  if (dart.library.io) '../platforms/notification_mobile.dart'
  if (dart.library.html) '../platforms/notification_web.dart';
