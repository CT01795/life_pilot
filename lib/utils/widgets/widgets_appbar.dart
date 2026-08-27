import 'package:flutter/material.dart';
import 'package:life_pilot/event/controller_appbar_actions.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

AppBar widgetsWhiteAppBar({
  required String title,
  required ControllerAppBarActions handler,
  required AppLocalizations loc,
  VoidCallback? onAdd,
  Future<void> Function()? onRefresh,
  String? refreshTooltip,
  bool isRefreshing = false,
  bool enableSearchAndExport = false,
  required bool enableUpload,
  bool showMap = false,
  VoidCallback? onToggleMap,
  List<Widget> extraActions = const [],
}) {
  return AppBar(
    title: Text(title,
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.bold,
        )),
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 0,
    actions: _buildActions(
        handler: handler,
        loc: loc,
        onAdd: onAdd,
        onRefresh: onRefresh,
        refreshTooltip: refreshTooltip,
        isRefreshing: isRefreshing,
        enableSearchAndExport: enableSearchAndExport,
        enableUpload: enableUpload,
        showMap: showMap,
        onToggleMap: onToggleMap,
        extraActions: extraActions),
  );
}

List<Widget> _buildActions({
  required ControllerAppBarActions handler,
  required AppLocalizations loc,
  VoidCallback? onAdd,
  Future<void> Function()? onRefresh,
  String? refreshTooltip,
  bool isRefreshing = false,
  bool enableSearchAndExport = false,
  required bool enableUpload,
  bool showMap = false,
  VoidCallback? onToggleMap,
  List<Widget> extraActions = const [],
}) {
  final List<Widget> actions = [];

  if (onToggleMap != null) {
    actions.add(
      IconButton(
        icon: Icon(showMap ? Icons.view_agenda_outlined : Icons.map_outlined),
        tooltip: showMap ? _listTooltip(loc) : _mapTooltip(loc),
        onPressed: onToggleMap,
      ),
    );
  }

  if (onRefresh != null) {
    actions.add(
      IconButton(
        icon: isRefreshing
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
        tooltip: refreshTooltip,
        onPressed: isRefreshing ? null : () => onRefresh(),
      ),
    );
  }

  actions.addAll(extraActions);

  if (enableSearchAndExport) {
    actions.addAll([
      IconButton(
        icon: const Icon(Icons.search),
        tooltip: loc.search,
        onPressed: () => handler.toggleSearchPanel(loc),
      ),
      IconButton(
          icon: const Icon(Icons.download),
          tooltip: loc.exportExcel,
          onPressed: () async {
            final exportResult = await handler.exportEvents(loc);
            AppNavigator.showSnackBar(exportResult);
          }),
      if (enableUpload)
        IconButton(
            icon: const Icon(Icons.upload),
            tooltip: loc.uploadExcel,
            onPressed: () async {
              final uploadResult = await handler.uploadEvents(loc);
              AppNavigator.showSnackBar(uploadResult);
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

String _listTooltip(AppLocalizations loc) {
  if (loc.localeName.startsWith('zh')) return '切換為清單';
  if (loc.localeName.startsWith('ja')) return 'リストに切り替え';
  if (loc.localeName.startsWith('ko')) return '목록으로 전환';
  return 'Switch to list';
}

String _mapTooltip(AppLocalizations loc) {
  if (loc.localeName.startsWith('zh')) return '切換為地圖';
  if (loc.localeName.startsWith('ja')) return '地図に切り替え';
  if (loc.localeName.startsWith('ko')) return '지도로 전환';
  return 'Switch to map';
}
