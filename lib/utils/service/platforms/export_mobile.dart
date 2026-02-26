import 'dart:io' as io;
import 'dart:typed_data';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/utils/service/export/service_export_platform.dart';
import 'package:path_provider/path_provider.dart';

class ServiceExportPlatformImpl implements ServiceExportPlatform {
  @override
  Future<String> exportFile(
      String filename, Uint8List bytes) async {
    try {
      io.Directory dir;
      if (io.Platform.isAndroid) {
        dir = io.Directory('/storage/emulated/0/Download');
      } else if (io.Platform.isIOS) {
        // ✅ iOS: 使用應用程式沙箱的 Documents 或 Downloads
        // iOS 17+ 開始支援 user-visible "Downloads" folder，舊版則 fallback。
        dir = await _getIosDownloadDirectory();
      } else if (io.Platform.isWindows) {
        dir = io.Directory(
            '${io.Platform.environment['USERPROFILE']}\\Downloads');
      } else if (io.Platform.isMacOS) {
        dir = io.Directory('${io.Platform.environment['HOME']}/Downloads');
      } else {
        // ✅ 其他平台 (Linux, Web fallback)
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

  // ✅ 取得 iOS 的下載目錄或備用 Documents 目錄
  Future<io.Directory> _getIosDownloadDirectory() async {
    try {
      // iOS 17+ 若 app 啟用「File Sharing」可直接使用 Downloads
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return downloads;

      // fallback: 使用 Documents
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      // 最保險的 fallback
      return await getApplicationDocumentsDirectory();
    }
  }
}
