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
          final visibleFeedback = controller.visibleFeedback;
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
                        itemCount: visibleFeedback.length +
                            1 +
                            ((controller.hasMore || controller.isLoadingMore)
                                ? 1
                                : 0),
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Padding(
                              padding: const EdgeInsets.all(8),
                              child: Wrap(
                                spacing: 8,
                                children: [
                                  for (final entry in {
                                    'in_progress': loc.statusInProgress,
                                    'pending': loc.statusPending,
                                    'completed': loc.statusCompleted,
                                  }.entries)
                                    FilterChip(
                                      label: Text(entry.value),
                                      selected: controller.selectedStatuses
                                          .contains(entry.key),
                                      onSelected: (_) =>
                                          controller.toggleStatus(entry.key),
                                    ),
                                ],
                              ),
                            );
                          }
                          index--;
                          if (index == visibleFeedback.length) {
                            return Center(
                              child: controller.isLoadingMore
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(),
                                    )
                                  : TextButton(
                                      onPressed: controller.loadMore,
                                      child: Text(loc.clickHereToSeeMore),
                                    ),
                            );
                          }
                          final feedback = visibleFeedback[index];
                          return Selector<ControllerFeedbackAdmin, bool>(
                              selector: (_, c) => feedback.isOk ?? false,
                              builder: (context, isOk, child) {
                                return ListTile(
                                  title: Text(feedback.subject),
                                  subtitle: Text(feedback.content),
                                  trailing: DropdownButton<String>(
                                    value: feedback.status,
                                    items: [
                                      DropdownMenuItem(
                                        value: 'in_progress',
                                        child: Text(loc.statusInProgress),
                                      ),
                                      DropdownMenuItem(
                                        value: 'pending',
                                        child: Text(loc.statusPending),
                                      ),
                                      DropdownMenuItem(
                                        value: 'completed',
                                        child: Text(loc.statusCompleted),
                                      ),
                                    ],
                                    onChanged: (status) {
                                      if (status != null) {
                                        controller.updateStatus(
                                          feedback,
                                          status,
                                          auth.currentAccount ??
                                              AuthConstants.guest,
                                        );
                                      }
                                    },
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
