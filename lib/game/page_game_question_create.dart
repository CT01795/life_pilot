import 'package:flutter/material.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/const.dart';

enum _QuestionKind { grammar, sentence, speaking, translation }

class PageGameQuestionCreate extends StatefulWidget {
  const PageGameQuestionCreate({
    super.key,
    required this.gameName,
    required this.initialLevel,
    this.existingQuestion,
  });

  final String gameName;
  final int initialLevel;
  final MyGameQuestion? existingQuestion;

  @override
  State<PageGameQuestionCreate> createState() => _PageGameQuestionCreateState();
}

class _PageGameQuestionCreateState extends State<PageGameQuestionCreate> {
  final _formKey = GlobalKey<FormState>();
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();
  final _groupController = TextEditingController();
  final _optionsController = TextEditingController();
  final _service = ServiceGame();

  late int _level;
  late final _QuestionKind _kind;
  late final List<String> _fixedGroups;
  final List<String> _availableGroups = [];
  String? _selectedGroup;
  bool _useCustomGroup = false;
  bool _isSaving = false;
  bool _canPop = false;
  bool _isConfirmingExit = false;
  late final String _initialQuestion;
  late final String _initialAnswer;
  late final String _initialGroup;
  late final String _initialOptions;
  late final int _initialLevel;

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
      _groupController.text = existing.group;
      _optionsController.text = (existing.options ?? '').split('_').join(', ');
      if (!_availableGroups.contains(existing.group)) {
        _availableGroups.add(existing.group);
      }
      _selectedGroup = existing.group;
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
      });
    } catch (_) {
      // The form can still use its built-in categories if loading fails.
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _groupController.dispose();
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
    if (_kind == _QuestionKind.grammar) {
      _optionsController.text =
          '${_questionController.text.trim()}, ${_answerController.text.trim()}';
    } else if (_kind == _QuestionKind.sentence) {
      final answer = _answerController.text.trim();
      final parts = answer.contains(RegExp(r'\s'))
          ? answer.split(RegExp(r'\s+'))
          : answer.split('');
      _questionController.text = parts.join('_');
    }
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context)!;
    final group = _selectedGroup ?? _groupController.text.trim();
    setState(() => _isSaving = true);
    try {
      switch (_kind) {
        case _QuestionKind.grammar:
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
              question: '${_questionController.text.trim()} <--> many ______',
              answer: _answerController.text,
              group: group,
              level: _level,
              options: options,
            );
          } else {
            await _service.updateGrammarQuestion(
              id: widget.existingQuestion!.id,
              question: '${_questionController.text.trim()} <--> many ______',
              answer: _answerController.text,
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.unknownError)),
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
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
              if (!isSpeaking && _kind != _QuestionKind.sentence)
                TextFormField(
                  controller: _questionController,
                  decoration: InputDecoration(
                    labelText: _kind == _QuestionKind.grammar
                        ? loc.grammarBaseWord
                        : loc.question,
                    border: const OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
              if (!isSpeaking && _kind != _QuestionKind.sentence) Gaps.h16,
              TextFormField(
                controller: _answerController,
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
              Gaps.h16,
              DropdownButtonFormField<String>(
                key: ValueKey('$_selectedGroup-$_useCustomGroup'),
                initialValue: _useCustomGroup ? '__custom__' : _selectedGroup,
                decoration: InputDecoration(
                  labelText: loc.questionGroup,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  ..._availableGroups.map((group) => DropdownMenuItem(
                        value: group,
                        child: Text(group),
                      )),
                  DropdownMenuItem(
                    value: '__custom__',
                    child: Text(loc.customQuestionGroup),
                  ),
                ],
                validator: (value) => value == null ? loc.requiredField : null,
                onChanged: (value) {
                  setState(() {
                    _useCustomGroup = value == '__custom__';
                    _selectedGroup = _useCustomGroup ? null : value;
                  });
                },
              ),
              if (_useCustomGroup) ...[
                Gaps.h16,
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
    );
  }
}
