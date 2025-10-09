import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/utils/utils_common_function.dart';

Future<void> exportEventsToExcel(
    {required List<EventItem> events, required AppLocalizations loc}) async {
  showSnackBar(message: loc.not_support_export);
}
