import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event_item.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/core/utils_locator.dart';
import 'package:life_pilot/utils/utils_common_function.dart';

import '../export/export_entry.dart';

class ControllerAppBarActions {
  final String tableName;
  final AppLocalizations loc;
  final void Function(void Function()) setState;
  final void Function(List<EventItem>) updateEvents;
  final bool Function() showSearchPanelGetter;
  final void Function(bool) onToggleShowSearch;

  ControllerAuth get _auth => getIt<ControllerAuth>();
  final ServiceStorage _service = getIt<ServiceStorage>();

  ControllerAppBarActions({
    required this.setState,
    required this.tableName,
    required this.loc,
    required this.updateEvents,
    required this.showSearchPanelGetter,
    required this.onToggleShowSearch,
  });

  void toggleSearchPanel() {
    setState(() {
      onToggleShowSearch(!showSearchPanelGetter());
    });
  }

  Future<void> refreshEvents() async {
    try {
      final events = await loadEvents(tableName: tableName);
      setState(() => updateEvents(events));
    } catch (e) {
      showSnackBar(message: "Failed to load events: $e");
    }
  }

  Future<void> exportEvents() async {
    try {
      final events = await _service.getEvents(
          tableName: tableName, inputUser: _auth.currentAccount);
      if (events == null || events.isEmpty) {
        showSnackBar(message: loc.no_events_to_export);
        return;
      }
      await exportEventsToExcel(events: events, loc: loc);
    } catch (e) {
      showSnackBar(message: "${loc.export_failed}：$e");
    }
  }
}
