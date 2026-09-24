import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:intl/intl.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event_ui.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/memory_trace/widgets_memory_card.dart';
import 'package:life_pilot/memory_trace/widgets_memory_dialog.dart';
import 'package:life_pilot/memory_trace/widgets_memory_trailing.dart';
import 'package:life_pilot/point_record/controller_point_record_list.dart';
import 'package:provider/provider.dart';

class WidgetsMemoryList extends StatelessWidget {
  static final Expando<_MemoryTimelineCounts> _timelineCountsCache = Expando();
  static final Map<String, _MemoryDateFormats> _dateFormatsCache = {};

  final ControllerAuth auth;
  final List<EventItem> filteredEvents;
  final ScrollController scrollController;
  final ControllerEvent controllerEvent;

  const WidgetsMemoryList({
    super.key,
    required this.auth,
    required this.filteredEvents,
    required this.scrollController,
    required this.controllerEvent,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final timelineCounts = _timelineCountsCache[filteredEvents] ??=
        _MemoryTimelineCounts.from(filteredEvents);
    final dateFormats = _dateFormatsCache.putIfAbsent(
      loc.localeName,
      () => _MemoryDateFormats(loc.localeName),
    );

    return ListView.builder(
      key: PageStorageKey(controllerEvent.fromTableName),
      controller: scrollController,
      scrollCacheExtent: const ScrollCacheExtent.pixels(180),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount:
          filteredEvents.length + (controllerEvent.hasMoreMemory ? 1 : 0),
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      itemBuilder: (context, index) {
        if (index == filteredEvents.length) {
          return Selector<ControllerEvent, bool>(
            selector: (_, controller) => controller.isLoadingMoreMemory,
            builder: (context, isLoading, _) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: OutlinedButton.icon(
                onPressed: isLoading
                    ? null
                    : () async {
                        try {
                          await controllerEvent.loadMoreMemoryEvents();
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(loc.dashboardLoadFailed)),
                          );
                        }
                      },
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.history_rounded),
                label: Text(loc.clickHereToSeeMore),
              ),
            ),
          );
        }
        final event = filteredEvents[index];
        final eventViewModel = controllerEvent.buildViewModel(
          event: event,
          loc: loc,
        );
        final date = eventViewModel.startDate;
        final previousDate = index == 0
            ? null
            : filteredEvents[index - 1].startDate;
        final showMonthHeader = date != null && !_sameMonth(date, previousDate);
        final showDateHeader = date != null && !_sameDay(date, previousDate);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index == 0)
              _MemoryJourneySummary(
                memoryCount: timelineCounts.memoryCount,
                dayCount: timelineCounts.dayCount,
                cityCount: timelineCounts.cityCount,
              ),
            if (showMonthHeader)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 20, 12, 0),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_stories_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dateFormats.month.format(date),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      loc.memoryCountForMonth(
                        timelineCounts.monthly[_monthKey(date)] ?? 1,
                      ),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (showDateHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateFormats.day.format(date),
                        style: const TextStyle(
                          color: Color(0xFF6D4876),
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE0F0),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        loc.memoryCountForDay(
                          timelineCounts.daily[_dayKey(date)] ?? 1,
                        ),
                        style: const TextStyle(
                          color: Color(0xFF6D4876),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Stack(
              children: [
                const Positioned(
                  left: 18,
                  top: 0,
                  bottom: 0,
                  child: SizedBox(
                    width: 2,
                    child: ColoredBox(color: Color(0xFFE1CDE6)),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 28,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B67A7),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Color(0x337E5787), blurRadius: 5),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 38),
                  child: WidgetsMemoryCard(
                    key: ValueKey(eventViewModel.id),
                    controllerEvent: controllerEvent,
                    eventViewModel: eventViewModel,
                    tableName: controllerEvent.fromTableName,
                    onTap: () => _showEventDialog(
                      context: context,
                      eventViewModel: eventViewModel,
                      tableName: controllerEvent.fromTableName,
                    ),
                    onDelete: eventViewModel.canDelete
                        ? () async {
                            await onDeletePressed(
                              context: context,
                              controller: controllerEvent,
                              event: eventViewModel.event,
                              loc: loc,
                            );
                          }
                        : null,
                    onAccounting: () => context
                        .read<ControllerAccountingList>()
                        .handleAccounting(
                          context: context,
                          eventId: eventViewModel.id,
                        ),
                    onPoints: () => context
                        .read<ControllerPointRecordList>()
                        .handlePointRecord(
                          context: context,
                          eventId: eventViewModel.id,
                        ),
                    onOpenLink: () =>
                        controllerEvent.onOpenLink(eventViewModel),
                    onOpenMap: () => controllerEvent.onOpenMap(eventViewModel),
                    trailing: widgetsMemoryTrailing(
                      context: context,
                      auth: auth,
                      controllerEvent: controllerEvent,
                      event: eventViewModel.event,
                    ),
                    showSubEvents: false,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  bool _sameDay(DateTime date, DateTime? other) {
    return other != null &&
        date.year == other.year &&
        date.month == other.month &&
        date.day == other.day;
  }

  int _dayKey(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  int _monthKey(DateTime date) => date.year * 100 + date.month;

  bool _sameMonth(DateTime date, DateTime? other) =>
      other != null && date.year == other.year && date.month == other.month;

  void _showEventDialog({
    required BuildContext context,
    required EventViewModel eventViewModel,
    required String tableName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color.fromARGB(200, 128, 128, 128),
      builder: (_) => WidgetsMemoryDialog(
        controllerEvent: controllerEvent,
        eventViewModel: eventViewModel,
        tableName: tableName,
        onAccounting: () => context
            .read<ControllerAccountingList>()
            .handleAccounting(context: context, eventId: eventViewModel.id),
        onPoints: () => context
            .read<ControllerPointRecordList>()
            .handlePointRecord(context: context, eventId: eventViewModel.id),
      ),
    );
  }
}

class _MemoryJourneySummary extends StatelessWidget {
  const _MemoryJourneySummary({
    required this.memoryCount,
    required this.dayCount,
    required this.cityCount,
  });

  final int memoryCount;
  final int dayCount;
  final int cityCount;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.route_outlined, color: colors.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loc.memoryJourneySummary(memoryCount, dayCount, cityCount),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryDateFormats {
  _MemoryDateFormats(String locale)
    : month = DateFormat.yMMMM(locale),
      day = DateFormat.yMMMMd(locale);

  final DateFormat month;
  final DateFormat day;
}

class _MemoryTimelineCounts {
  const _MemoryTimelineCounts({
    required this.daily,
    required this.monthly,
    required this.memoryCount,
    required this.dayCount,
    required this.cityCount,
  });

  factory _MemoryTimelineCounts.from(List<EventItem> events) {
    final daily = <int, int>{};
    final monthly = <int, int>{};
    final cities = <String>{};
    for (final event in events) {
      final date = event.startDate;
      if (date == null) continue;
      final dayKey = date.year * 10000 + date.month * 100 + date.day;
      final monthKey = date.year * 100 + date.month;
      daily[dayKey] = (daily[dayKey] ?? 0) + 1;
      monthly[monthKey] = (monthly[monthKey] ?? 0) + 1;
      final city = event.city.trim().toLowerCase();
      if (city.isNotEmpty) cities.add(city);
    }
    return _MemoryTimelineCounts(
      daily: daily,
      monthly: monthly,
      memoryCount: events.length,
      dayCount: daily.length,
      cityCount: cities.length,
    );
  }

  final Map<int, int> daily;
  final Map<int, int> monthly;
  final int memoryCount;
  final int dayCount;
  final int cityCount;
}
