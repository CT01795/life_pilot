import 'package:flutter/material.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/event/model_event_calendar.dart';
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

typedef SearchPanelBuilder = Widget Function({
  required ModelEventCalendar modelEventCalendar,
  required ControllerEvent controllerEvent,
  required AppLocalizations loc,
  required BuildContext context,
});

class GenericEventPage extends StatefulWidget {
  final ControllerEvent controllerEvent;
  final ModelEventCalendar _modelEventCalendar;
  final String title;
  final String emptyText;
  final ControllerAuth auth;
  final EventListBuilder listBuilder;
  final SearchPanelBuilder? searchPanelBuilder;

  const GenericEventPage({
    super.key,
    required this.controllerEvent,
    required ModelEventCalendar modelEventCalendar,
    required this.title,
    required this.emptyText,
    required this.auth,
    required this.listBuilder,
    this.searchPanelBuilder,
  }): _modelEventCalendar = modelEventCalendar;

  @override
  State<GenericEventPage> createState() => _GenericEventPageState();
}

class _GenericEventPageState extends State<GenericEventPage> {
  bool _hasLoaded = false; // ✅ 避免重複觸發 loadEvents()

  ControllerEvent get _controller => widget.controllerEvent;
  ModelEventCalendar get _model => widget._modelEventCalendar;

  late final ControllerAppBarActions _appBarHandler;

  @override
  void initState() {
    super.initState();
    _appBarHandler = ControllerAppBarActions(
      auth: widget.auth,
      modelEventCalendar: widget._modelEventCalendar, // 使用頁面同一個 model
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
          controllerEvent: _controller,
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
      loc: loc,
      context: context,
    );
  }

  Widget _buildBody(AppLocalizations loc) {
    final events = _model.getFilteredEvents(loc);
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
          enableUpload: widget.auth.currentAccount == AuthConstants.sysAdminEmail,
          handler: _appBarHandler,
          onAdd: () => _onAddPressed(context),
          loc: loc),
      body: AnimatedBuilder(
        animation: Listenable.merge([_controller, _appBarHandler]),
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