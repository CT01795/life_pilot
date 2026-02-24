// lib/views/widgets/event/sub_event_card.dart
import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/event/model_event_view.dart';
import 'package:life_pilot/views/widgets/calendar/widgets_calendar_card.dart';

class WidgetsCalendarSubCard extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final EventViewModel event;

  const WidgetsCalendarSubCard(
      {super.key,
      required this.event,
      this.onTap,
      this.onDelete,});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      margin: Insets.directionalL20T6,
      padding: Insets.all4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("👉 ${event.name}",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(event.dateRange),
          if(event.tags.isNotEmpty)
            WidgetsCalendarCard.tags(typeList: event.tags),
          if (event.hasLocation)
            Text(event.locationDisplay,
              softWrap: true, // 允許換行
              overflow: TextOverflow.visible, // 文字超過不截斷
              //overflow: TextOverflow.ellipsis,
            ),
          if (event.masterUrl?.isNotEmpty == true)
            WidgetsCalendarCard.link(context:context, loc: loc, url: event.masterUrl!, eventViewModel: event),
        ],
      ),
    );
  }
}
