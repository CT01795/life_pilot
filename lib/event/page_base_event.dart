import 'package:flutter/material.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/event/controller_appbar_actions.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/page_event_add.dart';
import 'package:life_pilot/utils/service/export/service_export_excel.dart';
import 'package:life_pilot/utils/service/export/service_export_platform.dart';
import 'package:provider/provider.dart';

import '../utils/widgets/widgets_appbar.dart';

typedef EventListBuilder = Widget Function({
  required List<EventItem> filteredEvents,
  required ScrollController scrollController,
});

typedef EventMapBuilder = Widget Function({
  required List<EventItem> filteredEvents,
});

typedef SearchPanelBuilder = Widget Function({
  required ControllerEvent controllerEvent,
  required AppLocalizations loc,
  required BuildContext context,
});

enum EventViewMode { list, map }

class GenericEventPage extends StatefulWidget {
  final ControllerEvent controllerEvent;
  final String title;
  final String emptyText;
  final ControllerAuth auth;
  final EventListBuilder listBuilder;
  final EventMapBuilder? mapBuilder;
  final SearchPanelBuilder? searchPanelBuilder;

  const GenericEventPage({
    super.key,
    required this.controllerEvent,
    required this.title,
    required this.emptyText,
    required this.auth,
    required this.listBuilder,
    required this.mapBuilder,
    this.searchPanelBuilder,
  });

  @override
  State<GenericEventPage> createState() => _GenericEventPageState();
}

class _GenericEventPageState extends State<GenericEventPage> {
  bool _hasLoaded = false; // ✅ 避免重複觸發 loadEvents()

  ControllerEvent get _controller => widget.controllerEvent;

  late final ControllerAppBarActions _appBarHandler;

  EventViewMode _viewMode = EventViewMode.list;

  @override
  void initState() {
    super.initState();
    _appBarHandler = ControllerAppBarActions(
      auth: widget.auth,
      modelEvent: widget.controllerEvent.modelEvent, // 使用頁面同一個 model
      serviceEvent: widget.controllerEvent.serviceEvent,       // 使用頁面同一個 controller
      exportService: context.read<ServiceExportPlatform>(),
      excelService: context.read<ServiceExportExcel>(),
      tableName: widget.controllerEvent.fromTableName,
    );

    // ✅ 只在第一次建立時執行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _safeLoadEvents();
    });
  }

  Future<void> _safeLoadEvents() async {
    if (_hasLoaded) return;
    _hasLoaded = true; 
    await _controller.loadEvents(isGetPublicEvents: true);
  }

  Future<void> _onAddPressed(BuildContext context) async {
    final newEvent = await Navigator.of(context).push<EventItem?>(
      MaterialPageRoute(
        builder: (_) => PageEventAdd(
          controllerEvent: _controller,
        ),
      ),
    );

    if (newEvent != null) {
      await _controller.loadEvents(isGetPublicEvents: true);
    }
  }

  Future<void> _onViewPressed(BuildContext context) async {
    setState(() {
      _viewMode = _viewMode == EventViewMode.list
          ? EventViewMode.map
          : EventViewMode.list;
    });
  }

  Widget _buildSearchPanel(AppLocalizations loc, BuildContext context) {
    if (!widget.controllerEvent.showSearchPanel || widget.searchPanelBuilder == null) {
      return const SizedBox.shrink();
    }

    return widget.searchPanelBuilder!(
      controllerEvent: _controller,
      loc: loc,
      context: context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: widgetsWhiteAppBar(
          title: widget.title,
          enableSearchAndExport: true,
          enableUpload: widget.auth.currentAccount == AuthConstants.sysAdminEmail,
          handler: _appBarHandler,
          onAdd: () => _onAddPressed(context),
          onView: () => _onViewPressed(context),
          loc: loc,),
      body: Column(
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([
              _controller,
              _appBarHandler,
            ]),
            builder: (_, __) => _buildSearchPanel(loc, context),
          ),
          Expanded( // ✅ 讓 ListView 可以使用剩餘高度
            child: Selector<ControllerEvent, List<EventItem>>(
              selector: (_, c) => c.getFilteredEvents(loc), // 只監聽事件列表
              builder: (_, filteredEvents, __) {
                final listView = widget.listBuilder(
                  filteredEvents: filteredEvents,
                  scrollController: _controller.scrollController,
                );

                final mapView = widget.mapBuilder?.call(
                  filteredEvents: filteredEvents,
                );
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _viewMode == EventViewMode.list || mapView == null
                      ? listView
                      : mapView,
                );
              },
            )
          ),
        ],
      )
    );
  }
}