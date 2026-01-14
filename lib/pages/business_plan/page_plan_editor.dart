import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/business_plan/controller_business_plan.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/models/business_plan/model_plan_question.dart';
import 'package:provider/provider.dart';

class PagePlanEditor extends StatefulWidget {
  const PagePlanEditor({super.key});

  @override
  State<PagePlanEditor> createState() => _PagePlanEditorState();
}

class _PagePlanEditorState extends State<PagePlanEditor> {
  late final TextEditingController _textController;
  ModelPlanQuestion? _lastQuestion;

  @override
  void initState() {
    super.initState();
    final c = context.read<ControllerBusinessPlan>();
    _textController =
        TextEditingController(text: c.currentQuestion.answer);
    _lastQuestion = c.currentQuestion;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Plan Editor'),
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
          // 🔒 只有在「題目真的變了」才同步文字
          if (_lastQuestion?.id != question.id) {
            _textController.text = question.answer;
            _lastQuestion = question;
          }

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
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: '請輸入你的回答…',
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
                        await c.commitCurrentAnswer(_textController.text);
                        final hasPrev = c.previous();
                        if (hasPrev) {
                          _textController.text = c.currentQuestion.answer;
                        }
                      },
                      child: const Text('Previous'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        // 1️⃣ 先存答案
                        await c.commitCurrentAnswer(_textController.text);
                        // 2️⃣ 再切題
                        final hasNext = c.next();
                        if (!hasNext) {
                          Navigator.pop(context); // 暫時完成
                        } else {
                          _textController.text = c.currentQuestion.answer;
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
