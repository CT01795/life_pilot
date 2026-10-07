import 'package:flutter/material.dart';
import 'package:life_pilot/auth/model_auth_view.dart';
import 'package:life_pilot/pages/home/model/dashboard/model_dashboard.dart';
import 'package:life_pilot/pages/home/widgets/dashboard/dashboard_city_selector.dart';
import 'package:provider/provider.dart';

class PlaceCitySelectorButton extends StatelessWidget {
  const PlaceCitySelectorButton({super.key});

  @override
  Widget build(BuildContext context) {
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

    return DashboardCitySelector(
      selectedCity: selectedCity,
      cities: cities,
      isLoading: isLoading,
      onChanged: (city) async {
        final account = auth.account;
        if (account == null) return;
        await dashboard.changePlaceCity(account: account, city: city);
      },
    );
  }
}
