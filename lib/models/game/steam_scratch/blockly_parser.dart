import 'package:life_pilot/controllers/game/steam_scratch/controller_game_steam_scratch.dart';
import 'package:xml/xml.dart';

List<Command> parseBlocklyJson(Map<String, dynamic> data) {
  final xmlStr = data["xml"];
  final xmlDoc = XmlDocument.parse(xmlStr);
  final rootElement = xmlDoc.rootElement;

  int? getValue(XmlElement? valueElement, ControllerGameSteamScratch g) {
    if (valueElement == null) return null;

    final shadow = valueElement.getElement('shadow');
    if (shadow == null) return null;

    final type = shadow.getAttribute('type');
    if (type == 'math_variable') {
      // ignore: deprecated_member_use
      final varName = shadow.getElement('field')?.text;
      if (varName == 'x') return g.state.x;
      if (varName == 'y') return g.state.y;
    } else if (type == 'math_number') {
      // ignore: deprecated_member_use
      return int.tryParse(shadow.getElement('field')?.text ?? '');
    }

    return null;
  }

  List<Command> parseBlocks(XmlElement parent) {
    List<Command> cmds = [];
    final blocks = parent.findElements('block');

    for (var b in blocks) {
      final type = b.getAttribute('type');

      switch (type) {
        case 'forward':
          cmds.add(ForwardCommand());
          break;
        case 'backward':
          cmds.add(BackwardCommand());
          break;
        /*case 'turn_left':
          cmds.add(TurnLeftCommand());
          break;
        case 'turn_right':
          cmds.add(TurnRightCommand());
          break;*/
        case 'jump_up':
          cmds.add(JumpUpCommand());
          break;
        case 'jump_down':
          cmds.add(JumpDownCommand());
          break;

        case 'controls_repeat_ext': // loop
          {
            int count = 1;
            final valueElement = b.getElement('value');
            if (valueElement != null) {
              final shadow = valueElement.findElements('shadow').isNotEmpty
                  ? valueElement.findElements('shadow').first
                  : null;
              if (shadow != null) {
                final field = shadow.getElement('field');
                if (field != null && field.getAttribute('name') == 'NUM') {
                  // ignore: deprecated_member_use
                  count = int.tryParse(field.text) ?? 1;
                }
              }
            }

            List<Command> innerCommands = [];
            final statementElement = b.getElement('statement');
            if (statementElement != null) {
              innerCommands = parseBlocks(statementElement);
            }

            cmds.add(LoopCommand(count: count, commands: innerCommands));
          }
          break;

        case 'controls_if': // if/else
          {
            List<Command> thenCmds = [];
            List<Command> elseCmds = [];

            final statements = b.findElements('statement').toList();
            if (statements.isNotEmpty) thenCmds = parseBlocks(statements[0]);
            if (statements.length > 1) elseCmds = parseBlocks(statements[1]);

            cmds.add(IfElseCommand(
              condition: (g) {
                final valueIf0 = b.getElement('value'); // IF0
                final logicCompare = valueIf0?.getElement('shadow');
                if (logicCompare == null ||
                    logicCompare.getAttribute('type') != 'logic_compare') {
                  return false;
                }

                // ignore: deprecated_member_use
                final op = logicCompare.getElement('field')?.text ?? 'EQ';
                final aVal = getValue(
                    logicCompare
                        .findElements('value')
                        .firstWhere((v) => v.getAttribute('name') == 'A'),
                    g);
                final bVal = getValue(
                    logicCompare
                        .findElements('value')
                        .firstWhere((v) => v.getAttribute('name') == 'B'),
                    g);

                if (aVal == null || bVal == null) return false;

                switch (op) {
                  case 'EQ':
                    return aVal == bVal;
                  case 'NEQ':
                    return aVal != bVal;
                  case 'GT':
                    return aVal > bVal;
                  case 'LT':
                    return aVal < bVal;
                  case 'GTE':
                    return aVal >= bVal;
                  case 'LTE':
                    return aVal <= bVal;
                  default:
                    return false;
                }
              },
              thenCommands: thenCmds,
              elseCommands: elseCmds,
            ));
          }
          break;
      }

      // 處理 next
      final next = b.getElement('next');
      if (next != null) {
        cmds.addAll(parseBlocks(next));
      }
    }

    return cmds;
  }

  return parseBlocks(rootElement);
}
