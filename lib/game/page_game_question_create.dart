import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_pilot/game/game_question_authoring_rules.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';
import 'package:life_pilot/subscription/widgets_subscription_usage.dart';
import 'package:life_pilot/auth/controller_auth.dart';
import 'package:provider/provider.dart';

enum _QuestionKind { grammar, sentence, speaking, translation }

class PageGameQuestionCreate extends StatefulWidget {
  const PageGameQuestionCreate({
    super.key,
    required this.gameName,
    required this.initialLevel,
    this.existingQuestion,
    this.initialQuestion,
    this.initialGroup,
  });

  final String gameName;
  final int initialLevel;
  final MyGameQuestion? existingQuestion;
  final String? initialQuestion;
  final String? initialGroup;

  @override
  State<PageGameQuestionCreate> createState() => _PageGameQuestionCreateState();
}

class _PageGameQuestionCreateState extends State<PageGameQuestionCreate> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  final _groupController = TextEditingController();
  final _customGroupLevelController = TextEditingController();
  final _optionsController = TextEditingController();
  final _service = ServiceGame();

  late int _level;
  late final _QuestionKind _kind;
  late final List<String> _fixedGroups;
  final List<String> _availableGroups = [];
  String? _selectedGroup;
  bool _useCustomGroup = false;
  String _customGroupBase = '';
  bool _isSaving = false;
  GameQuestionHint? _questionHint;
  bool _isLoadingHint = false;
  int _hintRequestId = 0;
  bool _canPop = false;
  bool _isConfirmingExit = false;
  late final String _initialQuestion;
  late final String _initialAnswer;
  late final String _initialGroup;
  late final String _initialOptions;
  late final int _initialLevel;

  bool get _usesPluralGrammarTemplate {
    if (_kind != _QuestionKind.grammar) return false;
    final group = (_selectedGroup ?? _groupController.text).toLowerCase();
    return group.contains('plural') ||
        (widget.existingQuestion?.question.contains('<--> many') ?? false);
  }

  bool get _allowsNumberedCustomGroup =>
      GameQuestionAuthoringRules.isNumberedLanguageGame(widget.gameName);

  bool get _isQuestionBankAdmin =>
      supabase.auth.currentUser?.id == AuthConstants.systemQuestionBankOwnerId;

  bool get _allowsCustomGroup =>
      GameQuestionAuthoringRules.canCreateCustomGroup(
        isAdmin: _isQuestionBankAdmin,
        gameName: widget.gameName,
      );

  String _groupWithoutLevel(String group) =>
      GameQuestionAuthoringRules.groupWithoutLevel(group);

  int _levelFromGroup(String group) =>
      GameQuestionAuthoringRules.levelFromGroup(group);

  String get _resolvedGroup {
    if (!_useCustomGroup) return _selectedGroup?.trim() ?? '';
    if (!_allowsNumberedCustomGroup) return _groupController.text.trim();
    return GameQuestionAuthoringRules.numberedGroup(
      base: _customGroupBase,
      suffix: _customGroupLevelController.text,
    );
  }

  @override
  void initState() {
    super.initState();
    _level = widget.initialLevel.clamp(1, 30);
    final name = widget.gameName.toLowerCase();
    if (name == 'english rpg adventure') {
      _kind = _QuestionKind.grammar;
    } else if (name == 'speaking') {
      _kind = _QuestionKind.speaking;
    } else if (name == 'word and sentence builder') {
      _kind = _QuestionKind.sentence;
    } else {
      _kind = _QuestionKind.translation;
    }

    if (name == 'word searching') {
      _fixedGroups = const ['英翻中Word'];
    } else if (widget.gameName.contains('日')) {
      _fixedGroups = const ['日翻中句子', '日翻中句子4', '日翻中句子7'];
    } else if (widget.gameName.contains('韓')) {
      _fixedGroups = const [
        '韓翻中句子',
        '韓翻中句子4',
        '韓翻中英句子',
        '韓翻中英句子4',
      ];
    } else if (_kind == _QuestionKind.translation) {
      _fixedGroups = const [
        '中翻英Word',
        '英翻中Word',
        'English sentences',
        'English sentences reverse',
      ];
    } else {
      _fixedGroups = const [];
    }
    _availableGroups.addAll(_fixedGroups);
    if (_availableGroups.isNotEmpty) _selectedGroup = _availableGroups.first;
    final initialGroup = widget.initialGroup?.trim() ?? '';
    if (initialGroup.isNotEmpty) {
      if (!_availableGroups.contains(initialGroup)) {
        _availableGroups.add(initialGroup);
      }
      _selectedGroup = initialGroup;
      if (_allowsNumberedCustomGroup) {
        _level = _levelFromGroup(initialGroup);
      }
    }
    _questionController.text = widget.initialQuestion?.trim() ?? '';
    _customGroupBase =
        _selectedGroup == null ? '' : _groupWithoutLevel(_selectedGroup!);

    final existing = widget.existingQuestion;
    if (existing != null) {
      _level = existing.level.clamp(1, 30);
      if (_kind == _QuestionKind.grammar) {
        _questionController.text =
            existing.question.split(RegExp(r'\s*(?:<-->|↔)\s*')).first.trim();
      } else if (_kind != _QuestionKind.sentence) {
        _questionController.text = existing.question;
      }
      _answerController.text = existing.answer;
      if (_kind == _QuestionKind.grammar) {
        if (existing.question.contains('<--> many')) {
          _questionController.text =
              existing.question.split('<--> many').first.trim();
        } else {
          _questionController.text = existing.question.replaceFirst(
            RegExp(r'_{2,}'),
            existing.answer,
          );
        }
      }
      _groupController.text = existing.group;
      _optionsController.text = (existing.options ?? '').split('_').join(', ');
      if (!_availableGroups.contains(existing.group)) {
        _availableGroups.add(existing.group);
      }
      _selectedGroup = existing.group;
      if (_allowsNumberedCustomGroup) {
        _level = _levelFromGroup(existing.group);
      }
    }
    _initialQuestion = _questionController.text;
    _initialAnswer = _answerController.text;
    _initialGroup = _selectedGroup ?? _groupController.text;
    _initialOptions = _optionsController.text;
    _initialLevel = _level;
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups =
          await _service.fetchMyQuestionGroups(gameName: widget.gameName);
      if (!mounted) return;
      setState(() {
        for (final group in groups) {
          if (!_availableGroups.contains(group)) _availableGroups.add(group);
        }
        _availableGroups.sort();
        _selectedGroup ??=
            _availableGroups.isEmpty ? null : _availableGroups.first;
      });
      if (widget.existingQuestion == null && _selectedGroup != null) {
        await _loadQuestionHint(_selectedGroup!);
      }
    } catch (_) {
      // The form can still use its built-in categories if loading fails.
    }
  }

  Future<void> _loadQuestionHint(String group) async {
    if (widget.existingQuestion != null) return;
    final requestId = ++_hintRequestId;
    setState(() {
      _isLoadingHint = true;
      _questionHint = null;
    });
    try {
      final hint = await _service.fetchAdminQuestionHint(
        gameName: widget.gameName,
        group: group,
      );
      if (!mounted || requestId != _hintRequestId) return;
      setState(() => _questionHint = hint);
    } catch (_) {
      if (mounted && requestId == _hintRequestId) {
        setState(() => _questionHint = null);
      }
    } finally {
      if (mounted && requestId == _hintRequestId) {
        setState(() => _isLoadingHint = false);
      }
    }
  }

  String get _displayHintQuestion {
    final hint = _questionHint;
    if (hint == null) return '';
    if (_kind == _QuestionKind.sentence || _kind == _QuestionKind.speaking) {
      return hint.answer;
    }
    if (_kind == _QuestionKind.grammar) {
      return GameQuestionAuthoringRules.grammarHint(
        question: hint.question,
        answer: hint.answer,
        isPlural: _usesPluralGrammarTemplate,
      );
    }
    return hint.question;
  }

  bool get _showQuestionHint =>
      widget.existingQuestion == null && _questionHint != null;

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _groupController.dispose();
    _customGroupLevelController.dispose();
    _optionsController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.requiredField;
    }
    return null;
  }

  String _creationHelp(AppLocalizations loc) {
    final name = widget.gameName.toLowerCase();
    if (_kind == _QuestionKind.grammar) {
      return loc.grammarQuestionHelp;
    }
    if (_kind == _QuestionKind.sentence) {
      return loc.sentenceQuestionHelp;
    }
    if (_kind == _QuestionKind.speaking) {
      return loc.speakingQuestionHelp;
    }
    if (name == 'word searching') {
      return loc.wordSearchQuestionHelp;
    }
    if (widget.gameName.contains('日')) {
      return loc.japaneseTranslationQuestionHelp;
    }
    if (widget.gameName.contains('韓')) {
      return loc.koreanTranslationQuestionHelp;
    }
    return loc.translationQuestionHelp;
  }

  bool get _hasUnsavedChanges {
    return _questionController.text != _initialQuestion ||
        _answerController.text != _initialAnswer ||
        (_selectedGroup ?? _groupController.text) != _initialGroup ||
        _customGroupLevelController.text.isNotEmpty ||
        _optionsController.text != _initialOptions ||
        _level != _initialLevel;
  }

  Future<void> _handlePop(bool didPop, Object? result) async {
    if (didPop || _isConfirmingExit) return;
    if (result == true || !_hasUnsavedChanges) {
      _allowPop(result);
      return;
    }

    _isConfirmingExit = true;
    final loc = AppLocalizations.of(context)!;
    final discard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            content: Text(loc.unsavedChangesPrompt),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(loc.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(loc.confirm),
              ),
            ],
          ),
        ) ??
        false;
    _isConfirmingExit = false;
    if (mounted && discard) _allowPop(result);
  }

  void _allowPop(Object? result) {
    if (!mounted) return;
    setState(() => _canPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, result);
    });
  }

  Future<void> _save() async {
    if (_kind == _QuestionKind.sentence) {
      _questionController.text = GameQuestionAuthoringRules.sentenceQuestion(
        _answerController.text,
      );
    }
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context)!;
    final group = _resolvedGroup;
    if (_allowsNumberedCustomGroup) {
      _level = _levelFromGroup(group);
    }
    setState(() => _isSaving = true);
    try {
      switch (_kind) {
        case _QuestionKind.grammar:
          final answer = _answerController.text.trim();
          final completedQuestion = _questionController.text.trim();
          final question = GameQuestionAuthoringRules.grammarQuestion(
            completedQuestion: completedQuestion,
            answer: answer,
            isPlural: _usesPluralGrammarTemplate,
          );
          if (!_usesPluralGrammarTemplate &&
              !GameQuestionAuthoringRules.grammarAnswerAppears(
                completedQuestion: completedQuestion,
                answer: answer,
              )) {
            throw FormatException(loc.grammarAnswerMustAppear);
          }
          if (_usesPluralGrammarTemplate) {
            _optionsController.text = '$completedQuestion, $answer';
          }
          final options = _optionsController.text
              .split(RegExp(r'[,，_\n]'))
              .map((option) => option.trim())
              .where((option) => option.isNotEmpty)
              .toSet()
              .toList();
          if (!options.contains(_answerController.text.trim())) {
            options.add(_answerController.text.trim());
          }
          if (options.length < 2) {
            throw FormatException(loc.twoOptionsRequired);
          }
          if (widget.existingQuestion == null) {
            await _service.addGrammarQuestion(
              question: question,
              answer: answer,
              group: group,
              level: _level,
              options: options,
            );
          } else {
            await _service.updateGrammarQuestion(
              id: widget.existingQuestion!.id,
              question: question,
              answer: answer,
              group: group,
              level: _level,
              options: options,
            );
          }
          break;
        case _QuestionKind.sentence:
          final words = _questionController.text.trim().contains('_')
              ? _questionController.text.trim()
              : _questionController.text.trim().split(RegExp(r'\s+')).join('_');
          if (widget.existingQuestion == null) {
            await _service.addSentenceQuestion(
              question: words,
              answer: _answerController.text,
              group: group,
              level: _level,
            );
          } else {
            await _service.updateSentenceQuestion(
              id: widget.existingQuestion!.id,
              question: words,
              answer: _answerController.text,
              group: group,
              level: _level,
            );
          }
          break;
        case _QuestionKind.speaking:
          if (widget.existingQuestion == null) {
            await _service.addSentenceQuestion(
              question: _answerController.text,
              answer: _answerController.text,
              group: group,
              level: _level,
            );
          } else {
            await _service.updateSentenceQuestion(
              id: widget.existingQuestion!.id,
              question: _answerController.text,
              answer: _answerController.text,
              group: group,
              level: _level,
            );
          }
          break;
        case _QuestionKind.translation:
          if (widget.existingQuestion == null) {
            await _service.addTranslationQuestion(
              question: _questionController.text,
              answer: _answerController.text,
              group: group,
              level: _level,
            );
          } else {
            await _service.updateTranslationQuestion(
              id: widget.existingQuestion!.id,
              question: _questionController.text,
              answer: _answerController.text,
              group: group,
              level: _level,
            );
          }
          break;
      }
      if (!mounted) return;
      if (widget.existingQuestion == null) {
        await context.read<ControllerAuth>().refreshSubscriptionUsage();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingQuestion == null
                ? loc.questionAdded
                : loc.questionUpdated,
          ),
        ),
      );
      Navigator.pop(context, true);
    } on DuplicateGameQuestionException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.duplicateQuestion)),
        );
      }
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (error) {
      if (mounted) {
        final message = subscriptionErrorMessage(loc, error);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.isEmpty ? loc.unknownError : message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final isSpeaking = _kind == _QuestionKind.speaking;
    return PopScope<Object?>(
      canPop: _canPop,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.existingQuestion == null
                ? loc.addQuestion
                : loc.editQuestion,
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.existingQuestion == null)
                  const SubscriptionUsageBanner(resource: 'game_questions'),
                Card(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.lightbulb_outline),
                        const SizedBox(width: 12),
                        Expanded(child: Text(_creationHelp(loc))),
                      ],
                    ),
                  ),
                ),
                Gaps.h16,
                if (_isLoadingHint && widget.existingQuestion == null)
                  const Center(child: LinearProgressIndicator()),
                if (_showQuestionHint) ...[
                  Card(
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc.questionExample,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(_displayHintQuestion),
                          Gaps.h8,
                          Text(
                            loc.answerExample,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          Text(_questionHint!.answer),
                        ],
                      ),
                    ),
                  ),
                  Gaps.h16,
                ],
                if (!isSpeaking && _kind != _QuestionKind.sentence)
                  TextFormField(
                    controller: _questionController,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _kind == _QuestionKind.grammar
                          ? _usesPluralGrammarTemplate
                              ? loc.grammarBaseWord
                              : loc.completedGrammarQuestion
                          : loc.question,
                      border: const OutlineInputBorder(),
                    ),
                    validator: _required,
                  ),
                if (!isSpeaking && _kind != _QuestionKind.sentence) Gaps.h16,
                TextFormField(
                  controller: _answerController,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: _kind == _QuestionKind.sentence
                        ? loc.sentenceOrWord
                        : isSpeaking
                            ? loc.speakingText
                            : loc.correctAnswer,
                    border: const OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
                if (_kind == _QuestionKind.grammar &&
                    !_usesPluralGrammarTemplate) ...[
                  Gaps.h16,
                  TextFormField(
                    controller: _optionsController,
                    minLines: 1,
                    maxLines: 2,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: loc.answerOptions,
                      helperText: loc.answerOptionsHint,
                      border: const OutlineInputBorder(),
                    ),
                    validator: _required,
                  ),
                ],
                Gaps.h16,
                DropdownButtonFormField<String>(
                  key: ValueKey('$_selectedGroup-$_useCustomGroup'),
                  initialValue: _useCustomGroup ? '__custom__' : _selectedGroup,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: loc.questionGroup,
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    ..._availableGroups.map((group) => DropdownMenuItem(
                          value: group,
                          child: Tooltip(
                            message: group,
                            child: Text(
                              group,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )),
                    if (_allowsCustomGroup)
                      DropdownMenuItem(
                        value: '__custom__',
                        child: Text(loc.customQuestionGroup),
                      ),
                  ],
                  validator: (value) =>
                      value == null ? loc.requiredField : null,
                  onChanged: (value) {
                    setState(() {
                      if (value == '__custom__') {
                        if (_allowsNumberedCustomGroup) {
                          _customGroupBase = _groupWithoutLevel(
                            _selectedGroup ?? _availableGroups.first,
                          );
                        }
                        _customGroupLevelController.clear();
                        _groupController.clear();
                        _useCustomGroup = true;
                        _selectedGroup = null;
                      } else {
                        _useCustomGroup = false;
                        _selectedGroup = value;
                        if (value != null && _allowsNumberedCustomGroup) {
                          _level = _levelFromGroup(value);
                        }
                      }
                      _questionHint = null;
                    });
                    if (value != null && value != '__custom__') {
                      _loadQuestionHint(value);
                    }
                  },
                ),
                if (_useCustomGroup) ...[
                  Gaps.h16,
                  if (_allowsNumberedCustomGroup)
                    TextFormField(
                      controller: _customGroupLevelController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: InputDecoration(
                        labelText: loc.questionGroupLevelNumber,
                        prefixText: _customGroupBase,
                        border: const OutlineInputBorder(),
                      ),
                    )
                  else
                    TextFormField(
                      controller: _groupController,
                      decoration: InputDecoration(
                        labelText: loc.newQuestionGroup,
                        border: const OutlineInputBorder(),
                      ),
                      validator: _required,
                    ),
                ],
                Gaps.h16,
                if (!_allowsNumberedCustomGroup)
                  DropdownButtonFormField<int>(
                    initialValue: _level,
                    decoration: InputDecoration(
                      labelText: loc.gameLevel,
                      border: const OutlineInputBorder(),
                    ),
                    items: List.generate(
                      30,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) setState(() => _level = value);
                    },
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(loc.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
