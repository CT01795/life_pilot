import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/widgets_event_card.dart';

class WidgetsEventDialog extends StatelessWidget {
  final EventViewModel eventViewModel;
  final String tableName;
  const WidgetsEventDialog({
    super.key,
    required this.eventViewModel,
    required this.tableName,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: Insets.h6,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: WidgetsEventCard(
              eventViewModel: eventViewModel,
              tableName: tableName,
              onTap: () => Navigator.pop(context),
            ),
          ),
          PositionedDirectional(
            end: Gaps.w8.width,
            top: Gaps.h48.height,
            child: _buildCloseButton(context: context, loc: loc),
          ),
        ],
      ),
    );
  }

  Widget _buildCloseButton(
      {required BuildContext context, required AppLocalizations loc}) {
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
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}
