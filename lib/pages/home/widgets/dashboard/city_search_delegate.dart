import 'package:flutter/material.dart';
import 'package:life_pilot/pages/home/model/dashboard/dashboard_city.dart';

class CitySearchDelegate extends SearchDelegate<String> {
  final List<DashboardCity> cities;

  CitySearchDelegate(
    this.cities,
  );

  @override
  List<Widget>? buildActions(BuildContext context) {
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
    return _buildList();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildList();
  }

  Widget _buildList() {
    final list = cities.where((e) {
      return e.name.contains(query);
    }).toList();

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final city = list[index];

        return ListTile(
          title: Text(city.name),
          subtitle: Text(
            '${city.count}',
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
