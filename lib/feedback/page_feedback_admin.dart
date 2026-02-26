import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:life_pilot/feedback/controller_feedback_admin.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

class PageFeedbackAdmin extends StatelessWidget {
  const PageFeedbackAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ControllerFeedbackAdmin()..loadFeedback(),
      child: Consumer<ControllerFeedbackAdmin>(
        builder: (context, controller, _) {
          return Scaffold(
            body: controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: controller.feedbackList.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (context, index) {
                      final feedback = controller.feedbackList[index];
                      return Selector<ControllerFeedbackAdmin, bool>(
                          selector: (_, c) =>
                              c.feedbackList[index].isOk ?? false,
                          builder: (_, isOk, __) {
                            return ListTile(
                              title: Text(feedback.subject),
                              subtitle: Text(feedback.content),
                              trailing: isOk == true
                                  ? const Icon(Icons.check, color: Colors.green)
                                  : ElevatedButton(
                                      onPressed: () => controller.markAsDone(
                                          feedback,
                                          AuthConstants.sysAdminEmail),
                                      child: const Text('Mark Done'),
                                    ),
                              onTap: () async {
                                await controller.loadFeedbackScreenshots(feedback);
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: Text(feedback.subject,
                                        style: const TextStyle(fontSize: 20)),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(feedback.content),
                                          Gaps.h8,
                                          // ✅ 多張截圖縮圖化顯示
                                          if (feedback.screenshot != null && feedback.screenshot!.isNotEmpty)
                                            FutureBuilder<List<Uint8List>>(
                                              future: feedback.decodeScreenshotsAsync(),
                                              builder: (context, snapshot) {
                                                if (!snapshot.hasData) {
                                                  return const Padding(
                                                    padding: EdgeInsets.all(8),
                                                    child: CircularProgressIndicator(),
                                                  );
                                                }

                                                final images = snapshot.data!;
                                                return Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: images.map((bytes) {
                                                    return GestureDetector(
                                                      onTap: () => showDialog(
                                                        context: context,
                                                        builder: (_) => Dialog(
                                                          child: InteractiveViewer(
                                                            child: Image.memory(bytes),
                                                          ),
                                                        ),
                                                      ),
                                                      child: Image.memory(
                                                        bytes,
                                                        width: 120,
                                                        height: 120,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    );
                                                  }).toList(),
                                                );
                                              },
                                            ),
                                          Gaps.h8,
                                          if (feedback.isOk == true)
                                            Text(
                                                'Processed by: ${feedback.dealBy} at ${feedback.dealAt}'),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Close')),
                                    ],
                                  ),
                                );
                              },
                            );
                          });
                    },
                  ),
          );
        },
      ),
    );
  }
}
