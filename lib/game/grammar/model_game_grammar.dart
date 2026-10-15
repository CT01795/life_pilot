class ModelGameGrammarQuestion {
  final String questionId;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String type;
  bool? isRight;

  ModelGameGrammarQuestion({
    required this.questionId,
    required this.question,
    required List<String> options,
    required this.correctAnswer,
    required this.type,
    this.isRight,
  }) : options = List.unmodifiable(options);

  String get spokenQuestion =>
      question.replaceAll('______', correctAnswer).replaceAll('<-->', ',');
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
  int _answeredCount = 0;
  bool? _isRightAnswer;

  int get answeredCount => _answeredCount;
  bool? get isRightAnswer => _isRightAnswer;
  bool get isBattleOver =>
      monster != null && (monster!.hp <= 0 || player.hp <= 0);
  bool get canAnswer =>
      monster != null &&
      !isBattleOver &&
      currentQuestion != null &&
      _isRightAnswer == null;

  void startBattle(int level) {
    player = ModelGameGrammarPlayer();
    monster = ModelGameGrammarMonster('Monster', 50 + level * 10, 10);
    _answeredCount = 0;
    prepareQuestion();
  }

  void prepareQuestion() {
    currentQuestion = null;
    _isRightAnswer = null;
  }

  /// Returns null for an unavailable or already answered question.
  bool? answer(String answer) {
    if (!canAnswer) return null;
    final correct = answer == currentQuestion!.correctAnswer;
    _isRightAnswer = correct;
    _answeredCount++;
    if (correct) {
      monster!.hp -= player.attack;
    } else {
      player.hp -= monster!.attack;
    }
    return correct;
  }
}
