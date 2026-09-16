import 'package:flutter/material.dart';

class DashboardHeaderSummary extends StatelessWidget {
  const DashboardHeaderSummary({
    super.key,
    required this.value,
    required this.tooltip,
    this.isLoading = false,
  });

  final String value;
  final String tooltip;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        value: isLoading ? null : value,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 112, minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.primary,
                  ),
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
