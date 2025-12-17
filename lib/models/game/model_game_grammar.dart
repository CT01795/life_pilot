class ModelGameGrammarQuestion {
  final String questionId;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String type;
  bool? isRight;

  ModelGameGrammarQuestion ({
    required this.questionId,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.type,
    this.isRight,
  });
}

class ModelGameGrammarPlayer {
  int hp = 100;
  int attack = 20;
}

class ModelGameGrammarMonster {
  String name;
  int hp;
  int attack;

  ModelGameGrammarMonster(this.name, this.hp, this.attack);
}

class ModelGameGrammar {
  ModelGameGrammarPlayer player = ModelGameGrammarPlayer();
  ModelGameGrammarMonster? monster;
  ModelGameGrammarQuestion? currentQuestion;
}