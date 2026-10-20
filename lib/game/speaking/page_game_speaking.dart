// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/game/speaking/controller_game_speaking.dart';
import 'package:life_pilot/game/speaking/model_game_speaking.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/logger.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/game/service_game_speech.dart';
import 'package:life_pilot/game/widgets_game_help_button.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

// ignore: must_be_immutable
class PageGameSpeaking extends StatefulWidget {
  final String gameId;
  int gameLevel;
  final String questionBank;
  final ServiceGame? service;
  final ServiceGameSpeech? speech;
  PageGameSpeaking({
    super.key,
    required this.gameId,
    required this.gameLevel,
    this.questionBank = 'admin',
    this.service,
    this.speech,
  });

  @override
  State<PageGameSpeaking> createState() => _PageGameSpeakingState();
}

class _PageGameSpeakingState extends State<PageGameSpeaking> {
  late final ControllerGameSpeaking controller;
  bool _hasPopped = false; // 旗標，避免重複 pop
  double size = 32.0;
  int _answerRevision = 0;
  ModelGameSpeaking? _displayedQuestion;
  bool isRecording = false;
  TextEditingController answerController =
      TextEditingController(); // 顯示答案的 TextField
  late stt.SpeechToText _speech;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    final auth = context.read<ControllerAuth>();
    controller = ControllerGameSpeaking(
      gameId: widget.gameId,
      gameLevel: widget.gameLevel == -1 ? 1 : widget.gameLevel,
      questionBank: widget.questionBank,
      userName: auth.currentAccount ?? AuthConstants.guest,
      service: widget.service ?? ServiceGame(),
      speech: widget.speech,
      maxQuestions: widget.gameLevel == -1 ? 10 : 999,
    );

    controller.addListener(_onQuestionChanged);
    controller.loadNextQuestion();
  }

  void _onQuestionChanged() {
    final question = controller.currentQuestion;
    if (identical(question, _displayedQuestion)) return;
    _displayedQuestion = question;
    _answerRevision++;
    answerController.clear();
  }

  @override
  void dispose() {
    _answerRevision++;
    unawaited(_speech.cancel());
    controller.removeListener(_onQuestionChanged);
    controller.dispose();
    answerController.dispose();
    super.dispose();
  }

  Future<void> onAnswer() async {
    final question = controller.currentQuestion;
    if (question == null || !controller.answer(answerController.text)) return;
    final revision = ++_answerRevision;
    unawaited(showCorrectAnswer(question.correctAnswer, revision));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted ||
        revision != _answerRevision ||
        !identical(question, controller.currentQuestion)) {
      return;
    }
    _answerRevision++;
    answerController.clear();
  }

  Future<void> showCorrectAnswer(String text, int revision) async {
    final question = controller.currentQuestion;
    answerController.clear();
    final words = text.split(' ');
    for (final word in words) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!mounted ||
          revision != _answerRevision ||
          !identical(question, controller.currentQuestion)) {
        return;
      }
      final updated = '${answerController.text}$word ';
      answerController.value = TextEditingValue(
        text: updated,
        selection: TextSelection.collapsed(offset: updated.length),
      );
    }
  }

  void onSpeechResult(String recognizedText) {
    if (!mounted || !isRecording || !controller.canAnswer) return;

    answerController.value = TextEditingValue(
      text: recognizedText,
      selection: TextSelection.collapsed(offset: recognizedText.length),
    );
  }

  Future<void> startSpeechRecognition({
    required void Function(String text) onResult,
  }) async {
    if (!controller.canAnswer) return;
    final revision = ++_answerRevision;
    final question = controller.currentQuestion;
    if (_speech.isListening) {
      await _speech.stop();
      if (!mounted) return;
    }
    final available = await _speech.initialize(
      onError: (error) {
        logger.e('Speech error: $error');

        // ⛔ timeout 不當作失敗
        if (error.errorMsg == 'error_speech_timeout') {
          return;
        }

        if (!mounted) return;
        setState(() {
          isRecording = false;
        });
      },
    );

    if (!mounted ||
        !isRecording ||
        !controller.canAnswer ||
        revision != _answerRevision ||
        !identical(question, controller.currentQuestion)) {
      return;
    }
    if (!available) {
      setState(() => isRecording = false);
      return;
    }

    answerController.clear();

    await _speech.listen(
      onResult: (result) {
        if (!mounted ||
            !isRecording ||
            revision != _answerRevision ||
            !identical(question, controller.currentQuestion)) {
          return;
        }
        onResult(result.recognizedWords);
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: 'en_US',
        listenMode: stt.ListenMode.confirmation,
        partialResults: true,
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> stopSpeechRecognition() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final loc = AppLocalizations.of(context)!;
        if (controller.isFinished && !_hasPopped) {
          _hasPopped = true;
          Future.microtask(() {
            if (mounted) Navigator.pop(context, true);
          });
          return Scaffold(
            body: Center(
              child: Text(loc.congratulationsScore(controller.score)),
            ),
          );
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
                    onPressed: controller.loadNextQuestion,
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

        return AbsorbPointer(
          absorbing: controller.isBusy, // true = 全部不能點
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: Color(0xFFF5F7FA),
                appBar: AppBar(
                  backgroundColor: Color(0xFF4DB6AC),
                  leading: IconButton(
                    tooltip: loc.back,
                    icon: Icon(Icons.arrow_back),
                    onPressed: () {
                      Navigator.maybePop(context);
                    },
                  ),
                  title: Text(
                    loc.gameTitleScore(loc.speakingTitle, controller.score),
                  ),
                  actions: [
                    GameHelpButton(description: loc.gameInstructionsSpeaking),
                  ],
                ),
                body: Column(
                  children: [
                    // 第一列：喇叭按鈕 + 題目
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: loc.pressToPlayAudio,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(64, 64),
                            ),
                            icon: Icon(
                              Icons.volume_up,
                              size: 52,
                              color: isRecording
                                  ? Colors.grey
                                  : Color(0xFF26A69A),
                            ),
                            onPressed: isRecording
                                ? null // 🔒 錄音中不能按
                                : () => controller.speak(
                                    controller.currentQuestion!.correctAnswer,
                                  ),
                          ),
                          Gaps.w8,
                          Flexible(
                            child: Text(
                              controller.currentQuestion!.question,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Gaps.h16,
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            tooltip: isRecording
                                ? loc.finishSpeaking
                                : loc.startSpeaking,
                            icon: Icon(
                              !isRecording
                                  ? Icons.mic_none
                                  : Icons.stop, // 錄音時顯示停止
                              size: 50,
                              color: !isRecording
                                  ? Color(0xFF26A69A)
                                  : Colors.red,
                            ),
                            onPressed: () async {
                              if (!isRecording) {
                                // 開始錄音
                                setState(() {
                                  isRecording = true;
                                });
                                // 🚀 開始語音辨識
                                await startSpeechRecognition(
                                  onResult: onSpeechResult,
                                );
                              } else {
                                // ⏹ 停止錄音
                                await stopSpeechRecognition();
                                if (!mounted) return;
                                setState(() {
                                  isRecording = false;
                                });
                                onAnswer(); // 停止後立即提交答案
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    Gaps.h16,
                    // 逐字顯示答案的 TextField
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: TextField(
                          controller: answerController,
                          maxLines: null,
                          readOnly: false,
                          keyboardType: TextInputType.multiline,
                          textAlign: TextAlign.left,
                          textAlignVertical: TextAlignVertical.top,
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.blueAccent,
                          ),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: loc.answerHere,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 🔹 等待遮罩（可選但很推薦）
              if (controller.isBusy)
                Container(color: Colors.black.withValues(alpha: 0.2)),
            ],
          ),
        );
      },
    );
  }
}
