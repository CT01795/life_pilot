import 'package:flutter/material.dart';
import 'package:life_pilot/event/page_recommended_content.dart';

class PageRecommendEvent extends StatelessWidget {
  const PageRecommendEvent({super.key});

  @override
  Widget build(BuildContext context) =>
      const RecommendedContentPage(kind: RecommendedContentKind.event);
}
