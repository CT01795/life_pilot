import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/social/controller_game_social.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/game/service_game.dart';
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
              icon: Icon(Icons.arrow_back),
              onPressed: () {
                Navigator.maybePop(context);
              },
            ),
            title: Text("Social (${controller.score}/100)"),
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
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFECEFF1), // blue grey 50
                          padding: EdgeInsets
                              .zero, // 🔹 移除 ElevatedButton 內建 padding
                        ),
                        onPressed: () => controller.speak(q.scene),
                        child: Row(
                          mainAxisSize: MainAxisSize.max, // 🔹 改成 max，佔滿整個按鈕
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            IconButton(
                              tooltip: loc.speakingText,
                              onPressed: () => controller.speak(q.scene),
                              icon: const Icon(
                                Icons.volume_up,
                                color: Color(0xFF212121),
                              ),
                              iconSize: isCompact ? 30 : 36,
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
                  Gaps.h8,
                  // 三個答案按鈕
                  ...q.options.map((opt) {
                    Color buttonColor = controller.getButtonColor(opt); // 淺藍
                    Color borderColor =
                        controller.getBorderColor(opt); // Material Blue 700
                    Icon? statusIcon =
                        controller.getStatusIcon(opt); // 用於顯示勾勾或叉叉
                    return Padding(
                      padding: Insets.all8,
                      child: SizedBox(
                        width: double.infinity, // 寬度等於螢幕寬度
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: buttonColor,
                          ),
                          onPressed: () => controller.speak(
                              opt), // 🔹 原本按鈕改成 TTS //=> controller.answer(opt),
                          child: Row(
                            mainAxisSize: MainAxisSize.max, // 🔹 改成 max，佔滿整個按鈕
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              // ⭐ 改成自訂 CheckBox 風格的 Radio
                              GestureDetector(
                                onTap: controller.lastAnswer == null
                                    ? () => onAnswer(opt)
                                    : null,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.rectangle,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: borderColor,
                                    ),
                                  ),
                                  child: Center(
                                    child: opt == controller.lastAnswer
                                        ? Icon(Icons.check,
                                            color: borderColor, size: 48)
                                        : SizedBox.shrink(),
                                  ),
                                ),
                              ),
                              Gaps.w24,
                              Expanded(
                                child: Text(
                                  opt,
                                  style: TextStyle(
                                      fontSize: size, color: Color(0xFF212121)),
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
