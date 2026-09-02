import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';

class DashboardRepository {
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

    final result = await supabase
        .from(TableNames.calendarEvents)
        .select(
          'id,name,start_date,start_time,end_date,end_time,city,location,'
          'type,is_free,description,master_url,is_completed',
        )
        .eq(Fields.account, account)
        .eq('is_completed', false)
        .gte(
          'start_date',
          today.toUtc().toIso8601String(),
        )
        .lt(
          'start_date',
          tomorrow.toUtc().toIso8601String(),
        )
        .order(
          'start_date',
          ascending: true,
        )
        .order(
          'start_time',
          ascending: true,
        )
        .limit(5);

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
    final result = await supabase
        .from(TableNames.calendarEvents)
        .select()
        .eq(Fields.account, account)
        .eq(Fields.id, eventId)
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
    await supabase
        .from(TableNames.calendarEvents)
        .update({
          'is_completed': true,
        })
        .eq(
          Fields.id,
          id,
        )
        .eq(
          Fields.account,
          account,
        );
  }

  //=====================================================================================================
  Future<DashboardSetting> loadDashboardSetting({
    required String account,
  }) async {
    final result = await supabase
        .from(TableNames.dashboardSetting)
        .select()
        .eq(Fields.account, account)
        .maybeSingle();

    if (result == null) {
      final setting = DashboardSetting(
          recommendEventCity: '台北', recommendPlaceCity: '台北', language: 'zh');

      await supabase.from('dashboard_setting').insert({
        Fields.account: account,
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
    await supabase.from(TableNames.dashboardSetting).upsert({
      Fields.account: account,
      ...setting.toJson(),
    });
  }

  Future<List<DashboardCity>> loadEventCities() async {
    final result = await supabase.rpc('get_event_city_counts');

    return (result as List)
        .map(
          (e) => DashboardCity.fromJson(e),
        )
        .toList();
  }

  Future<List<RecommendedEvent>> loadRecommendEvents(String city) async {
    final result = await supabase.rpc(
      'get_home_recommended_events',
      params: {
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

  Future<List<DashboardCity>> loadPlaceCities() async {
    final result = await supabase.rpc('get_place_city_counts');

    return (result as List)
        .map(
          (e) => DashboardCity.fromJson(e),
        )
        .toList();
  }

  Future<List<RecommendedPlace>> loadRecommendPlaces(String city) async {
    final result = await supabase.rpc(
      'get_home_recommended_places',
      params: {
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

  Future<AccountingDashboardSummary> loadAccountingSummary(
      {required String accountId}) async {
    final accountResult = await supabase
        .from(TableNames.accountingAccount)
        .select('id,main_currency,balance')
        .eq(
          Fields.id,
          accountId,
        )
        .eq(Fields.isValid, true)
        .maybeSingle();

    if (accountResult == null) {
      return const AccountingDashboardSummary.empty();
    }
    //final accountId = accountResult[Fields.id];
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
    final result = await supabase
        .from(TableNames.accountingDetail)
        .select('description,value,currency,created_at,date,group')
        .eq(
          'account_id',
          accountId,
        )
        .eq('currency', currency)
        .gte(
          'date',
          start.toUtc().toIso8601String(),
        )
        .lt(
          'date',
          end.toUtc().toIso8601String(),
        )
        .order('date', ascending: false);

    final rows = result as List;
    final records = rows
        .take(5)
        .map(
          (e) => IncomeExpenseItem.fromJson(e),
        )
        .toList();
    return AccountingDashboardSummary(
      records: records,
      total: (accountResult['balance'] ?? 0).toInt(),
      todayTotal: rows.fold<int>(
        0,
        (sum, row) => sum + ((row['value'] ?? 0) as num).toInt(),
      ),
      currency: currency ?? 'TWD',
    );
  }

  Future<PointDashboardSummary> loadPointSummary(
      {required String accountId}) async {
    final accountResult = await supabase
        .from(TableNames.pointRecordAccount)
        .select('id,points')
        .eq(
          Fields.id,
          accountId,
        )
        .eq(Fields.isValid, true)
        .maybeSingle();

    if (accountResult == null) {
      return const PointDashboardSummary.empty();
    }
    //final accountId = accountResult[Fields.id];
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    );
    final end = start.add(
      const Duration(days: 1),
    );
    final result = await supabase
        .from(TableNames.pointRecordDetail)
        .select('description,type,value,created_at,date,group')
        .eq(
          'account_id',
          accountId,
        )
        .gte(
          'date',
          start.toUtc().toIso8601String(),
        )
        .lt(
          'date',
          end.toUtc().toIso8601String(),
        )
        .order('date', ascending: false);

    final rows = result as List;
    final records = rows
        .take(5)
        .map(
          (e) => PointRecordItem.fromJson(e),
        )
        .toList();
    return PointDashboardSummary(
      records: records,
      total: (accountResult['points'] ?? 0).toInt(),
      todayTotal: rows.fold<int>(
        0,
        (sum, row) => sum + ((row['value'] ?? 0) as num).toInt(),
      ),
    );
  }
}
