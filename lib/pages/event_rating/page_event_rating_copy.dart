import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/event_rating/controller_event_rating_copy.dart';
import 'package:life_pilot/views/widgets/event_rating/widgets_event_card_rating_copy.dart';
import 'package:provider/provider.dart';

class PageEventRating extends StatefulWidget {
  const PageEventRating({super.key});

  @override
  State<PageEventRating> createState() => _PageEventRatingState();
}

class _PageEventRatingState extends State<PageEventRating> {
  final TextEditingController searchController = TextEditingController();
  String keyword = '';

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ControllerEventRatingCopy>();
    final filtered = controller.searchEvents(keyword);

    return Scaffold(
      appBar: AppBar(title: const Text('活動評價')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: '搜尋活動...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => keyword = v),
            ),
            const SizedBox(height: 12),
            if (filtered.isEmpty && keyword.isNotEmpty)
              Column(
                children: [
                  Text('找不到活動，您可以新增活動'),
                  const SizedBox(height: 6),
                  ElevatedButton(
                    onPressed: () {
                      controller.addEvent(keyword);
                      searchController.clear();
                      setState(() => keyword = '');
                    },
                    child: const Text('新增活動'),
                  ),
                ],
              ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) => EventCardRatingCopy(
                  event: filtered[i],
                  controller: controller,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
