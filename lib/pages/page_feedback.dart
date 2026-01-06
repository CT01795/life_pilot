import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/auth/controller_auth.dart';
import 'package:life_pilot/controllers/controller_feedback.dart';
import 'package:life_pilot/core/const.dart';
import 'package:life_pilot/services/service_feedback.dart';
import 'package:provider/provider.dart';

class PageFeedback extends StatelessWidget {
  const PageFeedback({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          ControllerFeedback(ServiceFeedback(), context.read<ControllerAuth>()),
      child: const PageFeedbackBody(),
    );
  }
}

class PageFeedbackBody extends StatelessWidget {
  const PageFeedbackBody({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ControllerFeedback>();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(2),
        child: ListView(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Purpose'),
              onChanged: (v) => controller.subject = v,
            ),
            TextField(
              decoration:
                  const InputDecoration(labelText: 'Copy (comma separated)'),
              onChanged: (v) => controller.ccRaw = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Content'),
              maxLines: 4,
              onChanged: (v) => controller.content = v,
            ),
            Gaps.h8,
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Capture screen'),
              onPressed: controller.captureScreenshot,
            ),
            if (controller.screenshot.isNotEmpty == true)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: controller.screenshot
                      .map((imgBytes) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              imgBytes,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ))
                      .toList(),
                ),
              ),
            Gaps.h8,
            ElevatedButton(
              onPressed: controller.isSending
                  ? null
                  : () => controller.submit(context),
              child: controller.isSending
                  ? const CircularProgressIndicator()
                  : const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
