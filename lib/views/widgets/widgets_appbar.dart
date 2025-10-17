import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_appbar_actions.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

AppBar widgetsWhiteAppBar({
  required String title,
  required ControllerAppBarActions handler,
  required AppLocalizations loc,
  required String tableName,
  required void Function(void Function()) setState,
  VoidCallback? onAdd,
  bool enableSearchAndExport = false,
}) {
  return AppBar(
    title: Text(title), // TODO 使用傳入 title 而非 constEmpty
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 0,
    actions:
        _buildActions(handler, loc, setState, onAdd, enableSearchAndExport),
  );
}

List<Widget> _buildActions(
  ControllerAppBarActions handler,
  AppLocalizations loc,
  void Function(void Function()) setState,
  VoidCallback? onAdd,
  bool enableSearchAndExport,
) {
  final List<Widget> actions = [];

  if (enableSearchAndExport) {
    actions.addAll([
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: loc.search,
        onPressed: handler.toggleSearchPanel,
      ),
      IconButton(
        icon: const Icon(Icons.download),
        tooltip: loc.export_excel,
        onPressed: handler.exportEvents,
      ),
    ]);
  }

  if (onAdd != null) {
    actions.add(
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: loc.event_add,
        onPressed: onAdd,
      ),
    );
  }

  return actions;
}
