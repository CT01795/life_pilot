import 'package:flutter/material.dart';
import 'package:life_pilot/utils/const.dart';

class DashboardCardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;

  const DashboardCardHeader({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon),
        Gaps.w8,
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (trailing != null) ...[
          Gaps.w8,
          Flexible(
            child: trailing!,
          ),
        ],
      ],
    );
  }
}
