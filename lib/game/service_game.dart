import 'dart:async';
import 'dart:math';
import 'package:life_pilot/game/question_page_reader.dart';
import 'package:life_pilot/game/game_question_source_rules.dart';
import 'package:life_pilot/game/game_question_row_rules.dart';
import 'package:life_pilot/game/model_question_bank.dart';

export 'package:life_pilot/game/model_question_bank.dart';

import 'package:life_pilot/game/question_bank_availability.dart';

export 'package:life_pilot/game/question_bank_availability.dart';

import 'package:life_pilot/game/grammar/model_game_grammar.dart';
import 'package:life_pilot/game/mario_translation/model_game_mario_translation.dart';
import 'package:life_pilot/game/model_game_item.dart';
import 'package:life_pilot/game/model_game_user.dart';
import 'package:life_pilot/game/sentence/model_game_sentence.dart';
import 'package:life_pilot/game/social/model_game_social.dart';
import 'package:life_pilot/game/speaking/model_game_speaking.dart';
import 'package:life_pilot/game/translation/model_game_translation.dart';
import 'package:life_pilot/game/word_search/model_game_word_search.dart';
import 'package:life_pilot/utils/supabase.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:life_pilot/local_storage/local_data_store.dart';
import 'package:uuid/uuid.dart';

class DuplicateGameQuestionException implements Exception {
  const DuplicateGameQuestionException();
}

class DuplicateGameLevelException implements Exception {
  const DuplicateGameLevelException();
}

class GameQuestionHasAnswersException implements Exception {
  const GameQuestionHasAnswersException();
}

class ServiceGame {
  static const _grammarQuestionTable = GameQuestionSourceRules.grammarTable;
  static const _sentenceQuestionTable = GameQuestionSourceRules.sentenceTable;
  static const _translationQuestionTable =
      GameQuestionSourceRules.translationTable;
  static const localGameListCache = 'local_game_list_cache';
  final Map<String, Future<List<ModelGameUser>>> _localProgressRequests = {};

  String get _ownerEmail =>
      supabase.auth.currentUser?.email?.toLowerCase() ??
      (throw StateError('User must be signed in'));

  Future<bool> get _storesLocally async =>
      await LocalDataStore.instance.preferredLocation(_ownerEmail) ==
      DataStorageLocation.local;

  Future<List<Map<String, dynamic>>> _localQuestions(String tableName) =>
      LocalDataStore.instance.list(owner: _ownerEmail, resource: tableName);

  Future<bool> _hasLocalDuplicate({
    required String tableName,
    required String question,
    required String answer,
    required String group,
    String? excludingId,
  }) async {
    return GameQuestionRowRules.hasDuplicateQuestion(
      await _localQuestions(tableName),
      question: question,
      answer: answer,
      group: group,
      excludingId: excludingId,
    );
  }

  Future<void> _insertAnswer(
    String tableName,
    Map<String, Object?> values,
  ) async {
    if (await _storesLocally) {
      final id = const Uuid().v4();
      await LocalDataStore.instance.put(
        owner: _ownerEmail,
        resource: tableName,
        id: id,
        data: {Fields.id: id, ...values},
      );
      return;
    }
    await supabase.from(tableName).insert(values);
  }

  String get _currentUserId {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User must be signed in');
    return userId;
  }

  //------------------------- 共用 -------------------------
  Future<void> saveUserGameScore({
    required String newUserName,
    required double newScore,
    required String? newGameId,
    bool? newIsPass,
  }) async {
    if (newScore == 0 || newScore < 2) {
      //不紀錄0分
      return;
    }
    if (await _storesLocally) {
      final id = const Uuid().v4();
      await LocalDataStore.instance.put(
        owner: _ownerEmail,
        resource: TableNames.gameUser,
        id: id,
        data: {
          Fields.id: id,
          'owner_id': _currentUserId,
          'game_id': newGameId,
          'score': newScore,
          'name': newUserName,
          'is_pass': newIsPass,
          Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
        },
      );
      return;
    }
    await supabase.from(TableNames.gameUser).insert({
      'owner_id': _currentUserId,
      'game_id': newGameId,
      'score': newScore,
      'name': newUserName,
      'is_pass': newIsPass,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<ModelGameItem>> fetchGames() async {
    if (await _storesLocally) {
      final cached = await LocalDataStore.instance.list(
        owner: _ownerEmail,
        resource: localGameListCache,
      );
      if (cached.isNotEmpty) return _mapAndSortGames(cached);
    }

    final data = await supabase
        .from(TableNames.gameList)
        .select('id,game_type,game_name,level')
        .order('game_type', ascending: true)
        .order('game_name', ascending: true)
        .order('level', ascending: true);

    // 轉成 GameItem
    final rows = (data as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    // Do not block the first game screen on hundreds of IndexedDB writes.
    // The cloud response is already usable; the cache is warmed in the
    // background for the next visit.
    unawaited(cacheGameList(rows));
    return _mapAndSortGames(rows);
  }

  Future<void> cacheGameList(Iterable<Map<String, dynamic>> rows) async {
    await Future.wait(
      rows.map((row) {
        final id = parseStringValue(row[Fields.id]);
        if (id.isEmpty) return Future<void>.value();
        return LocalDataStore.instance.put(
          owner: _ownerEmail,
          resource: localGameListCache,
          id: id,
          data: Map<String, Object?>.from(row),
        );
      }),
    );
  }

  List<ModelGameItem> _mapAndSortGames(Iterable<Map<String, dynamic>> rows) {
    final games = rows.map(ModelGameItem.fromMap).toList();
    games.sort((a, b) {
      final typeOrder = a.gameType.compareTo(b.gameType);
      if (typeOrder != 0) return typeOrder;
      final nameOrder = a.gameName.compareTo(b.gameName);
      if (nameOrder != 0) return nameOrder;
      return a.level.compareTo(b.level);
    });
    return games;
  }

  // 查詢目前使用者的分數紀錄
  Future<List<ModelGameUser>> fetchUserProgress(
    String userName,
    String gameType,
    String gameName,
  ) async {
    if (await _storesLocally) {
      return _localProgress(userName, gameType, gameName);
    }
    final response = await supabase.rpc(
      'fetch_user_progress',
      params: {
        'p_name': userName,
        'p_game_type': gameType,
        'p_game_name': gameName,
      },
    );

    if (response == null || response is! List) {
      return [];
    }

    final data = response;
    return data.map((e) => ModelGameUser.fromMap(e)).toList();
  }

  /// Returns only the progress summary needed to decide which level is
  /// unlocked. The game list used to download the complete history for this
  /// single number, which became slower as answer history grew.
  Future<int> fetchHighestPassedLevel({
    required String userName,
    required String gameType,
    required String gameName,
  }) async {
    if (await _storesLocally) {
      final passedLevels = (await _localProgress(
        userName,
        gameType,
        gameName,
      )).where((row) => row.isPass ?? false).map((row) => row.level ?? 0);
      return passedLevels.fold<int>(0, max);
    }

    try {
      final result = await supabase.rpc(
        'get_user_game_highest_passed_level',
        params: {'p_game_type': gameType, 'p_game_name': gameName},
      );
      return parseIntValue(result);
    } on PostgrestException catch (error) {
      // Keep older deployments usable until the accompanying migration is
      // installed. This fallback can be removed after every environment has
      // the summary RPC.
      if (error.code != '42883' && error.code != 'PGRST202') rethrow;
      final progress = await fetchUserProgress(userName, gameType, gameName);
      return progress
          .where((row) => row.isPass ?? false)
          .map((row) => row.level ?? 0)
          .fold<int>(0, max);
    }
  }

  Future<List<ModelGameUser>> fetchUserProgressPage({
    required String userName,
    required String gameType,
    required String gameName,
    required DateTime dateFrom,
    required DateTime dateTo,
    bool includeLatestFallback = false,
  }) async {
    final upperBound = DateTime(dateTo.year, dateTo.month, dateTo.day + 1);
    if (await _storesLocally) {
      final all = await _localProgress(userName, gameType, gameName);
      var selected = all
          .where(
            (row) =>
                row.createdAt != null &&
                !row.createdAt!.isBefore(dateFrom) &&
                row.createdAt!.isBefore(upperBound),
          )
          .toList();
      if (includeLatestFallback && selected.isEmpty && all.isNotEmpty) {
        selected = [all.first];
      }
      return selected;
    }
    final rows = await supabase
        .from(TableNames.gameUser)
        .select(
          'id,name,game_id,score,created_at,is_pass,game_list!inner(game_type,game_name,level)',
        )
        .ilike('name', userName)
        .eq('game_list.game_type', gameType)
        .eq('game_list.game_name', gameName)
        .gte(Fields.createdAt, dateFrom.toUtc().toIso8601String())
        .lt(Fields.createdAt, upperBound.toUtc().toIso8601String())
        .order(Fields.createdAt, ascending: false);
    final result = List<Map<String, dynamic>>.from(rows);
    if (includeLatestFallback && result.isEmpty) {
      final fallback = await supabase
          .from(TableNames.gameUser)
          .select(
            'id,name,game_id,score,created_at,is_pass,game_list!inner(game_type,game_name,level)',
          )
          .ilike('name', userName)
          .eq('game_list.game_type', gameType)
          .eq('game_list.game_name', gameName)
          .order(Fields.createdAt, ascending: false)
          .limit(1);
      result.addAll(List<Map<String, dynamic>>.from(fallback));
    }
    return result.map(_mapProgressWithGame).toList();
  }

  Future<bool> hasUserProgressBefore({
    required String userName,
    required String gameType,
    required String gameName,
    required DateTime before,
  }) async {
    if (await _storesLocally) {
      final rows = await _localProgress(userName, gameType, gameName);
      return rows.any((row) => row.createdAt?.isBefore(before) ?? false);
    }
    final rows = await supabase
        .from(TableNames.gameUser)
        .select('id, game_list!inner(game_type, game_name)')
        .ilike('name', userName)
        .eq('game_list.game_type', gameType)
        .eq('game_list.game_name', gameName)
        .lt(Fields.createdAt, before.toUtc().toIso8601String())
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<DateTime?> latestUserProgressDateBefore({
    required String userName,
    required String gameType,
    required String gameName,
    required DateTime before,
  }) async {
    if (await _storesLocally) {
      final dates =
          (await _localProgress(userName, gameType, gameName))
              .map((row) => row.createdAt)
              .whereType<DateTime>()
              .where((date) => date.isBefore(before))
              .toList()
            ..sort((a, b) => b.compareTo(a));
      return dates.firstOrNull;
    }
    final rows = await supabase
        .from(TableNames.gameUser)
        .select('created_at, game_list!inner(game_type, game_name)')
        .ilike('name', userName)
        .eq('game_list.game_type', gameType)
        .eq('game_list.game_name', gameName)
        .lt(Fields.createdAt, before.toUtc().toIso8601String())
        .order(Fields.createdAt, ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return tryParseDateTimeValue(
      parseStringValue(rows.first[Fields.createdAt]),
      toLocal: true,
    );
  }

  ModelGameUser _mapProgressWithGame(Map<String, dynamic> row) {
    final game = row['game_list'] is Map
        ? Map<String, dynamic>.from(row['game_list'] as Map)
        : <String, dynamic>{};
    return ModelGameUser.fromMap({...row, ...game});
  }

  Future<List<ModelGameUser>> _localProgress(
    String userName,
    String gameType,
    String gameName,
  ) {
    final key = '${userName.toLowerCase()}|$gameType|$gameName';
    return _localProgressRequests.putIfAbsent(
      key,
      () => _loadLocalProgress(userName, gameType, gameName),
    );
  }

  Future<List<ModelGameUser>> _loadLocalProgress(
    String userName,
    String gameType,
    String gameName,
  ) async {
    final games = {for (final game in await fetchGames()) game.id: game};
    final rows = await _localQuestions(TableNames.gameUser);
    final result = <ModelGameUser>[];
    for (final row in rows) {
      final game = games[parseOptionalStringValue(row['game_id'])];
      if (game == null ||
          normalizeStringValue(row['name']) != normalizeStringValue(userName) ||
          game.gameType != gameType ||
          game.gameName != gameName) {
        continue;
      }
      result.add(
        ModelGameUser.fromMap({
          ...row,
          'game_type': game.gameType,
          'game_name': game.gameName,
          'level': game.level,
        }),
      );
    }
    result.sort(
      (a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
    );
    return result;
  }

  void invalidateLocalProgress() => _localProgressRequests.clear();

  Future<void> addGrammarQuestion({
    required String question,
    required String answer,
    required String group,
    required int level,
    required List<String> options,
  }) async {
    await _insertQuestion(_grammarQuestionTable, {
      'question': question.trim(),
      'answer': answer.trim(),
      'group': group.trim(),
      'level': level,
      'options': options.map((option) => option.trim()).join('_'),
    });
  }

  Future<void> addSentenceQuestion({
    required String question,
    required String answer,
    required String group,
    required int level,
  }) async {
    await _insertQuestion(_sentenceQuestionTable, {
      'question': question.trim(),
      'answer': answer.trim(),
      'group': group.trim(),
      'level': level,
    });
  }

  Future<void> addTranslationQuestion({
    required String question,
    required String answer,
    required String group,
    required int level,
  }) async {
    await _insertQuestion(_translationQuestionTable, {
      'question': question.trim(),
      'answer': answer.trim(),
      'group': group.trim(),
      'level': level,
    });
  }

  Future<void> addSocialQuestion({
    required String title,
    required String scene,
    required String category,
    required int level,
    required List<Map<String, dynamic>> choices,
  }) async {
    try {
      if (await _storesLocally) {
        final duplicate =
            (await _localQuestions(TableNames.gameSocialScenarios)).any(
              (row) =>
                  normalizeStringValue(row['category']) ==
                      normalizeStringValue(category) &&
                  GameQuestionRowRules.duplicateKey(row['scene']) ==
                      GameQuestionRowRules.duplicateKey(scene),
            );
        if (duplicate) {
          throw const DuplicateGameQuestionException();
        }
        final id = const Uuid().v4();
        await LocalDataStore.instance.put(
          owner: _ownerEmail,
          resource: TableNames.gameSocialScenarios,
          id: id,
          data: {
            Fields.id: id,
            'title': title.trim(),
            'scene': scene.trim(),
            'category': category.trim(),
            'level': level,
            'is_active': true,
            'owner_id': _currentUserId,
            'choices': choices,
          },
        );
        return;
      }
      await supabase.rpc(
        'create_my_social_question',
        params: {
          'p_title': title.trim(),
          'p_scene': scene.trim(),
          'p_category': category.trim(),
          'p_level': level,
          'p_choices': choices,
        },
      );
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const DuplicateGameQuestionException();
      }
      rethrow;
    }
  }

  Future<void> updateSocialQuestion({
    required String id,
    required String title,
    required String scene,
    required String category,
    required List<Map<String, dynamic>> choices,
  }) async {
    try {
      if (await _storesLocally) {
        final rows = await _localQuestions(TableNames.gameSocialScenarios);
        final row = rows
            .where((item) => parseOptionalStringValue(item[Fields.id]) == id)
            .firstOrNull;
        if (row == null) {
          throw StateError('Local social question not found.');
        }
        final duplicate = rows.any(
          (item) =>
              parseOptionalStringValue(item[Fields.id]) != id &&
              normalizeStringValue(item['category']) ==
                  normalizeStringValue(category) &&
              GameQuestionRowRules.duplicateKey(item['scene']) ==
                  GameQuestionRowRules.duplicateKey(scene),
        );
        if (duplicate) {
          throw const DuplicateGameQuestionException();
        }
        await LocalDataStore.instance.put(
          owner: _ownerEmail,
          resource: TableNames.gameSocialScenarios,
          id: id,
          data: {
            ...row,
            'title': title.trim(),
            'scene': scene.trim(),
            'category': category.trim(),
            'choices': choices,
          },
          syncState: LocalSyncState.modifiedLocally,
        );
        return;
      }
      await supabase.rpc(
        'update_my_social_question',
        params: {
          'p_scenario_id': id,
          'p_title': title.trim(),
          'p_scene': scene.trim(),
          'p_category': category.trim(),
          'p_choices': choices,
        },
      );
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const DuplicateGameQuestionException();
      }
      rethrow;
    }
  }

  Future<MySocialQuestionPage> fetchMySocialQuestions({
    String keyword = '',
    String? category,
    String status = 'all',
    int offset = 0,
    int limit = 20,
  }) async {
    final localMode = await _storesLocally;
    if (!localMode) {
      final page = await readQuestionPage(
        offset: offset,
        limit: limit,
        fetch: (pageOffset, pageLimit) async =>
            await supabase.rpc(
                  'get_my_social_questions_page',
                  params: {
                    'p_keyword': keyword.trim(),
                    'p_category': category,
                    'p_status': status,
                    'p_offset': pageOffset,
                    'p_limit': pageLimit,
                  },
                )
                as List<dynamic>,
      );
      return MySocialQuestionPage(
        questions: page.rows
            .map(
              (row) => MySocialQuestion.fromJson(row, sortChoicesByScore: true),
            )
            .toList(),
        totalCount: page.totalCount,
        hasMore: page.hasMore,
      );
    }
    final localRows = await _localQuestions(TableNames.gameSocialScenarios);
    final normalizedKeyword = normalizeStringValue(keyword);
    final localQuestions = localRows
        .where((row) {
          final matchesKeyword =
              normalizedKeyword.isEmpty ||
              normalizeStringValue(row['title']).contains(normalizedKeyword) ||
              normalizeStringValue(row['scene']).contains(normalizedKeyword);
          final matchesCategory =
              category == null || row['category'] == category;
          final matchesStatus = GameQuestionRowRules.matchesStatus(
            row['is_active'],
            status,
          );
          return matchesKeyword && matchesCategory && matchesStatus;
        })
        .map((row) => MySocialQuestion.fromJson(row));
    final localList = localQuestions.toList();
    return MySocialQuestionPage(
      questions: localList.skip(offset).take(limit).toList(),
      totalCount: localList.length,
      hasMore: offset + limit < localList.length,
    );
  }

  Future<List<String>> fetchMySocialQuestionCategories() async {
    final localMode = await _storesLocally;
    final rows = localMode
        ? <dynamic>[]
        : await supabase.rpc('get_my_social_question_categories')
              as List<dynamic>;
    final categories = rows
        .map(
          (row) => parseStringValue((row as Map<String, dynamic>)['category']),
        )
        .where((category) => category.isNotEmpty)
        .toSet();
    categories.addAll(
      (await _localQuestions(TableNames.gameSocialScenarios))
          .map((row) => parseStringValue(row['category']))
          .where((value) => value.isNotEmpty),
    );
    return categories.toList()..sort();
  }

  Future<void> createGameLevel({
    required String gameType,
    required String gameName,
    required int level,
  }) async {
    try {
      await supabase.rpc(
        'create_game_level',
        params: {
          'p_game_type': gameType.trim(),
          'p_game_name': gameName.trim(),
          'p_level': level,
        },
      );
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw const DuplicateGameLevelException();
      rethrow;
    }
  }

  Future<void> setMySocialQuestionActive({
    required String id,
    required bool isActive,
  }) async {
    if (await _storesLocally) {
      final rows = await _localQuestions(TableNames.gameSocialScenarios);
      final row = rows
          .where((item) => parseOptionalStringValue(item[Fields.id]) == id)
          .firstOrNull;
      if (row == null) {
        throw StateError('Local social question not found.');
      }
      await LocalDataStore.instance.put(
        owner: _ownerEmail,
        resource: TableNames.gameSocialScenarios,
        id: id,
        data: {...row, 'is_active': isActive},
        syncState: LocalSyncState.modifiedLocally,
      );
      return;
    }
    await supabase.rpc(
      'set_my_social_question_active',
      params: {'p_scenario_id': id, 'p_is_active': isActive},
    );
  }

  Future<void> deleteMySocialQuestion(String id) async {
    if (await _storesLocally) {
      final exists = await LocalDataStore.instance.contains(
        owner: _ownerEmail,
        resource: TableNames.gameSocialScenarios,
        id: id,
      );
      if (!exists) {
        throw StateError('Local social question not found.');
      }
      await LocalDataStore.instance.delete(
        owner: _ownerEmail,
        resource: TableNames.gameSocialScenarios,
        id: id,
      );
      return;
    }
    try {
      await supabase.rpc(
        'delete_my_social_question',
        params: {'p_scenario_id': id},
      );
    } on PostgrestException catch (error) {
      if (error.code == '23503') {
        throw const GameQuestionHasAnswersException();
      }
      rethrow;
    }
  }

  Future<void> updateGrammarQuestion({
    required String id,
    required String question,
    required String answer,
    required String group,
    required int level,
    required List<String> options,
  }) async {
    await _updateQuestion(
      tableName: _grammarQuestionTable,
      id: id,
      question: question,
      answer: answer,
      group: group,
      level: level,
      extraValues: {
        'options': options.map((option) => option.trim()).join('_'),
      },
    );
  }

  Future<void> updateSentenceQuestion({
    required String id,
    required String question,
    required String answer,
    required String group,
    required int level,
  }) async {
    await _updateQuestion(
      tableName: _sentenceQuestionTable,
      id: id,
      question: question,
      answer: answer,
      group: group,
      level: level,
    );
  }

  Future<void> updateTranslationQuestion({
    required String id,
    required String question,
    required String answer,
    required String group,
    required int level,
  }) async {
    await _updateQuestion(
      tableName: _translationQuestionTable,
      id: id,
      question: question,
      answer: answer,
      group: group,
      level: level,
    );
  }

  Future<QuestionBankAvailability> getQuestionBankAvailability({
    required String gameName,
    required int level,
    required String questionBank,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User must be signed in');
    final normalizedName = gameName.toLowerCase();
    final bankOwnerId = questionBank == 'admin'
        ? AuthConstants.systemQuestionBankOwnerId
        : userId;
    if (normalizedName == 'social') {
      final localMode = await _storesLocally;
      final rows = localMode
          ? <dynamic>[]
          : await supabase
                .from(TableNames.gameSocialScenarios)
                .select('id, ${TableNames.gameSocialChoices}(id)')
                .eq('owner_id', bankOwnerId)
                .eq('is_active', true)
                .lte('level', level);
      var completeQuestionCount = rows.where((row) {
        final choices = row[TableNames.gameSocialChoices] as List<dynamic>?;
        return (choices?.length ?? 0) >= 3;
      }).length;
      if (localMode) {
        completeQuestionCount +=
            (await _localQuestions(TableNames.gameSocialScenarios)).where((
              row,
            ) {
              final choices = row['choices'] as List?;
              return GameQuestionRowRules.isPlayableAtLevel(row, level) &&
                  (choices?.length ?? 0) >= 3;
            }).length;
      }
      return QuestionBankAvailability.forGame(
        gameName: gameName,
        questionCount: completeQuestionCount,
      );
    }
    final tableName = GameQuestionSourceRules.tableForGame(gameName);

    final localMode = await _storesLocally;
    final rows = localMode
        ? <dynamic>[]
        : await supabase.rpc(
                'get_question_bank_group_counts',
                params: {
                  'p_table_name': tableName,
                  'p_level': level,
                  'p_question_bank': questionBank == 'admin' ? 'admin' : 'mine',
                },
              )
              as List<dynamic>;
    final groupCounts = <String, int>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final group = parseStringValue(row['question_group']);
      if (!_groupMatchesGame(gameName, group)) continue;
      groupCounts[group] = tryParseIntValue(row['question_count']) ?? 0;
    }
    for (final row
        in localMode
            ? await _localQuestions(tableName)
            : const <Map<String, dynamic>>[]) {
      final localGroup = parseStringValue(row['group']);
      if (!GameQuestionRowRules.isPlayableAtLevel(
        row,
        level,
        gameName: gameName,
      )) {
        continue;
      }
      groupCounts[localGroup] = (groupCounts[localGroup] ?? 0) + 1;
    }
    final questionCount = groupCounts.values.fold<int>(
      0,
      (total, count) => total + count,
    );

    return QuestionBankAvailability.forGame(
      gameName: gameName,
      questionCount: questionCount,
    );
  }

  Future<MyGameQuestionPage> fetchMyQuestions({
    required String gameName,
    String keyword = '',
    String? group,
    String status = 'all',
    int offset = 0,
    int limit = 20,
  }) async {
    if (supabase.auth.currentUser == null) {
      throw StateError('User must be signed in');
    }
    final tableName = _questionTableForGame(gameName);
    final localMode = await _storesLocally;
    if (!localMode) {
      final page = await readQuestionPage(
        offset: offset,
        limit: limit,
        fetch: (pageOffset, pageLimit) async =>
            await supabase.rpc(
                  'get_my_questions_page',
                  params: {
                    'p_table_name': tableName,
                    'p_game_name': gameName,
                    'p_keyword': keyword.trim(),
                    'p_group': group,
                    'p_status': status,
                    'p_offset': pageOffset,
                    'p_limit': pageLimit,
                  },
                )
                as List<dynamic>,
      );
      return MyGameQuestionPage(
        questions: page.rows
            .map((row) => MyGameQuestion.fromJson(row))
            .toList(),
        totalCount: page.totalCount,
        hasMore: page.hasMore,
      );
    }
    final localRows = await _localQuestions(tableName);
    final normalizedKeyword = normalizeStringValue(keyword);
    final matchingLocal = localRows
        .where((row) {
          final matchesGame = _groupMatchesGame(
            gameName,
            parseStringValue(row['group']),
          );
          final matchesKeyword =
              normalizedKeyword.isEmpty ||
              normalizeStringValue(
                row['question'],
              ).contains(normalizedKeyword) ||
              normalizeStringValue(row['answer']).contains(normalizedKeyword);
          final matchesGroup = group == null || row['group'] == group;
          final matchesStatus = GameQuestionRowRules.matchesStatus(
            row['is_active'],
            status,
          );
          return matchesGame && matchesKeyword && matchesGroup && matchesStatus;
        })
        .map((row) => MyGameQuestion.fromJson(row, groupField: 'group'))
        .toList();
    return MyGameQuestionPage(
      questions: matchingLocal.skip(offset).take(limit).toList(),
      totalCount: matchingLocal.length,
      hasMore: offset + limit < matchingLocal.length,
    );
  }

  Future<List<String>> fetchMyQuestionGroupsForManagement({
    required String gameName,
  }) async {
    if (supabase.auth.currentUser == null) {
      throw StateError('User must be signed in');
    }
    final localMode = await _storesLocally;
    final rows = localMode
        ? <dynamic>[]
        : await supabase.rpc(
                'get_my_question_groups_for_management',
                params: {'p_table_name': _questionTableForGame(gameName)},
              )
              as List<dynamic>;
    final groups = rows
        .map(
          (row) =>
              parseStringValue((row as Map<String, dynamic>)['question_group']),
        )
        .where(
          (group) => group.isNotEmpty && _groupMatchesGame(gameName, group),
        )
        .toSet();
    if (localMode) {
      groups.addAll(
        (await _localQuestions(_questionTableForGame(gameName)))
            .map((row) => parseStringValue(row['group']))
            .where(
              (group) => group.isNotEmpty && _groupMatchesGame(gameName, group),
            ),
      );
    }
    return groups.toList()..sort();
  }

  Future<List<String>> fetchMyQuestionGroups({required String gameName}) async {
    if (supabase.auth.currentUser == null) {
      throw StateError('User must be signed in');
    }
    if (await _storesLocally) {
      final groups =
          (await _localQuestions(_questionTableForGame(gameName)))
              .map((row) => parseStringValue(row['group']).trim())
              .where(
                (group) =>
                    group.isNotEmpty && _groupMatchesGame(gameName, group),
              )
              .toSet()
              .toList()
            ..sort();
      return groups;
    }
    final rows =
        await supabase.rpc(
              'get_question_bank_groups',
              params: {'p_table_name': _questionTableForGame(gameName)},
            )
            as List<dynamic>;
    final groups =
        rows
            .map(
              (row) => parseStringValue(
                (row as Map<String, dynamic>)['question_group'],
              ).trim(),
            )
            .where(
              (group) => group.isNotEmpty && _groupMatchesGame(gameName, group),
            )
            .toList()
          ..sort();
    return groups;
  }

  Future<GameQuestionHint?> fetchAdminQuestionHint({
    required String gameName,
    required String group,
  }) async {
    if (await _storesLocally) return null;
    final randomKey = Random.secure().nextDouble();
    var rows = await supabase
        .from(_questionTableForGame(gameName))
        .select('question, answer')
        .eq('owner_id', AuthConstants.systemQuestionBankOwnerId)
        .eq('group', group)
        .eq('is_active', true)
        .gte('rand_key', randomKey)
        .order('rand_key')
        .limit(1);
    if (rows.isEmpty) {
      rows = await supabase
          .from(_questionTableForGame(gameName))
          .select('question, answer')
          .eq('owner_id', AuthConstants.systemQuestionBankOwnerId)
          .eq('group', group)
          .eq('is_active', true)
          .lt('rand_key', randomKey)
          .order('rand_key')
          .limit(1);
    }
    if (rows.isEmpty) return null;
    final row = rows.first;
    return GameQuestionHint(
      question: parseStringValue(row['question']),
      answer: parseStringValue(row['answer']),
    );
  }

  Future<void> deleteMyQuestion({
    required String gameName,
    required String questionId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User must be signed in');
    final tableName = _questionTableForGame(gameName);
    if (await _storesLocally) {
      final exists = await LocalDataStore.instance.contains(
        owner: _ownerEmail,
        resource: tableName,
        id: questionId,
      );
      if (!exists) {
        throw StateError('Local question not found.');
      }
      await LocalDataStore.instance.delete(
        owner: _ownerEmail,
        resource: tableName,
        id: questionId,
      );
      return;
    }
    late final List<Map<String, dynamic>> deletedRows;
    try {
      deletedRows = await supabase
          .from(_questionTableForGame(gameName))
          .delete()
          .eq(Fields.id, questionId)
          .eq('owner_id', userId)
          .select('id');
    } on PostgrestException catch (error) {
      if (error.code == '23503') {
        throw const GameQuestionHasAnswersException();
      }
      rethrow;
    }
    if (deletedRows.isEmpty) {
      throw StateError('Question was not deleted');
    }
  }

  Future<void> setMyQuestionActive({
    required String gameName,
    required String questionId,
    required bool isActive,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User must be signed in');
    final tableName = _questionTableForGame(gameName);
    if (await _storesLocally) {
      final rows = await _localQuestions(tableName);
      final row = rows
          .where(
            (item) => parseOptionalStringValue(item[Fields.id]) == questionId,
          )
          .firstOrNull;
      if (row == null) {
        throw StateError('Local question not found.');
      }
      await LocalDataStore.instance.put(
        owner: _ownerEmail,
        resource: tableName,
        id: questionId,
        data: {...row, 'is_active': isActive},
        syncState: LocalSyncState.modifiedLocally,
      );
      return;
    }
    final updatedRows = await supabase
        .from(_questionTableForGame(gameName))
        .update({'is_active': isActive})
        .eq(Fields.id, questionId)
        .eq('owner_id', userId)
        .select('id');
    if (updatedRows.isEmpty) {
      throw StateError('Question status was not updated');
    }
  }

  String _questionTableForGame(String gameName) =>
      GameQuestionSourceRules.tableForGame(gameName);

  bool _groupMatchesGame(String gameName, String group) =>
      GameQuestionSourceRules.groupMatchesGame(gameName, group);

  Future<void> _insertQuestion(
    String tableName,
    Map<String, Object?> values,
  ) async {
    try {
      if (await _storesLocally) {
        if (await _hasLocalDuplicate(
          tableName: tableName,
          question: parseStringValue(values['question']),
          answer: parseStringValue(values['answer']),
          group: parseStringValue(values['group']),
        )) {
          throw const DuplicateGameQuestionException();
        }
        final id = const Uuid().v4();
        await LocalDataStore.instance.put(
          owner: _ownerEmail,
          resource: tableName,
          id: id,
          data: {
            Fields.id: id,
            ...values,
            'owner_id': _currentUserId,
            'is_active': true,
            'rand_key': Random.secure().nextDouble(),
            Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
          },
        );
        return;
      }
      await supabase.from(tableName).insert(values);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const DuplicateGameQuestionException();
      }
      rethrow;
    }
  }

  Future<void> _updateQuestion({
    required String tableName,
    required String id,
    required String question,
    required String answer,
    required String group,
    required int level,
    Map<String, Object?> extraValues = const {},
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User must be signed in');

    try {
      if (await _storesLocally) {
        final rows = await _localQuestions(tableName);
        final row = rows
            .where((item) => parseOptionalStringValue(item[Fields.id]) == id)
            .firstOrNull;
        if (row == null) {
          throw StateError('Local question not found.');
        }
        if (await _hasLocalDuplicate(
          tableName: tableName,
          question: question,
          answer: answer,
          group: group,
          excludingId: id,
        )) {
          throw const DuplicateGameQuestionException();
        }
        await LocalDataStore.instance.put(
          owner: _ownerEmail,
          resource: tableName,
          id: id,
          data: {
            ...row,
            'question': question.trim(),
            'answer': answer.trim(),
            'group': group.trim(),
            'level': level,
            ...extraValues,
          },
          syncState: LocalSyncState.modifiedLocally,
        );
        return;
      }
      await supabase
          .from(tableName)
          .update({
            'question': question.trim(),
            'answer': answer.trim(),
            'group': group.trim(),
            'level': level,
            ...extraValues,
          })
          .eq(Fields.id, id)
          .eq('owner_id', userId);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        throw const DuplicateGameQuestionException();
      }
      rethrow;
    }
  }

  //------------------------- Grammar -------------------------
  Future<ModelGameGrammarQuestion> fetchGrammarQuestion(
    String userName,
    int level, {
    String questionBank = 'admin',
  }) async {
    final localMode = await _storesLocally;
    if (questionBank == 'my' || localMode) {
      final local = (await _localQuestions(_grammarQuestionTable))
          .where((row) => GameQuestionRowRules.isPlayableAtLevel(row, level))
          .toList();
      if (local.isNotEmpty) {
        final data = local[Random.secure().nextInt(local.length)];
        return ModelGameGrammarQuestion(
          questionId: parseStringValue(data[Fields.id]),
          question: parseStringValue(data['question']),
          correctAnswer: parseStringValue(data['answer']),
          type: parseStringValue(data['group']),
          options: parseStringValue(data['options']).split('_'),
        );
      }
    }
    if (localMode) throw StateError('local_question_bank_empty');
    final result = await supabase.rpc(
      'get_grammar_question',
      params: {
        'user_name': userName,
        'p_level': level,
        'p_question_bank': questionBank,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];
    return ModelGameGrammarQuestion(
      questionId: data[Fields.id],
      question: data['question'],
      correctAnswer: data['correct_answer'],
      type: data['type'],
      options: (data['options'] ?? '').split('_'),
    );
  }

  // 寫入使用者答題紀錄
  Future<void> submitGrammarAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await _insertAnswer(TableNames.gameGrammarUser, {
      'owner_id': _currentUserId,
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }

  //------------------------- Sentence -------------------------
  Future<ModelGameSentence> fetchSentenceQuestion(
    String userName,
    int level, {
    String questionBank = 'admin',
  }) async {
    final localMode = await _storesLocally;
    if (questionBank == 'my' || localMode) {
      final local = (await _localQuestions(_sentenceQuestionTable))
          .where((row) => GameQuestionRowRules.isPlayableAtLevel(row, level))
          .toList();
      if (local.isNotEmpty) {
        final data = local[Random.secure().nextInt(local.length)];
        final question = parseStringValue(data['question']);
        return ModelGameSentence(
          questionId: parseStringValue(data[Fields.id]),
          question: question,
          correctAnswer: parseStringValue(data['answer']),
          type: parseStringValue(data['group']),
          options: question.split('_'),
        );
      }
    }
    if (localMode) throw StateError('local_question_bank_empty');
    final result = await supabase.rpc(
      'get_sentence_question',
      params: {
        'user_name': userName,
        'p_level': level,
        'p_question_bank': questionBank,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }
    final data = result[0];
    return ModelGameSentence(
      questionId: data[Fields.id],
      question: data['question'],
      correctAnswer: data['correct_answer'],
      type: data['type'],
      options: (data['question'] ?? '').split('_'),
    );
  }

  // 寫入使用者答題紀錄
  Future<void> submitSentenceAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await _insertAnswer(TableNames.gameSentenceUser, {
      'owner_id': _currentUserId,
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }

  //------------------------- Speaking -------------------------
  Future<ModelGameSpeaking> fetchSpeakingQuestion(
    String userName,
    int level, {
    String questionBank = 'admin',
  }) async {
    final localMode = await _storesLocally;
    if (questionBank == 'my' || localMode) {
      final local = (await _localQuestions(_sentenceQuestionTable))
          .where((row) => GameQuestionRowRules.isPlayableAtLevel(row, level))
          .toList();
      if (local.isNotEmpty) {
        final data = local[Random.secure().nextInt(local.length)];
        return ModelGameSpeaking(
          questionId: parseStringValue(data[Fields.id]),
          question: parseStringValue(data['question']),
          correctAnswer: parseStringValue(data['answer']),
          type: parseStringValue(data['group']),
        );
      }
    }
    if (localMode) throw StateError('local_question_bank_empty');
    final result = await supabase.rpc(
      'get_speaking_question',
      params: {
        'user_name': userName,
        'p_level': level,
        'p_question_bank': questionBank,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];
    return ModelGameSpeaking(
      questionId: data[Fields.id],
      question: data['question'],
      correctAnswer: data['correct_answer'],
      type: data['type'],
    );
  }

  // 寫入使用者答題紀錄
  Future<void> submitSpeakingAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await _insertAnswer(TableNames.gameSpeakingUser, {
      'owner_id': _currentUserId,
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }

  //------------------------- Social -------------------------
  Future<ModelGameSocial> fetchSocialQuestion(
    String userName,
    int level, {
    String questionBank = 'admin',
  }) async {
    final localMode = await _storesLocally;
    if (questionBank == 'my' || localMode) {
      final local = (await _localQuestions(TableNames.gameSocialScenarios))
          .where((row) => GameQuestionRowRules.isPlayableAtLevel(row, level))
          .toList();
      if (local.isNotEmpty) {
        final data = local[Random.secure().nextInt(local.length)];
        final choices =
            (data['choices'] as List? ?? const [])
                .map((raw) => Map<String, dynamic>.from(raw as Map))
                .toList()
              ..sort(
                (a, b) => (tryParseIntValue(b['score']) ?? 0).compareTo(
                  tryParseIntValue(a['score']) ?? 0,
                ),
              );
        if (choices.length >= 3) {
          final shuffled = choices.take(3).toList()..shuffle();
          return ModelGameSocial(
            id: parseStringValue(data[Fields.id]),
            scene: parseStringValue(data['scene']),
            correctAnswer: parseStringValue(choices.first['option_text']),
            options: shuffled
                .map((choice) => parseStringValue(choice['option_text']))
                .toList(),
            scores: shuffled
                .map((choice) => tryParseIntValue(choice['score']) ?? 0)
                .toList(),
          );
        }
      }
    }
    if (localMode) throw StateError('local_question_bank_empty');
    final result = await supabase.rpc(
      'get_social_with_options',
      params: {
        'user_name': userName,
        'p_level': level,
        'p_question_bank': questionBank,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];
    Map tmpMap = {
      data['answer1']: data['score1'],
      data['answer2']: data['score2'],
      data['answer3']: data['score3'],
    };
    List<String> options = [data['answer1'], data['answer2'], data['answer3']]
      ..shuffle();
    List<int> scores = [
      tmpMap[options[0]],
      tmpMap[options[1]],
      tmpMap[options[2]],
    ];
    return ModelGameSocial(
      id: data[Fields.id],
      scene: data['scene'],
      correctAnswer: data['answer1'],
      options: options,
      scores: scores,
    );
  }

  // 寫入使用者答題紀錄
  Future<void> submitSocialAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await _insertAnswer(TableNames.gameSocialUser, {
      'owner_id': _currentUserId,
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }

  //------------------------- Mario Translation -------------------------
  Future<ModelGameMarioTranslation> fetchMarioTranslationQuestion(
    String userName,
    int level, {
    String questionBank = 'admin',
  }) async {
    final localMode = await _storesLocally;
    if (questionBank == 'my' || localMode) {
      final local = (await _localQuestions(_translationQuestionTable))
          .where((row) => GameQuestionRowRules.isPlayableAtLevel(row, level))
          .toList();
      if (local.length >= 3) {
        local.shuffle();
        final data = local.first;
        return ModelGameMarioTranslation(
          questionId: parseStringValue(data[Fields.id]),
          question: parseStringValue(data['question']),
          correctAnswer: parseStringValue(data['answer']),
          options:
              local
                  .take(3)
                  .map((row) => parseStringValue(row['answer']))
                  .toList()
                ..shuffle(),
        );
      }
    }
    if (localMode) throw StateError('local_question_bank_empty');
    final result = await supabase
        .rpc(
          'get_translation_with_options',
          params: {
            'user_name': userName,
            'p_level': level,
            'p_question_bank': questionBank,
          },
        )
        .timeout(const Duration(seconds: 15));

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];

    return ModelGameMarioTranslation(
      questionId: data[Fields.id],
      question: data['question'],
      correctAnswer: data['correct_answer'],
      options: [data['correct_answer'], data['wrong1'], data['wrong2']]
        ..shuffle(),
    );
  }

  //------------------------- Translation -------------------------
  Future<ModelGameTranslation> fetchTranslationQuestion(
    String userName,
    int level,
    String gameName, {
    String questionBank = 'admin',
  }) async {
    final localMode = await _storesLocally;
    if (questionBank == 'my' || localMode) {
      final local = (await _localQuestions(_translationQuestionTable))
          .where(
            (row) => GameQuestionRowRules.isPlayableAtLevel(
              row,
              level,
              gameName: gameName,
            ),
          )
          .toList();
      if (local.length >= 3) {
        local.shuffle();
        final data = local.first;
        return ModelGameTranslation(
          questionId: parseStringValue(data[Fields.id]),
          question: parseStringValue(data['question']),
          group: parseStringValue(data['group']),
          correctAnswer: parseStringValue(data['answer']),
          options:
              local
                  .take(3)
                  .map((row) => parseStringValue(row['answer']))
                  .toList()
                ..shuffle(),
        );
      }
    }
    if (localMode) throw StateError('local_question_bank_empty');
    final functionName = GameQuestionSourceRules.translationRpc(gameName);

    final result = await supabase.rpc(
      functionName,
      params: {
        'user_name': userName,
        'p_level': level,
        'p_question_bank': questionBank,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }

    final data = result[0];

    return ModelGameTranslation(
      questionId: data[Fields.id],
      question: data['question'],
      group: data['group'],
      correctAnswer: data['correct_answer'],
      options: [
        data['correct_answer'],
        data['wrong1'] ?? '',
        data['wrong2'] ?? '',
      ]..shuffle(),
    );
  }

  Future<Set<String>> getSynonyms(String question) async {
    if (await _storesLocally) return const <String>{};
    final response = await supabase
        .from(TableNames.gameTranslationSynonyms)
        .select('answer')
        .eq('question', question.toLowerCase());

    return response
        .map((row) => parseStringValue(row['answer']).toLowerCase())
        .where((answer) => answer.isNotEmpty)
        .toSet();
  }

  // 寫入使用者答題紀錄
  Future<void> submitTranslationAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await _insertAnswer(TableNames.gameTranslationUser, {
      'owner_id': _currentUserId,
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }

  //------------------------- Word Search -------------------------
  Future<ModelGameWordSearch> fetchWordSearchQuestion(
    String userName,
    int level, {
    String questionBank = 'admin',
  }) async {
    final localMode = await _storesLocally;
    if (questionBank == 'my' || localMode) {
      final local = (await _localQuestions(_translationQuestionTable))
          .where(
            (row) => GameQuestionRowRules.isPlayableAtLevel(
              row,
              level,
              gameName: 'Word Searching',
            ),
          )
          .toList();
      if (local.isNotEmpty) {
        final data = local[Random.secure().nextInt(local.length)];
        return ModelGameWordSearch(
          questionId: parseStringValue(data[Fields.id]),
          question: parseStringValue(data['question']),
          found: false,
        );
      }
    }
    if (localMode) throw StateError('local_question_bank_empty');
    final result = await supabase.rpc(
      'get_next_word_question',
      params: {
        'user_name': userName,
        'p_level': level,
        'p_question_bank': questionBank,
      },
    );

    if (result == null || result.isEmpty) {
      throw Exception("No data returned");
    }
    final data = result[0];
    return ModelGameWordSearch(
      questionId: data[Fields.id],
      question: data['question'],
      found: false,
    );
  }

  // 寫入使用者答題紀錄
  Future<void> submitWordSearchAnswer({
    required String userName,
    required String questionId,
    required String answer,
    required bool isRightAnswer,
  }) async {
    await _insertAnswer(TableNames.gameWordSearchUser, {
      'owner_id': _currentUserId,
      'user': userName,
      'question_id': questionId,
      'answer': answer,
      'is_right': isRightAnswer,
      Fields.createdAt: DateTime.now().toUtc().toIso8601String(),
    });
  }
}
