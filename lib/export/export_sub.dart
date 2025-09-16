import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';

Future<void> exportRecommendedEventsToExcel(BuildContext context, List<Event> events) async {
  final loc = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(loc.not_support_export)),
  );
}