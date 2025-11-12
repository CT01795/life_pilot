import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/event/controller_appbar_actions.dart';
import 'package:life_pilot/core/app_navigator.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

AppBar widgetsWhiteAppBar({
  required String title,
  required ControllerAppBarActions handler,
  required AppLocalizations loc,
  required String tableName,
  VoidCallback? onAdd,
  bool enableSearchAndExport = false,
}) {
  return AppBar(
    title: Text(title, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold,)),
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 0,
    actions: _buildActions(
        handler: handler,
        loc: loc,
        onAdd: onAdd,
        enableSearchAndExport: enableSearchAndExport),
  );
}

List<Widget> _buildActions({
  required ControllerAppBarActions handler,
  required AppLocalizations loc,
  VoidCallback? onAdd,
  bool enableSearchAndExport = false,
}) {
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
          tooltip: loc.exportExcel,
          onPressed: () async {
            final exportResult = await handler.exportEvents(loc);
            AppNavigator.showSnackBar(exportResult);
          }),
    ]);
  }

  if (onAdd != null) {
    actions.add(
      IconButton(
        icon: const Icon(Icons.add),
        tooltip: loc.eventAdd,
        onPressed: onAdd,
      ),
    );
  }

  return actions;
}
