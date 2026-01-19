import 'package:flutter/material.dart';

typedef EmojiRatingCallback = void Function(int rating);

class EventRatingEmoji extends StatelessWidget {
  final int rating;
  final EmojiRatingCallback? onRatingChanged;

  const EventRatingEmoji({super.key, required this.rating, this.onRatingChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(11, (index) {
        final value = index - 5;
        bool isActive = (value != 0 && (rating >= value && rating > 0 || rating <= value && rating < 0)) || (value == 0 && rating == 0);
        String emoji = value > 0 ? '😄' : value < 0 ? '😡' : '😐';
        return GestureDetector(
          onTap: onRatingChanged != null ? () => onRatingChanged!(value) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              emoji,
              style: TextStyle(fontSize: 24, color: isActive ? Colors.orange : Colors.grey),
            ),
          ),
        );
      }),
    );
  }
}
