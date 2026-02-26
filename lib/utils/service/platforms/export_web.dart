// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/service/export/service_export_platform.dart';

class ServiceExportPlatformImpl implements ServiceExportPlatform {
  @override
  Future<String> exportFile(String filename, Uint8List bytes) async {
    try {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      return filename;
    } catch (e) {
      logger.d('export_failed: ${e.toString()}');
      rethrow;
    }
  }
}
