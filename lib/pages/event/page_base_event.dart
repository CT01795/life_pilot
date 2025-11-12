import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/calendar/model_event_calendar.dart';
import 'package:life_pilot/controllers/event/controller_appbar_actions.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/pages/event/page_event_add.dart';
import 'package:life_pilot/services/event/service_event.dart';
import 'package:life_pilot/services/export/service_export_excel.dart';
import 'package:life_pilot/services/export/service_export_platform.dart';

import '../../views/widgets/ok_widgets_appbar.dart';

typedef EventListBuilder = Widget Function({
  required List<EventItem> filteredEvents,
  required ScrollController scrollController,
});

typedef SearchPanelBuilder = Widget Function({
  required ModelEventCalendar modelEventCalendar,
  required ControllerEvent controllerEvent,
  required String tableName,
  required AppLocalizations loc,
  required BuildContext context,
});

class GenericEventPage extends StatefulWidget {
  final ControllerEvent controllerEvent;
  final ModelEventCalendar modelEventCalendar;
  final String title;
  final String emptyText;
  final ControllerAuth auth;
  final ServiceEvent serviceEvent;
  final ServiceExportPlatform exportService; // ✅ 新增
  final ServiceExportExcel excelService; // ✅ 新增
  final String tableName;
  final String? toTableName;
  final EventListBuilder listBuilder;
  final SearchPanelBuilder? searchPanelBuilder;

  const GenericEventPage({
    super.key,
    required this.controllerEvent,
    required this.modelEventCalendar,
    required this.title,
    required this.emptyText,
    required this.auth,
    required this.serviceEvent,
    required this.exportService, // ✅ 新增
    required this.excelService, // ✅ 新增
    required this.tableName,
    this.toTableName,
    required this.listBuilder,
    this.searchPanelBuilder,
  });

  @override
  State<GenericEventPage> createState() => _GenericEventPageState();
}

class _GenericEventPageState extends State<GenericEventPage> {
  bool _hasLoaded = false; // ✅ 避免重複觸發 loadEvents()

  ControllerEvent get _controller => widget.controllerEvent;
  ModelEventCalendar get _model => widget.modelEventCalendar;

  @override
  void initState() {
    super.initState();
    // ✅ 只在第一次建立時執行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _safeLoadEvents();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // 若已載入過，則不再重複觸發
    if (!_hasLoaded) {
      _safeLoadEvents();
    }
  }

  Future<void> _safeLoadEvents() async {
    if (_hasLoaded) return;
    _hasLoaded = true; 
    await _controller.loadEvents();
  }

  Future<void> _onAddPressed(BuildContext context) async {
    final newEvent = await Navigator.of(context).push<EventItem?>(
      MaterialPageRoute(
        builder: (_) => PageEventAdd(
          auth: widget.auth,
          serviceEvent: widget.serviceEvent,
          controllerEvent: _controller,
          tableName: widget.tableName,
        ),
      ),
    );

    if (newEvent != null) {
      await _controller.loadEvents();
    }
  }

  Widget _buildSearchPanel(AppLocalizations loc, BuildContext context) {
    if (!_model.showSearchPanel || widget.searchPanelBuilder == null) {
      return const SizedBox.shrink();
    }

    return widget.searchPanelBuilder!(
      modelEventCalendar: _model,
      controllerEvent: _controller,
      tableName: widget.tableName,
      loc: loc,
      context: context,
    );
  }

  Widget _buildBody(AppLocalizations loc) {
    final events = _model.filteredEvents;
    final scrollController = _model.scrollController;

    if (events.isEmpty) {
      return Center(child: Text(widget.emptyText, textAlign: TextAlign.center));
    }

    return widget.listBuilder(
      filteredEvents: events,
      scrollController: scrollController,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: widgetsWhiteAppBar(
          title: widget.title,
          enableSearchAndExport: true,
          handler: ControllerAppBarActions(
            auth: widget.auth,
            modelEventCalendar: _model,
            serviceEvent: widget.serviceEvent,
            controllerEvent: _controller,
            exportService: widget.exportService, // ✅ 新增
            excelService: widget.excelService, // ✅ 新增
            tableName: widget.tableName,
          ),
          onAdd: () => _onAddPressed(context),
          tableName: widget.tableName,
          loc: loc),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Column(
          children: [
            _buildSearchPanel(loc, context),
            Expanded(child: _buildBody(loc)),
          ],
        ),
      )
    );
  }
}