import 'package:flutter/material.dart';
import 'package:life_pilot/game/steam_scratch_maze/controller_game_steam_scratch_maze.dart';
import 'package:life_pilot/game/steam_scratch_maze/blockly_parser.dart';
import 'package:life_pilot/game/model_blockly_message_queue.dart';
import 'package:life_pilot/game/widgets_blockly_web_editor.dart';

class PageGameSteamScratchMazeBlocklyEditor extends StatefulWidget {
  final Function(List<Command>) onCommandsReady;
  const PageGameSteamScratchMazeBlocklyEditor({
    super.key,
    required this.onCommandsReady,
  });
  @override
  State<PageGameSteamScratchMazeBlocklyEditor> createState() =>
      PageGameSteamScratchMazeBlocklyEditorState();
}

class PageGameSteamScratchMazeBlocklyEditorState
    extends State<PageGameSteamScratchMazeBlocklyEditor> {
  final ModelBlocklyMessageQueue _messages = ModelBlocklyMessageQueue();

  void setMaxBlocks(int value) => _messages.setMaxBlocks(value);

  Future<void> requestBlocklyJson() async => _messages.requestCommands();

  @override
  Widget build(BuildContext context) => WidgetsBlocklyWebEditor(
    messages: _messages,
    onCommandsJson: (json) => widget.onCommandsReady(parseBlocklyJson(json)),
  );
}
