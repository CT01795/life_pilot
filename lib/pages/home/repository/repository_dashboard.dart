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
import 'package:life_pilot/utils/supabase.dart';
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
      return query.selectLocal(
        rows.where((row) {
          final owner = normalizeStringValue(row[Fields.account]);
          return owner.isEmpty || owner == normalizeStringValue(localOwner);
        }),
      );
    }

    final result = await supabase
        .from(TableNames.calendarEvents)
        .select(
          'id,name,start_date,start_time,end_date,end_time,country,city,location,'
          'type,is_free,description,master_url,sub_events,is_completed,account',
        )
        .eq('is_completed', false)
        .lt('start_date', query.rangeEnd.toUtc().toIso8601String())
        .or(
          'end_date.gte.${query.today.toUtc().toIso8601String()},'
          'and(end_date.is.null,start_date.gte.${query.today.toUtc().toIso8601String()})',
        );

    // Calendar SELECT policies expose only the owner and accepted shares.
    return query.decodeRows([
      for (final row in result)
        {
          ...row,
          'is_shared':
              normalizeStringValue(row[Fields.account]) !=
              normalizeStringValue(account),
        },
    ]);
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
        .select(DashboardSetting.persistedColumns)
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

  Future<({List<DashboardCity> events, List<DashboardCity> places})>
  loadRecommendationCityCounts() async {
    await _requireNetworkForLocalCloudContent();
    final result = await supabase.rpc('get_home_recommendation_city_counts');
    if (result is! Map) {
      throw const FormatException('Invalid recommendation city counts');
    }
    List<DashboardCity> decode(Object? value) => (value as List? ?? const [])
        .map((row) => DashboardCity.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    return (events: decode(result['events']), places: decode(result['places']));
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
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final result = await supabase.rpc(
      'get_my_dashboard_ledger_summary',
      params: {
        'p_kind': 'accounting',
        'p_account_id': accountId,
        'p_day_start': start.toUtc().toIso8601String(),
        'p_day_end': end.toUtc().toIso8601String(),
      },
    );
    return _decodeAccountingSummary(result);
  }

  AccountingDashboardSummary _decodeAccountingSummary(Object? result) {
    if (result == null) return const AccountingDashboardSummary.empty();
    final row = Map<String, dynamic>.from(result as Map);
    final records = (row['records'] as List? ?? const [])
        .map(
          (item) => IncomeExpenseItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    return AccountingDashboardSummary(
      records: records,
      total: parseNumValue(row['total']),
      todayTotal: parseNumValue(row['today_total']),
      currency: parseStringValue(row['currency'], fallback: 'TWD'),
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
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final result = await supabase.rpc(
      'get_my_dashboard_ledger_summary',
      params: {
        'p_kind': 'points',
        'p_account_id': accountId,
        'p_day_start': start.toUtc().toIso8601String(),
        'p_day_end': end.toUtc().toIso8601String(),
      },
    );
    return _decodePointSummary(result);
  }

  PointDashboardSummary _decodePointSummary(Object? result) {
    if (result == null) return const PointDashboardSummary.empty();
    final row = Map<String, dynamic>.from(result as Map);
    final records = (row['records'] as List? ?? const [])
        .map(
          (item) => PointRecordItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    return PointDashboardSummary(
      records: records,
      total: parseIntValue(row['total']),
      todayTotal: parseIntValue(row['today_total']),
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
