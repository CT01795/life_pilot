import 'package:flutter/material.dart' hide DateUtils;
import 'package:life_pilot/controllers/game/controller_game_list.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/game/model_game_item.dart';

class PageGameList extends StatefulWidget {
  const PageGameList({
    super.key,
  });

  @override
  State<PageGameList> createState() => _PageGameListState();
}

class _PageGameListState extends State<PageGameList> {
  // 範例遊戲類別與遊戲名稱
  late final ControllerGameList controllerGameList;
  late final List<String> gameCategories;
  late final Map<String, List<GameItem>> gamesByCategory;

  String? selectedCategory;
  String? selectedGameId; // 用 id 存值
  bool isLoading = true; // 是否還在讀取資料

  @override
  void initState() {
    super.initState();
    controllerGameList = ControllerGameList();
    _loadGames();
  }

  Future<void> _loadGames() async {
    setState(() {
      isLoading = true;
    });
    await controllerGameList.loadGames();

    // 載入完成後，取資料更新本地狀態
    gameCategories = controllerGameList.gameCategories;
    gamesByCategory = controllerGameList.gamesByCategory;
    selectedCategory = gameCategories.isNotEmpty ? gameCategories.first : null;
    selectedGameId = selectedCategory != null &&
            gamesByCategory[selectedCategory!]!.isNotEmpty
        ? gamesByCategory[selectedCategory!]!.first.id
        : null;
    setState(() {
      isLoading = false;
    });
  }

  GameItem? get selectedGameItem {
    if (selectedCategory == null || selectedGameId == null) return null;
    return gamesByCategory[selectedCategory!]!
        .firstWhere((g) => g.id == selectedGameId);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: Padding(
        padding: Insets.all2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 遊戲類別下拉選單
            DropdownButton<String>(
              isExpanded: true,
              value: selectedCategory,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedCategory = value;
                    // 類別變更時，遊戲名稱自動更新
                    selectedGameId =
                        gamesByCategory[selectedCategory!]!.first.id;
                  });
                }
              },
              items: gameCategories
                  .map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ))
                  .toList(),
            ),
            Gaps.h16,
            // 遊戲名稱下拉選單
            DropdownButton<String>(
              isExpanded: true,
              value: selectedGameId,
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedGameId = value;
                  });
                }
              },
              items: selectedCategory != null
                  ? gamesByCategory[selectedCategory!]!
                      .map((game) => DropdownMenuItem(
                            value: game.id, // 選中的值是 id
                            child: Text(game.gameName), // 顯示名稱
                          ))
                      .toList()
                  : [],
            ),
            Gaps.h16,
            ElevatedButton(
              onPressed: selectedGameItem != null
                  ? () {
                      // 開始遊戲時可使用 selectedGameItem.id 或 gameName
                      print('Start game: ${selectedGameItem!.gameName}');
                    }
                  : null,
              child: const Text('Start'),
            ),
            Gaps.h16,
          ],
        ),
      ),
    );
  }
}
