import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_generic_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/utils/utils_event_app_bar_action.dart';
import 'package:provider/provider.dart';

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
  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<ControllerGenericEvent>(context);
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildWhiteAppBar(
        title: widget.title,
        enableSearchAndExport: true,
        handler: AppBarActionsHandler(
          setState: setState,
          showSearchPanelGetter: () => controller.showSearchPanel,
          onToggleShowSearch: (value) => controller.toggleSearchPanel(value: value),
          tableName: widget.tableName,
          updateEvents: (newEvents) => controller.setEvents(events: newEvents),
          loc: loc,
        ),
        setState: setState,
        onAdd: () => controller.onAddEvent(),
        tableName: widget.tableName,
        loc: loc),
      body: Column(
        children: [
          if (controller.showSearchPanel && widget.searchPanelBuilder != null)
            widget.searchPanelBuilder!(
                searchController: controller.searchController,
                searchKeywords: controller.searchKeywords,
                onSearchKeywordsChanged: (value) => controller.updateSearch(keywords: value),
                startDate: controller.startDate,
                endDate: controller.endDate,
                onStartDateChanged: (value) => controller.updateStartDate(date: value),
                onEndDateChanged: (value) => controller.updateEndDate(date: value),
                setState: setState,
                tableName: widget.tableName,
                loc: loc),
          Expanded(
            child: controller.filteredEvents.isEmpty
              ? Center(child: Text(widget.emptyText))
              : widget.listBuilder(
                  filteredEvents: controller.filteredEvents,
                  scrollController: controller.scrollController,
                  refreshCallback: controller.loadEvents,
                  selectedEventIds: controller.selectedEventIds,
                  removedEventIds: controller.removedEventIds,
                  setState: setState,
                ),
          ),
        ],
      ),
    );
  }
}
