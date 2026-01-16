import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/business_plan/controller_business_plan.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/business_plan/model_plan_question.dart';
import 'package:life_pilot/pages/business_plan/page_plan_preview.dart';
import 'package:provider/provider.dart';
import 'package:html_editor_enhanced/html_editor.dart';

class PagePlanEditor extends StatefulWidget {
  const PagePlanEditor({super.key});

  @override
  State<PagePlanEditor> createState() => _PagePlanEditorState();
}

class _PagePlanEditorState extends State<PagePlanEditor> {
  late HtmlEditorController _htmlController;

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
    final answer = c.currentQuestion.answer;
    _htmlController.clear(); // 先清空
    _htmlController.setText(answer);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Plan Editor'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(16), // 增加高度，變胖
          child: Selector<ControllerBusinessPlan, double>(
            selector: (_, c) => c.progress,
            builder: (_, p, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), // 加點內邊距
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
      body: Selector<ControllerBusinessPlan, ModelPlanQuestion>(
        selector: (_, c) => c.currentQuestion,
        builder: (_, question, __) {
          final c = context.read<ControllerBusinessPlan>();
          return Padding(
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
                  question.prompt,
                  style: const TextStyle(fontSize: 16),
                ),
                Gaps.h16,
                // Answer
                Expanded(
                  child: HtmlEditor(
                    controller: _htmlController,
                    htmlEditorOptions: HtmlEditorOptions(
                      initialText: question.answer.isEmpty ? "" : question.answer,
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
                          setState(() {});
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
                          setState(() {});
                        }
                      },
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
