import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/translation/controller_game_translation.dart';
import 'package:life_pilot/game/translation/model_game_translation.dart';
import 'package:life_pilot/game/game_question_authoring_rules.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/widgets_game_help_button.dart';
import 'package:provider/provider.dart';

// ignore: must_be_immutable
class PageGameTranslation extends StatefulWidget {
  final String gameId;
  final String gameName;
  int gameLevel;
  final String questionBank;
  PageGameTranslation({
    super.key,
    required this.gameId,
    required this.gameLevel,
    required this.gameName,
    this.questionBank = 'admin',
  });

  @override
  State<PageGameTranslation> createState() => _PageGameTranslationState();
}

class _PageGameTranslationState extends State<PageGameTranslation> {
  late final ControllerGameTranslation controller;
  bool _hasPopped = false; // 旗標，避免重複 pop
  double questionSize = 32.0;
  double answerSize = 32.0;

  @override
  void initState() {
    super.initState();
    questionSize =
        GameQuestionAuthoringRules.isNumberedLanguageGame(widget.gameName)
        ? 24.0
        : questionSize;
    answerSize =
        GameQuestionAuthoringRules.isNumberedLanguageGame(widget.gameName)
        ? 24.0
        : answerSize;
    final auth = context.read<ControllerAuth>();
    controller = ControllerGameTranslation(
      gameId: widget.gameId,
      gameLevel: widget.gameLevel == -1 ? 1 : widget.gameLevel,
      gameName: widget.gameName,
      questionBank: widget.questionBank,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: ServiceGame(),
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
            title: Text(
              loc.gameTitleScore(loc.translationTitle, controller.score),
            ),
            actions: [
              GameHelpButton(description: loc.gameInstructionsTranslation),
            ],
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
                          onPressed: () =>
                              controller.speak(q.question, q.group, true),
                          child: Row(
                            mainAxisSize: MainAxisSize.max, // 🔹 改成 max，佔滿整個按鈕
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              IconButton(
                                tooltip: loc.pressToPlayAudio,
                                onPressed: () =>
                                    controller.speak(q.question, q.group, true),
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
                                  q.question,
                                  style: TextStyle(
                                    fontSize: isCompact ? 24 : questionSize,
                                    color: Color(0xFF212121),
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
                  // 三個答案按鈕
                  ...q.options.map((opt) {
                    final feedback = controller.feedbackFor(opt);
                    final (
                      buttonColor,
                      borderColor,
                      statusIcon,
                    ) = switch (feedback) {
                      TranslationOptionFeedback.neutral => (
                        const Color(0xFFE3F2FD),
                        const Color(0xFF1976D2),
                        null,
                      ),
                      TranslationOptionFeedback.correct => (
                        const Color(0xFFC8E6C9),
                        const Color(0xFF388E3C),
                        const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF2E7D32),
                          size: 32,
                        ),
                      ),
                      TranslationOptionFeedback.incorrect => (
                        const Color(0xFFFFCDD2),
                        const Color(0xFFD32F2F),
                        const Icon(
                          Icons.clear_rounded,
                          color: Color(0xFFD32F2F),
                          size: 32,
                        ),
                      ),
                    };
                    return Padding(
                      padding: Insets.all8,
                      child: SizedBox(
                        width: double.infinity, // 寬度等於螢幕寬度
                        child: GameSpeechTooltip(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                            ),
                            onPressed: () =>
                                controller.speak(opt, q.group, false),
                            child: Row(
                              mainAxisSize:
                                  MainAxisSize.max, // 🔹 改成 max，佔滿整個按鈕
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                // ⭐ 改成自訂 CheckBox 風格的 Radio
                                Tooltip(
                                  message: loc.checkOption,
                                  child: GestureDetector(
                                    onTap: controller.canAnswer
                                        ? () => onAnswer(opt)
                                        : null,
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.rectangle,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Center(
                                        child: opt == controller.lastAnswer
                                            ? Icon(
                                                Icons.check,
                                                color: borderColor,
                                                size: 48,
                                              )
                                            : SizedBox.shrink(),
                                      ),
                                    ),
                                  ),
                                ),
                                Gaps.w24,
                                Expanded(
                                  child: Text(
                                    opt,
                                    style: TextStyle(
                                      fontSize: answerSize,
                                      color: Color(0xFF212121),
                                    ),
                                    softWrap: true, // 允許自動換行
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                                Gaps.w8,
                                // ⭐ 這裡必須安全顯示
                                statusIcon ?? SizedBox.shrink(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
