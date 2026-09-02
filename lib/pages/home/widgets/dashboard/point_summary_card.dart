import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_card_header.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_load_failure.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_section_loading.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/point_selector_button.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:provider/provider.dart';

class PointSummaryCard extends StatelessWidget {
  const PointSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final records = context.select<ModelDashboard, List<PointRecordItem>>(
      (m) => m.state.todayPoints,
    );
    final hasLoadFailed = context.select<ModelDashboard, bool>(
      (m) => m.hasFailed(DashboardSection.points),
    );
    final isLoading = context.select<ModelDashboard, bool>(
      (m) => m.isLoading(DashboardSection.points),
    );
    final hasSelectedAccount = context.select<ModelDashboard, bool>(
      (m) => m.setting.pointAccountId != null,
    );

    final todayTotal = context.select<ModelDashboard, int>(
      (m) => m.state.todayPointsTotal,
    );
    final pointsTotal = context.select<ModelDashboard, int>(
      (m) => m.state.pointsTotal,
    );

    final formatter = NumberFormat('#,###');

    return Card(
      color: colorScheme.brightness == Brightness.dark
          ? colorScheme.surfaceContainerHigh
          : const Color(0xFFEDE6C8),
      elevation: 2,
      child: Padding(
        padding: Insets.all12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardCardHeader(
              icon: Icons.stars,
              title: loc.pointsRecord,
              trailing: const PointSelectorButton(),
            ),
            if (!hasSelectedAccount)
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(loc.selectAccount),
              )
            else ...[
              Gaps.h16,
              ListTile(
                dense: true,
                title: Text(
                  loc.totalPoints,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                trailing: Text(
                  formatter.format(pointsTotal),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: pointsTotal < 0
                            ? colorScheme.error
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              ListTile(
                dense: true,
                title: Text(loc.todayPoints,
                    style: Theme.of(context).textTheme.titleMedium),
                trailing: Text(
                  formatter.format(todayTotal),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: todayTotal < 0
                            ? colorScheme.error
                            : colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Divider(),
              if (isLoading && records.isNotEmpty)
                const LinearProgressIndicator(),
              if (hasLoadFailed)
                DashboardLoadFailure(
                  onRetry: () => context.read<ModelDashboard>().retrySection(
                        section: DashboardSection.points,
                        account: context.read<ModelAuthView>().account!,
                      ),
                )
              else if (isLoading && records.isEmpty)
                const DashboardSectionLoading()
              else if (records.isEmpty)
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(loc.noInfoAvailable),
                )
              else
                ...records.take(5).map(
                      (record) => ListTile(
                        dense: true,
                        title: Text(record.description,
                            style: Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(
                            record.group == null || record.group!.isEmpty
                                ? ''
                                : record.group!,
                            style: Theme.of(context).textTheme.titleMedium),
                        trailing: Text(
                          formatter.format(record.value),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: record.value < 0
                                        ? colorScheme.error
                                        : colorScheme.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ),
                    ),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  context
                      .read<ControllerPageMain>()
                      .changePage(PageType.pointsRecord);
                },
                child: Text(loc.clickHereToSeeMore),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
