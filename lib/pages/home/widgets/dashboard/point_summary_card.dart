import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:life_pilot/apps/controller_page_main.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/model/point/point_record_item.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_card_header.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/point_selector_button.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/enum.dart';
import 'package:provider/provider.dart';

class PointSummaryCard extends StatelessWidget {
  const PointSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final records = context.select<ModelDashboard, List<PointRecordItem>>(
      (m) => m.state.todayPoints,
    );

    final total = records.fold<int>(
      0,
      (sum, e) => sum + e.value,
    );

    final formatter = NumberFormat('#,###');
    
    return Card(
      color: Color(0xFFEDE6C8),
      elevation: 2,
      child: Padding(
        padding: Insets.all12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DashboardCardHeader(
              icon: Icons.stars,
              title: loc.pointsRecord,
              trailing:const PointSelectorButton(),
            ),
            Gaps.h16,
            ListTile(
              dense: true,
              title: Text(loc.todayPoints, style: Theme.of(context).textTheme.titleMedium),
              trailing: Text(
                formatter.format(total),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: total < 0
                          ? Colors.red 
                          : Colors.black, 
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const Divider(),

            if (records.isEmpty)
              ListTile(
                leading: Icon(Icons.info_outline),
                 title: Text(loc.noInfoAvailable),
              )
            else
              ...records.map(
                (record) => ListTile(
                  dense: true,
                  title: Text(record.description,
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(
                      record.group == null || record.group!.isEmpty ? '' : record.group!,
                      style: Theme.of(context).textTheme.titleMedium),
                  trailing: Text(
                    formatter.format(record.value),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: record.value < 0
                              ? Colors.red
                              : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ),
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
