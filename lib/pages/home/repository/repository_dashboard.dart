import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  Future<List<CalendarEvent>> loadTodayEvents(String account) async {
    final now = DateTime.now();
    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final tomorrow = today.add(
      const Duration(days: 3),
    );

    final result = await _supabase
        .from('calendar_events')
        .select()
        .eq('account', account)
        .gte(
          'start_date',
          today.toIso8601String(),
        )
        .lt(
          'start_date',
          tomorrow.toIso8601String(),
        )
        .order(
          'start_date',
          ascending: true,
        )
        .order(
          'start_time',
          ascending: true,
        );

    return (result as List)
        .map(
          (e) => CalendarEvent.fromJson(e),
        )
        .toList();
  }

  Future<List<CalendarEvent>> getSpecificEvent(
    String eventId,
    String account,
  ) async {
    final result = await _supabase
        .from('calendar_events')
        .select()
        .eq('account', account)
        .eq('id', eventId)
        .order(
          'start_date',
          ascending: true,
        )
        .order(
          'start_time',
          ascending: true,
        );

    return (result as List)
        .map(
          (e) => CalendarEvent.fromJson(e),
        )
        .toList();
  }

  Future<void> completeEvent({
    required String id,
    required String account,
  }) async {
    await _supabase
        .from('calendar_events')
        .update({
          'is_completed': true,
        })
        .eq(
          'id',
          id,
        )
        .eq(
          'account',
          account,
        );
  }

  //=====================================================================================================
  Future<DashboardSetting> loadDashboardSetting({
    required String account,
  }) async {
    final result = await _supabase
        .from('dashboard_setting')
        .select()
        .eq('account', account)
        .maybeSingle();

    if (result == null) {
      final setting = DashboardSetting(
          recommendEventCity: '台北', recommendPlaceCity: '台北', language: 'zh');

      await _supabase.from('dashboard_setting').insert({
        'account': account,
        ...setting.toJson(),
      });

      return setting;
    }

    return DashboardSetting.fromJson(result);
  }

  Future<void> saveDashboardSetting({
    required String account,
    required DashboardSetting setting,
  }) async {
    await _supabase.from('dashboard_setting').upsert({
      'account': account,
      ...setting.toJson(),
    });
  }

  Future<List<DashboardCity>> loadEventCities(String account) async {
    final result = await _supabase.rpc(
      'get_event_city_counts',
      params: {
        'input_account': account,
      },
    );

    return (result as List)
        .map(
          (e) => DashboardCity.fromJson(e),
        )
        .toList();
  }

  Future<List<RecommendedEvent>> loadRecommendEvents(
      String account, String city) async {
    final result = await _supabase.rpc(
      'get_home_recommended_events',
      params: {
        'p_account': account,
        'p_city': city,
        'p_limit': 5,
      },
    );

    return (result as List)
        .map(
          (e) => RecommendedEvent.fromJson(e),
        )
        .toList();
  }

  Future<List<DashboardCity>> loadPlaceCities(String account) async {
    final result = await _supabase.rpc(
      'get_place_city_counts',
      params: {
        'input_account': account,
      },
    );

    return (result as List)
        .map(
          (e) => DashboardCity.fromJson(e),
        )
        .toList();
  }

  Future<List<RecommendedPlace>> loadRecommendPlaces(
      String account, String city) async {
    final result = await _supabase.rpc(
      'get_home_recommended_places',
      params: {
        'p_account': account,
        'p_city': city,
        'p_limit': 5,
      },
    );

    return (result as List)
        .map(
          (e) => RecommendedPlace.fromJson(e),
        )
        .toList();
  }

  Future<List<IncomeExpenseItem>> loadTodayIncomeExpense(String account) async {
    final accountResult = await _supabase
        .from('accounting_account')
        .select('id,main_currency')
        .eq(
          'account',
          account,
        )
        .maybeSingle();

    if (accountResult == null) {
      return [];
    }
    final accountId = accountResult['id'];
    final currency = accountResult['main_currency'];
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    );
    final end = start.add(
      const Duration(days: 1),
    );
    final result = await _supabase
        .from('accounting_detail')
        .select()
        .eq(
          'account_id',
          accountId,
        )
        .eq('currency', currency)
        .gte(
          'date',
          start.toIso8601String(),
        )
        .lt(
          'date',
          end.toIso8601String(),
        )
        .order('date', ascending: false);

    return (result as List)
        .map(
          (e) => IncomeExpenseItem.fromJson(e),
        )
        .toList();
  }

  Future<List<PointRecordItem>> loadPoints(String account) async {
    final accountResult = await _supabase
        .from('point_record_account')
        .select('id')
        .eq(
          'account',
          account,
        )
        .maybeSingle();

    if (accountResult == null) {
      return [];
    }
    final accountId = accountResult['id'];
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    );
    final end = start.add(
      const Duration(days: 1),
    );
    final result = await _supabase
        .from('point_record_detail')
        .select()
        .eq(
          'account_id',
          accountId,
        )
        .gte(
          'date',
          start.toIso8601String(),
        )
        .lt(
          'date',
          end.toIso8601String(),
        )
        .order('date', ascending: false);

    return (result as List)
        .map(
          (e) => PointRecordItem.fromJson(e),
        )
        .toList();
  }
}
