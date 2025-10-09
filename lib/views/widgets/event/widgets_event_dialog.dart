import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/controller_event.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/my_app.dart';
import 'package:life_pilot/utils/core/utils_const.dart';
import 'package:life_pilot/views/widgets/event/widgets_event_card.dart';

class WidgetsEventDialog extends StatelessWidget {
  final String tableName;
  final EventController eventController;
  const WidgetsEventDialog(
      {super.key, required this.tableName, required this.eventController});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: kGapEIH6,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: WidgetsEventCard(
              eventController: eventController,
              tableName: tableName,
              index: 0,
              onTap: () => Navigator.pop(context),
            ),
          ),
          PositionedDirectional(
            end: kGapW8().width,
            top: kGapH8().height,
            child: _buildCloseButton(loc: loc),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton({required AppLocalizations loc}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.close),
        tooltip: loc.close,
        onPressed: () => navigatorKey.currentState?.pop(),
      ),
    );
  }
}
