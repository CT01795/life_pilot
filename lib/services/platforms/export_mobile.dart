import 'dart:io' as io;
import 'dart:typed_data';
import 'package:life_pilot/core/logger.dart';
import 'package:life_pilot/services/export/service_export_platform.dart';
import 'package:path_provider/path_provider.dart';

class ServiceExportPlatformImpl implements ServiceExportPlatform {
  @override
  Future<String> exportFile(
      String filename, Uint8List bytes) async {
    try {
      io.Directory dir;
      if (io.Platform.isAndroid) {
        dir = io.Directory('/storage/emulated/0/Download');
      } else if (io.Platform.isWindows) {
        dir = io.Directory(
            '${io.Platform.environment['USERPROFILE']}\\Downloads');
      } else if (io.Platform.isMacOS) {
        dir = io.Directory('${io.Platform.environment['HOME']}/Downloads');
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final file = io.File('${dir.path}/$filename');
      await file.create(recursive: true);
      await file.writeAsBytes(bytes);
      
      return file.path;
    } catch (e) {
      logger.d('export_failed: ${e.toString()}');
      rethrow;
    }
  }
}
