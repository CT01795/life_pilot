import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_recommendations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_schedule_query.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard_detail_query.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/service/network_availability.dart';

class DashboardRepository {
  String? get _localOwner => supabase.auth.currentUser?.email?.toLowerCase();

  Future<bool> get _storesLocally async {
    final owner = _localOwner;
    return owner != null &&
        await LocalDataStore.instance.preferredLocation(owner) ==
            DataStorageLocation.local;
  }

  Future<void> _requireNetworkForLocalCloudContent() async {
    if (await _storesLocally && !await hasNetworkConnection()) {
      throw StateError('Network is unavailable for cloud content.');
    }
  }

  Future<List<CalendarEvent>> loadTodayEvents(String account) async {
    final query = ModelDashboardScheduleQuery(DateTime.now());
    final localOwner = _localOwner;
    if (localOwner != null && await _storesLocally) {
      final rows = await LocalDataStore.instance.readOnlyRows(
        owner: localOwner,
        resource: TableNames.calendarEvents,
      );
      return query.selectLocal(rows);
    }

    final result = await supabase
        .from(TableNames.calendarEvents)
        .select(
          'id,name,start_date,start_time,end_date,end_time,country,city,location,'
          'type,is_free,description,master_url,sub_events,is_completed',
        )
        .eq(Fields.account, account)
        .eq('is_completed', false)
        .lt('start_date', query.rangeEnd.toUtc().toIso8601String())
        .or(
          'end_date.gte.${query.today.toUtc().toIso8601String()},'
          'and(end_date.is.null,start_date.gte.${query.today.toUtc().toIso8601String()})',
        );

    return query.decodeRows((result as List).cast<Map<String, dynamic>>());
  }

  Future<void> completeEvent({
    required String id,
    required String account,
  }) async {
    if (await _storesLocally) {
      final row = await LocalDataStore.instance.readOnlyRow(
        owner: account,
        resource: TableNames.calendarEvents,
        id: id,
      );
      if (row == null) return;
      final updated = Map<String, Object?>.from(row)..['is_completed'] = true;
      await LocalDataStore.instance.put(
        owner: account,
        resource: TableNames.calendarEvents,
        id: id,
        data: updated,
        syncState: LocalSyncState.modifiedLocally,
      );
      return;
    }
    await supabase
        .from(TableNames.calendarEvents)
        .update({'is_completed': true})
        .eq(Fields.id, id)
        .eq(Fields.account, account);
  }

  //=====================================================================================================
  Future<DashboardSetting> loadDashboardSetting({
    required String account,
  }) async {
    if (await _storesLocally) {
      final rows = await LocalDataStore.instance.readOnlyRows(
        owner: account,
        resource: TableNames.dashboardSetting,
      );
      if (rows.isNotEmpty) {
        final saved = DashboardSetting.fromJson(rows.first);
        if (saved.accountingAccountId != null || saved.pointAccountId != null) {
          return saved;
        }
      }
      return _recoverLocalDashboardSetting(account);
    }
    final result = await supabase
        .from(TableNames.dashboardSetting)
        .select()
        .eq(Fields.account, account)
        .maybeSingle();

    if (result == null) {
      final setting = DashboardSetting(
        recommendEventCity: '台北',
        recommendPlaceCity: '台北',
        language: 'zh',
      );

      await supabase.from('dashboard_setting').insert({
        Fields.account: account,
        ...setting.toJson(),
      });

      return setting;
    }

    return DashboardSetting.fromJson(result);
  }

  Future<DashboardSetting> _recoverLocalDashboardSetting(String account) async {
    // Local mode must remain independent from Supabase. If the transferred
    // dashboard setting is incomplete, rebuild it from local account rows.
    final accounts = await Future.wait([
      LocalDataStore.instance.readOnlyRows(
        owner: account,
        resource: TableNames.accountingAccount,
      ),
      LocalDataStore.instance.readOnlyRows(
        owner: account,
        resource: TableNames.pointRecordAccount,
      ),
    ]);
    final setting = DashboardSetting.fromLocalAccounts(
      accountingAccounts: accounts[0],
      pointAccounts: accounts[1],
    );
    await LocalDataStore.instance.put(
      owner: account,
      resource: TableNames.dashboardSetting,
      id: account.toLowerCase(),
      data: {Fields.account: account, ...setting.toJson()},
    );
    return setting;
  }

  Future<void> saveDashboardSetting({
    required String account,
    required DashboardSetting setting,
  }) async {
    if (await _storesLocally) {
      await LocalDataStore.instance.put(
        owner: account,
        resource: TableNames.dashboardSetting,
        id: account.toLowerCase(),
        data: {Fields.account: account, ...setting.toJson()},
      );
      return;
    }
    await supabase.from(TableNames.dashboardSetting).upsert({
      Fields.account: account,
      ...setting.toJson(),
    });
  }

  Future<List<DashboardCity>> loadEventCities() async {
    await _requireNetworkForLocalCloudContent();
    final result = await supabase.rpc('get_event_city_counts');

    return (result as List).map((e) => DashboardCity.fromJson(e)).toList();
  }

  Future<List<RecommendedEvent>> loadRecommendEvents(String city) async {
    await _requireNetworkForLocalCloudContent();
    final result = await supabase.rpc(
      'get_home_recommended_events',
      params: {'p_city': city, 'p_limit': 5},
    );

    return ModelDashboardRecommendations.events(
      (result as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<List<DashboardCity>> loadPlaceCities() async {
    await _requireNetworkForLocalCloudContent();
    final result = await supabase.rpc('get_place_city_counts');

    return (result as List).map((e) => DashboardCity.fromJson(e)).toList();
  }

  Future<List<RecommendedPlace>> loadRecommendPlaces(String city) async {
    await _requireNetworkForLocalCloudContent();
    final result = await supabase.rpc(
      'get_home_recommended_places',
      params: {'p_city': city, 'p_limit': 5},
    );

    return ModelDashboardRecommendations.places(
      (result as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<AccountingDashboardSummary> loadAccountingSummary({
    required String accountId,
  }) async {
    if (accountId.isEmpty) return const AccountingDashboardSummary.empty();
    final localOwner = _localOwner;
    if (localOwner != null && await _storesLocally) {
      final account = await LocalDataStore.instance.readOnlyRow(
        owner: localOwner,
        resource: TableNames.accountingAccount,
        id: accountId,
      );
      if (account == null || account[Fields.isValid] != true) {
        return const AccountingDashboardSummary.empty();
      }
      final currency = parseStringValue(
        account['main_currency'],
        fallback: 'TWD',
      );
      final details = await _todayLocalDetails(
        owner: localOwner,
        resource: TableNames.accountingDetail,
        accountId: accountId,
        currency: currency,
      );
      return AccountingDashboardSummary(
        records: details.previewRows.map(IncomeExpenseItem.fromJson).toList(),
        total: parseNumValue(account['balance']),
        todayTotal: details.todayTotal,
        currency: currency,
      );
    }
    final accountResult = await supabase
        .from(TableNames.accountingAccount)
        .select('id,main_currency,balance')
        .eq(Fields.id, accountId)
        .eq(Fields.isValid, true)
        .maybeSingle();

    if (accountResult == null) {
      return const AccountingDashboardSummary.empty();
    }
    //final accountId = accountResult[Fields.id];
    final currency = accountResult['main_currency'];
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final result = await supabase
        .from(TableNames.accountingDetail)
        .select('description,value,currency,created_at,date,group')
        .eq('account_id', accountId)
        .eq('currency', currency)
        .gte('date', start.toUtc().toIso8601String())
        .lt('date', end.toUtc().toIso8601String())
        .order('date', ascending: false);

    final rows = result as List;
    final records = rows
        .take(5)
        .map((e) => IncomeExpenseItem.fromJson(e))
        .toList();
    return AccountingDashboardSummary(
      records: records,
      total: parseNumValue(accountResult['balance']),
      todayTotal: rows.fold<num>(
        0,
        (sum, row) => sum + parseNumValue(row['value']),
      ),
      currency: currency ?? 'TWD',
    );
  }

  Future<PointDashboardSummary> loadPointSummary({
    required String accountId,
  }) async {
    if (accountId.isEmpty) return const PointDashboardSummary.empty();
    final localOwner = _localOwner;
    if (localOwner != null && await _storesLocally) {
      final account = await LocalDataStore.instance.readOnlyRow(
        owner: localOwner,
        resource: TableNames.pointRecordAccount,
        id: accountId,
      );
      if (account == null || account[Fields.isValid] != true) {
        return const PointDashboardSummary.empty();
      }
      final details = await _todayLocalDetails(
        owner: localOwner,
        resource: TableNames.pointRecordDetail,
        accountId: accountId,
      );
      return PointDashboardSummary(
        records: details.previewRows.map(PointRecordItem.fromJson).toList(),
        total: parseIntValue(account['points']),
        todayTotal: details.todayTotal.toInt(),
      );
    }
    final accountResult = await supabase
        .from(TableNames.pointRecordAccount)
        .select('id,points')
        .eq(Fields.id, accountId)
        .eq(Fields.isValid, true)
        .maybeSingle();

    if (accountResult == null) {
      return const PointDashboardSummary.empty();
    }
    //final accountId = accountResult[Fields.id];
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final result = await supabase
        .from(TableNames.pointRecordDetail)
        .select('description,type,value,created_at,date,group')
        .eq('account_id', accountId)
        .gte('date', start.toUtc().toIso8601String())
        .lt('date', end.toUtc().toIso8601String())
        .order('date', ascending: false);

    final rows = result as List;
    final records = rows
        .take(5)
        .map((e) => PointRecordItem.fromJson(e))
        .toList();
    return PointDashboardSummary(
      records: records,
      total: parseIntValue(accountResult['points']),
      todayTotal: rows.fold<int>(
        0,
        (sum, row) => sum + parseIntValue(row['value']),
      ),
    );
  }

  Future<ModelDashboardDetailProjection> _todayLocalDetails({
    required String owner,
    required String resource,
    required String accountId,
    String? currency,
  }) async {
    final query = ModelDashboardDetailQuery(
      now: DateTime.now(),
      accountId: accountId,
      currency: currency,
    );
    final rows = await LocalDataStore.instance.readOnlyRows(
      owner: owner,
      resource: resource,
    );
    return resource == TableNames.pointRecordDetail
        ? query.selectPoints(rows)
        : query.selectAccounting(rows);
  }
}
