import 'package:flutter/material.dart';
import 'package:life_pilot/pages/home/model/accounting/income_expense_item.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_setting.dart';
import 'package:life_pilot/pages/home/model/event/calendar_event.dart';
import 'package:life_pilot/pages/home/model/event/recommended_event.dart';
import 'package:life_pilot/pages/home/model/place/recommended_place.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final rangeEnd = today.add(const Duration(days: 3));

    if (await _storesLocally) {
      final rows = await LocalDataStore.instance.list(
        owner: _localOwner!,
        resource: TableNames.calendarEvents,
      );
      final filtered =
          rows
              .where((row) {
                if (row['is_completed'] == true) return false;
                final start = DateTime.tryParse(
                  row['start_date']?.toString() ?? '',
                )?.toLocal();
                if (start == null) return false;
                final end = DateTime.tryParse(
                  row['end_date']?.toString() ?? '',
                )?.toLocal();
                final effectiveEnd = end ?? start;
                return !effectiveEnd.isBefore(today) &&
                    start.isBefore(rangeEnd);
              })
              .map(CalendarEvent.fromJson)
              .toList()
            ..sort(_compareCalendarEvents);
      return filtered;
    }

    final result = await supabase
        .from(TableNames.calendarEvents)
        .select(
          'id,name,start_date,start_time,end_date,end_time,country,city,location,'
          'type,is_free,description,master_url,sub_events,is_completed',
        )
        .eq(Fields.account, account)
        .eq('is_completed', false)
        .lt('start_date', rangeEnd.toUtc().toIso8601String())
        .or(
          'end_date.gte.${today.toUtc().toIso8601String()},'
          'and(end_date.is.null,start_date.gte.${today.toUtc().toIso8601String()})',
        );

    return (result as List).map((e) => CalendarEvent.fromJson(e)).toList()
      ..sort(_compareCalendarEvents);
  }

  static int _compareCalendarEvents(CalendarEvent left, CalendarEvent right) {
    var comparison = (left.startDate ?? DateTime(9999)).compareTo(
      right.startDate ?? DateTime(9999),
    );
    if (comparison != 0) return comparison;
    comparison = _timeMinutes(
      left.startTime,
    ).compareTo(_timeMinutes(right.startTime));
    if (comparison != 0) return comparison;
    comparison = (left.city ?? '').compareTo(right.city ?? '');
    if (comparison != 0) return comparison;
    comparison = (left.location ?? '').compareTo(right.location ?? '');
    return comparison != 0 ? comparison : left.name.compareTo(right.name);
  }

  static int _timeMinutes(TimeOfDay? time) =>
      time == null ? 24 * 60 : time.hour * 60 + time.minute;

  Future<List<CalendarEvent>> getSpecificEvent(
    String eventId,
    String account,
  ) async {
    if (await _storesLocally) {
      final rows = await LocalDataStore.instance.list(
        owner: _localOwner ?? account.toLowerCase(),
        resource: TableNames.calendarEvents,
      );
      final filtered =
          rows.where((row) => row[Fields.id]?.toString() == eventId).toList()
            ..sort((a, b) {
              final dateComparison = (a['start_date']?.toString() ?? '')
                  .compareTo(b['start_date']?.toString() ?? '');
              if (dateComparison != 0) return dateComparison;
              return (a['start_time']?.toString() ?? '').compareTo(
                b['start_time']?.toString() ?? '',
              );
            });
      return filtered.map(CalendarEvent.fromJson).toList();
    }

    final result = await supabase
        .from(TableNames.calendarEvents)
        .select()
        .eq(Fields.account, account)
        .eq(Fields.id, eventId)
        .order('start_date', ascending: true)
        .order('start_time', ascending: true);

    return (result as List).map((e) => CalendarEvent.fromJson(e)).toList();
  }

  Future<void> completeEvent({
    required String id,
    required String account,
  }) async {
    if (await _storesLocally) {
      final rows = await LocalDataStore.instance.list(
        owner: account,
        resource: TableNames.calendarEvents,
      );
      final matches = rows.where((row) => row[Fields.id]?.toString() == id);
      if (matches.isEmpty) return;
      final updated = Map<String, Object?>.from(matches.first)
        ..['is_completed'] = true;
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
      final rows = await LocalDataStore.instance.list(
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
    final accountingAccounts = await LocalDataStore.instance.list(
      owner: account,
      resource: TableNames.accountingAccount,
    );
    final pointAccounts = await LocalDataStore.instance.list(
      owner: account,
      resource: TableNames.pointRecordAccount,
    );
    Map<String, dynamic>? firstValid(List<Map<String, dynamic>> rows) {
      for (final row in rows) {
        if (row[Fields.isValid] == true) return row;
      }
      return null;
    }

    final accounting = firstValid(accountingAccounts);
    final points = firstValid(pointAccounts);
    final setting = DashboardSetting(
      recommendEventCity: '台北',
      recommendPlaceCity: '台北',
      language: 'zh',
      accountingAccountId: accounting?[Fields.id]?.toString(),
      accountingAccountName: accounting?[Fields.account]?.toString(),
      pointAccountId: points?[Fields.id]?.toString(),
      pointAccountName: points?[Fields.account]?.toString(),
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

    return (result as List).map((e) => RecommendedEvent.fromJson(e)).toList()
      ..sort(_compareRecommendedEvents);
  }

  static int _compareRecommendedEvents(
    RecommendedEvent left,
    RecommendedEvent right,
  ) {
    var comparison = (left.startDate ?? DateTime(9999)).compareTo(
      right.startDate ?? DateTime(9999),
    );
    if (comparison != 0) return comparison;
    comparison = _timeMinutes(
      left.startTime,
    ).compareTo(_timeMinutes(right.startTime));
    if (comparison != 0) return comparison;
    comparison = (left.city ?? '').compareTo(right.city ?? '');
    if (comparison != 0) return comparison;
    comparison = (left.location ?? '').compareTo(right.location ?? '');
    return comparison != 0 ? comparison : left.name.compareTo(right.name);
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

    return (result as List).map((e) => RecommendedPlace.fromJson(e)).toList();
  }

  Future<AccountingDashboardSummary> loadAccountingSummary({
    required String accountId,
  }) async {
    if (accountId.isEmpty) return const AccountingDashboardSummary.empty();
    if (await _storesLocally) {
      final accounts = await LocalDataStore.instance.list(
        owner: _localOwner!,
        resource: TableNames.accountingAccount,
      );
      final account = accounts
          .where(
            (row) =>
                row[Fields.id]?.toString() == accountId &&
                row[Fields.isValid] == true,
          )
          .firstOrNull;
      if (account == null) return const AccountingDashboardSummary.empty();
      final currency = account['main_currency']?.toString() ?? 'TWD';
      final rows = await _todayLocalDetails(
        resource: TableNames.accountingDetail,
        accountId: accountId,
        currency: currency,
      );
      return AccountingDashboardSummary(
        records: rows.take(5).map(IncomeExpenseItem.fromJson).toList(),
        total: (account['balance'] as num?) ?? 0,
        todayTotal: rows.fold<num>(
          0,
          (sum, row) => sum + ((row['value'] as num?) ?? 0),
        ),
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
      total: (accountResult['balance'] as num?) ?? 0,
      todayTotal: rows.fold<num>(
        0,
        (sum, row) => sum + ((row['value'] as num?) ?? 0),
      ),
      currency: currency ?? 'TWD',
    );
  }

  Future<PointDashboardSummary> loadPointSummary({
    required String accountId,
  }) async {
    if (accountId.isEmpty) return const PointDashboardSummary.empty();
    if (await _storesLocally) {
      final accounts = await LocalDataStore.instance.list(
        owner: _localOwner!,
        resource: TableNames.pointRecordAccount,
      );
      final account = accounts
          .where(
            (row) =>
                row[Fields.id]?.toString() == accountId &&
                row[Fields.isValid] == true,
          )
          .firstOrNull;
      if (account == null) return const PointDashboardSummary.empty();
      final rows = await _todayLocalDetails(
        resource: TableNames.pointRecordDetail,
        accountId: accountId,
      );
      return PointDashboardSummary(
        records: rows.take(5).map(PointRecordItem.fromJson).toList(),
        total: (account['points'] as num?)?.toInt() ?? 0,
        todayTotal: rows.fold<int>(
          0,
          (sum, row) => sum + ((row['value'] as num?)?.toInt() ?? 0),
        ),
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
      total: (accountResult['points'] ?? 0).toInt(),
      todayTotal: rows.fold<int>(
        0,
        (sum, row) => sum + ((row['value'] ?? 0) as num).toInt(),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _todayLocalDetails({
    required String resource,
    required String accountId,
    String? currency,
  }) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    final rows = await LocalDataStore.instance.list(
      owner: _localOwner!,
      resource: resource,
    );
    final result =
        rows.where((row) {
          if (row['account_id']?.toString() != accountId) return false;
          if (currency != null && row['currency']?.toString() != currency) {
            return false;
          }
          final date = DateTime.tryParse(
            row['date']?.toString() ?? '',
          )?.toLocal();
          return date != null && !date.isBefore(start) && date.isBefore(end);
        }).toList()..sort(
          (a, b) => (b['date']?.toString() ?? '').compareTo(
            a['date']?.toString() ?? '',
          ),
        );
    return result;
  }
}
