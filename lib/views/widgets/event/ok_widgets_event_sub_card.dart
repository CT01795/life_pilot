// lib/views/widgets/event/sub_event_card.dart
import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/event/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/views/widgets/event/ok_widgets_event_card.dart';

class WidgetsEventSubCard extends StatelessWidget {
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final EventViewModel event;

  const WidgetsEventSubCard(
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
            WidgetsEventCard.tags(typeList: event.tags),
          if (event.hasLocation)
            Text(event.locationDisplay,
              overflow: TextOverflow.ellipsis,
              softWrap: true,),
          if (event.masterUrl?.isNotEmpty == true)
            WidgetsEventCard.link(loc: loc, url: event.masterUrl!),
        ],
      ),
    );
  }
}
