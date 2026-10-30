import 'dart:async';
import 'package:life_pilot/utils/paged_row_reader.dart';

import 'package:flutter/material.dart';
import 'package:life_pilot/event/event_save_exception.dart';
import 'package:life_pilot/event/event_delete_exception.dart';
import 'package:life_pilot/event/model_event_item.dart';
import 'package:life_pilot/event/model_event_load_policy.dart';
import 'package:life_pilot/event/model_local_event_query.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/date_time.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:life_pilot/utils/event_city_normalizer.dart';
import 'package:life_pilot/utils/extension.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/text_normalization.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/repository_cloud_gateway.dart';
import 'package:life_pilot/utils/repository_event_cloud_operations.dart';

class ServiceEvent {
  ServiceEvent({RepositoryEventCloudOperations? cloudOperations})
    : _cloudOperations = cloudOperations ?? RepositoryEventCloudOperations();

  final RepositoryEventCloudOperations _cloudOperations;

  // Controllers already know the active storage mode. Do not open the native
  // local database just to decide whether a cloud query should use it.
  Future<bool> _usesLocalStorage(
    String tableName,
    String? owner,
    DataStorageLocation? storageLocation,
  ) async {
    if ((tableName != TableNames.calendarEvents &&
            tableName != TableNames.memoryTrace) ||
        owner == null ||
        owner.isEmpty) {
      return false;
    }
    return (storageLocation ??
            await LocalDataStore.instance.preferredLocation(owner)) ==
        DataStorageLocation.local;
  }

  // The fallback preview only needs the card header. Do not download photos
  // and sub-events twice; the normal day query supplies the complete record.
  static const _fallbackPreviewColumns =
      'id,name,start_date,end_date,start_time,end_time,country,city,location,account';

  static DateTime? _lastCleanupRequestDate;
  static Future<void>? _cleanupRequest;

  bool get _isCurrentUserAdmin =>
      supabase.auth.currentUser?.appMetadata['role'] == AuthConstants.adminRole;

  Future<List<String>> getCompletedCalendarEventIds({
    required String account,
  }) async {
    final normalizedAccount = normalizeText(account);
    if (normalizedAccount.isEmpty) return const [];

    final response = await supabase
        .from(TableNames.calendarEvents)
        .select(Fields.id)
        .eq('is_completed', true);

    return (response as List)
        .map(
          (row) => parseOptionalStringValue(
            (row as Map<String, dynamic>)[Fields.id],
          ),
        )
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
  }

  Future<MapCoordinateBackfillResult> backfillMapCoordinates({
    required String tableName,
    int offset = 0,
  }) async {
    final response = await _cloudOperations.backfillCoordinates(
      tableName: tableName,
      offset: offset,
      backend: () => apiSupabase.post('/external/map-geocode/backfill', {
        'table_name': tableName,
        'limit': 25,
        'offset': offset,
      }),
    );
    return MapCoordinateBackfillResult.fromJson(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<EventItem> ensureMapCoordinates({
    required String tableName,
    required EventItem event,
  }) async {
    if (event.mapLat != null && event.mapLng != null) {
      return event;
    }
    if (event.city.trim().isEmpty && event.location.trim().isEmpty) {
      return event;
    }

    final response = await _cloudOperations.mapCoordinates(
      tableName: tableName,
      eventId: event.id,
      backend: () => apiSupabase.post('/external/map-geocode', {
        'table_name': tableName,
        'event_id': event.id,
      }),
    );
    if (response is Map<String, dynamic>) {
      event.mapLat = tryParseDoubleValue(response['lat']);
      event.mapLng = tryParseDoubleValue(response['lng']);
    }
    return event;
  }

  Future<void> _cleanupRecommendedEventsOncePerDay(DateTime today) async {
    if (_lastCleanupRequestDate == today) return;
    final activeRequest = _cleanupRequest;
    if (activeRequest != null) return activeRequest;

    final request = () async {
      try {
        await RepositoryCloudGateway().rpcOrBackend(
          'life_pilot_run_daily_cleanup',
          backend: () =>
              apiSupabase.post('event/cleanup_recommended_events', const {}),
        );
        _lastCleanupRequestDate = today;
      } catch (error, stackTrace) {
        logger.e(
          'Daily recommended event cleanup failed',
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        _cleanupRequest = null;
      }
    }();
    _cleanupRequest = request;
    return request;
  }

  // 📌 取得推薦事件
  Future<List<EventItem>?> getEvents({
    required String tableName,
    DateTime? dateS,
    DateTime? dateE,
    String? id,
    String? inputUser,
    DataStorageLocation? storageLocation,
    int? limit,
    int offset = 0,
    void Function(List<EventItem> events)? onPartialEvents,
    bool Function()? shouldContinue,
  }) async {
    if (shouldContinue?.call() == false) return [];
    final loadPolicy = ModelEventLoadPolicy.forTable(tableName);
    final today = DateTimeFormatter.dateOnly(DateTime.now());
    if (tableName == TableNames.recommendEvents) {
      unawaited(_cleanupRecommendedEventsOncePerDay(today));
    }
    final inputDateS =
        (dateS ??
                (tableName == TableNames.memoryTrace
                    ? DateTime(
                        today.year,
                        today.month,
                        today.day,
                      ).subtract(const Duration(days: 29))
                    : today))
            .formatDateString();
    final inputDateE =
        (dateE ?? DateTime(today.year + 2, today.month, today.day))
            .formatDateString();

    final useLocal = await _usesLocalStorage(
      tableName,
      inputUser,
      storageLocation,
    );
    if (shouldContinue?.call() == false) return [];
    if (useLocal) {
      final localRows = await LocalDataStore.instance
          .readOnlyRows(owner: inputUser!, resource: tableName)
          .timeout(const Duration(seconds: 15));
      if (shouldContinue?.call() == false) return [];
      final selected = ModelLocalEventQuery.iterate(
        localRows,
        start:
            dateS ??
            (tableName == TableNames.memoryTrace
                ? today.subtract(const Duration(days: 29))
                : today),
        end: dateE ?? DateTime(today.year + 2, today.month, today.day),
        id: id,
        offset: offset,
        limit: limit,
        shouldContinue: shouldContinue,
      );
      if (onPartialEvents == null) {
        final events = selected.toList();
        if (shouldContinue?.call() == false) return [];
        return events;
      }
      final events = <EventItem>[];
      for (final event in selected) {
        if (shouldContinue?.call() == false) return [];
        events.add(event);
        if (events.length == loadPolicy.previewBatchSize) {
          onPartialEvents(List<EventItem>.unmodifiable(events));
          // Let the first cards render before decoding the remaining history.
          await Future<void>.delayed(Duration.zero);
        } else if (events.length % 100 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }
      if (shouldContinue?.call() == false) return [];
      return events;
    }

    try {
      final payload = <String, dynamic>{
        'table_name': tableName,
        'inputid': id,
        'inputdates': inputDateS,
        'inputdatee': inputDateE,
        if (tableName != TableNames.recommendEvents &&
            tableName != TableNames.recommendPlaces)
          'inputuser': inputUser,
      };
      if (limit != null) {
        payload['inputlimit'] = limit;
        payload['inputoffset'] = offset;
      }
      Future<List<dynamic>> fetchRows(int pageOffset, int pageLimit) async {
        final response = await supabase.rpc(
          'get_filtered_$tableName',
          params: {
            'payload': {
              ...payload,
              'inputlimit': pageLimit,
              'inputoffset': pageOffset,
            },
          },
        );
        return response as List<dynamic>;
      }

      final decoded = <EventItem>[];
      void publishRows(List<dynamic> rows) {
        for (final row in rows.skip(decoded.length)) {
          decoded.add(_decodeEventRow(row as Map<String, dynamic>));
        }
        onPartialEvents?.call(List<EventItem>.unmodifiable(decoded));
      }

      final response = limit == null
          ? await supabase.rpc(
              'get_filtered_$tableName',
              params: {'payload': payload},
            )
          : await readPagedRows(
              fetch: fetchRows,
              offset: offset,
              limit: limit,
              initialBatchSize:
                  tableName == TableNames.memoryTrace &&
                      onPartialEvents != null &&
                      offset == 0
                  ? loadPolicy.previewBatchSize
                  : null,
              onProgress: onPartialEvents == null ? null : publishRows,
              shouldContinue: shouldContinue,
            );
      if (shouldContinue?.call() == false) return [];

      final events = onPartialEvents != null && limit != null
          ? decoded
          : (response as List)
                .map((row) => _decodeEventRow(row as Map<String, dynamic>))
                .toList();

      return events;
    } catch (ex, st) {
      logger.e(ex, stackTrace: st);
      rethrow;
    }
  }

  EventItem _decodeEventRow(Map<String, dynamic> row) {
    final event = EventItem.fromJson(json: row);
    event.startDate = event.startDate?.toLocal();
    event.endDate = event.endDate?.toLocal();
    return event;
  }

  Future<bool> hasEventsBefore({
    required String tableName,
    required DateTime before,
    String? inputUser,
    DataStorageLocation? storageLocation,
    bool Function()? shouldContinue,
  }) async {
    if (shouldContinue?.call() == false) return false;
    final local = await _usesLocalStorage(
      tableName,
      inputUser,
      storageLocation,
    );
    if (shouldContinue?.call() == false) return false;
    if (local) {
      final rows = await LocalDataStore.instance.readOnlyRows(
        owner: inputUser!,
        resource: tableName,
      );
      if (shouldContinue?.call() == false) return false;
      return ModelLocalEventQuery.hasRowsBefore(rows, before);
    }
    var query = supabase
        .from(tableName)
        .select(Fields.id)
        .lt(EventFields.startDate, before.formatDateString());
    if (inputUser != null && inputUser.isNotEmpty) {
      query = query.eq(Fields.account, inputUser);
    }
    final rows = await query.limit(1);
    if (shouldContinue?.call() == false) return false;
    return rows.isNotEmpty;
  }

  Future<DateTime?> latestEventDateBefore({
    required String tableName,
    required DateTime before,
    String? inputUser,
    DataStorageLocation? storageLocation,
    void Function(EventItem event)? onLatestEvent,
    bool Function()? shouldContinue,
  }) async {
    if (shouldContinue?.call() == false) return null;
    final local = await _usesLocalStorage(
      tableName,
      inputUser,
      storageLocation,
    );
    if (shouldContinue?.call() == false) return null;
    if (local) {
      final rows = await LocalDataStore.instance.readOnlyRows(
        owner: inputUser!,
        resource: tableName,
      );
      if (shouldContinue?.call() == false) return null;
      final latest = ModelLocalEventQuery.latestRowBefore(rows, before);
      if (latest == null) return null;
      onLatestEvent?.call(_decodeEventRow(latest));
      return tryParseDateTimeValue(latest[EventFields.startDate]);
    }
    var query = supabase
        .from(tableName)
        .select(
          onLatestEvent == null
              ? EventFields.startDate
              : _fallbackPreviewColumns,
        )
        .lt(EventFields.startDate, before.formatDateString());
    if (inputUser != null && inputUser.isNotEmpty) {
      query = query.eq(Fields.account, inputUser);
    }
    final rows = await query
        .order(EventFields.startDate, ascending: false)
        .limit(1);
    if (shouldContinue?.call() == false) return null;
    if (rows.isEmpty) return null;
    onLatestEvent?.call(_decodeEventRow(rows.first));
    return tryParseDateTimeValue(
      parseStringValue(rows.first[EventFields.startDate]),
      toLocal: true,
    );
  }

  // 💾 儲存（新增或更新）事件 + 排程通知
  Future<void> saveEvent({
    required String currentAccount,
    required EventItem event,
    required bool isNew,
    required String tableName,
    String? originalAccount,
    bool? originalIsApproved,
  }) async {
    try {
      _validateEvent(event: event);
      if (tableName == TableNames.recommendEvents) {
        event.city = EventCityNormalizer.normalize(event.city);
        for (final subEvent in event.subEvents) {
          subEvent.city = EventCityNormalizer.normalize(subEvent.city);
        }
      }
      if ((isNew || event.reminderOptions.isEmpty) &&
          tableName == TableNames.calendarEvents) {
        event.reminderOptions = [
          CalendarReminderOption.oneHour, // 事件開始前1小時
          CalendarReminderOption.sameDay8am,
          CalendarReminderOption.dayBefore8am, // 前一天早上8點
        ];
      }

      if (event.repeatOptions.key.isEmpty) {
        event.repeatOptions = CalendarRepeatRule.once;
      }

      event.endDate = _normalizeEndDate(event.startDate, event.endDate);
      event.endTime = _normalizeEndTime(
        event.startTime,
        event.endTime,
        event.startDate,
        event.endDate,
      );

      for (final subEvent in event.subEvents) {
        subEvent.endDate = _normalizeEndDate(
          subEvent.startDate,
          subEvent.endDate,
        );
        subEvent.endTime = _normalizeEndTime(
          subEvent.startTime,
          subEvent.endTime,
          subEvent.startDate,
          subEvent.endDate,
        );
      }

      final isRecommendedContent =
          tableName == TableNames.recommendEvents ||
          tableName == TableNames.recommendPlaces;
      if (isNew || !isRecommendedContent) {
        event.account = currentAccount;
        event.isApproved = false;
      } else if (_isCurrentUserAdmin) {
        // 管理者編輯或審核內容時保留投稿者，不接管作者身分。
        event.account = originalAccount?.trim().isNotEmpty == true
            ? originalAccount
            : event.account ?? currentAccount;
        event.isApproved = originalIsApproved ?? event.isApproved;
      } else {
        // 作者修改已公開內容後必須重新審核，修改期間不再公開。
        event.account = currentAccount;
        event.isApproved = false;
      }
      final isPersonalLocalResource =
          tableName == TableNames.calendarEvents ||
          tableName == TableNames.memoryTrace;
      final storageLocation = isPersonalLocalResource
          ? await LocalDataStore.instance.preferredLocation(currentAccount)
          : DataStorageLocation.cloud;
      final alreadyStoredLocally =
          isPersonalLocalResource &&
          await LocalDataStore.instance.contains(
            owner: currentAccount,
            resource: tableName,
            id: event.id,
          );
      if (storageLocation == DataStorageLocation.local ||
          alreadyStoredLocally) {
        await LocalDataStore.instance.put(
          owner: currentAccount,
          resource: tableName,
          id: event.id,
          data: event.toJson(),
          syncState: isNew && !alreadyStoredLocally
              ? LocalSyncState.localOnly
              : LocalSyncState.modifiedLocally,
        );
        return;
      }
      //final Map<String, dynamic> data = event.toJson();
      if (isNew) {
        await supabase.from(tableName).insert([event.toJson()]);
      } else {
        final data = event.toJson();
        var query = supabase
            .from(tableName)
            .update(data)
            .eq(Fields.id, data[Fields.id]);

        // 非系統管理員只能更新自己的事件
        if (!_isCurrentUserAdmin && data[Fields.account] != null) {
          query = query.eq(Fields.account, data[Fields.account]);
        }

        await query;
      }
    } on PostgrestException catch (ex, stacktrace) {
      logger.e("saveEvent error", error: ex, stackTrace: stacktrace);
      if (ex.code == '23505') {
        throw const EventSaveException(EventSaveError.duplicate);
      }
      if (ex.code == '42501') {
        throw const EventSaveException(EventSaveError.permissionDenied);
      }
      rethrow;
    } catch (ex, stacktrace) {
      logger.e("saveEvent error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  // ❌ 刪除推薦事件
  Future<void> deleteEvent({
    required String currentAccount,
    required EventItem event,
    required String tableName,
  }) async {
    try {
      final data = event.toJson();
      final isPersonalLocalResource =
          tableName == TableNames.calendarEvents ||
          tableName == TableNames.memoryTrace;
      final storageLocation = isPersonalLocalResource
          ? await LocalDataStore.instance.preferredLocation(currentAccount)
          : DataStorageLocation.cloud;
      final existsLocally =
          isPersonalLocalResource &&
          await LocalDataStore.instance.contains(
            owner: currentAccount,
            resource: tableName,
            id: event.id,
          );
      if (storageLocation == DataStorageLocation.local) {
        if (!existsLocally) {
          throw StateError('Local event not found.');
        }
        await LocalDataStore.instance.delete(
          owner: currentAccount,
          resource: tableName,
          id: event.id,
        );
        return;
      }
      final isRecommendedContent =
          tableName == TableNames.recommendEvents ||
          tableName == TableNames.recommendPlaces;
      if (isRecommendedContent && !_isCurrentUserAdmin) {
        try {
          final reviewState = await supabase
              .from(tableName)
              .select('is_approved,was_approved')
              .eq(Fields.id, event.id)
              .eq(Fields.account, currentAccount)
              .maybeSingle();
          if (reviewState?[EventFields.isApproved] == true) {
            throw const EventDeleteException(EventDeleteError.published);
          }
          if (reviewState?['was_approved'] == true) {
            throw const EventDeleteException(
              EventDeleteError.previouslyPublished,
            );
          }
        } on PostgrestException catch (error) {
          // Before the review-history migration is installed, the currently
          // published flag still prevents accidental deletion.
          if (event.isApproved) {
            throw const EventDeleteException(EventDeleteError.published);
          }
          if (error.code != '42703' && error.code != 'PGRST204') rethrow;
        }
      }
      if (tableName == TableNames.recommendEvents) {
        await supabase.from(TableNames.recommendEventsDeleted).insert([data]);
      }

      var query = supabase
          .from(tableName)
          .delete()
          .eq(Fields.id, data[Fields.id]);

      // 非系統管理員只能刪自己的事件
      if (!_isCurrentUserAdmin) {
        query = query.eq(Fields.account, currentAccount);
      }

      final result = await query.select();

      if (result.isEmpty) {
        throw Exception("event not found");
      }
    } catch (ex, stacktrace) {
      logger.e("deleteEvent error", error: ex, stackTrace: stacktrace);
      rethrow;
    }
  }

  // ✅ 核准事件 (由管理者)
  Future<void> approvalEvent({
    required String eventId,
    required String tableName,
  }) async {
    await supabase
        .from(tableName)
        .update({EventFields.isApproved: true})
        .eq(Fields.id, eventId);
  }

  Future<void> updateLikeEvent({
    required EventItem event,
    required String account,
    String? tableName,
  }) async {
    if (tableName == TableNames.recommendEvents ||
        tableName == TableNames.recommendPlaces) {
      await supabase.rpc(
        'set_recommended_content_preference',
        params: {
          'p_table_name': tableName,
          'p_content_id': event.id,
          'p_is_like': event.isLike == true,
          'p_is_dislike': event.isDislike == true,
        },
      );
      return;
    }
    final Map<String, dynamic> data = {
      "id": event.id,
      "is_like": event.isLike,
      "is_dislike": event.isDislike,
      "account": account,
    };
    try {
      await supabase.from(TableNames.recommendEventsFavor).insert([data]);
    } on PostgrestException catch (ex) {
      if (ex.code != '23505') rethrow;
      final rows = await supabase
          .from(TableNames.recommendEventsFavor)
          .update(data)
          .eq(Fields.id, event.id)
          .eq('account', account)
          .select('id');
      if (rows.isEmpty) throw StateError('Preference was not saved');
    }
  }

  // --- 私有方法 ---
  void _validateEvent({required EventItem event}) {
    if (event.name.isEmpty) {
      throw const EventSaveException(EventSaveError.missingName);
    }
  }

  DateTime? _normalizeEndDate(DateTime? start, DateTime? end) {
    if (end != null && !end.isAfter(start!)) return null;
    return end;
  }

  TimeOfDay? _normalizeEndTime(
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if ((endDate == null || endDate == startDate) &&
        endTime != null &&
        !endTime.isAfter(startTime!)) {
      return null;
    }
    return endTime;
  }
}

class MapCoordinateBackfillResult {
  final int saved;
  final int remaining;
  final int nextOffset;
  final double coveragePercent;

  const MapCoordinateBackfillResult({
    required this.saved,
    required this.remaining,
    required this.nextOffset,
    required this.coveragePercent,
  });

  factory MapCoordinateBackfillResult.fromJson(Map<String, dynamic> json) {
    return MapCoordinateBackfillResult(
      saved: parseIntValue(json['saved']),
      remaining: parseIntValue(json['remaining']),
      nextOffset: parseIntValue(json['next_offset']),
      coveragePercent: parseDoubleValue(json['coverage_percent']),
    );
  }
}
