import 'package:flutter/material.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/city_search_delegate.dart';
import 'package:provider/provider.dart';

class EventCitySelectorButton extends StatelessWidget {
  const EventCitySelectorButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final dashboard = context.watch<ModelDashboard>();
    final auth = context.read<ModelAuthView>();

    return Tooltip(
      message: loc.selectCity,
      child: OutlinedButton.icon(
        icon: const Icon(
          Icons.location_on,
        ),
        label: Text(
          dashboard.setting.recommendEventCity,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onPressed: () async {
          final city = await showSearch<String>(
            context: context,
            delegate: CitySearchDelegate(
              dashboard.eventCities,
            ),
          );

          if (city == null) {
            return;
          }

          if (auth.account == null) {
            return;
          }

          if (city == dashboard.setting.recommendEventCity) {
            return;
          }

          await dashboard.changeEventCity(
            account: auth.account!,
            city: city,
          );

          await dashboard.refreshRecommendEvent(
            account: auth.account!,
          );
        },
      ),
    );
  }
}
