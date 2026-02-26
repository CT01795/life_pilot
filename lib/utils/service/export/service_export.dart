export '../platforms/export_stub.dart'
    if (dart.library.io) '../platforms/export_mobile.dart'
    if (dart.library.html) '../platforms/export_web.dart';
