// ignore: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:life_pilot/export/common/export_common.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/utils/utils_common_function.dart';

Future<void> exportEventsToExcel(
    {required List<Event> events, required AppLocalizations loc}) async {
  final bytes = buildExcelBytes(events: events, loc: loc);
  final filename = 'events_${DateTime.now().millisecondsSinceEpoch}.xlsx';
  _downloadOnWeb(filename: filename, data: bytes);
  showSnackBar(message: '${loc.downloaded}：$filename');
}

void _downloadOnWeb({required String filename, required Uint8List data}) {
  final blob = html.Blob([data]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
