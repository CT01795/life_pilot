import 'package:flutter/material.dart';
import 'package:life_pilot/utils/widgets/widgets_load_error.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/feedback/controller_feedback_admin.dart';
import 'package:life_pilot/feedback/service_feedback.dart';
import 'package:life_pilot/feedback/widgets_feedback_screenshots.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/value_parser.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/widgets/widgets_adaptive_button.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:provider/provider.dart';

class PageFeedbackAdmin extends StatelessWidget {
  const PageFeedbackAdmin({super.key, this.service});
  final ServiceFeedback? service;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ControllerAuth>();
    final loc = AppLocalizations.of(context)!;

    if (!auth.isSysAdmin &&
        !context.read<ControllerPageMain>().canAccess(PageType.feedbackAdmin)) {
      return Scaffold(body: Center(child: Text(loc.accessDenied)));
    }

    return ChangeNotifierProvider(
      create: (_) =>
          ControllerFeedbackAdmin(service ?? ServiceFeedback(), auth)
            ..loadFeedback(),
      child: Consumer<ControllerFeedbackAdmin>(
        builder: (context, controller, _) {
          final visibleFeedback = controller.visibleFeedback;
          return Scaffold(
            body: controller.isLoading && controller.feedbackList.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : controller.loadError != null &&
                      controller.feedbackList.isEmpty
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
                          label: AdaptiveButtonLabel(loc.retry),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount:
                        visibleFeedback.length +
                        1 +
                        (controller.hasHistoryAction ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              if (controller.loadError != null)
                                WidgetsLoadError(
                                  onRetry: controller.loadFeedback,
                                ),
                              Wrap(
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
                            ],
                          ),
                        );
                      }
                      index--;
                      if (index == visibleFeedback.length) {
                        return Center(
                          child:
                              controller.isLoadingMore ||
                                  controller.isCheckingHistory
                              ? const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(),
                                )
                              : controller.historyError != null
                              ? TextButton.icon(
                                  onPressed: controller.retryHistory,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(loc.retry),
                                )
                              : controller.loadMoreError != null
                              ? TextButton.icon(
                                  onPressed: controller.loadMore,
                                  icon: const Icon(Icons.refresh),
                                  label: Text(loc.retry),
                                )
                              : TextButton(
                                  onPressed: controller.loadMore,
                                  child: Text(loc.clickHereToSeeMore),
                                ),
                        );
                      }
                      final feedback = visibleFeedback[index];
                      return Selector<ControllerFeedbackAdmin, (String, bool)>(
                        selector: (_, c) => (
                          feedback.status,
                          c.isUpdating(feedback.id) ||
                              c.isLoading ||
                              c.isLoadingMore,
                        ),
                        builder: (context, state, child) {
                          final statusDropdown = DropdownButton<String>(
                            isExpanded: true,
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
                            onChanged: state.$2
                                ? null
                                : (status) async {
                                    if (status != null) {
                                      final result = await controller
                                          .updateStatus(
                                            feedback,
                                            status,
                                            auth.currentAccount ??
                                                AuthConstants.guest,
                                          );
                                      if (context.mounted && result == false) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(loc.unknownError),
                                          ),
                                        );
                                      }
                                    }
                                  },
                          );
                          final compact =
                              MediaQuery.sizeOf(context).width < 520;
                          return ListTile(
                            title: Text(
                              feedback.subject,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: compact
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        feedback.content,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Gaps.h4,
                                      SizedBox(
                                        width: 180,
                                        child: statusDropdown,
                                      ),
                                    ],
                                  )
                                : Text(
                                    feedback.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            trailing: compact
                                ? null
                                : SizedBox(width: 180, child: statusDropdown),
                            onTap: () async {
                              showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: Text(
                                    feedback.subject,
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  content: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(feedback.content),
                                        Gaps.h8,
                                        WidgetsFeedbackScreenshots(
                                          feedback: feedback,
                                        ),
                                        Gaps.h8,
                                        if (feedback.isOk == true)
                                          Text(
                                            loc.feedbackProcessedBy(
                                              feedback.dealBy ?? '',
                                              parseStringValue(feedback.dealAt),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: Text(loc.close),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
