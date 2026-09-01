// ignore_for_file: deprecated_member_use

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/controller_game_list.dart';
import 'package:life_pilot/game/game_question_bank_visibility.dart';
import 'package:life_pilot/game/game_exit_guard.dart';
import 'package:life_pilot/game/page_game_question_create.dart';
import 'package:life_pilot/game/page_game_my_questions.dart';
import 'package:life_pilot/game/mario_translation/page_game_mario_translation.dart';
import 'package:life_pilot/game/social/page_game_social.dart';
import 'package:life_pilot/game/social/page_game_social_question_create.dart';
import 'package:life_pilot/game/social/page_game_social_questions.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/game/model_game_item.dart';
import 'package:life_pilot/game/model_game_user.dart';
import 'package:life_pilot/game/grammar/page_game_grammar.dart';
import 'package:life_pilot/game/puzzle_map/page_game_puzzle_map.dart';
import 'package:life_pilot/game/sentence/page_game_sentence.dart';
import 'package:life_pilot/game/speaking/page_game_speaking.dart';
import 'package:life_pilot/game/steam_monomino/page_game_steam_monomino.dart';
import 'package:life_pilot/game/steam_polyomino/page_game_steam_polyomino.dart';
import 'package:life_pilot/game/word_search/page_game_word_search.dart';
import 'package:life_pilot/game/steam_scratch/page_game_steam_scratch.dart';
import 'package:life_pilot/game/translation/page_game_translation.dart';
import 'package:life_pilot/game/steam_scratch_maze/page_game_steam_scratch_maze.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/app_navigator.dart';
import 'package:provider/provider.dart';

import '../utils/logger.dart';

class PageGameList extends StatefulWidget {
  const PageGameList({
    super.key,
  });

  @override
  State<PageGameList> createState() => _PageGameListState();
}

class _PageGameListState extends State<PageGameList> {
  int unlockedMaxLevel = 1; // 預設第 1 關
  // 範例遊戲類別與遊戲名稱
  late final ControllerGameList controllerGameList;
  final ServiceGame _serviceGame = ServiceGame();
  String? selectedCategory;
  String? selectedGameName;
  int? selectedLevel;
  String selectedQuestionBank = 'admin';
  List<ModelGameUser> userProgress = [];
  int _progressRequestId = 0;
  bool _hasLoadError = false;
  bool _isOpeningGame = false;
  bool _isLoadingProgress = false;
  bool _isLoadingMoreProgress = false;
  bool _hasMoreProgress = false;
  DateTime? _progressStartDate;
  late final bool _isQuestionBankAdmin;

  String get _effectiveQuestionBank =>
      _isQuestionBankAdmin && selectedQuestionBank == 'mine'
          ? 'admin'
          : selectedQuestionBank;

  @override
  void initState() {
    super.initState();
    final auth = context.read<ControllerAuth>();
    final currentAccount = auth.currentAccount ?? AuthConstants.guest;
    _isQuestionBankAdmin = currentAccount.trim().toLowerCase() ==
        AuthConstants.systemEventOwnerEmail.toLowerCase();
    controllerGameList = ControllerGameList(
      serviceGame: _serviceGame,
      userName: currentAccount,
    );

    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _hasLoadError = false);
    try {
      await controllerGameList.loadGames();
      if (!mounted) return;
      if (controllerGameList.gamesByCategory.isNotEmpty) {
        setState(() {
          selectedCategory = controllerGameList.gamesByCategory.keys.first;
          final gamesMap =
              controllerGameList.gamesByCategory[selectedCategory!]!;
          selectedGameName = gamesMap.keys.first;
          selectedLevel = gamesMap[selectedGameName]!.first.level;
        });
        await _loadUserProgress();
      } else {
        setState(() {});
      }
    } catch (error, stackTrace) {
      logger.e('Load games failed', error: error, stackTrace: stackTrace);
      if (mounted) setState(() => _hasLoadError = true);
    }
  }

  Future<void> _loadUserProgress() async {
    if (selectedCategory == null || selectedGameName == null) return;
    final requestId = ++_progressRequestId;
    final requestedCategory = selectedCategory!;
    final requestedGameName = selectedGameName!;
    if (mounted) setState(() => _isLoadingProgress = true);
    // 取得該遊戲所有關卡紀錄
    late final List<ModelGameUser> progress;
    late final List<ModelGameUser> displayProgress;
    late DateTime startDate;
    late final bool hasMore;
    try {
      progress = await controllerGameList.loadUserProgress(
        requestedCategory,
        requestedGameName,
      );
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      startDate = today.subtract(const Duration(days: 29));
      displayProgress = await _serviceGame.fetchUserProgressPage(
        userName: controllerGameList.userName,
        gameType: requestedCategory,
        gameName: requestedGameName,
        dateFrom: startDate,
        dateTo: today,
        includeLatestFallback: true,
      );
      final fallbackDates = displayProgress
          .map((item) => item.createdAt)
          .whereType<DateTime>()
          .where((date) => date.isBefore(startDate))
          .toList();
      if (displayProgress.isNotEmpty &&
          fallbackDates.length == displayProgress.length) {
        startDate = fallbackDates.reduce((a, b) => a.isAfter(b) ? a : b);
      }
      hasMore = await _serviceGame.hasUserProgressBefore(
        userName: controllerGameList.userName,
        gameType: requestedCategory,
        gameName: requestedGameName,
        before: startDate,
      );
    } catch (error, stackTrace) {
      logger.e('Load game progress failed',
          error: error, stackTrace: stackTrace);
      if (mounted && requestId == _progressRequestId) {
        setState(() => _isLoadingProgress = false);
        AppNavigator.showErrorBar(
          AppLocalizations.of(context)!.unknownError,
        );
      }
      return;
    }
    if (!mounted || requestId != _progressRequestId) return;
    if (selectedCategory != requestedCategory ||
        selectedGameName != requestedGameName) {
      return;
    }
    setState(() {
      _isLoadingProgress = false;
      _progressStartDate = startDate;
      _hasMoreProgress = hasMore;
      userProgress = displayProgress;

      // 取得最高通關 level
      unlockedMaxLevel = controllerGameList.getHighestPassedLevel(progress) + 1;
      // 將選單預設值設為最大可進入關卡
      selectedLevel = unlockedMaxLevel;
      // 如果 unlockedMaxLevel 超過關卡列表最大值，則選最後一關
      final levelList = controllerGameList
          .gamesByCategory[selectedCategory!]![selectedGameName!]!;
      if (selectedLevel! > levelList.last.level) {
        selectedLevel = levelList.last.level;
      }
    });
  }

  Future<void> _loadMoreProgress() async {
    if (_isLoadingMoreProgress ||
        !_hasMoreProgress ||
        _progressStartDate == null ||
        selectedCategory == null ||
        selectedGameName == null) {
      return;
    }
    setState(() => _isLoadingMoreProgress = true);
    try {
      final latestOlder = await _serviceGame.latestUserProgressDateBefore(
        userName: controllerGameList.userName,
        gameType: selectedCategory!,
        gameName: selectedGameName!,
        before: _progressStartDate!,
      );
      if (!mounted) return;
      if (latestOlder == null) {
        setState(() => _hasMoreProgress = false);
        return;
      }
      final dateTo = DateTime(
        latestOlder.year,
        latestOlder.month,
        latestOlder.day,
      );
      final dateFrom = dateTo.subtract(const Duration(days: 29));
      final older = await _serviceGame.fetchUserProgressPage(
        userName: controllerGameList.userName,
        gameType: selectedCategory!,
        gameName: selectedGameName!,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      final hasMore = await _serviceGame.hasUserProgressBefore(
        userName: controllerGameList.userName,
        gameType: selectedCategory!,
        gameName: selectedGameName!,
        before: dateFrom,
      );
      if (!mounted) return;
      final unique = <String, ModelGameUser>{};
      for (final item in [...userProgress, ...older]) {
        unique[item.id ?? ''] = item;
      }
      setState(() {
        _progressStartDate = dateFrom;
        _hasMoreProgress = hasMore;
        userProgress = unique.values.toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0))
              .compareTo(a.createdAt ?? DateTime(0)));
      });
    } finally {
      if (mounted) setState(() => _isLoadingMoreProgress = false);
    }
  }

  @override
  void dispose() {
    _progressRequestId++;
    controllerGameList.dispose();
    super.dispose();
  }

  ModelGameItem? get selectedGameItem {
    if (selectedCategory == null ||
        selectedGameName == null ||
        selectedLevel == null) {
      return null;
    }
    final gameMap = controllerGameList.gamesByCategory[selectedCategory!];
    if (gameMap == null) return null;
    final levelList = gameMap[selectedGameName!];
    if (levelList == null) return null;
    return levelList.firstWhere((g) => g.level == selectedLevel,
        orElse: () => levelList.first);
  }

  bool get _supportsQuestionBank {
    final gameName = selectedGameName?.toLowerCase() ?? '';
    return gameName == 'mario translation' ||
        gameName == 'english rpg adventure' ||
        gameName == 'speaking' ||
        gameName == 'social' ||
        gameName == 'word and sentence builder' ||
        gameName == 'word searching' ||
        gameName.contains('translation');
  }

  bool get _supportsQuestionManagement =>
      (selectedGameName?.toLowerCase() ?? '') != 'social';

  bool get _isSocialGame => (selectedGameName?.toLowerCase() ?? '') == 'social';

  bool get _showQuestionManagementActions =>
      GameQuestionBankVisibility.showManagementActions(
        isAdmin: _isQuestionBankAdmin,
        selectedQuestionBank: selectedQuestionBank,
      );

  Future<void> _showCreateGameLevel() async {
    if (!_isQuestionBankAdmin ||
        selectedCategory == null ||
        selectedGameName == null) {
      return;
    }
    final loc = AppLocalizations.of(context)!;
    final gameType = selectedCategory!;
    final gameName = selectedGameName!;
    final levels = controllerGameList.gamesByCategory[gameType]![gameName]!;
    final currentMaxLevel = levels.map((item) => item.level).reduce(
          (current, value) => current > value ? current : value,
        );
    final nextLevel = currentMaxLevel + 1;
    final controller = TextEditingController(text: '$nextLevel');
    String? errorText;
    var saving = false;
    final created = await showDialog<bool>(
          context: context,
          barrierDismissible: !saving,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: Text('${loc.add} ${loc.gameLevel}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$gameType · $gameName'),
                  Text('${loc.gameLevel}: $currentMaxLevel →'),
                  Gaps.h16,
                  TextField(
                    controller: controller,
                    autofocus: true,
                    enabled: !saving,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: loc.gameLevel,
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      saving ? null : () => Navigator.pop(dialogContext, false),
                  child: Text(loc.cancel),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final level = int.tryParse(controller.text);
                          if (level == null ||
                              level <= currentMaxLevel ||
                              level > 999) {
                            setDialogState(
                              () => errorText = '${currentMaxLevel + 1}–999',
                            );
                            return;
                          }
                          setDialogState(() {
                            saving = true;
                            errorText = null;
                          });
                          try {
                            await _serviceGame.createGameLevel(
                              gameType: gameType,
                              gameName: gameName,
                              level: level,
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext, true);
                            }
                          } on DuplicateGameLevelException {
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                saving = false;
                                errorText = '${currentMaxLevel + 1}–999';
                              });
                            }
                          } catch (error, stackTrace) {
                            logger.e('Create game level failed',
                                error: error, stackTrace: stackTrace);
                            if (dialogContext.mounted) {
                              setDialogState(() {
                                saving = false;
                                errorText = loc.unknownError;
                              });
                            }
                          }
                        },
                  child: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(loc.save),
                ),
              ],
            ),
          ),
        ) ??
        false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    if (created && mounted) {
      await controllerGameList.loadGames();
      if (!mounted) return;
      setState(() {
        selectedCategory = gameType;
        selectedGameName = gameName;
        selectedLevel = controllerGameList
            .gamesByCategory[gameType]![gameName]!.first.level;
      });
      await _loadUserProgress();
    }
  }

  Future<int?> _showLevelPicker(
    List<ModelGameItem> levels,
    int? currentLevel,
    int unlockedMaxLevel,
  ) async {
    final loc = AppLocalizations.of(context)!;
    final selectedIndex = levels.indexWhere(
      (item) => item.level == currentLevel,
    );
    final scrollController = ScrollController(
      initialScrollOffset: (selectedIndex < 0 ? 0 : selectedIndex) * 56.0,
    );
    try {
      return await showModalBottomSheet<int>(
        context: context,
        showDragHandle: true,
        builder: (context) => FractionallySizedBox(
          heightFactor: 0.75,
          child: Column(
            children: [
              Text(
                loc.gameLevel,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Gaps.h8,
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemExtent: 56,
                  itemCount: levels.length,
                  itemBuilder: (context, index) {
                    final level = levels[index].level;
                    final locked = level > unlockedMaxLevel;
                    return ListTile(
                      enabled: !locked,
                      title: Text('${loc.gameLevel} $level'),
                      trailing: locked
                          ? const Icon(Icons.lock_outline)
                          : level == currentLevel
                              ? const Icon(Icons.check)
                              : null,
                      onTap:
                          locked ? null : () => Navigator.pop(context, level),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      scrollController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final localeName = Localizations.localeOf(context).toString();
    final currentYearDateFormat = DateFormat('MM/dd HH:mm', localeName);
    final previousYearDateFormat = DateFormat('yyyy/MM/dd HH:mm', localeName);
    if (controllerGameList.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_hasLoadError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(loc.unknownError),
              Gaps.h8,
              ElevatedButton(
                onPressed: _loadData,
                child: Text(loc.retry),
              ),
            ],
          ),
        ),
      );
    }

    final gameMap = selectedCategory != null
        ? controllerGameList.gamesByCategory[selectedCategory!]
        : null;
    final levelList =
        selectedGameName != null ? gameMap![selectedGameName!] : null;

    return Scaffold(
      body: Padding(
        padding: Insets.all8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 遊戲類別下拉選單
            DropdownButton<String>(
              isExpanded: true,
              value: selectedCategory,
              onChanged: (value) async {
                if (value != null) {
                  setState(() {
                    selectedCategory = value;
                    final gamesMap =
                        controllerGameList.gamesByCategory[selectedCategory!]!;
                    selectedGameName = gamesMap.keys.first;
                    selectedLevel = gamesMap[selectedGameName!]!.first.level;
                  });
                  await _loadUserProgress();
                }
              },
              items: controllerGameList.gamesByCategory.keys
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(
                          cat,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
            ),
            Gaps.h16,
            // 遊戲名稱
            DropdownButton<String>(
              isExpanded: true,
              value: selectedGameName,
              onChanged: (value) async {
                if (value != null && selectedCategory != null) {
                  setState(() {
                    selectedGameName = value;
                    final levelList = controllerGameList.gamesByCategory[
                        selectedCategory!]![selectedGameName!]!;
                    selectedLevel = levelList.first.level;
                  });
                  await _loadUserProgress();
                }
              },
              items: gameMap?.keys
                  .map((gameName) => DropdownMenuItem(
                        value: gameName,
                        child: Text(
                          gameName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
            ),
            Gaps.h16,
            // 關卡選單
            OutlinedButton(
              onPressed: levelList == null
                  ? null
                  : () async {
                      final value = await _showLevelPicker(
                        levelList,
                        selectedLevel,
                        unlockedMaxLevel,
                      );
                      if (value != null && mounted) {
                        setState(() => selectedLevel = value);
                      }
                    },
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${loc.gameLevel} ${selectedLevel ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
            if (_isQuestionBankAdmin) ...[
              Gaps.h8,
              OutlinedButton.icon(
                onPressed: _showCreateGameLevel,
                icon: const Icon(Icons.add),
                label: Text('${loc.add} ${loc.gameLevel}'),
              ),
            ],
            Gaps.h16,
            if (_supportsQuestionBank) ...[
              DropdownButtonFormField<String>(
                key: ValueKey(selectedQuestionBank),
                initialValue: selectedQuestionBank,
                decoration: InputDecoration(
                  labelText: loc.questionBank,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text(loc.adminQuestionBank),
                  ),
                  DropdownMenuItem(
                    value: 'mine',
                    child: Text(loc.myQuestionBank),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedQuestionBank = value);
                  }
                },
              ),
              Gaps.h8,
              if (_isSocialGame && _showQuestionManagementActions)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(loc.addQuestion),
                        onPressed: () async {
                          final added = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const PageGameSocialQuestionCreate(),
                            ),
                          );
                          if (mounted && added == true) {
                            setState(() => selectedQuestionBank = 'mine');
                          }
                        },
                      ),
                    ),
                    Gaps.w8,
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.list_alt),
                        label: Text(loc.myQuestions),
                        onPressed: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PageGameSocialQuestions(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              if (_supportsQuestionManagement && _showQuestionManagementActions)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(loc.addQuestion),
                        onPressed:
                            selectedGameName == null || selectedLevel == null
                                ? null
                                : () async {
                                    final added = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PageGameQuestionCreate(
                                          gameName: selectedGameName!,
                                          initialLevel: selectedLevel!,
                                        ),
                                      ),
                                    );
                                    if (mounted && added == true) {
                                      setState(
                                        () => selectedQuestionBank = 'mine',
                                      );
                                    }
                                  },
                      ),
                    ),
                    Gaps.w8,
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.list_alt),
                        label: Text(loc.myQuestions),
                        onPressed: selectedGameName == null
                            ? null
                            : () => Navigator.push<void>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PageGameMyQuestions(
                                      gameName: selectedGameName!,
                                      initialLevel: selectedLevel ?? 1,
                                    ),
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
              Gaps.h16,
            ],
            ElevatedButton(
              onPressed: (!_isOpeningGame &&
                      selectedGameItem != null &&
                      selectedLevel! <= unlockedMaxLevel)
                  ? () async {
                      setState(() => _isOpeningGame = true);
                      final game = selectedGameItem!;
                      if (_effectiveQuestionBank == 'mine' &&
                          _supportsQuestionBank) {
                        try {
                          final availability =
                              await _serviceGame.getMyQuestionBankAvailability(
                            gameName: game.gameName,
                            level: game.level,
                          );
                          if (!availability.canPlay) {
                            if (mounted) {
                              AppNavigator.showErrorBar(
                                availability.requiresThreeInGroup
                                    ? loc.threeQuestionsRequired
                                    : loc.myQuestionBankEmpty,
                              );
                              setState(() => _isOpeningGame = false);
                            }
                            return;
                          }
                        } catch (error, stackTrace) {
                          logger.e('Check question bank availability failed',
                              error: error, stackTrace: stackTrace);
                          if (mounted) {
                            AppNavigator.showErrorBar(loc.unknownError);
                            setState(() => _isOpeningGame = false);
                          }
                          return;
                        }
                      }
                      if (game.gameName.toLowerCase() ==
                          "social".toLowerCase()) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameExitGuard(
                              child: PageGameSocial(
                                gameId: game.id,
                                gameLevel: game.level,
                                questionBank: _effectiveQuestionBank,
                              ),
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadUserProgress();
                        }
                      } else if (game.gameName.toLowerCase() ==
                          "mario translation".toLowerCase()) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) {
                              // 先建立遊戲實例
                              final game1 = PageGameMarioTranslation(
                                context: context,
                                gameId: game.id,
                                gameLevel: game.level,
                                questionBank: _effectiveQuestionBank,
                              );

                              return GameExitGuard(
                                child: Scaffold(
                                  body: Stack(
                                    children: [
                                      GameWidget(
                                        game: game1,
                                        loadingBuilder: (context) =>
                                            const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorBuilder: (context, error) =>
                                            Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(loc.unknownError),
                                              Gaps.h8,
                                              ElevatedButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: Text(loc.back),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 8,
                                        left: 8,
                                        child: SafeArea(
                                          child: Material(
                                            color: Colors.black54,
                                            shape: const CircleBorder(),
                                            child: IconButton(
                                              tooltip: loc.back,
                                              icon: const Icon(
                                                Icons.arrow_back,
                                                color: Colors.white,
                                              ),
                                              onPressed: () =>
                                                  Navigator.maybePop(context),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 20,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center, // 水平置中
                                          children: [
                                            GestureDetector(
                                              onTapDown: (_) {
                                                if (game1.isLoaded) {
                                                  game1.player.moveLeft(true);
                                                }
                                              },
                                              onTapUp: (_) {
                                                if (game1.isLoaded) {
                                                  game1.player.moveLeft(false);
                                                }
                                              },
                                              child: Container(
                                                width: 60,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  color: GameColors.buttonBase,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: Colors.white12),
                                                ),
                                                child: Icon(
                                                    Icons.arrow_back_rounded,
                                                    color: Colors.white70,
                                                    size: 60),
                                              ),
                                            ),
                                            Gaps.w16,
                                            GestureDetector(
                                              onTapDown: (_) {
                                                if (game1.isLoaded) {
                                                  game1.player.moveRight(true);
                                                }
                                              },
                                              onTapUp: (_) {
                                                if (game1.isLoaded) {
                                                  game1.player.moveRight(false);
                                                }
                                              },
                                              child: Container(
                                                width: 60,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  color: GameColors.buttonBase,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: Colors.white12),
                                                ),
                                                child: Icon(
                                                    Icons.arrow_forward_rounded,
                                                    color: Colors.white70,
                                                    size: 60),
                                              ),
                                            ),
                                            Gaps.w16,
                                            GestureDetector(
                                              onTap: () {
                                                if (game1.isLoaded) {
                                                  game1.player.jump();
                                                }
                                              },
                                              child: Container(
                                                width: 60,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  color:
                                                      GameColors.buttonAccent,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: Colors.white12),
                                                ),
                                                child: Icon(
                                                  Icons.arrow_upward_rounded,
                                                  color: Colors.white70,
                                                  size: 60,
                                                ),
                                              ),
                                            ),
                                            Gaps.w16,
                                            GestureDetector(
                                              onTap: () async {
                                                if (game1.isLoaded) {
                                                  await game1.shoot();
                                                }
                                              },
                                              child: Container(
                                                width: 60,
                                                height: 60,
                                                decoration: BoxDecoration(
                                                  color: Color(0xFFC94B4B),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                      color: Colors.white12),
                                                ),
                                                child: Icon(Icons.circle,
                                                    color: Colors.white70),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                        if (result == true) {
                          await _loadUserProgress();
                        }
                      } else if (game.gameName.toLowerCase() ==
                          "scratch".toLowerCase()) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameExitGuard(
                              child: PageGameSteamScratch(
                                  gameId: game.id, gameLevel: game.level),
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadUserProgress();
                        }
                      } else if (game.gameName.toLowerCase() ==
                          "scratch (maze)".toLowerCase()) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameExitGuard(
                              child: PageGameSteamScratchMaze(
                                  gameId: game.id, gameLevel: game.level),
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadUserProgress();
                        }
                      } else if (game.gameName.toLowerCase() ==
                          "monomino".toLowerCase()) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameExitGuard(
                              child: PageGameSteamMonomino(
                                  gameId: game.id, gameLevel: game.level),
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadUserProgress();
                        }
                      } else if (game.gameName.toLowerCase() ==
                          "polyomino".toLowerCase()) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameExitGuard(
                              child: PageGameSteamPolyomino(
                                  gameId: game.id, gameLevel: game.level),
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadUserProgress();
                        } //Polyomino
                      } else if (game.gameName.toLowerCase() ==
                          "word and sentence builder".toLowerCase()) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameExitGuard(
                              child: PageGameSentence(
                                gameId: game.id,
                                gameLevel: game.level,
                                questionBank: _effectiveQuestionBank,
                              ),
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadUserProgress();
                        }
                      } else if (game.gameName.toLowerCase() ==
                          "speaking".toLowerCase()) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameExitGuard(
                              child: PageGameSpeaking(
                                gameId: game.id,
                                gameLevel: game.level,
                                questionBank: _effectiveQuestionBank,
                              ),
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadUserProgress();
                        }
                      } else if (game.gameName.toLowerCase() ==
                          "puzzle map".toLowerCase()) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameExitGuard(
                              child: PageGamePuzzleMap(
                                gameId: game.id,
                                gameLevel: game.level,
                              ),
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadUserProgress();
                        }
                      } else if (game.gameName.toLowerCase() ==
                          "english rpg adventure".toLowerCase()) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameExitGuard(
                              child: PageGameGrammar(
                                gameId: game.id,
                                gameLevel: game.level,
                                questionBank: _effectiveQuestionBank,
                              ),
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadUserProgress();
                        }
                      } else if (game.gameName.toLowerCase() ==
                          "word searching".toLowerCase()) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameExitGuard(
                              child: PageGameWordSearch(
                                gameId: game.id,
                                gameLevel: game.level,
                                questionBank: _effectiveQuestionBank,
                              ),
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadUserProgress();
                        }
                      } else if (game.gameName
                          .toLowerCase()
                          .contains("translation".toLowerCase())) {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GameExitGuard(
                              child: PageGameTranslation(
                                gameId: game.id,
                                gameLevel: game.level,
                                gameName: game.gameName,
                                questionBank: _effectiveQuestionBank,
                              ),
                            ),
                          ),
                        );
                        if (result == true) {
                          await _loadUserProgress();
                        }
                      } else {
                        // 其他遊戲開啟方式
                        logger.i("尚未實作此遊戲頁面");
                      }
                      if (mounted) {
                        setState(() => _isOpeningGame = false);
                      }
                    }
                  : null,
              child: _isOpeningGame
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(loc.gameStart),
            ),
            const Divider(),
            Expanded(
              child: _isLoadingProgress
                  ? const Center(child: CircularProgressIndicator())
                  : userProgress.isEmpty
                      ? Center(child: Text(loc.gameNoRecords))
                      : ListView.builder(
                          cacheExtent: 240,
                          addAutomaticKeepAlives: false,
                          itemCount: userProgress.length +
                              ((_hasMoreProgress || _isLoadingMoreProgress)
                                  ? 1
                                  : 0),
                          itemBuilder: (context, index) {
                            if (index == userProgress.length) {
                              return Center(
                                child: _isLoadingMoreProgress
                                    ? const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(),
                                      )
                                    : TextButton(
                                        onPressed: _loadMoreProgress,
                                        child: Text(loc.clickHereToSeeMore),
                                      ),
                              );
                            }
                            final item = userProgress[index];
                            final formattedDate = item.createdAt != null
                                ? (item.createdAt!.year == now.year
                                        ? currentYearDateFormat
                                        : previousYearDateFormat)
                                    .format(item.createdAt!)
                                : '';
                            // 判斷第一筆，設定文字顏色
                            final textColor = index == 0
                                ? colorScheme.primary
                                : colorScheme.onSurface;
                            final textBold = index == 0
                                ? FontWeight.bold
                                : FontWeight.normal;
                            return ListTile(
                              leading: index == 0
                                  ? Icon(
                                      Icons.emoji_events_outlined,
                                      color: colorScheme.primary,
                                    )
                                  : null,
                              title: Text(
                                formattedDate,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: textBold,
                                ),
                              ),
                              subtitle: Text(
                                '${loc.gameLevel} ${item.level}  '
                                '${loc.gameScore}: ${item.score}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
