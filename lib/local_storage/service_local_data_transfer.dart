import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';

class LocalDataTransferResult {
  const LocalDataTransferResult({
    required this.moved,
    required this.failed,
    this.failureReason,
  });
  final int moved;
  final int failed;
  final String? failureReason;
  bool get succeeded => failed == 0;
}

class ServiceLocalDataTransfer {
  static const _resources = [
    TableNames.calendarEvents,
    TableNames.memoryTrace,
    TableNames.accountingAccount,
    TableNames.accountingDetail,
    TableNames.pointRecordAccount,
    TableNames.pointRecordDetail,
    'game_grammar',
    'game_sentence',
    'game_translation',
    TableNames.gameSocialScenarios,
    TableNames.gameGrammarUser,
    TableNames.gameSentenceUser,
    TableNames.gameSpeakingUser,
    TableNames.gameSocialUser,
    TableNames.gameTranslationUser,
    TableNames.gameWordSearchUser,
    TableNames.gameUser,
  ];

  Future<LocalDataTransferResult> moveCloudToLocal(String account) async {
    final staged = <Map<String, Object?>>[];
    var dashboardSettingSaved = false;
    try {
      final dashboardSetting = await supabase
          .from(TableNames.dashboardSetting)
          .select()
          .eq(Fields.account, account)
          .maybeSingle();
      final exported =
          await supabase.rpc('export_my_cloud_data_for_local') as List<dynamic>;
      for (final rawItem in exported) {
        final exportItem = Map<String, dynamic>.from(rawItem as Map);
        final resource = exportItem['table_name']?.toString() ?? '';
        if (!_resources.contains(resource)) {
          return LocalDataTransferResult(
            moved: 0,
            failed: 1,
            failureReason: 'unsupported_local_resource:$resource',
          );
        }
        final rawRow = exportItem['record'];
        final row = Map<String, Object?>.from(rawRow as Map);
        final id = row[Fields.id]?.toString();
        if (id == null || id.isEmpty) {
          return const LocalDataTransferResult(moved: 0, failed: 1);
        }
        if (await LocalDataStore.instance.contains(
          owner: account,
          resource: resource,
          id: id,
        )) {
          for (final item in staged) {
            await LocalDataStore.instance.delete(
              owner: account,
              resource: item['table_name']!.toString(),
              id: item['id']!.toString(),
            );
          }
          return LocalDataTransferResult(
            moved: 0,
            failed: 1,
            failureReason: 'local_record_conflict:$resource:$id',
          );
        }
        await LocalDataStore.instance.put(
          owner: account,
          resource: resource,
          id: id,
          data: row,
          syncState: LocalSyncState.movedFromCloud,
          originalCloudId: id,
        );
        staged.add({'table_name': resource, 'id': id});
      }
      if (dashboardSetting != null) {
        await LocalDataStore.instance.put(
          owner: account,
          resource: TableNames.dashboardSetting,
          id: account.toLowerCase(),
          data: Map<String, Object?>.from(dashboardSetting),
          syncState: LocalSyncState.movedFromCloud,
        );
        dashboardSettingSaved = true;
      }
      if (staged.isNotEmpty) {
        final deleted = await supabase.rpc(
          'delete_cloud_records_after_local_copy',
          params: {'p_records': staged},
        );
        if ((int.tryParse(deleted.toString()) ?? -1) != staged.length) {
          throw StateError('cloud_delete_incomplete');
        }
      }
      return LocalDataTransferResult(moved: staged.length, failed: 0);
    } catch (error) {
      for (final item in staged) {
        await LocalDataStore.instance.delete(
          owner: account,
          resource: item['table_name']!.toString(),
          id: item['id']!.toString(),
        );
      }
      if (dashboardSettingSaved) {
        await LocalDataStore.instance.delete(
          owner: account,
          resource: TableNames.dashboardSetting,
          id: account.toLowerCase(),
        );
      }
      return LocalDataTransferResult(
        moved: 0,
        failed: staged.isEmpty ? 1 : staged.length,
        failureReason: error.toString(),
      );
    }
  }

  Future<LocalDataTransferResult> uploadLocalToCloud(
    String account,
  ) async {
    final payload = <Map<String, Object?>>[];
    for (final resource in _resources) {
      final rows = await LocalDataStore.instance.list(
        owner: account,
        resource: resource,
      );
      for (final row in rows) {
        final normalizedRow = _normalizeForCloud(resource, row);
        final id = normalizedRow[Fields.id]?.toString();
        if (id == null || id.isEmpty) {
          return const LocalDataTransferResult(
            moved: 0,
            failed: 1,
            failureReason: 'invalid_local_record',
          );
        }
        payload.add({'table_name': resource, 'record': normalizedRow});
      }
    }
    if (payload.isEmpty) {
      await LocalDataStore.instance.deleteAllRecords(owner: account);
      return const LocalDataTransferResult(moved: 0, failed: 0);
    }
    try {
      final restored = await supabase.rpc(
        'restore_local_personal_records_admin',
        params: {'p_records': payload},
      );
      final restoredCount = int.tryParse(restored.toString()) ?? 0;
      if (restoredCount != payload.length) {
        return const LocalDataTransferResult(
          moved: 0,
          failed: 1,
          failureReason: 'local_upload_incomplete',
        );
      }
      await LocalDataStore.instance.deleteAllRecords(owner: account);
      return LocalDataTransferResult(moved: payload.length, failed: 0);
    } catch (error) {
      return LocalDataTransferResult(
        moved: 0,
        failed: payload.length,
        failureReason: error.toString(),
      );
    }
  }

  Map<String, dynamic> _normalizeForCloud(
    String resource,
    Map<String, dynamic> row,
  ) {
    final normalized = Map<String, dynamic>.from(row);
    if (resource == TableNames.calendarEvents ||
        resource == TableNames.memoryTrace) {
      final country = normalized['country']?.toString().trim() ?? '';
      normalized['country'] = country.isEmpty ? 'TW' : country.toUpperCase();
    }
    return normalized;
  }
}
