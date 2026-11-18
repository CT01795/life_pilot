import 'package:flutter/material.dart';

class WidgetsAccountSearchField extends StatelessWidget {
  const WidgetsAccountSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: MaterialLocalizations.of(context).cancelButtonLabel,
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onClear();
                  },
                ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: onChanged,
        onSubmitted: onChanged,
      ),
    ),
  );
}
