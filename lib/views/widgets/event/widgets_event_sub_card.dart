// lib/views/widgets/event/sub_event_card.dart
import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_card.dart';

class WidgetsEventSubCard extends StatelessWidget {
  final String parentLocation;
  final EventController eventController;

  const WidgetsEventSubCard({
    super.key,
    required this.parentLocation,
    required this.eventController
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final showLocation = (eventController.hasLocation)
        && eventController.location != parentLocation;

    return Container(
      width: double.infinity,
      margin: kGapEIL20R0T6B0,
      padding: kGapEI4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("👉 ${eventController.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(eventController.dateRange),
          if (eventController.fee.isNotEmpty) WidgetsEventCard.tags(types: eventController.fee),
          if (eventController.type.isNotEmpty) WidgetsEventCard.tags(types: eventController.type),
          if (showLocation)
            WidgetsEventCard.location(eventController: eventController),
          if (eventController.masterUrl?.isNotEmpty == true)
            WidgetsEventCard.link(loc: loc, url: eventController.masterUrl!),
        ],
      ),
    );
  }
}
