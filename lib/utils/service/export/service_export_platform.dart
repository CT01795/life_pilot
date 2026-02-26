
import 'dart:typed_data';

abstract class ServiceExportPlatform {
  Future<String> exportFile(String filename, Uint8List bytes);
}
