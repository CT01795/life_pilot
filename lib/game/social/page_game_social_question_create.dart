import 'package:flutter/material.dart';
import 'package:life_pilot/game/service_game.dart';
import 'package:life_pilot/l10n/app_localizations.dart';
import 'package:life_pilot/utils/api.dart';
import 'package:life_pilot/utils/const.dart';

class PageGameSocialQuestionCreate extends StatefulWidget {
  const PageGameSocialQuestionCreate({
    super.key,
    this.existingQuestion,
  });

  final MySocialQuestion? existingQuestion;

  @override
  State<PageGameSocialQuestionCreate> createState() =>
      _PageGameSocialQuestionCreateState();
}

class _PageGameSocialQuestionCreateState
    extends State<PageGameSocialQuestionCreate> {
  static const _categories = ['social', 'friendship', 'conflict', 'daily'];
  static const _scores = [5, 0, -5, -10];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sceneController = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _optionControllers = List.generate(3, (_) => TextEditingController());
  final _feedbackControllers = List.generate(3, (_) => TextEditingController());
  final _service = ServiceGame();

  String _category = _categories.first;
  bool _useCustomCategory = false;
  int _bestIndex = 0;
  final List<int> _optionScores = [10, 0, -5];
  bool _isSaving = false;
  bool _canPop = false;
  bool _isConfirmingExit = false;
  late final String _initialTitle;
  late final String _initialScene;
  late final String _initialCategory;
  late final List<String> _initialOptions;
  late final List<String> _initialFeedback;
  late final List<int> _initialScores;
  late final int _initialBestIndex;

  bool get _isAdmin =>
      supabase.auth.currentUser?.id == AuthConstants.systemQuestionBankOwnerId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingQuestion;
    if (existing != null) {
      _titleController.text = existing.title;
      _sceneController.text = existing.scene;
      if (_categories.contains(existing.category)) {
        _category = existing.category;
      } else if (_isAdmin) {
        _useCustomCategory = true;
        _customCategoryController.text = existing.category;
      }
      for (var index = 0;
          index < existing.choices.length && index < 3;
          index++) {
        final choice = existing.choices[index];
        _optionControllers[index].text = choice.text;
        _feedbackControllers[index].text = choice.feedback;
        _optionScores[index] = choice.score;
        if (choice.isBest) _bestIndex = index;
      }
    }
    _initialTitle = _titleController.text;
    _initialScene = _sceneController.text;
    _initialCategory = _resolvedCategory;
    _initialOptions = _optionControllers.map((item) => item.text).toList();
    _initialFeedback = _feedbackControllers.map((item) => item.text).toList();
    _initialScores = List.of(_optionScores);
    _initialBestIndex = _bestIndex;
  }

  String get _resolvedCategory =>
      _useCustomCategory ? _customCategoryController.text.trim() : _category;

  bool get _hasUnsavedChanges =>
      _titleController.text != _initialTitle ||
      _sceneController.text != _initialScene ||
      _resolvedCategory != _initialCategory ||
      _bestIndex != _initialBestIndex ||
      !_sameList(
          _optionControllers.map((item) => item.text), _initialOptions) ||
      !_sameList(
          _feedbackControllers.map((item) => item.text), _initialFeedback) ||
      !_sameList(_optionScores, _initialScores);

  bool _sameList<T>(Iterable<T> current, List<T> initial) {
    final values = current.toList();
    if (values.length != initial.length) return false;
    for (var index = 0; index < values.length; index++) {
      if (values[index] != initial[index]) return false;
    }
    return true;
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

  @override
  void dispose() {
    _titleController.dispose();
    _sceneController.dispose();
    _customCategoryController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    for (final controller in _feedbackControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.requiredField;
    }
    return null;
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    final loc = AppLocalizations.of(context)!;
    final category = _resolvedCategory;
    setState(() => _isSaving = true);
    try {
      final choices = List.generate(3, (index) {
        return {
          'option_text': _optionControllers[index].text.trim(),
          'score': index == _bestIndex ? 10 : _optionScores[index],
          'feedback': _feedbackControllers[index].text.trim(),
          'is_best': index == _bestIndex,
        };
      });
      if (widget.existingQuestion == null) {
        await _service.addSocialQuestion(
          title: _titleController.text,
          scene: _sceneController.text,
          category: category,
          level: 1,
          choices: choices,
        );
      } else {
        await _service.updateSocialQuestion(
          id: widget.existingQuestion!.id,
          title: _titleController.text,
          scene: _sceneController.text,
          category: category,
          choices: choices,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(widget.existingQuestion == null
            ? loc.questionAdded
            : loc.questionUpdated),
      ));
      _allowPop(true);
    } on DuplicateGameQuestionException {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.duplicateQuestion)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(loc.unknownError)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return PopScope<Object?>(
      canPop: _canPop,
      onPopInvokedWithResult: _handlePop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.existingQuestion == null
              ? 'Social · ${loc.addQuestion}'
              : 'Social · ${loc.editQuestion}'),
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
                      Expanded(
                        child: Text(
                          '${loc.question} → ${loc.description} → '
                          '${loc.answerOptions}\n${loc.gameScore}: +10',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Gaps.h16,
              TextFormField(
                controller: _titleController,
                minLines: 1,
                maxLines: 3,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                scrollPadding: const EdgeInsets.only(bottom: 160),
                decoration: InputDecoration(
                  labelText: loc.question,
                  border: const OutlineInputBorder(),
                ),
                validator: _required,
              ),
              Gaps.h16,
              TextFormField(
                controller: _sceneController,
                minLines: 3,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                scrollPadding: const EdgeInsets.only(bottom: 160),
                decoration: InputDecoration(
                  labelText: loc.description,
                  border: const OutlineInputBorder(),
                ),
                validator: _required,
              ),
              Gaps.h16,
              DropdownButtonFormField<String>(
                initialValue: _useCustomCategory ? '__custom__' : _category,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: loc.questionGroup,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  ..._categories.map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  if (_isAdmin)
                    DropdownMenuItem(
                      value: '__custom__',
                      child: Text(loc.customQuestionGroup),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _useCustomCategory = value == '__custom__';
                    if (!_useCustomCategory) _category = value;
                  });
                },
              ),
              if (_useCustomCategory) ...[
                Gaps.h8,
                TextFormField(
                  controller: _customCategoryController,
                  decoration: InputDecoration(
                    labelText: loc.questionGroup,
                    border: const OutlineInputBorder(),
                  ),
                  validator: _required,
                ),
              ],
              Gaps.h16,
              Text(loc.answerOptions,
                  style: Theme.of(context).textTheme.titleMedium),
              Gaps.h8,
              ...List.generate(3, _buildChoiceCard),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(loc.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceCard(int index) {
    final loc = AppLocalizations.of(context)!;
    final isBest = index == _bestIndex;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                isBest ? Icons.radio_button_checked : Icons.radio_button_off,
              ),
              title: Text('${loc.answerOptions} ${index + 1}'),
              onTap: () {
                setState(() {
                  if (_optionScores[_bestIndex] == 10) {
                    _optionScores[_bestIndex] = 0;
                  }
                  _bestIndex = index;
                });
              },
            ),
            TextFormField(
              controller: _optionControllers[index],
              minLines: 2,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              scrollPadding: const EdgeInsets.only(bottom: 160),
              decoration: InputDecoration(
                labelText: '${loc.answerOptions} ${index + 1}',
                border: const OutlineInputBorder(),
              ),
              validator: _required,
            ),
            Gaps.h8,
            DropdownButtonFormField<int>(
              key: ValueKey('$index-$isBest-${_optionScores[index]}'),
              initialValue: isBest ? 10 : _optionScores[index],
              decoration: InputDecoration(
                labelText: loc.gameScore,
                border: const OutlineInputBorder(),
              ),
              items: (isBest ? const [10] : _scores)
                  .map((score) => DropdownMenuItem(
                        value: score,
                        child: Text(score > 0 ? '+$score' : '$score'),
                      ))
                  .toList(),
              onChanged: isBest
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => _optionScores[index] = value);
                      }
                    },
            ),
            Gaps.h8,
            TextFormField(
              controller: _feedbackControllers[index],
              minLines: 2,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              scrollPadding: const EdgeInsets.only(bottom: 160),
              decoration: InputDecoration(
                labelText: loc.feedback,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
