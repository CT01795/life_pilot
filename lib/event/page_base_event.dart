import 'package:flutter/material.dart';
import 'package:life_pilot/event/controller_appbar_actions.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/page_event_add.dart';
import 'package:life_pilot/event/widgets_event_map.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:life_pilot/utils/const.dart';
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

class GenericEventPage extends StatefulWidget {
  final ControllerEvent controllerEvent;
  final String title;
  final String emptyText;
  final ControllerAuth auth;
  final EventListBuilder listBuilder;
  final SearchPanelBuilder? searchPanelBuilder;
  final bool enableCityFilter;

  const GenericEventPage({
    super.key,
    required this.controllerEvent,
    required this.title,
    required this.emptyText,
    required this.auth,
    required this.listBuilder,
    this.searchPanelBuilder,
    this.enableCityFilter = false,
  });

  @override
  State<GenericEventPage> createState() => _GenericEventPageState();
}

class _GenericEventPageState extends State<GenericEventPage> {
  String? _selectedCity;
  bool _showMap = false;
  bool _hasLoaded = false; // ✅ 避免重複觸發 loadEvents()
  bool _isBackfillingCoordinates = false;
  int _coordinateBackfillOffset = 0;

  ControllerEvent get _controller => widget.controllerEvent;

  late final ControllerAppBarActions _appBarHandler;

  @override
  void initState() {
    super.initState();
    _appBarHandler = ControllerAppBarActions(
      auth: widget.auth,
      modelEvent: widget.controllerEvent.modelEvent, // 使用頁面同一個 model
      serviceEvent: widget.controllerEvent.serviceEvent, // 使用頁面同一個 controller
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
    await _controller.checkPublicEventsUpdatedToday();
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

  Widget _buildSearchPanel(AppLocalizations loc, BuildContext context) {
    if (!widget.controllerEvent.showSearchPanel ||
        widget.searchPanelBuilder == null) {
      return const SizedBox.shrink();
    }

    return widget.searchPanelBuilder!(
      controllerEvent: _controller,
      loc: loc,
      context: context,
    );
  }

  bool get _supportsCoordinateBackfill =>
      _controller.fromTableName == TableNames.recommendEvents ||
      _controller.fromTableName == TableNames.recommendPlaces;

  Future<void> _backfillMapCoordinates(AppLocalizations loc) async {
    if (_isBackfillingCoordinates) return;
    setState(() => _isBackfillingCoordinates = true);
    try {
      final result = await _controller.serviceEvent.backfillMapCoordinates(
        tableName: _controller.fromTableName,
        offset: _coordinateBackfillOffset,
      );
      _coordinateBackfillOffset = result.nextOffset;
      if (!mounted) return;
      AppNavigator.showSnackBar(
        loc.mapCoordinateBackfillResult(
          result.saved,
          result.remaining,
          result.coveragePercent.toStringAsFixed(2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      AppNavigator.showSnackBar(loc.mapCoordinateBackfillFailed);
    } finally {
      if (mounted) setState(() => _isBackfillingCoordinates = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    context.watch<ControllerEvent>();

    return Scaffold(
        appBar: widgetsWhiteAppBar(
          title: widget.title,
          enableSearchAndExport: true,
          enableUpload: widget.auth.isSysAdmin,
          onRefresh: _controller.canRefreshPublicEvents
              ? () async {
                  final succeeded = await _controller.refreshPublicEvents();
                  if (!context.mounted) return;
                  AppNavigator.showSnackBar(
                    succeeded
                        ? loc.eventRefreshSucceeded
                        : _controller.publicEventsRefreshRunning
                            ? loc.eventRefreshRunning
                            : loc.eventRefreshFailed,
                  );
                }
              : null,
          isRefreshing: _controller.isRefreshingPublicEvents,
          refreshTooltip: loc.eventRefresh,
          showMap: _showMap,
          onToggleMap: () => setState(() => _showMap = !_showMap),
          extraActions: [
            if (widget.auth.isSysAdmin && _supportsCoordinateBackfill)
              IconButton(
                icon: _isBackfillingCoordinates
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_location_alt_outlined),
                tooltip: loc.mapCoordinateBackfill,
                onPressed: _isBackfillingCoordinates
                    ? null
                    : () => _backfillMapCoordinates(loc),
              ),
          ],
          handler: _appBarHandler,
          onAdd: () => _onAddPressed(context),
          loc: loc,
        ),
        body: Column(
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([
                _controller,
                _appBarHandler,
              ]),
              builder: (_, __) => _buildSearchPanel(loc, context),
            ),
            Expanded(
                // ✅ 讓 ListView 可以使用剩餘高度
                child: Selector<ControllerEvent, List<EventItem>>(
              selector: (_, c) => c.getFilteredEvents(loc), // 只監聽事件列表
              builder: (_, filteredEvents, __) {
                final cities = filteredEvents
                    .map((event) => eventRegionKey(event.city))
                    .where((city) => city.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
                final effectiveCity =
                    _selectedCity != null && cities.contains(_selectedCity)
                        ? _selectedCity
                        : null;
                if (_selectedCity != effectiveCity) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() => _selectedCity = effectiveCity);
                  });
                }
                final visibleEvents = effectiveCity == null
                    ? filteredEvents
                    : filteredEvents
                        .where((event) =>
                            eventRegionKey(event.city) == effectiveCity)
                        .toList();
                return Column(
                  children: [
                    if (widget.enableCityFilter && cities.isNotEmpty)
                      SizedBox(
                        height: 54,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          scrollDirection: Axis.horizontal,
                          children: [
                            _cityChip(
                              label: _allCitiesLabel(),
                              selected: effectiveCity == null,
                              onSelected: () =>
                                  setState(() => _selectedCity = null),
                            ),
                            ...cities.map(
                              (city) => _cityChip(
                                label: city,
                                selected: effectiveCity == city,
                                onSelected: () =>
                                    setState(() => _selectedCity = city),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: visibleEvents.isEmpty
                          ? Center(child: Text(widget.emptyText))
                          : _showMap
                              ? WidgetsEventMap(
                                  events: filteredEvents,
                                  onCitySelected: (city) {
                                    setState(() {
                                      _selectedCity = city;
                                      _showMap = false;
                                    });
                                  },
                                )
                              : widget.listBuilder(
                                  filteredEvents: visibleEvents,
                                  scrollController:
                                      _controller.scrollController,
                                ),
                    ),
                  ],
                );
              },
            )),
          ],
        ));
  }

  Widget _cityChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        onSelected: (_) => onSelected(),
        avatar: selected ? const Icon(Icons.place_rounded, size: 16) : null,
        label: Text(label),
        showCheckmark: false,
        selectedColor: const Color(0xFFD9F3EE),
        side: BorderSide(
          color: selected ? const Color(0xFF16877B) : const Color(0xFFDDE5E8),
        ),
        labelStyle: TextStyle(
          color: selected ? const Color(0xFF086A60) : const Color(0xFF526168),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }

  String _allCitiesLabel() {
    return switch (Localizations.localeOf(context).languageCode) {
      'zh' => '全部城市',
      'ja' => 'すべての都市',
      'ko' => '모든 도시',
      _ => 'All cities',
    };
  }
}
