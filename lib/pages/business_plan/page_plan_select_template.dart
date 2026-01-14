import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/business_plan/controller_business_plan.dart';
import 'package:life_pilot/models/business_plan/model_plan_template.dart';
import 'package:life_pilot/pages/business_plan/page_plan_editor.dart';
import 'package:provider/provider.dart';

class PagePlanSelectTemplate extends StatefulWidget {
  const PagePlanSelectTemplate({super.key});

  @override
  State<PagePlanSelectTemplate> createState() => _PagePlanSelectTemplateState();
}

class _PagePlanSelectTemplateState extends State<PagePlanSelectTemplate> {
  @override
  void initState() {
    super.initState();
    context.read<ControllerBusinessPlan>().loadTemplates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Template')),
      body: Selector<ControllerBusinessPlan, bool>(
        selector: (_, c) => c.isTemplateLoading,
        builder: (_, loading, __) {
          if (loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Selector<ControllerBusinessPlan, List<ModelPlanTemplate>>(
            selector: (_, c) => c.templates,
            builder: (_, templates, __) {
              return ListView.builder(
                itemCount: templates.length,
                itemBuilder: (_, i) {
                  final t = templates[i];
                  return ListTile(
                    title: Text(t.name),
                    subtitle: Text(t.description),
                    onTap: () => _createPlan(context, t),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _createPlan(BuildContext context, ModelPlanTemplate template) async {
    final textController = TextEditingController();

    final title = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Plan Title'),
        content: TextField(controller: textController),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, textController.text),
              child: const Text('Create')),
        ],
      ),
    );

    if (title == null || title.isEmpty) return;

    await context.read<ControllerBusinessPlan>().createPlanFromTemplate(
          title: title,
          templateId: template.id,
        );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PagePlanEditor()),
    );
  }
}