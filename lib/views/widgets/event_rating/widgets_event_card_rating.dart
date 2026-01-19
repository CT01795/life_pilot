import 'package:flutter/material.dart';
import 'package:life_pilot/controllers/event_rating/controller_event_rating.dart';
import 'package:life_pilot/models/event/model_event_item.dart';
import 'package:life_pilot/views/widgets/event_rating/widgets_event_rating_emoji.dart';

class EventCardRating extends StatefulWidget {
  final EventItem event;
  final ControllerEventRating controller;

  const EventCardRating({super.key, required this.event, required this.controller});

  @override
  State<EventCardRating> createState() => _EventCardRatingState();
}

class _EventCardRatingState extends State<EventCardRating> {
  int rating = 0;
  TextEditingController commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final r = widget.controller.getEventRating(widget.event.id);
    if (r != null) {
      rating = r.rating;
      commentController.text = r.comment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.event.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            EventRatingEmoji(
              rating: rating,
              onRatingChanged: (value) {
                setState(() => rating = value);
                widget.controller.submitEventRating(widget.event.id, rating, commentController.text);
              },
            ),
            const SizedBox(height: 6),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                hintText: '留下評論...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (text) {
                widget.controller.submitEventRating(widget.event.id, rating, text);
              },
            ),
          ],
        ),
      ),
    );
  }
}
