import 'dart:typed_data';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/services/export/service_export_platform.dart';

class ServiceExportPlatformImpl implements ServiceExportPlatform {
  @override
  Future<String> exportFile(String filename, Uint8List bytes) async {
    throw Exception(MSG.notSupportExport);
  }
}
