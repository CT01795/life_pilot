// ignore_for_file: deprecated_member_use

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/controller_game_list.dart';
import 'package:life_pilot/game/game_exit_guard.dart';
import 'package:life_pilot/game/page_game_question_create.dart';
import 'package:life_pilot/game/page_game_my_questions.dart';
import 'package:life_pilot/game/mario_translation/page_game_mario_translation.dart';
import 'package:life_pilot/game/social/page_game_social.dart';
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
    // 取得該遊戲所有關卡紀錄
    late final List<ModelGameUser> progress;
    try {
      progress = await controllerGameList.loadUserProgress(
        requestedCategory,
        requestedGameName,
      );
    } catch (error, stackTrace) {
      logger.e('Load game progress failed',
          error: error, stackTrace: stackTrace);
      if (mounted && requestId == _progressRequestId) {
        setState(() {});
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
      userProgress = progress;

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
        gameName == 'word and sentence builder' ||
        gameName == 'word searching' ||
        gameName.contains('translation');
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final loc = AppLocalizations.of(context)!;
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
                        child: Text(cat),
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
                        child: Text(gameName),
                      ))
                  .toList(),
            ),
            Gaps.h16,
            // 關卡選單
            DropdownButton<int>(
              isExpanded: true,
              value: selectedLevel,
              onChanged: (value) {
                if (value != null && value <= unlockedMaxLevel) {
                  setState(() {
                    selectedLevel = value;
                  });
                }
              },
              items: levelList?.map((g) {
                final locked = g.level > unlockedMaxLevel;
                return DropdownMenuItem<int>(
                  value: g.level,
                  enabled: !locked,
                  child: Text(
                    '${loc.gameLevel} ${g.level}${locked ? ' 🔒' : ''}',
                    style: TextStyle(
                      color: locked ? Colors.grey : Colors.black,
                    ),
                  ),
                );
              }).toList(),
            ),
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
              child: userProgress.isEmpty
                  ? Center(child: Text(loc.gameNoRecords))
                  : ListView.builder(
                      itemCount: userProgress.length,
                      itemBuilder: (context, index) {
                        final item = userProgress[index];
                        final formattedDate = item.createdAt != null
                            ? DateFormat(item.createdAt?.year == now.year
                                    ? 'MM/dd HH:mm'
                                    : 'yyyy/MM/dd HH:mm')
                                .format(item.createdAt!)
                            : '';
                        // 判斷第一筆，設定文字顏色
                        final textColor =
                            index == 0 ? Colors.blue.shade700 : Colors.black;
                        final textBold =
                            index == 0 ? FontWeight.bold : FontWeight.normal;
                        return ListTile(
                          title: Text(
                            '$formattedDate ${loc.gameLevel} ${item.level} '
                            '=> ${loc.gameScore}: ${item.score}',
                            style: TextStyle(
                                color: textColor, fontWeight: textBold),
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
