import 'package:flutter/material.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:life_pilot/utils/utils_event_app_bar_action.dart';

typedef EventListBuilder = Widget Function(
  List<Event> filteredEvents,
  ScrollController scrollController,
  VoidCallback refreshCallback,
  Set<String> selectedIds,
  Set<String> removedIds,
  void Function(void Function()) setState,
);

typedef SearchPanelBuilder = Widget Function({
  required TextEditingController searchController,
  required String searchKeywords,
  required void Function(String) onSearchKeywordsChanged,
  required DateTime? startDate,
  required DateTime? endDate,
  required void Function(DateTime?) onStartDateChanged,
  required void Function(DateTime?) onEndDateChanged,
  required void Function(void Function()) setState,
  required BuildContext context,
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

  List<Event> _events = [];
  Set<String> selectedIds = {};
  Set<String> removedIds = {};

  String _searchKeywords = constEmpty;
  DateTime? _startDate;
  DateTime? _endDate;

  bool _showSearchPanel = false;

  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  Future<void> didChangeDependencies() async {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    _handler = AppBarActionsHandler(
      context: context,
      setState: setState,
      tableName: widget.tableName,
      updateEvents: (newEvents) => _events = newEvents,
      showSearchPanelGetter: () => _showSearchPanel,
      onToggleShowSearch: (val) {
        setState(() {
          _showSearchPanel = val;
          if (!_showSearchPanel) _clearSearchFilters();
        });
      },
    );

    await _handler.refreshCallback();
  }

  void _clearSearchFilters() {
    setState(() {
      _searchController.clear();
      _searchKeywords = '';
      _startDate = null;
      _endDate = null;
    });
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
          context,
          title: widget.title,
          enableSearchAndExport: true,
          handler: _handler,
          setState: setState,
          onAdd: () => _handler.onAddEvent(),
          tableName: widget.tableName,
        ),
        body: Column(
          children: [
            if (_showSearchPanel && widget.searchPanelBuilder != null)
              widget.searchPanelBuilder!(
                searchController: _searchController,
                searchKeywords: _searchKeywords,
                onSearchKeywordsChanged: (val) => setState(() => _searchKeywords = val),
                startDate: _startDate,
                endDate: _endDate,
                onStartDateChanged: (date) => setState(() => _startDate = date),
                onEndDateChanged: (date) => setState(() => _endDate = date),
                setState: setState,
                context: context,
              ),
            Expanded(
              child: _events.isEmpty
                  ? Center(child: Text(widget.emptyText))
                  : widget.listBuilder(
                      filterEvents(
                        events: _events,
                        removedEventIds: removedIds,
                        searchKeywords: _searchKeywords,
                        startDate: widget.tableName != constTableRecommendedAttractions ? _startDate : null,
                        endDate: widget.tableName != constTableRecommendedAttractions ? _endDate : null,
                      ),
                      _scrollController,
                      _handler.refreshCallback,
                      selectedIds,
                      removedIds,
                      setState,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
