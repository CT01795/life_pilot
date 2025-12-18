import 'package:flutter/material.dart' hide DateUtils;
import 'package:intl/intl.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/game/controller_game_list.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/game/model_game_item.dart';
import 'package:life_pilot/models/game/model_game_user.dart';
import 'package:life_pilot/pages/game/page_game_grammar.dart';
import 'package:life_pilot/pages/game/page_game_puzzle_map.dart';
import 'package:life_pilot/pages/game/page_game_sentence.dart';
import 'package:life_pilot/pages/game/page_game_say_sentence.dart';
import 'package:life_pilot/pages/game/page_game_steam_kumon.dart';
import 'package:life_pilot/pages/game/page_game_steam_polyomino.dart';
import 'package:life_pilot/pages/game/steam_super_hero/page_game_steam_super_hero.dart';
import 'package:life_pilot/pages/game/page_game_word_match.dart';
import 'package:life_pilot/services/game/service_game.dart';
import 'package:provider/provider.dart';

import '../../core/logger.dart';

class PageGameList extends StatefulWidget {
  const PageGameList({
    super.key,
  });

  @override
  State<PageGameList> createState() => _PageGameListState();
}

class _PageGameListState extends State<PageGameList> {
  int unlockedMaxLevel = 1;  // 預設第 1 關
  // 範例遊戲類別與遊戲名稱
  late final ControllerGameList controllerGameList;
  String? selectedCategory;
  String? selectedGameName;
  int? selectedLevel;
  List<ModelGameUser> userProgress = [];

  @override
  void initState() {
    super.initState();
    final auth = context.read<ControllerAuth>();
    final serviceGame = ServiceGame();
    controllerGameList = ControllerGameList(
      serviceGame: serviceGame,
      userName: auth.currentAccount ?? AuthConstants.guest,
    );

    _loadData();
  }

  Future<void> _loadData() async {
    await controllerGameList.loadGames();
    if (controllerGameList.gamesByCategory.isNotEmpty) {
      selectedCategory = controllerGameList.gamesByCategory.keys.first;
      final gamesMap = controllerGameList.gamesByCategory[selectedCategory!]!;
      selectedGameName = gamesMap.keys.first;
      selectedLevel = gamesMap[selectedGameName]!.first.level;
      await _loadUserProgress();
    }
  }

  Future<void> _loadUserProgress() async {
    if (selectedCategory == null || selectedGameName == null) return;
    // 取得該遊戲所有關卡紀錄
    final progress = await controllerGameList.loadUserProgress(
      selectedCategory!,
      selectedGameName!,
    );
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

  ModelGameItem? get selectedGameItem {
    if (selectedCategory == null || selectedGameName == null || selectedLevel == null) return null;
    final gameMap = controllerGameList.gamesByCategory[selectedCategory!];
    if (gameMap == null) return null;
    final levelList = gameMap[selectedGameName!];
    if (levelList == null) return null;
    return levelList.firstWhere((g) => g.level == selectedLevel, orElse: () => levelList.first);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    if (controllerGameList.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final gameMap = selectedCategory != null
        ? controllerGameList.gamesByCategory[selectedCategory!]
        : null;
    final levelList = selectedGameName != null
        ? gameMap![selectedGameName!]
        : null;
        
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
                    final gamesMap = controllerGameList.gamesByCategory[selectedCategory!]!;
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
                    final levelList = controllerGameList
                        .gamesByCategory[selectedCategory!]![selectedGameName!]!;
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
                    'Level ${g.level}${locked ? ' 🔒' : ''}',
                    style: TextStyle(
                      color: locked ? Colors.grey : Colors.black,
                    ),
                  ),
                );
              }).toList(),
            ),
            Gaps.h16,
            ElevatedButton(
              onPressed: (selectedGameItem != null && selectedLevel! <= unlockedMaxLevel)
                ? () async {
                    final game = selectedGameItem!;
                    if (game.gameName.toLowerCase() == "translation".toLowerCase()) {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PageGameWordMatch(gameId: game.id),
                        ),
                      );
                      if (result == true) {
                        await _loadUserProgress();
                      }
                    } else if (game.gameName.toLowerCase() == "scratch".toLowerCase()) {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PageGameSteamSuperHero(gameId: game.id, gameLevel: game.level),
                        ),
                      );
                      if (result == true) {
                        await _loadUserProgress();
                      }
                    } else if (game.gameName.toLowerCase() == "monomino".toLowerCase()) {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PageGameSteamKumon(gameId: game.id, gameLevel: game.level),
                        ),
                      );
                      if (result == true) {
                        await _loadUserProgress();
                      } 
                    } else if (game.gameName.toLowerCase() == "polyomino".toLowerCase()) {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PageGameSteamPolyomino(gameId: game.id, gameLevel: game.level),
                        ),
                      );
                      if (result == true) {
                        await _loadUserProgress();
                      } //Polyomino
                    } else if (game.gameName.toLowerCase() == "word and sentence builder".toLowerCase()) {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PageGameSentence(gameId: game.id),
                        ),
                      );
                      if (result == true) {
                        await _loadUserProgress();
                      } 
                    } else if (game.gameName.toLowerCase() == "speaking".toLowerCase()) {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PageGameSaySentence(gameId: game.id),
                        ),
                      );
                      if (result == true) {
                        await _loadUserProgress();
                      } 
                    } else if (game.gameName.toLowerCase() == "puzzle map".toLowerCase()) {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PageGamePuzzleMap(gameId: game.id, gameLevel: game.level,),
                        ),
                      );
                      if (result == true) {
                        await _loadUserProgress();
                      } 
                    } else if (game.gameName.toLowerCase() == "english rpg adventure".toLowerCase()) {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PageGameGrammar(gameId: game.id),
                        ),
                      );
                      if (result == true) {
                        await _loadUserProgress();
                      } 
                    }  else { 
                      // 其他遊戲開啟方式
                      logger.i("尚未實作此遊戲頁面");
                    }
                  }
                : null,
            child: const Text('Start'),
            ),
            const Divider(),
            Expanded(
              child: userProgress.isEmpty
                  ? const Center(child: Text('No data'))
                  : ListView.builder(
                      itemCount: userProgress.length,
                      itemBuilder: (context, index) {
                        final item = userProgress[index];
                        final formattedDate = item.createdAt != null
                            ? DateFormat(item.createdAt?.year == now.year ? 'MM/dd HH:mm' : 'yyyy/MM/dd HH:mm')
                                    .format(item.createdAt!)
                            : constEmpty;
                        // 判斷第一筆，設定文字顏色
                        final textColor = index == 0 ? Colors.blue.shade700 : Colors.black;
                        final textBold = index == 0 ? FontWeight.bold : FontWeight.normal;
                        return ListTile(
                          title: Text(
                            '$formattedDate Level ${item.level} => Score: ${item.score}',
                            style: TextStyle(color: textColor, fontWeight: textBold),
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
