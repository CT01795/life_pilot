import 'package:flutter/material.dart';

/// Keeps the read-only notice visible without pushing a small viewport's
/// contents outside the screen. Long translations can scroll independently.
class SubscriptionReadOnlyNotice extends StatelessWidget {
  const SubscriptionReadOnlyNotice({
    super.key,
    required this.message,
    required this.child,
  });
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      return Column(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .3),
            child: SingleChildScrollView(
              child: SafeArea(
                bottom: false,
                child: Material(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(message),
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      );
    },
  );
}
