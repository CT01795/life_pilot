import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/feedback/controller_feedback_admin.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:provider/provider.dart';

class PageFeedbackAdmin extends StatelessWidget {
  const PageFeedbackAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ControllerAuth>();
    final loc = AppLocalizations.of(context)!;

    if (!auth.isSysAdmin) {
      return const Scaffold(
        body: Center(child: Text('Access denied')),
      );
    }

    return ChangeNotifierProvider(
      create: (_) =>
          ControllerFeedbackAdmin(ServiceFeedback(), auth)..loadFeedback(),
      child: Consumer<ControllerFeedbackAdmin>(
        builder: (context, controller, _) {
          return Scaffold(
            body: controller.isLoading
                ? const Center(child: CircularProgressIndicator())
                : controller.loadError != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_outlined, size: 48),
                            Gaps.h8,
                            Text(loc.dashboardLoadFailed),
                            Gaps.h8,
                            OutlinedButton.icon(
                              onPressed: controller.loadFeedback,
                              icon: const Icon(Icons.refresh),
                              label: Text(loc.retry),
                            ),
                          ],
                        ),
                      )
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
                                      ? const Icon(Icons.check,
                                          color: Colors.green)
                                      : ElevatedButton(
                                          onPressed: () =>
                                              controller.markAsDone(
                                                  feedback,
                                                  auth.currentAccount ??
                                                      AuthConstants.guest),
                                          child: const Text('Mark Done'),
                                        ),
                                  onTap: () async {
                                    showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text(feedback.subject,
                                            style:
                                                const TextStyle(fontSize: 20)),
                                        content: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(feedback.content),
                                              Gaps.h8,
                                              // ✅ 多張截圖縮圖化顯示
                                              if (feedback.screenshot != null &&
                                                  feedback
                                                      .screenshot!.isNotEmpty)
                                                FutureBuilder<List<Uint8List>>(
                                                  future: feedback
                                                      .decodeScreenshotsAsync(),
                                                  builder: (context, snapshot) {
                                                    if (snapshot.hasError) {
                                                      return Icon(
                                                        Icons
                                                            .broken_image_outlined,
                                                        size: 44,
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .error,
                                                      );
                                                    }
                                                    if (!snapshot.hasData) {
                                                      return const Padding(
                                                        padding:
                                                            EdgeInsets.all(8),
                                                        child:
                                                            CircularProgressIndicator(),
                                                      );
                                                    }

                                                    final images =
                                                        snapshot.data!;
                                                    final thumbnailCacheSize = (120 *
                                                            MediaQuery
                                                                .devicePixelRatioOf(
                                                                    context))
                                                        .round();
                                                    return Wrap(
                                                      spacing: 8,
                                                      runSpacing: 8,
                                                      children:
                                                          images.map((bytes) {
                                                        return GestureDetector(
                                                          onTap: () =>
                                                              showDialog(
                                                            context: context,
                                                            builder: (_) =>
                                                                Dialog(
                                                              child:
                                                                  InteractiveViewer(
                                                                child: Image
                                                                    .memory(
                                                                        bytes),
                                                              ),
                                                            ),
                                                          ),
                                                          child: Image.memory(
                                                            bytes,
                                                            width: 120,
                                                            height: 120,
                                                            fit: BoxFit.cover,
                                                            cacheWidth:
                                                                thumbnailCacheSize,
                                                            cacheHeight:
                                                                thumbnailCacheSize,
                                                            filterQuality:
                                                                FilterQuality
                                                                    .low,
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
