import 'dart:io' as io;
import 'dart:typed_data';
import 'package:life_pilot/export/common/export_common.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:path_provider/path_provider.dart';

Future<void> exportEventsToExcel(
    {required List<Event> events, required AppLocalizations loc}) async {
  final bytes = buildExcelBytes(events: events, loc: loc);
  final filename = 'events_${DateTime.now().millisecondsSinceEpoch}.xlsx';

  try {
    final file = await _saveToFile(filename, bytes);
    showSnackBar(message: '${loc.export_success}：${file.path}');
  } catch (e) {
    showSnackBar(message: '${loc.export_failed}：$e');
  }
}

Future<io.File> _saveToFile(String filename, Uint8List bytes) async {
  io.Directory dir;

  if (io.Platform.isAndroid) {
    dir = io.Directory('/storage/emulated/0/Download');
  } else if (io.Platform.isWindows) {
    dir = io.Directory('${io.Platform.environment['USERPROFILE']}\\Downloads');
  } else if (io.Platform.isMacOS) {
    dir = io.Directory('${io.Platform.environment['HOME']}/Downloads');
  } else {
    dir = await getApplicationDocumentsDirectory();
  }

  final file = io.File('${dir.path}/$filename');
  await file.create(recursive: true);
  return file.writeAsBytes(bytes);
}
