import 'package:flutter/material.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_template.dart';
import 'package:life_pilot/business_plan/page_plan_editor.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ControllerBusinessPlan>().loadTemplates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.selectTemplate)),
      body: Selector<ControllerBusinessPlan, bool>(
        selector: (_, c) => c.isTemplateLoading,
        builder: (_, loading, _) {
          if (loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Selector<ControllerBusinessPlan, List<ModelPlanTemplate>>(
            selector: (_, c) => c.templates,
            builder: (_, templates, _) {
              return ListView.builder(
                itemCount: templates.length,
                itemBuilder: (_, i) {
                  final t = templates[i];
                  return ListTile(
                    title: Text(t.title),
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
    final loc = AppLocalizations.of(context)!;
    final textController = TextEditingController();

    final title = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.planTitle),
        content: TextField(controller: textController),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(loc.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: Text(loc.create),
          ),
        ],
      ),
    );

    if (title == null || title.isEmpty) return;

    await context.read<ControllerBusinessPlan>().createPlanFromTemplate(
      title: title,
      templateId: template.id,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<ControllerBusinessPlan>(),
          child: const PagePlanEditor(),
        ),
      ),
    );
  }
}
