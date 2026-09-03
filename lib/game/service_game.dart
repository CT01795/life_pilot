import 'dart:math';

import 'package:life_pilot/game/grammar/model_game_grammar.dart';
import 'package:life_pilot/game/mario_translation/model_game_mario_translation.dart';
import 'package:life_pilot/game/model_game_item.dart';
import 'package:life_pilot/game/model_game_user.dart';
import 'package:life_pilot/game/sentence/model_game_sentence.dart';
import 'package:life_pilot/game/social/model_game_social.dart';
import 'package:life_pilot/game/speaking/model_game_speaking.dart';
import 'package:life_pilot/game/translation/model_game_translation.dart';
import 'package:life_pilot/game/word_search/model_game_word_search.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
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

class GameQuestionHint {
  const GameQuestionHint({required this.question, required this.answer});

  final String question;
  final String answer;
}

class QuestionBankAvailability {
  const QuestionBankAvailability({
    required this.questionCount,
    required this.canPlay,
    required this.requiresThreeInGroup,
  });

  final int questionCount;
  final bool canPlay;
  final bool requiresThreeInGroup;
}

class MyGameQuestion {
  const MyGameQuestion({
    required this.id,
    required this.question,
    required this.answer,
    required this.group,
    required this.level,
    required this.isActive,
    this.options,
  });

  final String id;
  final String question;
  final String answer;
  final String group;
  final int level;
  final bool isActive;
  final String? options;
}

class MyGameQuestionPage {
  const MyGameQuestionPage({
    required this.questions,
    required this.totalCount,
  });

  final List<MyGameQuestion> questions;
  final int totalCount;
}

class MySocialChoice {
  const MySocialChoice({
    required this.text,
    required this.score,
    required this.feedback,
    required this.isBest,
  });

  final String text;
  final int score;
  final String feedback;
  final bool isBest;
}

class MySocialQuestion {
  const MySocialQuestion({
    required this.id,
    required this.title,
    required this.scene,
    required this.category,
    required this.isActive,
    required this.choices,
  });

  final String id;
  final String title;
  final String scene;
  final String category;
  final bool isActive;
  final List<MySocialChoice> choices;
}

class MySocialQuestionPage {
  const MySocialQuestionPage({
    required this.questions,
    required this.totalCount,
  });

  final List<MySocialQuestion> questions;
  final int totalCount;
}

class ServiceGame {
  static const _grammarQuestionTable = 'game_grammar';
  static const _sentenceQuestionTable = 'game_sentence';
  static const _translationQuestionTable = 'game_translation';

  String get _ownerEmail =>
      supabase.auth.currentUser?.email?.toLowerCase() ??
      (throw StateError('User must be signed in'));

  Future<bool> get _storesLocally async =>
      await LocalDataStore.instance.preferredLocation(_ownerEmail) ==
      DataStorageLocation.local;

  Future<List<Map<String, dynamic>>> _localQuestions(String tableName) =>
      LocalDataStore.instance.list(owner: _ownerEmail, resource: tableName);

  String _duplicateKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s_]+'), '');

  Future<bool> _hasLocalDuplicate({
    required String tableName,
    required String question,
    required String answer,
    required String group,
    String? excludingId,
  }) async {
    final questionKey = _duplicateKey(question);
    final answerKey = _duplicateKey(answer);
    final groupKey = group.trim().toLowerCase();
    return (await _localQuestions(tableName)).any((row) =>
        row[Fields.id]?.toString() != excludingId &&
        row['group']?.toString().trim().toLowerCase() == groupKey &&
        _duplicateKey(row['question']?.toString() ?? '') == questionKey &&
        _duplicateKey(row['answer']?.toString() ?? '') == answerKey);
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
  Future<void> saveUserGameScore(
      {required String newUserName,
      required double newScore,
      required String? newGameId,
      bool? newIsPass}) async {
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
    final data = await supabase
        .from(TableNames.gameList)
        .select()
        .order('game_type', ascending: true)
        .order('game_name', ascending: true)
        .order('level', ascending: true);

    // 轉成 GameItem
    return (data as List<dynamic>).map((e) {
      final map = e as Map<String, dynamic>;
      return ModelGameItem(
        id: map[Fields.id] as String,
        gameType: map['game_type'] as String,
        gameName: map['game_name'] as String,
        level: int.tryParse(map['level']?.toString() ?? '') ?? 1,
      );
    }).toList();
  }

  // 查詢目前使用者的分數紀錄
  Future<List<ModelGameUser>> fetchUserProgress(
      String userName, String gameType, String gameName) async {
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
          .where((row) =>
              row.createdAt != null &&
              !row.createdAt!.isBefore(dateFrom) &&
              row.createdAt!.isBefore(upperBound))
          .toList();
      if (includeLatestFallback && selected.isEmpty && all.isNotEmpty) {
        selected = [all.first];
      }
      return selected;
    }
    final rows = await supabase
        .from(TableNames.gameUser)
        .select('*, game_list!inner(game_type, game_name, level)')
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
          .select('*, game_list!inner(game_type, game_name, level)')
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
      final dates = (await _localProgress(userName, gameType, gameName))
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
    return DateTime.tryParse(rows.first[Fields.createdAt]?.toString() ?? '')
        ?.toLocal();
  }

  ModelGameUser _mapProgressWithGame(Map<String, dynamic> row) {
    final game = row['game_list'] is Map
        ? Map<String, dynamic>.from(row['game_list'] as Map)
        : <String, dynamic>{};
    return ModelGameUser.fromMap({...row, ...game});
  }

  Future<List<ModelGameUser>> _localProgress(
      String userName, String gameType, String gameName) async {
    final games = {for (final game in await fetchGames()) game.id: game};
    final rows = await _localQuestions(TableNames.gameUser);
    final result = <ModelGameUser>[];
    for (final row in rows) {
      final game = games[row['game_id']?.toString()];
      if (game == null ||
          row['name']?.toString().toLowerCase() != userName.toLowerCase() ||
          game.gameType != gameType ||
          game.gameName != gameName) {
        continue;
      }
      result.add(ModelGameUser.fromMap({
        ...row,
        'game_type': game.gameType,
        'game_name': game.gameName,
        'level': game.level
      }));
    }
    result.sort((a, b) =>
        (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return result;
  }

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
            (await _localQuestions(TableNames.gameSocialScenarios)).any((row) =>
                row['category']?.toString().trim().toLowerCase() ==
                    category.trim().toLowerCase() &&
                _duplicateKey(row['scene']?.toString() ?? '') ==
                    _duplicateKey(scene));
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
      if (await LocalDataStore.instance.contains(
        owner: _ownerEmail,
        resource: TableNames.gameSocialScenarios,
        id: id,
      )) {
        final rows = await _localQuestions(TableNames.gameSocialScenarios);
        final row = rows.firstWhere((item) => item[Fields.id] == id);
        final duplicate = rows.any((item) =>
            item[Fields.id]?.toString() != id &&
            item['category']?.toString().trim().toLowerCase() ==
                category.trim().toLowerCase() &&
            _duplicateKey(item['scene']?.toString() ?? '') ==
                _duplicateKey(scene));
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
      await supabase.rpc('update_my_social_question', params: {
        'p_scenario_id': id,
        'p_title': title.trim(),
        'p_scene': scene.trim(),
        'p_category': category.trim(),
        'p_choices': choices,
      });
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
  }) async {
    final localMode = await _storesLocally;
    final rows = localMode
        ? <dynamic>[]
        : await supabase.rpc('get_my_social_questions_page', params: {
            'p_keyword': keyword.trim(),
            'p_category': category,
            'p_status': status,
            'p_offset': offset,
            'p_limit': 20,
          }) as List<dynamic>;
    final questions = rows.cast<Map<String, dynamic>>().map((row) {
      final choices =
          (row['choices'] as List<dynamic>? ?? const []).map((choice) {
        final data = choice as Map<String, dynamic>;
        return MySocialChoice(
          text: data['option_text']?.toString() ?? '',
          score: int.tryParse(data['score']?.toString() ?? '') ?? 0,
          feedback: data['feedback']?.toString() ?? '',
          isBest: data['is_best'] == true,
        );
      }).toList()
            ..sort((a, b) => b.score.compareTo(a.score));
      return MySocialQuestion(
        id: row['id'].toString(),
        title: row['title']?.toString() ?? '',
        scene: row['scene']?.toString() ?? '',
        category: row['category']?.toString() ?? 'social',
        isActive: row['is_active'] == true,
        choices: choices,
      );
    }).toList();
    final localRows = await _localQuestions(TableNames.gameSocialScenarios);
    final normalizedKeyword = keyword.trim().toLowerCase();
    final localQuestions = localRows.where((row) {
      final matchesKeyword = normalizedKeyword.isEmpty ||
          row['title'].toString().toLowerCase().contains(normalizedKeyword) ||
          row['scene'].toString().toLowerCase().contains(normalizedKeyword);
      final matchesCategory = category == null || row['category'] == category;
      final active = row['is_active'] == true;
      final matchesStatus = status == 'all' ||
          (status == 'active' && active) ||
          (status == 'inactive' && !active);
      return matchesKeyword && matchesCategory && matchesStatus;
    }).map((row) {
      final choices = (row['choices'] as List? ?? const []).map((raw) {
        final choice = Map<String, dynamic>.from(raw as Map);
        return MySocialChoice(
          text: choice['option_text']?.toString() ?? '',
          score: int.tryParse(choice['score']?.toString() ?? '0') ?? 0,
          feedback: choice['feedback']?.toString() ?? '',
          isBest: choice['is_best'] == true,
        );
      }).toList();
      return MySocialQuestion(
        id: row[Fields.id].toString(),
        title: row['title']?.toString() ?? '',
        scene: row['scene']?.toString() ?? '',
        category: row['category']?.toString() ?? 'social',
        isActive: row['is_active'] == true,
        choices: choices,
      );
    });
    final localList = localQuestions.toList();
    if (localMode) questions.addAll(localList.skip(offset).take(20));
    return MySocialQuestionPage(
      questions: questions,
      totalCount: localMode ? localList.length : questions.length,
    );
  }

  Future<List<String>> fetchMySocialQuestionCategories() async {
    final localMode = await _storesLocally;
    final rows = localMode
        ? <dynamic>[]
        : await supabase.rpc('get_my_social_question_categories')
            as List<dynamic>;
    final categories = rows
        .map((row) =>
            (row as Map<String, dynamic>)['category']?.toString() ?? '')
        .where((category) => category.isNotEmpty)
        .toSet();
    categories.addAll((await _localQuestions(TableNames.gameSocialScenarios))
        .map((row) => row['category']?.toString() ?? '')
        .where((value) => value.isNotEmpty));
    return categories.toList()..sort();
  }

  Future<void> createGameLevel({
    required String gameType,
    required String gameName,
    required int level,
  }) async {
    try {
      await supabase.rpc('create_game_level', params: {
        'p_game_type': gameType.trim(),
        'p_game_name': gameName.trim(),
        'p_level': level,
      });
    } on PostgrestException catch (error) {
      if (error.code == '23505') throw const DuplicateGameLevelException();
      rethrow;
    }
  }

  Future<void> setMySocialQuestionActive({
    required String id,
    required bool isActive,
  }) async {
    if (await LocalDataStore.instance.contains(
      owner: _ownerEmail,
      resource: TableNames.gameSocialScenarios,
      id: id,
    )) {
      final rows = await _localQuestions(TableNames.gameSocialScenarios);
      final row = rows.firstWhere((item) => item[Fields.id] == id);
      await LocalDataStore.instance.put(
        owner: _ownerEmail,
        resource: TableNames.gameSocialScenarios,
        id: id,
        data: {...row, 'is_active': isActive},
        syncState: LocalSyncState.modifiedLocally,
      );
      return;
    }
    await supabase.rpc('set_my_social_question_active', params: {
      'p_scenario_id': id,
      'p_is_active': isActive,
    });
  }

  Future<void> deleteMySocialQuestion(String id) async {
    if (await LocalDataStore.instance.contains(
      owner: _ownerEmail,
      resource: TableNames.gameSocialScenarios,
      id: id,
    )) {
      await LocalDataStore.instance.delete(
        owner: _ownerEmail,
        resource: TableNames.gameSocialScenarios,
        id: id,
      );
      return;
    }
    try {
      await supabase.rpc('delete_my_social_question', params: {
        'p_scenario_id': id,
      });
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

  Future<QuestionBankAvailability> getMyQuestionBankAvailability({
    required String gameName,
    required int level,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User must be signed in');
    final normalizedName = gameName.toLowerCase();
    if (normalizedName == 'social') {
      final localMode = await _storesLocally;
      final rows = localMode
          ? <dynamic>[]
          : await supabase
              .from(TableNames.gameSocialScenarios)
              .select('id, ${TableNames.gameSocialChoices}(id)')
              .eq('owner_id', userId)
              .eq('is_active', true)
              .lte('level', level);
      var completeQuestionCount = rows.where((row) {
        final choices = row[TableNames.gameSocialChoices] as List<dynamic>?;
        return (choices?.length ?? 0) >= 3;
      }).length;
      if (localMode) {
        completeQuestionCount +=
            (await _localQuestions(TableNames.gameSocialScenarios))
                .where((row) {
          final choices = row['choices'] as List?;
          return row['is_active'] == true &&
              (int.tryParse(row['level']?.toString() ?? '1') ?? 1) <= level &&
              (choices?.length ?? 0) >= 3;
        }).length;
      }
      return QuestionBankAvailability(
        questionCount: completeQuestionCount,
        canPlay: completeQuestionCount > 0,
        requiresThreeInGroup: false,
      );
    }
    late final String tableName;
    if (normalizedName == 'english rpg adventure') {
      tableName = _grammarQuestionTable;
    } else if (normalizedName == 'speaking' ||
        normalizedName == 'word and sentence builder') {
      tableName = _sentenceQuestionTable;
    } else {
      tableName = _translationQuestionTable;
    }

    final localMode = await _storesLocally;
    final rows = localMode
        ? <dynamic>[]
        : await supabase.rpc(
            'get_my_question_group_counts',
            params: {
              'p_table_name': tableName,
              'p_level': level,
            },
          ) as List<dynamic>;
    final groupCounts = <String, int>{};
    for (final row in rows.cast<Map<String, dynamic>>()) {
      final group = row['question_group']?.toString() ?? '';
      if (!_groupMatchesGame(gameName, group)) continue;
      groupCounts[group] = int.tryParse(row['question_count'].toString()) ?? 0;
    }
    for (final row in localMode
        ? await _localQuestions(tableName)
        : const <Map<String, dynamic>>[]) {
      final localGroup = row['group']?.toString() ?? '';
      if (row['is_active'] != true ||
          (int.tryParse(row['level']?.toString() ?? '1') ?? 1) > level ||
          !_groupMatchesGame(gameName, localGroup)) {
        continue;
      }
      groupCounts[localGroup] = (groupCounts[localGroup] ?? 0) + 1;
    }
    final questionCount = groupCounts.values.fold<int>(
      0,
      (total, count) => total + count,
    );

    final requiresThree = normalizedName.contains('translation');
    if (!requiresThree) {
      return QuestionBankAvailability(
        questionCount: questionCount,
        canPlay: questionCount > 0,
        requiresThreeInGroup: false,
      );
    }

    return QuestionBankAvailability(
      questionCount: questionCount,
      canPlay: groupCounts.isNotEmpty &&
          groupCounts.values.every((count) => count >= 3),
      requiresThreeInGroup: true,
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
    final rows = localMode
        ? <dynamic>[]
        : await supabase.rpc(
            'get_my_questions_page',
            params: {
              'p_table_name': tableName,
              'p_game_name': gameName,
              'p_keyword': keyword.trim(),
              'p_group': group,
              'p_status': status,
              'p_offset': offset,
              'p_limit': limit,
            },
          ) as List<dynamic>;
    final questions = rows
        .cast<Map<String, dynamic>>()
        .map((row) => MyGameQuestion(
              id: row['id'].toString(),
              question: row['question']?.toString() ?? '',
              answer: row['answer']?.toString() ?? '',
              group: row['question_group']?.toString() ?? '',
              level: int.tryParse(row['level']?.toString() ?? '') ?? 1,
              isActive: row['is_active'] == true,
              options: row['options']?.toString(),
            ))
        .toList();
    final localRows = await _localQuestions(tableName);
    final normalizedKeyword = keyword.trim().toLowerCase();
    final matchingLocal = localRows
        .where((row) {
          final matchesGame = _groupMatchesGame(
            gameName,
            row['group']?.toString() ?? '',
          );
          final matchesKeyword = normalizedKeyword.isEmpty ||
              row['question']
                  .toString()
                  .toLowerCase()
                  .contains(normalizedKeyword) ||
              row['answer']
                  .toString()
                  .toLowerCase()
                  .contains(normalizedKeyword);
          final matchesGroup = group == null || row['group'] == group;
          final active = row['is_active'] == true;
          final matchesStatus = status == 'all' ||
              (status == 'active' && active) ||
              (status == 'inactive' && !active);
          return matchesGame && matchesKeyword && matchesGroup && matchesStatus;
        })
        .map((row) => MyGameQuestion(
              id: row[Fields.id].toString(),
              question: row['question']?.toString() ?? '',
              answer: row['answer']?.toString() ?? '',
              group: row['group']?.toString() ?? '',
              level: int.tryParse(row['level']?.toString() ?? '') ?? 1,
              isActive: row['is_active'] == true,
              options: row['options']?.toString(),
            ))
        .toList();
    final totalCount = localMode ? matchingLocal.length : questions.length;
    if (localMode) {
      questions.addAll(matchingLocal.skip(offset).take(limit));
    }
    return MyGameQuestionPage(
      questions: questions,
      totalCount: totalCount,
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
            params: {
              'p_table_name': _questionTableForGame(gameName),
            },
          ) as List<dynamic>;
    final groups = rows
        .map((row) =>
            (row as Map<String, dynamic>)['question_group']?.toString() ?? '')
        .where(
          (group) => group.isNotEmpty && _groupMatchesGame(gameName, group),
        )
        .toSet();
    if (localMode) {
      groups.addAll(
        (await _localQuestions(_questionTableForGame(gameName)))
            .map((row) => row['group']?.toString() ?? '')
            .where((group) =>
                group.isNotEmpty && _groupMatchesGame(gameName, group)),
      );
    }
    return groups.toList()..sort();
  }

  Future<List<String>> fetchMyQuestionGroups({
    required String gameName,
  }) async {
    if (supabase.auth.currentUser == null) {
      throw StateError('User must be signed in');
    }
    final rows = await supabase.rpc(
      'get_question_bank_groups',
      params: {
        'p_table_name': _questionTableForGame(gameName),
      },
    ) as List<dynamic>;
    final groups = rows
        .map((row) =>
            (row as Map<String, dynamic>)['question_group']
                ?.toString()
                .trim() ??
            '')
        .where(
            (group) => group.isNotEmpty && _groupMatchesGame(gameName, group))
        .toList()
      ..sort();
    return groups;
  }

  Future<GameQuestionHint?> fetchAdminQuestionHint({
    required String gameName,
    required String group,
  }) async {
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
      question: row['question']?.toString() ?? '',
      answer: row['answer']?.toString() ?? '',
    );
  }

  Future<void> deleteMyQuestion({
    required String gameName,
    required String questionId,
  }) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('User must be signed in');
    final tableName = _questionTableForGame(gameName);
    if (await LocalDataStore.instance.contains(
      owner: _ownerEmail,
      resource: tableName,
      id: questionId,
    )) {
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
          .eq('id', questionId)
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
    if (await LocalDataStore.instance.contains(
      owner: _ownerEmail,
      resource: tableName,
      id: questionId,
    )) {
      final rows = await _localQuestions(tableName);
      final row = rows.firstWhere((item) => item[Fields.id] == questionId);
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
        .eq('id', questionId)
        .eq('owner_id', userId)
        .select('id');
    if (updatedRows.isEmpty) {
      throw StateError('Question status was not updated');
    }
  }

  String _questionTableForGame(String gameName) {
    final normalizedName = gameName.toLowerCase();
    if (normalizedName == 'english rpg adventure') {
      return _grammarQuestionTable;
    }
    if (normalizedName == 'speaking' ||
        normalizedName == 'word and sentence builder') {
      return _sentenceQuestionTable;
    }
    return _translationQuestionTable;
  }

  bool _groupMatchesGame(String gameName, String group) {
    final normalizedName = gameName.toLowerCase();
    if (normalizedName == 'word searching') return group == '英翻中Word';
    if (gameName.contains('日')) return group.contains('日');
    if (gameName.contains('韓')) return group.contains('韓');
    if (normalizedName.contains('translation')) {
      return !group.contains('日') && !group.contains('韓');
    }
    return true;
  }

  Future<void> _insertQuestion(
    String tableName,
    Map<String, Object?> values,
  ) async {
    try {
      if (await _storesLocally) {
        if (await _hasLocalDuplicate(
          tableName: tableName,
          question: values['question']?.toString() ?? '',
          answer: values['answer']?.toString() ?? '',
          group: values['group']?.toString() ?? '',
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
      if (await LocalDataStore.instance.contains(
        owner: _ownerEmail,
        resource: tableName,
        id: id,
      )) {
        final rows = await _localQuestions(tableName);
        final row = rows.firstWhere((item) => item[Fields.id] == id);
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
          .eq('id', id)
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
      String userName, int level,
      {String questionBank = 'admin'}) async {
    if (questionBank == 'my') {
      final local = (await _localQuestions(_grammarQuestionTable))
          .where((row) =>
              row['is_active'] == true &&
              (int.tryParse(row['level']?.toString() ?? '1') ?? 1) <= level)
          .toList();
      if (local.isNotEmpty) {
        final data = local[Random.secure().nextInt(local.length)];
        return ModelGameGrammarQuestion(
          questionId: data[Fields.id].toString(),
          question: data['question']?.toString() ?? '',
          correctAnswer: data['answer']?.toString() ?? '',
          type: data['group']?.toString() ?? '',
          options: (data['options']?.toString() ?? '').split('_'),
        );
      }
    }
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
        options: (data['options'] ?? '').split('_'));
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
  Future<ModelGameSentence> fetchSentenceQuestion(String userName, int level,
      {String questionBank = 'admin'}) async {
    if (questionBank == 'my') {
      final local = (await _localQuestions(_sentenceQuestionTable))
          .where((row) =>
              row['is_active'] == true &&
              (int.tryParse(row['level']?.toString() ?? '1') ?? 1) <= level)
          .toList();
      if (local.isNotEmpty) {
        final data = local[Random.secure().nextInt(local.length)];
        final question = data['question']?.toString() ?? '';
        return ModelGameSentence(
          questionId: data[Fields.id].toString(),
          question: question,
          correctAnswer: data['answer']?.toString() ?? '',
          type: data['group']?.toString() ?? '',
          options: question.split('_'),
        );
      }
    }
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
        options: (data['question'] ?? '').split('_'));
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
  Future<ModelGameSpeaking> fetchSpeakingQuestion(String userName, int level,
      {String questionBank = 'admin'}) async {
    if (questionBank == 'my') {
      final local = (await _localQuestions(_sentenceQuestionTable))
          .where((row) =>
              row['is_active'] == true &&
              (int.tryParse(row['level']?.toString() ?? '1') ?? 1) <= level)
          .toList();
      if (local.isNotEmpty) {
        final data = local[Random.secure().nextInt(local.length)];
        return ModelGameSpeaking(
          questionId: data[Fields.id].toString(),
          question: data['question']?.toString() ?? '',
          correctAnswer: data['answer']?.toString() ?? '',
          type: data['group']?.toString() ?? '',
        );
      }
    }
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
  Future<ModelGameSocial> fetchSocialQuestion(String userName, int level,
      {String questionBank = 'admin'}) async {
    if (questionBank == 'my') {
      final local = (await _localQuestions(TableNames.gameSocialScenarios))
          .where((row) =>
              row['is_active'] == true &&
              (int.tryParse(row['level']?.toString() ?? '1') ?? 1) <= level)
          .toList();
      if (local.isNotEmpty) {
        final data = local[Random.secure().nextInt(local.length)];
        final choices = (data['choices'] as List? ?? const [])
            .map((raw) => Map<String, dynamic>.from(raw as Map))
            .toList()
          ..sort((a, b) => (int.tryParse(b['score'].toString()) ?? 0)
              .compareTo(int.tryParse(a['score'].toString()) ?? 0));
        if (choices.length >= 3) {
          final shuffled = choices.take(3).toList()..shuffle();
          return ModelGameSocial(
            id: data[Fields.id].toString(),
            scene: data['scene']?.toString() ?? '',
            correctAnswer: choices.first['option_text']?.toString() ?? '',
            options: shuffled
                .map((choice) => choice['option_text']?.toString() ?? '')
                .toList(),
            scores: shuffled
                .map((choice) => int.tryParse(choice['score'].toString()) ?? 0)
                .toList(),
          );
        }
      }
    }
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
      data['answer3']: data['score3']
    };
    List<String> options = [
      data['answer1'],
      data['answer2'],
      data['answer3'],
    ]..shuffle();
    List<int> scores = [
      tmpMap[options[0]],
      tmpMap[options[1]],
      tmpMap[options[2]]
    ];
    return ModelGameSocial(
        id: data[Fields.id],
        scene: data['scene'],
        correctAnswer: data['answer1'],
        options: options,
        scores: scores);
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
      String userName, int level,
      {String questionBank = 'admin'}) async {
    if (questionBank == 'my') {
      final local = (await _localQuestions(_translationQuestionTable))
          .where((row) =>
              row['is_active'] == true &&
              (int.tryParse(row['level']?.toString() ?? '1') ?? 1) <= level)
          .toList();
      if (local.length >= 3) {
        local.shuffle();
        final data = local.first;
        return ModelGameMarioTranslation(
          questionId: data[Fields.id].toString(),
          question: data['question']?.toString() ?? '',
          correctAnswer: data['answer']?.toString() ?? '',
          options: local
              .take(3)
              .map((row) => row['answer']?.toString() ?? '')
              .toList()
            ..shuffle(),
        );
      }
    }
    final result = await supabase.rpc(
      'get_translation_with_options',
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

    return ModelGameMarioTranslation(
        questionId: data[Fields.id],
        question: data['question'],
        correctAnswer: data['correct_answer'],
        options: [
          data['correct_answer'],
          data['wrong1'],
          data['wrong2'],
        ]..shuffle());
  }

  //------------------------- Translation -------------------------
  Future<ModelGameTranslation> fetchTranslationQuestion(
      String userName, int level, String gameName,
      {String questionBank = 'admin'}) async {
    if (questionBank == 'my') {
      final local = (await _localQuestions(_translationQuestionTable))
          .where((row) =>
              row['is_active'] == true &&
              (int.tryParse(row['level']?.toString() ?? '1') ?? 1) <= level &&
              _groupMatchesGame(gameName, row['group']?.toString() ?? ''))
          .toList();
      if (local.length >= 3) {
        local.shuffle();
        final data = local.first;
        return ModelGameTranslation(
          questionId: data[Fields.id].toString(),
          question: data['question']?.toString() ?? '',
          group: data['group']?.toString() ?? '',
          correctAnswer: data['answer']?.toString() ?? '',
          options: local
              .take(3)
              .map((row) => row['answer']?.toString() ?? '')
              .toList()
            ..shuffle(),
        );
      }
    }
    String functionName = 'get_translation_with_options';
    if (gameName.contains("日")) {
      functionName = 'get_translationjp_with_options';
    } else if (gameName.contains("韓")) {
      functionName = 'get_translationkr_with_options';
    }

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
        ]..shuffle());
  }

  Future<Set<String>> getSynonyms(String question) async {
    final response = await supabase
        .from(TableNames.gameTranslationSynonyms)
        .select('answer')
        .eq('question', question.toLowerCase());

    return response
        .map((row) => row['answer']?.toString().toLowerCase() ?? '')
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
      String userName, int level,
      {String questionBank = 'admin'}) async {
    if (questionBank == 'my') {
      final local = (await _localQuestions(_translationQuestionTable))
          .where((row) =>
              row['is_active'] == true &&
              (int.tryParse(row['level']?.toString() ?? '1') ?? 1) <= level &&
              _groupMatchesGame(
                  'Word Searching', row['group']?.toString() ?? ''))
          .toList();
      if (local.isNotEmpty) {
        final data = local[Random.secure().nextInt(local.length)];
        return ModelGameWordSearch(
          questionId: data[Fields.id].toString(),
          question: data['question']?.toString() ?? '',
          found: false,
        );
      }
    }
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
        questionId: data[Fields.id], question: data['question'], found: false);
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
