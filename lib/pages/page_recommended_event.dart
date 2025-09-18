import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/utils_event_app_bar_action.dart';
import 'package:life_pilot/utils/utils_const.dart';
import 'package:provider/provider.dart';

class PageRecommendedEvent extends StatefulWidget {
  const PageRecommendedEvent({super.key});

  @override
  State<PageRecommendedEvent> createState() => _PageRecommendedEventState();
}

class _PageRecommendedEventState extends State<PageRecommendedEvent> {
  bool _initialized = false;
  late ControllerAuth _auth;

  String tableName = constTableRecommendedEvents;
  String toTableName = constTableCalendarEvents;
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auth = Provider.of<ControllerAuth>(context,listen:true);
    if (_initialized) return;
    _initialized = true;

    _handler = AppBarActionsHandler(
      serviceStorage: _service,
      context: context,
      refreshCallback: () => _loadEvents(_auth.currentAccount),
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

    _loadEvents(_auth.currentAccount);
  }

  Future<void> _loadEvents(String? user) async {
    final recommended =
        await _service.getRecommendedEvents(tableName: tableName, inputUser: user);
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
          isEditable: !_auth.isAnonymous,
          onAdd:
              _auth.isAnonymous ? null : () => _handler.onAddEvent(context, tableName),
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
                  isEditable: !_auth.isAnonymous,
                  serviceStorage: _service,
                  setState: setState,
                  scrollController: _scrollController,
                  refreshCallback: () => _loadEvents(_auth.currentAccount),
                  tableName: tableName,
                  toTableName: toTableName,
                ),
            ),
          ],
        ),
      ),
    );
  }
}
