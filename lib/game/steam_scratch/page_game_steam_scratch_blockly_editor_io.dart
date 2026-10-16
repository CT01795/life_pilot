import 'package:flutter/material.dart';
import 'package:life_pilot/game/model_blockly_message_queue.dart';
import 'package:life_pilot/game/steam_scratch/blockly_parser.dart';
import 'package:life_pilot/game/steam_scratch/controller_game_steam_scratch.dart';
import 'package:life_pilot/game/widgets_blockly_native_editor.dart';

class PageGameSteamScratchBlocklyEditor extends StatefulWidget {
  const PageGameSteamScratchBlocklyEditor({
    super.key,
    required this.onCommandsReady,
  });

  final Function(List<Command>) onCommandsReady;

  @override
  State<PageGameSteamScratchBlocklyEditor> createState() =>
      PageGameSteamScratchBlocklyEditorState();
}

class PageGameSteamScratchBlocklyEditorState
    extends State<PageGameSteamScratchBlocklyEditor> {
  final ModelBlocklyMessageQueue _messages = ModelBlocklyMessageQueue();

  Future<void> setMaxBlocks(int value) async => _messages.setMaxBlocks(value);

  Future<void> requestBlocklyJson() async => _messages.requestCommands();

  @override
  Widget build(BuildContext context) => WidgetsBlocklyNativeEditor(
    messages: _messages,
    onCommandsJson: (json) => widget.onCommandsReady(parseBlocklyJson(json)),
  );
}
