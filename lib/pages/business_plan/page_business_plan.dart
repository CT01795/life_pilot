import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/business_plan/controller_business_plan.dart';
import 'package:life_pilot/models/business_plan/model_business_plan.dart';
import 'package:life_pilot/pages/business_plan/page_plan_preview.dart';
import 'package:life_pilot/pages/business_plan/page_plan_select_template.dart';
import 'package:provider/provider.dart';

class PageBusinessPlan extends StatefulWidget {
  const PageBusinessPlan({super.key});

  @override
  State<PageBusinessPlan> createState() => _PageBusinessPlanState();
}

class _PageBusinessPlanState extends State<PageBusinessPlan> {
  bool isEditingTitle = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Selector<ControllerBusinessPlan, bool>(
        selector: (_, c) => c.isPlansLoading,
        builder: (_, isLoading, __) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Selector<ControllerBusinessPlan, List<ModelBusinessPlan>>(
            selector: (_, c) => c.plans,
            builder: (_, plans, __) {
              if (plans.isEmpty) {
                return const Center(child: Text('No plans yet'));
              }

              return ListView.builder(
                itemCount: plans.length,
                itemBuilder: (_, i) {
                  return Selector<ControllerBusinessPlan, String>(
                    selector: (_, c) => c.plans[i].title, // 監聽這個 plan 的 title
                    builder: (_, title, __) {
                      return ListTile(
                        title: InlineEditableTitle(
                          initialText: title,
                          onSave: (newTitle) {
                            context.read<ControllerBusinessPlan>().updatePlanTitleByIndex(i, newTitle);
                          },
                          onEditingChanged: (editing) {
                            setState(() => isEditingTitle = editing);
                          },
                        ),
                        onTap: () {
                          if (isEditingTitle) return; // 🔒 編輯中鎖定跳頁
                          final plan = context.read<ControllerBusinessPlan>().plans[i];
                          context.read<ControllerBusinessPlan>().setCurrentPlanSummary(plan);
                          context.read<ControllerBusinessPlan>().loadPlanDetailIfNeeded(plan.id);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PagePlanPreview()),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PagePlanSelectTemplate(),
            ),
          );
        },
        child: const Icon(Icons.add, size: 50),
      ),
    );
  }
}

class InlineEditableTitle extends StatefulWidget {
  final String initialText;
  final ValueChanged<String> onSave;
  final ValueChanged<bool>? onEditingChanged; // ✅ 新增

  const InlineEditableTitle({
    super.key,
    required this.initialText,
    required this.onSave,
    this.onEditingChanged,
  });

  @override
  State<InlineEditableTitle> createState() => _InlineEditableTitleState();
}

class _InlineEditableTitleState extends State<InlineEditableTitle> {
  bool editing = false;
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(covariant InlineEditableTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!editing) {
      controller.text = widget.initialText;
    }
  }

  void _setEditing(bool value) {
    setState(() => editing = value);
    widget.onEditingChanged?.call(value); // 通知外層編輯狀態
  }

  void _save() {
    final text = controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSave(text);
    }
    _setEditing(false);
  }

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      return Row(
        children: [
          Expanded(
            child: Text(widget.initialText.isEmpty ? 'Untitled Plan' : widget.initialText),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.grey),
            onPressed: () => _setEditing(true), // 點鉛筆進入編輯
          ),
        ],
      );
    }

    // 編輯狀態：文字欄 + 勾勾
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (_) => _save(),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check, color: Colors.green),
          onPressed: _save,
        ),
      ],
    );
  }
}