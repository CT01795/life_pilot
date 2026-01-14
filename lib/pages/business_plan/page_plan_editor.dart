import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/business_plan/controller_business_plan.dart';
import 'package:life_pilot/models/business_plan/model_plan_question.dart';
import 'package:provider/provider.dart';

class PagePlanEditor extends StatefulWidget {
  const PagePlanEditor({super.key});

  @override
  State<PagePlanEditor> createState() => _PagePlanEditorState();
}

class _PagePlanEditorState extends State<PagePlanEditor> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    final c = context.read<ControllerBusinessPlan>();
    _textController =
        TextEditingController(text: c.currentQuestion.answer);
  }

  @override
  void didUpdateWidget(covariant PagePlanEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final c = context.read<ControllerBusinessPlan>();
    _textController.text = c.currentQuestion.answer;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Business Plan Editor')),
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
                const SizedBox(height: 16),

                // Question
                Text(
                  question.prompt,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 12),

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
                    onChanged: (value) {
                      c.saveAnswer(value);
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        final hasNext = c.next();
                        if (!hasNext) {
                          Navigator.pop(context); // 暫時完成
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
