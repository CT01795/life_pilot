import 'package:flutter/material.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/city_search_delegate.dart';
import 'package:provider/provider.dart';

class PlaceCitySelectorButton extends StatelessWidget {
  const PlaceCitySelectorButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final selectedCity = context.select<ModelDashboard, String>(
      (dashboard) => dashboard.setting.recommendPlaceCity,
    );
    final cities = context.select(
      (ModelDashboard dashboard) => dashboard.placeCities,
    );
    final dashboard = context.read<ModelDashboard>();
    final auth = context.read<ModelAuthView>();
    final isLoading = context.select<ModelDashboard, bool>(
      (dashboard) => dashboard.isLoading(DashboardSection.recommendPlaces),
    );

    return Tooltip(
      message: loc.selectCity,
      child: OutlinedButton.icon(
        icon: isLoading
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(
                Icons.location_on,
              ),
        label: Text(
          selectedCity,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: isLoading
            ? null
            : () async {
                final city = await showSearch<String>(
                  context: context,
                  delegate: CitySearchDelegate(
                    cities,
                  ),
                );

                if (city == null || city.trim().isEmpty) {
                  return;
                }

                if (auth.account == null) {
                  return;
                }

                if (city == selectedCity) {
                  return;
                }

                try {
                  await dashboard.changePlaceCity(
                    account: auth.account!,
                    city: city,
                  );
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(loc.dashboardSettingSaveFailed)),
                    );
                  }
                }
              },
      ),
    );
  }
}
