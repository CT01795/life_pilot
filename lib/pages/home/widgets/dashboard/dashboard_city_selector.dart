import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/city_search_delegate.dart';

typedef DashboardCityChanged = Future<void> Function(String city);

/// Shared city picker for recommendation dashboard sections.
class DashboardCitySelector extends StatelessWidget {
  const DashboardCitySelector({
    super.key,
    required this.selectedCity,
    required this.cities,
    required this.isLoading,
    required this.onChanged,
  });

  final String selectedCity;
  final List<DashboardCity> cities;
  final bool isLoading;
  final DashboardCityChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Tooltip(
      message: loc.selectCity,
      child: OutlinedButton.icon(
        icon: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.location_on),
        label: Text(selectedCity, maxLines: 1, overflow: TextOverflow.ellipsis),
        onPressed: isLoading ? null : () => _selectCity(context, loc),
      ),
    );
  }

  Future<void> _selectCity(BuildContext context, AppLocalizations loc) async {
    final city = await showSearch<String>(
      context: context,
      delegate: CitySearchDelegate(cities),
    );
    if (!context.mounted || city == null) return;

    final normalizedCity = city.trim();
    if (normalizedCity.isEmpty || normalizedCity == selectedCity) return;

    try {
      await onChanged(normalizedCity);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.dashboardSettingSaveFailed)));
    }
  }
}
