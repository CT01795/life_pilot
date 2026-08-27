import 'package:flutter/material.dart';
import 'package:life_pilot/utils/event_country.dart';

class WidgetsEventCountryDropdown extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  const WidgetsEventCountryDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = EventCountry.normalize(value);
    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: EventCountry.values
          .map(
            (country) => DropdownMenuItem(
              value: country.code,
              child: Text(
                '${country.label(context)} (${country.code})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (country) {
        if (country != null) onChanged(country);
      },
    );
  }
}
