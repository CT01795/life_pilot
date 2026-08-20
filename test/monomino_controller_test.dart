import 'package:flutter_test/flutter_test.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/steam_monomino/controller_game_steam_monomino.dart';

class _RecordingGameService extends ServiceGame {
  int savedScores = 0;

  @override
  Future<void> saveUserGameScore({
    required String newUserName,
    required double newScore,
    required String? newGameId,
    bool? newIsPass,
  }) async {
    savedScores++;
  }
}

void main() {
  test('checking a monomino path does not consume fixed-arrow state', () async {
    final controller = ControllerGameSteamMonomino(
      userName: 'test-user',
      service: _RecordingGameService(),
      gameId: 'test-game',
      gameLevel: 5,
    );
    final beforeCheck = List.of(controller.remainingFixed);

    await controller.checkPath();

    expect(controller.remainingFixed, beforeCheck);
  });
}
