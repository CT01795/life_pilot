// lib/views/widgets/event/sub_event_card.dart
import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/widgets_event_card.dart';

class WidgetsEventSubCard extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback onOpenLink;
  final EventViewModel event;

  const WidgetsEventSubCard(
      {super.key,
      required this.event,
      this.onTap,
      this.onDelete,
      required this.onOpenLink});

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
            WidgetsEventCard.tags(typeList: event.tags),
          if (event.hasLocation)
            Text(event.locationDisplay,
              softWrap: true, // 允許換行
              overflow: TextOverflow.visible, // 文字超過不截斷
              //overflow: TextOverflow.ellipsis,
            ),
          if (event.masterUrl?.isNotEmpty == true)
            WidgetsEventCard.link(text: loc.clickHereToSeeMore, onTap: onOpenLink),
        ],
      ),
    );
  }
}
