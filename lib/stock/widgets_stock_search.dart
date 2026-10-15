import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';

/// Keeps text input aligned with the Controller, including external clearing.
class WidgetsStockSearch extends StatefulWidget {
  const WidgetsStockSearch({
    super.key,
    required this.query,
    required this.onChanged,
  });
  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<WidgetsStockSearch> createState() => _WidgetsStockSearchState();
}

class _WidgetsStockSearchState extends State<WidgetsStockSearch> {
  late final TextEditingController _text;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant WidgetsStockSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text.text != widget.query) {
      _text.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return TextField(
      controller: _text,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(Icons.search),
        labelText: loc.search,
        border: const OutlineInputBorder(),
        suffixIcon: widget.query.isEmpty
            ? null
            : IconButton(
                tooltip: loc.clear,
                onPressed: () => widget.onChanged(''),
                icon: const Icon(Icons.clear),
              ),
      ),
    );
  }
}
