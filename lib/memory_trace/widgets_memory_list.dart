import 'package:flutter/material.dart';
import 'package:life_pilot/accounting/controller_accounting_list.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/event/controller_event_ui.dart';
import 'package:life_pilot/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/memory_trace/widgets_memory_card.dart';
import 'package:life_pilot/memory_trace/widgets_memory_dialog.dart';
import 'package:life_pilot/memory_trace/widgets_memory_trailing.dart';
import 'package:provider/provider.dart';

class WidgetsMemoryList extends StatelessWidget {
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
    final viewModels =
        controllerEvent.buildViewModels(events: filteredEvents, loc: loc);

    return ListView.builder(
      key: PageStorageKey(controllerEvent.fromTableName),
      controller: scrollController,
      itemCount: viewModels.length,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      addSemanticIndexes: false,
      itemBuilder: (context, index) {
        EventViewModel eventViewModel = viewModels[index];
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            controllerEvent.preloadWeatherForEvent(eventViewModel);
          }
        });
        final date = eventViewModel.startDate;
        final previousDate =
            index == 0 ? null : viewModels[index - 1].startDate;
        final showDateHeader = date != null && !_sameDay(date, previousDate);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDateHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 2),
                child: Text(
                  _dateLabel(context, date),
                  style: const TextStyle(
                    color: Color(0xFF6D4876),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 38,
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                              width: 2, color: const Color(0xFFE1CDE6)),
                        ),
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF9B67A7),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                  color: Color(0x337E5787), blurRadius: 5),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Container(
                              width: 2, color: const Color(0xFFE1CDE6)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: WidgetsMemoryCard(
                      key: ValueKey(eventViewModel.id),
                      controllerEvent: controllerEvent,
                      eventViewModel: eventViewModel,
                      tableName: controllerEvent.fromTableName,
                      onTap: () => _showEventDialog(
                          context: context,
                          eventViewModel: eventViewModel,
                          tableName: controllerEvent.fromTableName),
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
                ],
              ),
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

  String _dateLabel(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).languageCode;
    return switch (locale) {
      'zh' => '${date.year} 年 ${date.month} 月 ${date.day} 日',
      'ja' => '${date.year}年${date.month}月${date.day}日',
      'ko' => '${date.year}년 ${date.month}월 ${date.day}일',
      _ => '${date.year}/${date.month}/${date.day}',
    };
  }

  void _showEventDialog(
      {required BuildContext context,
      required EventViewModel eventViewModel,
      required String tableName}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color.fromARGB(200, 128, 128, 128),
      builder: (_) => WidgetsMemoryDialog(
        controllerEvent: controllerEvent,
        eventViewModel: eventViewModel,
        tableName: tableName,
      ),
    );
  }
}
