import 'package:flutter/material.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';

class CitySearchDelegate extends SearchDelegate<String> {
  final List<DashboardCity> cities;

  CitySearchDelegate(
    this.cities,
  );

  @override
  List<Widget>? buildActions(BuildContext context) {
    if (query.isEmpty) return null;

    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      )
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(
          context,
          '',
        );
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildList(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList(context);
  }

  Widget _buildList(BuildContext context) {
    final normalizedQuery = query.trim().toLowerCase();
    final list = cities.where((e) {
      return e.name.toLowerCase().contains(normalizedQuery);
    }).toList();

    if (list.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.noInfoAvailable),
      );
    }

    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: list.length,
      itemBuilder: (context, index) {
        final city = list[index];

        return ListTile(
          title: Text(city.name),
          trailing: Badge(
            label: Text('${city.count}'),
          ),
          onTap: () {
            close(
              context,
              city.name,
            );
          },
        );
      },
    );
  }
}
