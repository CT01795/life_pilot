import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/repository_optional_json_rpc.dart';
import 'package:life_pilot/local_storage/model_cloud_restore_receipt.dart';
import 'package:life_pilot/utils/repository_session_reads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/local_storage/repository_cloud_transfer_export.dart';

class LocalDataTransferResult {
  const LocalDataTransferResult({
    required this.moved,
    required this.failed,
    this.failureReason,
    this.omittedAnswers = 0,
  });
  final int moved;
  final int failed;
  final String? failureReason;
  final int omittedAnswers;
  bool get succeeded => failed == 0;
}

class ServiceLocalDataTransfer {
  ServiceLocalDataTransfer({
    SupabaseClient? client,
    LocalDataStore? store,
    ServiceGame? gameService,
  }) : _clientOverride = client,
       _storeOverride = store,
       _gameService = gameService ?? ServiceGame();
  final SupabaseClient? _clientOverride;
  final LocalDataStore? _storeOverride;
  final ServiceGame _gameService;
  SupabaseClient get _client => _clientOverride ?? supabase;
  LocalDataStore get _store => _storeOverride ?? LocalDataStore.instance;
  Future<Map<String, dynamic>?> cloudAnswerRetention() =>
      RepositorySessionReads(_client).read(
        'cloud-retention-preview',
        'own',
        () => RepositoryOptionalJsonRpc(
          _client,
        ).read('get_my_cloud_answer_retention', rememberMissing: false),
      );
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
    var cloudDeleteStarted = false;
    final session = _client.auth.currentSession;
    void current() {
      if (session == null ||
          session.user.email?.trim().toLowerCase() !=
              account.trim().toLowerCase() ||
          _client.auth.currentUser?.id != session.user.id ||
          _client.auth.currentSession?.accessToken != session.accessToken) {
        throw StateError('Transfer account changed');
      }
    }

    try {
      current();
      final gameList = List<Map<String, dynamic>>.from(
        await _client
            .from(TableNames.gameList)
            .select('id,game_type,game_name,level'),
      );
      current();
      await _gameService.cacheGameList(gameList);
      current();
      final dashboardSetting = await _client
          .from(TableNames.dashboardSetting)
          .select()
          .eq(Fields.account, account)
          .maybeSingle();
      current();
      await for (final exported in RepositoryCloudTransferExport(
        client: _client,
      ).pages(account)) {
        for (final rawItem in exported) {
          current();
          final exportItem = Map<String, dynamic>.from(rawItem as Map);
          final resource = parseStringValue(exportItem['table_name']);
          if (!_resources.contains(resource)) {
            throw StateError('unsupported_local_resource:$resource');
          }
          final rawRow = exportItem['record'];
          final row = Map<String, Object?>.from(rawRow as Map);
          final id = parseOptionalStringValue(row[Fields.id]);
          if (id == null || id.isEmpty) {
            throw const FormatException('Missing transfer record ID');
          }
          if (await _store.contains(
            owner: account,
            resource: resource,
            id: id,
          )) {
            throw StateError('local_record_conflict:$resource:$id');
          }
          current();
          await _store.put(
            owner: account,
            resource: resource,
            id: id,
            data: row,
            syncState: LocalSyncState.movedFromCloud,
            originalCloudId: id,
          );
          staged.add({'table_name': resource, 'id': id});
        }
      }
      current();
      if (dashboardSetting != null) {
        await _store.put(
          owner: account,
          resource: TableNames.dashboardSetting,
          id: account.toLowerCase(),
          data: Map<String, Object?>.from(dashboardSetting),
          syncState: LocalSyncState.movedFromCloud,
        );
        dashboardSettingSaved = true;
      }
      current();
      cloudDeleteStarted = true;
      final deleted = await _client
          .rpc(
            'delete_cloud_records_and_revoke_shares_after_local_copy',
            params: {'p_records': staged},
          )
          .timeout(const Duration(seconds: 30));
      if ((tryParseIntValue(deleted) ?? -1) != staged.length) {
        throw StateError('cloud_delete_incomplete');
      }
      return LocalDataTransferResult(moved: staged.length, failed: 0);
    } catch (error) {
      // A lost response is not proof of rollback. Preserve the only remaining
      // copy if the cloud transaction may already have committed.
      if (cloudDeleteStarted) {
        return LocalDataTransferResult(
          moved: 0,
          failed: staged.isEmpty ? 1 : staged.length,
          failureReason: 'cloud_delete_unconfirmed_local_copy_kept',
        );
      }
      for (final item in staged) {
        await _store.delete(
          owner: account,
          resource: parseStringValue(item['table_name']),
          id: parseStringValue(item[Fields.id]),
        );
      }
      if (dashboardSettingSaved) {
        await _store.delete(
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
    String account, {
    bool retentionAware = false,
    bool allowOmittingAnswers = false,
  }) async {
    final payload = <Map<String, Object?>>[];
    final dashboardSettings = await _store.list(
      owner: account,
      resource: TableNames.dashboardSetting,
    );
    for (final resource in _resources) {
      final rows = await _store.list(owner: account, resource: resource);
      for (final row in rows) {
        final normalizedRow = _normalizeForCloud(resource, row);
        final id = parseOptionalStringValue(normalizedRow[Fields.id]);
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
    if (payload.isEmpty && dashboardSettings.isEmpty) {
      await _store.deleteAllRecords(owner: account);
      return const LocalDataTransferResult(moved: 0, failed: 0);
    }
    try {
      final restored = await _client.rpc(
        retentionAware
            ? 'restore_local_personal_records_with_retention'
            : 'restore_local_personal_records_with_setting',
        params: {
          if (retentionAware) 'p_allow_history_omission': allowOmittingAnswers,
          'p_records': payload,
          'p_dashboard_setting': dashboardSettings.isEmpty
              ? null
              : dashboardSettings.first,
        },
      );
      final receipt = retentionAware
          ? CloudRestoreReceipt.parse(
              restored,
              expected: payload.length,
              allowOmission: allowOmittingAnswers,
            )
          : null;
      final restoredCount =
          receipt?.restored ?? tryParseIntValue(restored) ?? 0;
      if (restoredCount + (receipt?.omitted ?? 0) != payload.length) {
        return const LocalDataTransferResult(
          moved: 0,
          failed: 1,
          failureReason: 'local_upload_incomplete',
        );
      }
      await _store.deleteAllRecords(owner: account);
      return LocalDataTransferResult(
        moved: restoredCount,
        failed: 0,
        omittedAnswers: receipt?.omitted ?? 0,
      );
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
      final country = parseStringValue(normalized['country']).trim();
      normalized['country'] = country.isEmpty ? 'TW' : country.toUpperCase();
    }
    return normalized;
  }
}
