import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_event.dart';
import 'package:life_pilot/utils/utils_common_function.dart';

Future<void> exportRecommendedEventsToExcel(
    BuildContext context, List<Event> events) async {
  final loc = AppLocalizations.of(context)!;
  showSnackBar(context, loc.not_support_export);
}
