import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/accounting_account_navigation.dart';
import 'package:life_pilot/point_record/point_record_account_navigation.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:intl/intl.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event_ui.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/event_copy_flow.dart';
import 'package:life_pilot/memory_trace/widgets_memory_card.dart';
import 'package:life_pilot/memory_trace/model_memory_timeline.dart';
import 'package:life_pilot/memory_trace/widgets_memory_dialog.dart';
import 'package:life_pilot/memory_trace/widgets_memory_trailing.dart';
import 'package:life_pilot/point_record/controller_point_record_list.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

class WidgetsMemoryList extends StatelessWidget {
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
    final timelineCounts = ModelMemoryTimeline.forSnapshot(filteredEvents);
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
        final header = timelineCounts.headerAt(index);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index == 0)
              _MemoryJourneySummary(
                memoryCount: timelineCounts.memoryCount,
                dayCount: timelineCounts.dayCount,
                cityCount: timelineCounts.cityCount,
              ),
            if (header != null && header.month)
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
                    Gaps.w8,
                    Expanded(
                      child: Text(
                        dateFormats.month.format(header.date),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      loc.memoryCountForMonth(
                        timelineCounts.countForMonth(header.date, fallback: 1),
                      ),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (header != null && header.day)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        dateFormats.day.format(header.date),
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
                          timelineCounts.countForDay(header.date, fallback: 1),
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
                  child: Selector<ControllerEvent, bool>(
                    selector: (_, controller) =>
                        controller.isLoadingMemoryRecords,
                    builder: (_, loading, child) =>
                        IgnorePointer(ignoring: loading, child: child),
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
                      onCopy: () => copyEventToAnotherPage(
                        context: context,
                        event: eventViewModel.event,
                        sourceTableName: controllerEvent.fromTableName,
                      ),
                      onOpenLink: () =>
                          controllerEvent.onOpenLink(eventViewModel),
                      onOpenMap: () =>
                          controllerEvent.onOpenMap(eventViewModel),
                      trailing: widgetsMemoryTrailing(
                        context: context,
                        auth: auth,
                        controllerEvent: controllerEvent,
                        event: eventViewModel.event,
                      ),
                      showSubEvents: false,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

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
          Gaps.w8,
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
