import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/models/model_recommended_event.dart';
import 'package:life_pilot/utils/utils_common_function.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceStorage {
  final _client = Supabase.instance.client;
  ServiceStorage();

  List<RecommendedEvent>? allEvents;

  Future<List<RecommendedEvent>?> getRecommendedEvents() async {
    final startOfTwoDaysAgo = DateTime.now().subtract(const Duration(days: 1));
    final today = DateTime(
        startOfTwoDaysAgo.year, startOfTwoDaysAgo.month, startOfTwoDaysAgo.day);
    final isoDate = today.toIso8601String();

    final response = await _client
        .from('recommended_events')
        .select('*')
        .gte('start_date', isoDate)
        .order('start_date', ascending: true)
        .order('start_time', ascending: true)
        .order('city', ascending: true)
        .order('name', ascending: true);
    allEvents = response.map((e) => RecommendedEvent.fromJson(e)).toList();
    return allEvents;
  }

  Future<void> saveRecommendedEvent(
      BuildContext context, RecommendedEvent event, bool isNew) async {
    try {
      AppLocalizations loc = AppLocalizations.of(context)!;
      if (event.name.isEmpty) {
        showSnackBar(context, loc.event_save_error);
        throw Exception(loc.event_save_error);
      }
      final Map<String, dynamic> data = event.toJson();
      final List<Map<String, dynamic>> list = [data];
      if (isNew) {
        await _client.from('recommended_events').insert(list);
      } else {
        await _client
            .from('recommended_events')
            .update(data)
            .eq('id', event.id);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteRecommendedEvent(RecommendedEvent event) async {
    try {
      await _client.from('recommended_events').delete().eq('id', event.id);
    } catch (e) {
      rethrow;
    }
  }
}
