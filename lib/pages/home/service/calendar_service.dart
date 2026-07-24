import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class CalendarService {
  final SupabaseClient _supabase =
      Supabase.instance.client;

  /// 檢查是否已加入
  Future<bool> existsRecommendedEvent({
    required String account,
    required RecommendedEvent event,
  }) async {

    final result =
        await _supabase
            .from('calendar_events')
            .select('id')
            .eq(
              'account',
              account,
            )
            .eq(
              'source',
              'recommended_events',
            )
            .eq(
              'name',
              event.name,
            )
            .eq(
              'start_date',
              event.startDate!
                  .toIso8601String(),
            )
            .maybeSingle();


    return result != null;
}



  /// 加入行事曆
  Future<void> addRecommendedEvent({
    required String account,
    required RecommendedEvent event,
  }) async {


    await _supabase
        .from('calendar_events')
        .insert({

          // 新的 id
          'id':
              const Uuid().v4(),


          'account':
              account,


          'master_url':
              event.masterUrl,


          'start_date':
              event.startDate
                  ?.toIso8601String(),


          'end_date':
              event.endDate
                  ?.toIso8601String(),


          'start_time':
              event.startTime,


          'end_time':
              event.endTime,


          'city':
              event.city,


          'location':
              event.location,


          'name':
              event.name,


          'type':
              event.type,


          'description':
              event.description,

          'is_completed':
              false,

        });

  }
}