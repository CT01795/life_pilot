import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

/// Editable data area of a record confirmation dialog. The tooltip is scoped
/// to this row, not the dialog title or its confirm/cancel actions.
class WidgetsRecordPreviewTile extends StatelessWidget {
  const WidgetsRecordPreviewTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget title;
  final Widget subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: AppLocalizations.of(context)!.tapToEditRecordHint,
    child: ListTile(
      dense: true,
      isThreeLine: true,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    ),
  );
}
