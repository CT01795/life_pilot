import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/utils_app_bar_action.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:provider/provider.dart';

class PageRecommendedEvent extends StatefulWidget {
  const PageRecommendedEvent({super.key});

  @override
  State<PageRecommendedEvent> createState() => _PageRecommendedEventState();
}

class _PageRecommendedEventState extends State<PageRecommendedEvent> {
  String tableName = constTableRecommendedEvents;
  String toTableNamme = constTableCalendarEvents;
  late final ServiceStorage _service;
  late final ScrollController _scrollController;
  late AppBarActionsHandler _handler;
  final TextEditingController _searchController = TextEditingController();

  List<Event> _events = [];
  Set<String> selectedEventIds = {};
  Set<String> removedEventIds = {};

  String _searchKeywords = constEmpty;
  DateTime? _startDate;
  DateTime? _endDate;

  bool isGridView = true;
  bool _showSearchPanel = false;

  final PageStorageBucket _bucket = PageStorageBucket();
  AppLocalizations get loc => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _service = ServiceStorage();
    _scrollController = ScrollController();

    _handler = AppBarActionsHandler(
      serviceStorage: _service,
      context: context,
      refreshCallback: _loadEvents,
      setState: setState,
      isGridViewGetter: () => isGridView,
      showSearchPanelGetter: () => _showSearchPanel,
      onToggleGridView: (val) => setState(() => isGridView = val),
      onToggleShowSearch: (val) {
        setState(() {
          _showSearchPanel = val;
          if (!_showSearchPanel) {
            _clearSearchFilters();
          }
        });
      },
    );

    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final recommended =
        await _service.getRecommendedEvents(tableName: tableName);
    if (mounted) {
      setState(() {
        _events = recommended!;
      });
    }
  }

  void _clearSearchFilters() {
    setState(() {
      _searchController.clear();
      _searchKeywords = constEmpty;
      _startDate = null;
      _endDate = null;
    });
  }

  List<Event> get _filteredEvents => filterEvents(
    events: _events,
    removedEventIds: removedEventIds,
    searchKeywords: _searchKeywords,
    startDate: _startDate,
    endDate: _endDate,
  );

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isAnonymous = Provider.of<ControllerAuth>(context).isAnonymous;

    return PageStorage(
      bucket: _bucket,
      child: Scaffold(
        appBar: buildWhiteAppBar(
          context,
          title: loc.recommended_event,
          enableSearchAndExport: true,
          isGridView: isGridView,
          handler: _handler,
          setState: setState,
          isEditable: !isAnonymous,
          onAdd:
              isAnonymous ? null : () => _handler.onAddEvent(context, tableName),
          tableName: tableName,
        ),
        body: Column(
          children: [
            if (_showSearchPanel)
              buildSearchPanel(
                searchController: _searchController,
                searchKeywords: _searchKeywords,
                startDate: _startDate,
                endDate: _endDate,
                onSearchKeywordsChanged: (value) =>
                    setState(() => _searchKeywords = value),
                onStartDateChanged: (date) => setState(() => _startDate = date),
                onEndDateChanged: (date) => setState(() => _endDate = date),
                setState: setState,
                context: context,
              ),
            Expanded(
              child: _events.isEmpty
                ? Center(child: Text(loc.recommended_event_zero))
                : EventList(
                  events: _filteredEvents,
                  isGridView: isGridView,
                  selectedEventIds: selectedEventIds,
                  removedEventIds: removedEventIds,
                  isEditable: !isAnonymous,
                  serviceStorage: _service,
                  setState: setState,
                  scrollController: _scrollController,
                  refreshCallback: _loadEvents,
                  tableName: tableName,
                  toTableNamme: toTableNamme,
                ),
            ),
          ],
        ),
      ),
    );
  }
}
