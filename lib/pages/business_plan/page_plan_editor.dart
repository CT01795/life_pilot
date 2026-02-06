import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/business_plan/controller_business_plan.dart';
import 'package:life_pilot/core/const.dart';
import 'package:provider/provider.dart';
import 'package:html_editor_enhanced/html_editor.dart';

class PagePlanEditor extends StatefulWidget {
  const PagePlanEditor({super.key});

  @override
  State<PagePlanEditor> createState() => _PagePlanEditorState();
}

class _PagePlanEditorState extends State<PagePlanEditor> {
  late HtmlEditorController _htmlController;
  String? _currentQuestionId;

  @override
  void initState() {
    super.initState();
    _htmlController = HtmlEditorController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentAnswer();
    });
  }

  // 載入當前題目答案到 HtmlEditor
  void _loadCurrentAnswer() {
    final c = context.read<ControllerBusinessPlan>();
    final currentQuestionId = c.currentQuestion.id;
    // 只在 question 改變時 setText
    if (_currentQuestionId == currentQuestionId) return;
    final answer = c.currentQuestion.answer;
    _htmlController.setText(answer);
    setState(() {
      _currentQuestionId = currentQuestionId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.read<ControllerBusinessPlan>();
    return PopScope(
      canPop: false, // 我們手動控制 pop
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final html = await _htmlController.getText();
        await c.commitCurrentAnswer(html);

        Navigator.pop(context); // 手動返回
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Business Plan Editor'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(16), // 增加高度，變胖
            child: Selector<ControllerBusinessPlan, double>(
              selector: (_, c) => c.progress,
              builder: (_, p, __) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6), // 加點內邊距
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8), // 可選：圓角
                  child: LinearProgressIndicator(
                    value: p,
                    minHeight: 16, // 這裡再指定高度，確保變胖
                    backgroundColor: Colors.grey.shade300, // 背景色
                    color: Colors.blueAccent, // 進度條顏色
                  ),
                ),
              ),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section
              Text(
                c.currentPlan!.sections[c.sectionIndex].title,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Gaps.h16,
              // Question
              Text(
                c.currentQuestion.prompt,
                style: const TextStyle(fontSize: 16),
              ),
              Gaps.h16,
              // Answer
              Expanded(
                child: HtmlEditor(
                  controller: _htmlController,
                  htmlEditorOptions: HtmlEditorOptions(
                    initialText: c.currentQuestion.answer.isEmpty ? "" : c.currentQuestion.answer,
                    hint: "請輸入答案",
                  ),
                  htmlToolbarOptions: const HtmlToolbarOptions(
                    defaultToolbarButtons: [
                      StyleButtons(),
                      FontSettingButtons(),
                      ColorButtons(),
                      ListButtons(),
                      ParagraphButtons(),
                      InsertButtons(),
                    ],
                  ),
                ),
              ),
              Gaps.h16,
              // Navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      final html = await _htmlController.getText();
                      await c.commitCurrentAnswer(html);
                      final hasPrev = c.previous();
                      if (hasPrev) {
                        _loadCurrentAnswer();
                      }
                    },
                    child: const Text('Previous'),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final html = await _htmlController.getText();
                      await c.commitCurrentAnswer(html);
                      final hasNext = c.next();
                      if (!hasNext) {
                        Navigator.pop(context);
                      } else {
                        _loadCurrentAnswer();
                      }
                    },
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      )
    );
  }
}
