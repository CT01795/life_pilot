import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_auth.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_recommended_event.dart';
import 'package:life_pilot/services/service_storage.dart';
import 'package:life_pilot/utils/utils_app_bar_action.dart';
import 'package:provider/provider.dart';

class PageRecommendedEvent extends StatefulWidget {
  const PageRecommendedEvent({super.key});

  @override
  State<PageRecommendedEvent> createState() => _PageRecommendedEventState();
}

class _PageRecommendedEventState extends State<PageRecommendedEvent> {
  AppLocalizations get loc => AppLocalizations.of(context)!; 
  late AppBarActionsHandler handler;
  bool isGridView = true;
  bool _showSearchPanel = false;

  Set<String> selectedEventIds = {};
  Set<String> removedEventIds = {};

  late final ServiceStorage _service;

  String _searchKeywords = '';
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();

  late final ScrollController _scrollController;
  List<RecommendedEvent> _events = [];
  final PageStorageBucket _bucket = PageStorageBucket();

  @override
  void initState() {
    super.initState();
    _service = ServiceStorage();
    _scrollController = ScrollController();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final recommended = await _service.getRecommendedEvents();
    setState(() {
      _events = recommended!;
    });
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
    handler = AppBarActionsHandler(
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

    final filteredEvents = filterEvents(
      events: _events,
      removedEventIds: removedEventIds,
      searchKeywords: _searchKeywords,
      startDate: _startDate,
      endDate: _endDate,
    );

    bool isAnonymous = Provider.of<ControllerAuth>(context).isAnonymous;
    
    return PageStorage(
      bucket: _bucket,
      child: Scaffold(
        appBar: buildWhiteAppBar(context,
          title:loc.recommended_event,
          enableSearchAndExport: true,
          isGridView: isGridView,
          handler: handler,
          setState: setState,
          isEditable: !isAnonymous,
          onAdd: isAnonymous ? null : () => handler.onAddEvent(context),
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
                      events: filteredEvents,
                      isGridView: isGridView,
                      selectedEventIds: selectedEventIds,
                      removedEventIds: removedEventIds,
                      isEditable:  !isAnonymous, 
                      serviceStorage: _service,
                      setState: setState,
                      scrollController: _scrollController,
                      refreshCallback: _loadEvents, 
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

