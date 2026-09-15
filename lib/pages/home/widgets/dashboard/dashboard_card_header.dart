import 'package:flutter/material.dart';
import 'package:life_pilot/utils/const.dart';

class DashboardCardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final double? trailingWidth;

  const DashboardCardHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.trailingWidth = 160,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;

    return LayoutBuilder(
      builder: (context, constraints) {
        final titlePainter = TextPainter(
          text: TextSpan(text: title, style: titleStyle),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final desiredTitleWidth = 24 + 8 + titlePainter.width;
        final availableTrailingWidth = trailingWidth
            ?.clamp(0, constraints.maxWidth)
            .toDouble();
        final fitsOnOneLine =
            trailing == null ||
            availableTrailingWidth == null ||
            desiredTitleWidth + 8 + availableTrailingWidth <=
                constraints.maxWidth;
        Widget titleRow() => Row(
          children: [
            Icon(icon),
            Gaps.w8,
            Expanded(child: Text(title, style: titleStyle)),
          ],
        );

        if (trailing == null) return titleRow();

        if (availableTrailingWidth == null) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: titleRow()),
              Gaps.w8,
              trailing!,
            ],
          );
        }

        final trailingWidget = SizedBox(
          width: availableTrailingWidth,
          child: trailing,
        );
        if (fitsOnOneLine) {
          return Row(
            children: [
              Expanded(child: titleRow()),
              Gaps.w8,
              trailingWidget,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            titleRow(),
            Gaps.h8,
            Align(alignment: Alignment.centerRight, child: trailingWidget),
          ],
        );
      },
    );
  }
}
