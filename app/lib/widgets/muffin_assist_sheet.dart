import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/muffin.dart';
import '../models/muffin_wallet.dart';
import '../services/muffin_context_registry.dart';
import '../services/muffin_service.dart';
import '../services/muffin_wallet_service.dart';

class MuffinActionConfig {
  const MuffinActionConfig({
    required this.action,
    required this.label,
    this.contextOverride,
  });

  final MuffinAction action;
  final String label;
  final MuffinContext Function(MuffinContext context)? contextOverride;
}

class MuffinAssistSheet extends StatefulWidget {
  const MuffinAssistSheet({
    required this.title,
    required this.subtitle,
    required this.mode,
    required this.context,
    required this.actions,
    MuffinService? service,
    MuffinWalletService? walletService,
    this.initialAction,
    this.onGeneratedQuestionAnswered,
    super.key,
  })  : service = service ?? const _DefaultMuffinService(),
        walletService = walletService ?? const _DefaultMuffinWalletService();

  final String title;
  final String subtitle;
  final MuffinMode mode;
  final MuffinContext context;
  final List<MuffinActionConfig> actions;
  final MuffinService service;
  final MuffinWalletService walletService;
  final MuffinActionConfig? initialAction;
  final ValueChanged<bool>? onGeneratedQuestionAnswered;

  @override
  State<MuffinAssistSheet> createState() => _MuffinAssistSheetState();
}

class _MuffinAssistSheetState extends State<MuffinAssistSheet> {
  MuffinResponse? _response;
  MuffinAction? _loadingAction;
  String? _errorMessage;
  int? _generatedAnswerIndex;
  bool _generatedSubmitted = false;
  String? _previousMuffinResponse;
  MuffinTurn? _currentTurn;
  final List<MuffinTurn> _previousTurns = [];
  final Map<String, int> _exampleCounts = {};

  bool get _isLoading => _loadingAction != null;
  String get _contextKey => widget.context.contextKey ?? _fallbackContextKey();

  @override
  void initState() {
    super.initState();
    final initialAction = widget.initialAction;
    if (initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ask(initialAction);
      });
    }
  }

  @override
  void didUpdateWidget(covariant MuffinAssistSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey =
        oldWidget.context.contextKey ?? _fallbackContextKey(oldWidget);
    if (oldKey != _contextKey) {
      _response = null;
      _errorMessage = null;
      _generatedAnswerIndex = null;
      _generatedSubmitted = false;
      _previousMuffinResponse = null;
      _currentTurn = null;
      _previousTurns.clear();
    }
  }

  Future<void> _ask(MuffinActionConfig config) async {
    if (_isLoading) return;
    if (config.action == MuffinAction.translate && _currentTurn != null) {
      await _translateCurrentTurn(config);
      return;
    }
    setState(() {
      _loadingAction = config.action;
      _errorMessage = null;
      _generatedAnswerIndex = null;
      _generatedSubmitted = false;
    });
    final contextOverride = config.contextOverride?.call(widget.context);
    final requestContext = (contextOverride ?? widget.context).copyWith(
      contextKey: _contextKey,
      currentMuffinContent: _currentTurn?.sourceText,
      previousMuffinResponse: _previousMuffinResponse,
      currentAction: config.action.name,
      previousExampleIds: _previousTurns
          .where((turn) => turn.type == MuffinResponseType.example)
          .map((turn) => turn.id)
          .toList(growable: false),
    );
    final request = MuffinRequest(
      mode: widget.mode,
      action: config.action,
      context: requestContext,
    );
    _logRequestContext(requestContext);
    final response = await widget.service.ask(request);
    if (!mounted) return;
    if (!_isStillVisibleContext(requestContext.contextKey)) {
      if (kDebugMode) {
        debugPrint(
          'Discarded stale Muffin response: requestContext=${requestContext.contextKey} visibleContext=${MuffinContextRegistry.instance.current.value?.context.contextKey}',
        );
      }
      setState(() => _loadingAction = null);
      return;
    }
    setState(() {
      _loadingAction = null;
      if (response.responseType == MuffinResponseType.error) {
        _errorMessage = response.message;
      } else {
        _response = response;
        _previousMuffinResponse = response.message;
        final turn = _turnFromResponse(response);
        if (turn != null) {
          _currentTurn = turn;
          _previousTurns.add(turn);
          _logDisplayedTurn(turn);
        }
      }
    });
  }

  void _logRequestContext(MuffinContext requestContext) {
    if (!kDebugMode || requestContext.currentScreen != 'quiz') return;
    debugPrint('Visible quiz question: ${widget.context.questionId}');
    debugPrint('Muffin request question: ${requestContext.questionId}');
    assert(requestContext.questionId == widget.context.questionId);
  }

  bool _isStillVisibleContext(String? requestContextKey) {
    if (requestContextKey == null) return true;
    final visibleContext =
        MuffinContextRegistry.instance.current.value?.context.contextKey;
    return visibleContext == null || visibleContext == requestContextKey;
  }

  Future<void> _translateCurrentTurn(MuffinActionConfig config) async {
    final turn = _currentTurn;
    if (turn == null || _isLoading) return;
    final contextOverride = config.contextOverride?.call(widget.context);
    final target = (contextOverride ?? widget.context).targetLanguage ??
        widget.context.targetLanguage ??
        'Bahasa Melayu';
    final targetCode = _languageCode(target);
    if (kDebugMode) {
      debugPrint('Translation requested for turn: id=${turn.id}');
    }
    if (targetCode == turn.sourceLanguage) {
      setState(() => _response = _responseForTurn(turn, target));
      return;
    }
    final cached = turn.translations[targetCode];
    if (cached != null) {
      setState(() => _response = _responseForTurn(turn, target));
      return;
    }
    setState(() {
      _loadingAction = config.action;
      _errorMessage = null;
    });
    final response = await widget.service.ask(
      MuffinRequest(
        mode: widget.mode,
        action: MuffinAction.translate,
        context: widget.context.copyWith(
          targetLanguage: target,
          contextKey: _contextKey,
          currentMuffinContent: turn.sourceText,
          previousMuffinResponse: turn.sourceText,
          currentAction: MuffinAction.translate.name,
        ),
      ),
    );
    if (!mounted) return;
    if (!_isStillVisibleContext(turn.contextKey)) {
      if (kDebugMode) {
        debugPrint(
          'Discarded stale Muffin translation: turnContext=${turn.contextKey} visibleContext=${MuffinContextRegistry.instance.current.value?.context.contextKey}',
        );
      }
      setState(() => _loadingAction = null);
      return;
    }
    setState(() {
      _loadingAction = null;
      if (response.responseType == MuffinResponseType.error) {
        _errorMessage = response.message;
        return;
      }
      final translated = response.translatedText ?? response.message;
      final updatedTurn = turn.copyWith(
        displayLanguage: targetCode,
        translations: {...turn.translations, targetCode: translated},
      );
      _currentTurn = updatedTurn;
      _response = _responseForTurn(updatedTurn, target);
      _logDisplayedTurn(updatedTurn);
    });
  }

  MuffinTurn? _turnFromResponse(MuffinResponse response) {
    if (response.responseType == MuffinResponseType.error ||
        response.responseType == MuffinResponseType.refusal) {
      return null;
    }
    final sourceText = response.generatedQuestion?.question ?? response.message;
    final exampleIndex = response.responseType == MuffinResponseType.example
        ? _nextExampleIndex()
        : null;
    return MuffinTurn(
      id: response.suggestedNextAction ??
          '${_contextKey}_${response.responseType.name}_${_previousTurns.length + 1}',
      type: response.responseType,
      sourceText: sourceText,
      sourceLanguage: _detectLanguageCode(sourceText),
      displayLanguage: _detectLanguageCode(sourceText),
      translations: const <String, String>{},
      contextKey: _contextKey,
      exampleIndex: exampleIndex,
      generatedQuestion: response.generatedQuestion,
    );
  }

  MuffinResponse _responseForTurn(MuffinTurn turn, String targetLanguage) {
    assert(_currentTurn?.id == turn.id);
    final targetCode = _languageCode(targetLanguage);
    final message = targetCode == turn.sourceLanguage
        ? turn.sourceText
        : turn.translations[targetCode] ?? turn.sourceText;
    return MuffinResponse(
      responseType: turn.type,
      message: message,
      generatedQuestion:
          targetCode == turn.sourceLanguage ? turn.generatedQuestion : null,
    );
  }

  void _logDisplayedTurn(MuffinTurn turn) {
    if (!kDebugMode) return;
    debugPrint(
      'Displayed Muffin turn: id=${turn.id} type=${turn.type.name} context=${turn.contextKey}',
    );
  }

  int _nextExampleIndex() {
    final next = (_exampleCounts[_contextKey] ?? 0) + 1;
    _exampleCounts[_contextKey] = next;
    return next;
  }

  String _fallbackContextKey([MuffinAssistSheet? widgetOverride]) {
    final source = widgetOverride ?? widget;
    return [
      source.context.currentScreen ?? source.mode.name,
      source.context.subjectId,
      source.context.chapterId,
      source.context.lessonHeading,
      source.context.currentQuestion,
    ].whereType<String>().join('_');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MuffinWallet>(
      stream: widget.walletService.watchWallet(),
      initialData: MuffinWallet.full,
      builder: (context, snapshot) {
        final wallet = snapshot.data ?? MuffinWallet.full;
        final blocked = !wallet.hasBites || wallet.isDailyLimitReached;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5EEE8),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.psychology_rounded,
                        color: Color(0xFF496A5A),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    _MuffinBitesPill(wallet: wallet),
                  ],
                ),
                if (wallet.currentBites == 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Muffin is getting a little tired.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (blocked) ...[
                  const SizedBox(height: 8),
                  Text(
                    wallet.isDailyLimitReached
                        ? wallet.dailyRestText(DateTime.now())
                        : wallet.cooldownText(DateTime.now()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 18),
                for (final action in widget.actions)
                  if (_shouldShowAction(action))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed:
                              _isLoading || blocked ? null : () => _ask(action),
                          child: _loadingAction == action.action
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : _CostLabel(label: _labelForAction(action)),
                        ),
                      ),
                    ),
                const SizedBox(height: 10),
                if (_errorMessage != null)
                  _MuffinResponseCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_errorMessage!),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: _isLoading || widget.actions.isEmpty
                              ? null
                              : () => _ask(widget.actions.first),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else
                  _ResponseView(
                    response: _response,
                    selectedAnswerIndex: _generatedAnswerIndex,
                    submitted: _generatedSubmitted,
                    onSelectGeneratedAnswer: (index) =>
                        setState(() => _generatedAnswerIndex = index),
                    onSubmitGeneratedAnswer: () {
                      if (_generatedAnswerIndex == null) return;
                      setState(() => _generatedSubmitted = true);
                      widget.onGeneratedQuestionAnswered?.call(true);
                    },
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _labelForAction(MuffinActionConfig action) {
    if (action.action != MuffinAction.translate || _currentTurn == null) {
      return action.label;
    }
    return _nextResponseTranslationTarget() == 'English'
        ? 'Translate this response to English'
        : 'Translate this response to Bahasa Melayu';
  }

  bool _shouldShowAction(MuffinActionConfig action) {
    if (action.action != MuffinAction.translate) return true;
    if (_currentTurn == null) return false;
    final target =
        action.contextOverride?.call(widget.context).targetLanguage ??
            widget.context.targetLanguage ??
            'Bahasa Melayu';
    return _languageCode(target) ==
        _languageCode(_nextResponseTranslationTarget());
  }

  String _nextResponseTranslationTarget() {
    return _currentTurn?.displayLanguage == 'ms' ? 'English' : 'Bahasa Melayu';
  }

  String _languageCode(String language) {
    final normalized = language.toLowerCase();
    if (normalized == 'en' || normalized.contains('english')) return 'en';
    if (normalized == 'ms' ||
        normalized.contains('malay') ||
        normalized.contains('melayu')) {
      return 'ms';
    }
    return normalized;
  }

  String _detectLanguageCode(String text) {
    final normalized = text.toLowerCase();
    final malaySignals = RegExp(
            r'\b(ialah|dan|yang|dengan|contoh|nombor|pola|beza|jujukan|cuba|semak)\b')
        .allMatches(normalized)
        .length;
    final englishSignals = RegExp(
            r'\b(the|and|with|example|number|pattern|difference|sequence|try|check)\b')
        .allMatches(normalized)
        .length;
    if (malaySignals > englishSignals) return 'ms';
    return 'en';
  }
}

class _ResponseView extends StatelessWidget {
  const _ResponseView({
    required this.response,
    required this.selectedAnswerIndex,
    required this.submitted,
    required this.onSelectGeneratedAnswer,
    required this.onSubmitGeneratedAnswer,
  });

  final MuffinResponse? response;
  final int? selectedAnswerIndex;
  final bool submitted;
  final ValueChanged<int> onSelectGeneratedAnswer;
  final VoidCallback onSubmitGeneratedAnswer;

  @override
  Widget build(BuildContext context) {
    final response = this.response;
    if (response == null) {
      return const _MuffinResponseCard(
        child: Text('Choose how Muffin can help with this part.'),
      );
    }
    final generatedQuestion = response.generatedQuestion;
    return _MuffinResponseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(response.message),
          if (response.translatedText != null) ...[
            const SizedBox(height: 12),
            Text(response.translatedText!),
          ],
          if (generatedQuestion != null) ...[
            const SizedBox(height: 14),
            const Text(
              'Generated by Muffin',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(generatedQuestion.question),
            const SizedBox(height: 10),
            for (var index = 0;
                index < generatedQuestion.options.length;
                index++) ...[
              RadioListTile<int>(
                value: index,
                groupValue: selectedAnswerIndex,
                onChanged: submitted
                    ? null
                    : (value) {
                        if (value != null) onSelectGeneratedAnswer(value);
                      },
                title: Text(generatedQuestion.options[index]),
                contentPadding: EdgeInsets.zero,
              ),
            ],
            FilledButton(
              onPressed: submitted || selectedAnswerIndex == null
                  ? null
                  : onSubmitGeneratedAnswer,
              child: const Text('Check Muffin Practice'),
            ),
            if (submitted) ...[
              const SizedBox(height: 8),
              Text(
                _generatedFeedback(generatedQuestion),
              ),
            ],
          ],
          if (response.suggestedNextAction != null) ...[
            const SizedBox(height: 12),
            Text(response.suggestedNextAction!),
          ],
        ],
      ),
    );
  }

  String _generatedFeedback(MuffinGeneratedQuestion question) {
    final correctIndex = question.correctOptionIndex;
    final selectedIndex = selectedAnswerIndex;
    final explanation = question.explanation?.trim();
    final correctness = correctIndex == null || selectedIndex == null
        ? 'Good effort.'
        : selectedIndex == correctIndex
            ? 'Correct.'
            : 'Not quite.';
    final detail =
        explanation == null || explanation.isEmpty ? '' : ' $explanation';
    return '$correctness$detail This generated question is only for practice and does not change your official score.';
  }
}

class _MuffinResponseCard extends StatelessWidget {
  const _MuffinResponseCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8E3)),
      ),
      child: child,
    );
  }
}

class _DefaultMuffinService implements MuffinService {
  const _DefaultMuffinService();

  @override
  Future<MuffinResponse> ask(MuffinRequest request) {
    return MuffinServiceFactory.create().ask(request);
  }
}

class _DefaultMuffinWalletService implements MuffinWalletService {
  const _DefaultMuffinWalletService();

  @override
  Stream<MuffinWallet> watchWallet() {
    return MuffinWalletServiceFactory.create().watchWallet();
  }
}

class _MuffinBitesPill extends StatelessWidget {
  const _MuffinBitesPill({required this.wallet});

  final MuffinWallet wallet;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFE6D5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '🍪 ${wallet.currentBites}/${wallet.maxBites}',
          style: const TextStyle(
            color: Color(0xFFA45E37),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _CostLabel extends StatelessWidget {
  const _CostLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label)),
        const SizedBox(width: 8),
        const Text('🍪1'),
      ],
    );
  }
}
