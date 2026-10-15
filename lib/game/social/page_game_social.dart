import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/social/controller_game_social.dart';
import 'package:life_pilot/game/social/widgets_social_option.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/widgets_game_help_button.dart';
import 'package:provider/provider.dart';

// ignore: must_be_immutable
class PageGameSocial extends StatefulWidget {
  final String gameId;
  int gameLevel;
  final String questionBank;
  PageGameSocial({
    super.key,
    required this.gameId,
    required this.gameLevel,
    this.questionBank = 'admin',
  });

  @override
  State<PageGameSocial> createState() => _PageGameSocialState();
}

class _PageGameSocialState extends State<PageGameSocial> {
  late final ControllerGameSocial controller;
  bool _hasPopped = false; // 旗標，避免重複 pop
  double size = 32.0;

  @override
  void initState() {
    super.initState();

    final auth = context.read<ControllerAuth>();
    controller = ControllerGameSocial(
      gameId: widget.gameId,
      gameLevel: widget.gameLevel == -1 ? 1 : widget.gameLevel,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGame(),
      questionBank: widget.questionBank,
      maxQuestions: widget.gameLevel == -1 ? 10 : 999,
    );
    controller.loadNextQuestion();
  }

  // 呼叫這個方法答題並判斷是否完成題數
  Future<void> onAnswer(String option) async {
    await controller.answer(option);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final loc = AppLocalizations.of(context)!;
        final isCompact = MediaQuery.sizeOf(context).width < 600;
        // ✅ 判斷遊戲是否完成
        if (controller.isFinished && !_hasPopped) {
          _hasPopped = true;
          Future.microtask(() {
            if (mounted) Navigator.pop(context, true);
          });
          return const SizedBox.shrink(); // 回上一頁前先返回空 widget
        }

        if (controller.loadError != null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: loc.back,
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(loc.unknownError),
                  Gaps.h8,
                  ElevatedButton(
                    onPressed: controller.retry,
                    child: Text(loc.retry),
                  ),
                ],
              ),
            ),
          );
        }

        if (controller.isLoading || controller.currentQuestion == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final q = controller.currentQuestion!;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: loc.back,
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.maybePop(context);
              },
            ),
            title: Text(loc.gameTitleScore(loc.socialTitle, controller.score)),
            actions: [GameHelpButton(description: loc.gameInstructionsSocial)],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: Insets.all8,
                    child: SizedBox(
                      width: double.infinity, // 寬度等於螢幕寬度
                      child: GameSpeechTooltip(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFECEFF1),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: () => controller.speak(q.scene),
                          child: Row(
                            mainAxisSize: MainAxisSize.max, // 🔹 改成 max，佔滿整個按鈕
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              IconButton(
                                tooltip: loc.pressToPlayAudio,
                                onPressed: () => controller.speak(q.scene),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size(56, 56),
                                ),
                                icon: const Icon(
                                  Icons.volume_up,
                                  color: Color(0xFF212121),
                                ),
                                iconSize: isCompact ? 40 : 48,
                              ),
                              Gaps.w8,
                              Expanded(
                                child: Text(
                                  q.scene,
                                  style: TextStyle(
                                    fontSize: isCompact ? 24 : size,
                                    color: const Color(0xFF212121),
                                  ),
                                  textAlign: TextAlign.start,
                                  softWrap: true, // 允許換行
                                  overflow: TextOverflow.visible,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Gaps.h8,
                  for (final option in q.options)
                    WidgetsSocialOption(
                      option: option,
                      feedback: controller.feedbackFor(option),
                      selected: option == controller.lastAnswer,
                      canAnswer: controller.canAnswer,
                      onAnswer: () => onAnswer(option),
                      onSpeak: () => controller.speak(option),
                      fontSize: size,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
