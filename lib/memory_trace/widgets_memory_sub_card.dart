import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/memory_trace/widgets_memory_card.dart';

class WidgetsMemorySubCard extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final EventViewModel event;

  const WidgetsMemorySubCard(
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
            WidgetsMemoryCard.tags(typeList: event.tags),
          if (event.hasLocation)
            Text(event.locationDisplay,
              softWrap: true, // 允許換行
              overflow: TextOverflow.visible, // 文字超過不截斷
              //overflow: TextOverflow.ellipsis,
            ),
          if (event.masterUrl?.isNotEmpty == true)
            WidgetsMemoryCard.link(context:context, loc: loc, url: event.masterUrl!, eventViewModel: event),
        ],
      ),
    );
  }
}
