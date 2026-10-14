import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/utils/value_parser.dart';

class GameQuestionHint {
  const GameQuestionHint({required this.question, required this.answer});

  final String question;
  final String answer;
}

class MyGameQuestion {
  const MyGameQuestion({
    required this.id,
    required this.question,
    required this.answer,
    required this.group,
    required this.level,
    required this.isActive,
    this.options,
  });

  factory MyGameQuestion.fromJson(
    Map<String, dynamic> row, {
    String groupField = 'question_group',
  }) => MyGameQuestion(
    id: parseStringValue(row[Fields.id]),
    question: parseStringValue(row['question']),
    answer: parseStringValue(row['answer']),
    group: parseStringValue(row[groupField]),
    level: tryParseIntValue(row['level']) ?? 1,
    isActive: row['is_active'] == true,
    options: parseOptionalStringValue(row['options']),
  );

  final String id;
  final String question;
  final String answer;
  final String group;
  final int level;
  final bool isActive;
  final String? options;
}

class MyGameQuestionPage {
  const MyGameQuestionPage({
    required this.questions,
    required this.totalCount,
    this.hasMore,
  });

  final List<MyGameQuestion> questions;
  final int totalCount;
  final bool? hasMore;
}

class MySocialChoice {
  const MySocialChoice({
    required this.text,
    required this.score,
    required this.feedback,
    required this.isBest,
  });

  factory MySocialChoice.fromJson(Map<String, dynamic> row) => MySocialChoice(
    text: parseStringValue(row['option_text']),
    score: tryParseIntValue(row['score']) ?? 0,
    feedback: parseStringValue(row['feedback']),
    isBest: row['is_best'] == true,
  );

  final String text;
  final int score;
  final String feedback;
  final bool isBest;
}

class MySocialQuestion {
  const MySocialQuestion({
    required this.id,
    required this.title,
    required this.scene,
    required this.category,
    required this.isActive,
    required this.choices,
  });

  factory MySocialQuestion.fromJson(
    Map<String, dynamic> row, {
    bool sortChoicesByScore = false,
  }) {
    final choices = (row['choices'] as List? ?? const [])
        .map(
          (raw) =>
              MySocialChoice.fromJson(Map<String, dynamic>.from(raw as Map)),
        )
        .toList();
    if (sortChoicesByScore) {
      choices.sort((a, b) => b.score.compareTo(a.score));
    }
    return MySocialQuestion(
      id: parseStringValue(row[Fields.id]),
      title: parseStringValue(row['title']),
      scene: parseStringValue(row['scene']),
      category: parseStringValue(row['category'], fallback: 'social'),
      isActive: row['is_active'] == true,
      choices: choices,
    );
  }

  final String id;
  final String title;
  final String scene;
  final String category;
  final bool isActive;
  final List<MySocialChoice> choices;
}

class MySocialQuestionPage {
  const MySocialQuestionPage({
    required this.questions,
    required this.totalCount,
    this.hasMore,
  });

  final List<MySocialQuestion> questions;
  final int totalCount;
  final bool? hasMore;
}
