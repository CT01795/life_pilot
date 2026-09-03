import 'package:flutter/foundation.dart';
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
import 'package:life_pilot/subscription/widgets_subscription_usage.dart';

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
  final ScrollController _cityScrollController = ScrollController();
  bool _hasLoaded = false; // ✅ 避免重複觸發 loadEvents()
  bool _isBackfillingCoordinates = false;
  int _coordinateBackfillOffset = 0;

  ControllerEvent get _controller => widget.controllerEvent;

  late final ControllerAppBarActions _appBarHandler;

  @override
  void dispose() {
    _cityScrollController.dispose();
    super.dispose();
  }

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
      await widget.auth.refreshSubscriptionUsage();
      await _controller.loadEvents(isGetPublicEvents: true);
    }
  }

  void _showCityList(String? city) {
    setState(() {
      _selectedCity = city;
      _showMap = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_cityScrollController.hasClients) {
        _cityScrollController.jumpTo(0);
      }
      if (_controller.scrollController.hasClients) {
        _controller.scrollController.jumpTo(0);
      }
    });
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
    final pageState = context.select<
        ControllerEvent,
        ({
          bool loading,
          bool error,
          bool canRefresh,
          bool refreshing,
          bool running
        })>(
      (controller) => (
        loading: controller.isLoadingEvents,
        error: controller.hasLoadEventsError,
        canRefresh: controller.canRefreshPublicEvents,
        refreshing: controller.isRefreshingPublicEvents,
        running: controller.publicEventsRefreshRunning,
      ),
    );

    return Scaffold(
        appBar: widgetsWhiteAppBar(
          title: widget.title,
          enableSearchAndExport: true,
          enableUpload: widget.auth.isSysAdmin,
          onRefresh: pageState.canRefresh
              ? () async {
                  final succeeded = await _controller.refreshPublicEvents();
                  if (!context.mounted) return;
                  AppNavigator.showSnackBar(
                    succeeded
                        ? loc.eventRefreshSucceeded
                        : pageState.running
                            ? loc.eventRefreshRunning
                            : loc.eventRefreshFailed,
                  );
                }
              : null,
          isRefreshing: pageState.refreshing,
          refreshTooltip: loc.eventRefresh,
          showMap: _showMap,
          onToggleMap: () => setState(() => _showMap = !_showMap),
          extraMenuActions: [
            if (widget.auth.isSysAdmin && _supportsCoordinateBackfill)
              AppBarMenuAction(
                icon: Icons.add_location_alt_outlined,
                label: loc.mapCoordinateBackfill,
                isLoading: _isBackfillingCoordinates,
                onPressed: _isBackfillingCoordinates
                    ? null
                    : () => _backfillMapCoordinates(loc),
              ),
          ],
          handler: _appBarHandler,
          onAdd: () => _onAddPressed(context),
          loc: loc,
        ),
        body: (!_hasLoaded || pageState.loading)
            ? const Center(child: CircularProgressIndicator())
            : pageState.error
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(loc.dashboardLoadFailed),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () async {
                            _hasLoaded = false;
                            await _safeLoadEvents();
                          },
                          icon: const Icon(Icons.refresh),
                          label: Text(loc.retry),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      if (_controller.fromTableName ==
                          TableNames.calendarEvents)
                        const SubscriptionUsageBanner(
                          resource: 'calendar_events',
                        ),
                      AnimatedBuilder(
                        animation: _appBarHandler,
                        builder: (_, __) => Selector<ControllerEvent, int>(
                          selector: (_, controller) =>
                              controller.filterRevision,
                          builder: (_, __, ___) =>
                              _buildSearchPanel(loc, context),
                        ),
                      ),
                      Expanded(
                          // ✅ 讓 ListView 可以使用剩餘高度
                          child: Selector<ControllerEvent, List<EventItem>>(
                        key: ValueKey((_showMap, _selectedCity)),
                        selector: (_, c) => c.getFilteredEvents(loc), // 只監聽事件列表
                        builder: (_, filteredEvents, __) {
                          final cityCounts = <String, int>{};
                          for (final event in filteredEvents) {
                            final city = eventRegionKey(event.city);
                            if (city.isNotEmpty) {
                              cityCounts.update(
                                city,
                                (count) => count + 1,
                                ifAbsent: () => 1,
                              );
                            }
                          }
                          final cities = cityCounts.keys.toList()
                            ..sort((left, right) {
                              final countComparison = cityCounts[right]!
                                  .compareTo(cityCounts[left]!);
                              return countComparison != 0
                                  ? countComparison
                                  : left.compareTo(right);
                            });
                          final effectiveCity = _selectedCity != null &&
                                  cities.contains(_selectedCity)
                              ? _selectedCity
                              : null;
                          final displayedCities = [...cities];
                          if (effectiveCity != null) {
                            displayedCities
                              ..remove(effectiveCity)
                              ..insert(0, effectiveCity);
                          }
                          if (_selectedCity != effectiveCity) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() => _selectedCity = effectiveCity);
                              }
                            });
                          }
                          final visibleEvents = effectiveCity == null
                              ? filteredEvents
                              : filteredEvents
                                  .where((event) =>
                                      eventRegionKey(event.city) ==
                                      effectiveCity)
                                  .toList();
                          return Column(
                            children: [
                              if (widget.enableCityFilter && cities.isNotEmpty)
                                SizedBox(
                                  height: kIsWeb ? 58 : 54,
                                  child: _buildCityScroller(
                                    children: [
                                      _cityChip(
                                        label:
                                            '${_allCitiesLabel()} (${filteredEvents.length})',
                                        selected: effectiveCity == null,
                                        onSelected: () => _showCityList(null),
                                      ),
                                      ...displayedCities.map(
                                        (city) => _cityChip(
                                          label: '$city (${cityCounts[city]})',
                                          selected: effectiveCity == city,
                                          onSelected: () => _showCityList(city),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  switchInCurve: Curves.easeOut,
                                  switchOutCurve: Curves.easeOut,
                                  child: visibleEvents.isEmpty
                                      ? KeyedSubtree(
                                          key: const ValueKey('empty'),
                                          child: _buildEmptyState(loc),
                                        )
                                      : _showMap
                                          ? KeyedSubtree(
                                              key: const ValueKey('map'),
                                              child: WidgetsEventMap(
                                                events: filteredEvents,
                                                onCitySelected: _showCityList,
                                              ),
                                            )
                                          : KeyedSubtree(
                                              key: const ValueKey('list'),
                                              child: widget.listBuilder(
                                                filteredEvents: visibleEvents,
                                                scrollController: _controller
                                                    .scrollController,
                                              ),
                                            ),
                                ),
                              ),
                            ],
                          );
                        },
                      )),
                    ],
                  ));
  }

  Widget _buildCityScroller({required List<Widget> children}) {
    final cityList = ListView(
      controller: _cityScrollController,
      padding: kIsWeb
          ? const EdgeInsets.fromLTRB(12, 6, 12, 12)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      scrollDirection: Axis.horizontal,
      children: children,
    );
    if (!kIsWeb) return cityList;
    return Scrollbar(
      controller: _cityScrollController,
      thumbVisibility: true,
      interactive: true,
      scrollbarOrientation: ScrollbarOrientation.bottom,
      child: cityList,
    );
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

  Widget _buildEmptyState(AppLocalizations loc) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: Color(0xFF829097)),
            const SizedBox(height: 12),
            Text(widget.emptyText, textAlign: TextAlign.center),
            if (_controller.hasActiveSearchFilters) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _controller.clearSearchFilters,
                icon: const Icon(Icons.filter_alt_off_rounded),
                label: Text(loc.clear),
              ),
            ],
          ],
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
