import 'package:flutter/material.dart';
import 'package:life_pilot/utils/widgets/widgets_load_error.dart';
import 'package:life_pilot/business_plan/controller_business_plan.dart';
import 'package:life_pilot/business_plan/model_plan_template.dart';
import 'package:life_pilot/business_plan/page_plan_editor.dart';
import 'package:life_pilot/business_plan/page_plan_preview.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

class PagePlanSelectTemplate extends StatefulWidget {
  const PagePlanSelectTemplate({super.key});

  @override
  State<PagePlanSelectTemplate> createState() => _PagePlanSelectTemplateState();
}

class _PagePlanSelectTemplateState extends State<PagePlanSelectTemplate> {
  bool _askingTitle = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ControllerBusinessPlan>().loadTemplates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(loc.selectTemplate)),
      body: Consumer<ControllerBusinessPlan>(
        builder: (_, controller, _) => Column(
          children: [
            if (controller.templateLoadError != null)
              WidgetsLoadError(onRetry: controller.loadTemplates),
            if (controller.isCreatingPlan) const LinearProgressIndicator(),
            Expanded(child: _buildTemplates(controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplates(ControllerBusinessPlan controller) {
    if (controller.isTemplateLoading && controller.templates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final templates = controller.templates;
    if (templates.isEmpty) {
      return controller.templateLoadError != null
          ? const SizedBox.shrink()
          : Center(child: Text(AppLocalizations.of(context)!.noData));
    }
    return ListView.builder(
      itemCount: templates.length,
      itemBuilder: (_, index) {
        final template = templates[index];
        return ListTile(
          title: Text(template.title),
          subtitle: Text(template.description),
          onTap: controller.isCreatingPlan
              ? null
              : () => _createPlan(context, template),
        );
      },
    );
  }

  Future<void> _createPlan(
    BuildContext context,
    ModelPlanTemplate template,
  ) async {
    final controller = context.read<ControllerBusinessPlan>();
    if (_askingTitle || controller.isCreatingPlan) return;
    _askingTitle = true;
    try {
      final title = await showDialog<String>(
        context: context,
        builder: (_) => const _PlanTitleDialog(),
      );
      if (!context.mounted || title == null) return;
      final created = await controller.createPlanFromTemplate(
        title: title,
        templateId: template.id,
      );
      if (!context.mounted || !created) return;
      final hasQuestions =
          controller.currentPlan?.sections.any(
            (section) => section.questions.isNotEmpty,
          ) ??
          false;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider.value(
            value: controller,
            child: hasQuestions
                ? const PagePlanEditor()
                : const PagePlanPreview(),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.unknownError)),
      );
    } finally {
      _askingTitle = false;
    }
  }
}

/// The dialog owns its text controller for the entire route animation.
class _PlanTitleDialog extends StatefulWidget {
  const _PlanTitleDialog();
  @override
  State<_PlanTitleDialog> createState() => _PlanTitleDialogState();
}

class _PlanTitleDialogState extends State<_PlanTitleDialog> {
  final _title = TextEditingController();
  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(loc.planTitle),
      content: TextField(controller: _title, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _title,
          builder: (_, value, _) => ElevatedButton(
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, value.text.trim()),
            child: Text(loc.create),
          ),
        ),
      ],
    );
  }
}
