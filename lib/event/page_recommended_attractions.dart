import 'package:flutter/material.dart';
import 'package:life_pilot/event/page_recommended_content.dart';

class PageRecommendPlaces extends StatelessWidget {
  const PageRecommendPlaces({super.key});

  @override
  Widget build(BuildContext context) =>
      const RecommendedContentPage(kind: RecommendedContentKind.attraction);
}
