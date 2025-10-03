import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/l10n/app_localizations_en.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/utils/utils_event_app_bar_action.dart';

typedef EventListBuilder = Widget Function({
  required List<Event> filteredEvents,
  required ScrollController scrollController,
  required VoidCallback refreshCallback,
  required Set<String> selectedEventIds,
  required Set<String> removedEventIds,
  required void Function(void Function()) setState,
});

typedef SearchPanelBuilder = Widget Function({
  required TextEditingController searchController,
  required String searchKeywords,
  required void Function(String) onSearchKeywordsChanged,
  required DateTime? startDate,
  required DateTime? endDate,
  required void Function(DateTime?) onStartDateChanged,
  required void Function(DateTime?) onEndDateChanged,
  required void Function(void Function()) setState,
  required String tableName,
  required AppLocalizations loc,
});

class GenericEventPage extends StatefulWidget {
  final String title;
  final String tableName;
  final String? toTableName;
  final EventListBuilder listBuilder;
  final SearchPanelBuilder? searchPanelBuilder;
  final String emptyText;

  const GenericEventPage({
    super.key,
    required this.title,
    required this.tableName,
    this.toTableName,
    required this.listBuilder,
    this.searchPanelBuilder,
    required this.emptyText,
  });

  @override
  State<GenericEventPage> createState() => _GenericEventPageState();
}

class _GenericEventPageState extends State<GenericEventPage> {
  bool _initialized = false;

  late final ScrollController _scrollController;
  late final AppBarActionsHandler _handler;
  final TextEditingController _searchController = TextEditingController();
  late AppLocalizations _loc;

  List<Event> _events = [];
  Set<String> selectedEventIds = {};
  Set<String> removedEventIds = {};

  String _searchKeywords = constEmpty;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _showSearchPanel = false;

  static final PageStorageBucket _bucket = PageStorageBucket();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // 先初始化 handler 但 loc 還沒拿到，先給空實例，稍後更新
    _handler = AppBarActionsHandler(
      setState: setState,
      tableName: widget.tableName,
      updateEvents: (newEvents) => _events = newEvents,
      loc: AppLocalizationsEn(), // 預設值，避免空指標
      showSearchPanelGetter: () => _showSearchPanel,
      onToggleShowSearch: (val) {
        setState(() {
          _showSearchPanel = val;
          if (!_showSearchPanel) _clearSearchFilters();
        });
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _loc = AppLocalizations.of(context)!;
      _handler.loc = _loc;
      _initialized = true;
      // 用 microtask 避免 async didChangeDependencies 問題
      Future.microtask(() async {
        await _handler.refreshCallback();
        setState(() {}); // 確保 UI 更新
      });
    }
  }

  void _clearSearchFilters() {
    _searchController.clear();
    _searchKeywords = constEmpty;
    _startDate = null;
    _endDate = null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageStorage(
      bucket: _bucket,
      child: Scaffold(
        appBar: buildWhiteAppBar(
            title: widget.title,
            enableSearchAndExport: true,
            handler: _handler,
            setState: setState,
            onAdd: () => _handler.onAddEvent(),
            tableName: widget.tableName,
            loc: _loc),
        body: Column(
          children: [
            if (_showSearchPanel && widget.searchPanelBuilder != null)
              widget.searchPanelBuilder!(
                  searchController: _searchController,
                  searchKeywords: _searchKeywords,
                  onSearchKeywordsChanged: (val) =>
                      setState(() => _searchKeywords = val),
                  startDate: _startDate,
                  endDate: _endDate,
                  onStartDateChanged: (date) =>
                      setState(() => _startDate = date),
                  onEndDateChanged: (date) => setState(() => _endDate = date),
                  setState: setState,
                  tableName: widget.tableName,
                  loc: _loc),
            Expanded(
              child: _events.isEmpty
                  ? Center(child: Text(widget.emptyText))
                  : widget.listBuilder(
                      filteredEvents: filterEvents(
                        events: _events,
                        removedEventIds: removedEventIds,
                        searchKeywords: _searchKeywords,
                        startDate:
                            widget.tableName != constTableRecommendedAttractions
                                ? _startDate
                                : null,
                        endDate:
                            widget.tableName != constTableRecommendedAttractions
                                ? _endDate
                                : null,
                      ),
                      scrollController: _scrollController,
                      refreshCallback: _handler.refreshCallback,
                      selectedEventIds: selectedEventIds,
                      removedEventIds: removedEventIds,
                      setState: setState,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
