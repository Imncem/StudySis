import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/muffin.dart';
import '../models/muffin_wallet.dart';
import '../services/muffin_context_registry.dart';
import '../services/muffin_service.dart';
import '../services/muffin_wallet_service.dart';
import 'muffin_mascot_icon.dart';

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
  late MuffinMode _activeMode;
  late MuffinContext _activeContext;
  late List<MuffinActionConfig> _activeActions;
  Map<MuffinAction, MuffinActionAvailability> _availability = {};
  bool _availabilityLoading = false;
  int _availabilitySerial = 0;
  int? _walletBitesOverride;

  bool get _isLoading => _loadingAction != null;
  String get _contextKey => _activeContext.contextKey ?? _fallbackContextKey();

  @override
  void initState() {
    super.initState();
    _activeMode = widget.mode;
    _activeContext = widget.context;
    _activeActions = widget.actions;
    MuffinContextRegistry.instance.current.addListener(_handleVisibleContext);
    _refreshAvailability();
    final initialAction = widget.initialAction;
    if (initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ask(initialAction);
      });
    }
  }

  @override
  void dispose() {
    MuffinContextRegistry.instance.current
        .removeListener(_handleVisibleContext);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MuffinAssistSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey =
        oldWidget.context.contextKey ?? _fallbackContextKey(oldWidget);
    final oldActions =
        oldWidget.actions.map((action) => action.action).join('|');
    final newActions = widget.actions.map((action) => action.action).join('|');
    _activeMode = widget.mode;
    _activeContext = widget.context;
    _activeActions = widget.actions;
    if (oldKey != _contextKey) {
      _clearVisibleTurnState();
    }
    if (oldKey != _contextKey || oldActions != newActions) {
      _refreshAvailability();
    }
  }

  void _handleVisibleContext() {
    final visible = MuffinContextRegistry.instance.current.value;
    final visibleKey = visible?.context.contextKey;
    if (visibleKey == null || visibleKey == _contextKey) return;
    if (_response == null &&
        _errorMessage == null &&
        _currentTurn == null &&
        !_isLoading) {
      if (visible != null) {
        setState(() {
          _activeMode = visible.mode;
          _activeContext = visible.context;
          _activeActions = visible.actions;
        });
        _refreshAvailability();
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _loadingAction = null;
      if (visible != null) {
        _activeMode = visible.mode;
        _activeContext = visible.context;
        _activeActions = visible.actions;
      }
      _clearVisibleTurnState();
    });
    _refreshAvailability();
  }

  void _clearVisibleTurnState() {
    _response = null;
    _errorMessage = null;
    _generatedAnswerIndex = null;
    _generatedSubmitted = false;
    _previousMuffinResponse = null;
    _currentTurn = null;
    _previousTurns.clear();
  }

  Future<void> _refreshAvailability() async {
    final actions =
        _activeActions.map((action) => action.action).toSet().toList();
    if (actions.isEmpty) return;
    final serial = ++_availabilitySerial;
    final contextKey = _contextKey;
    setState(() {
      _availabilityLoading = true;
      _availability = {};
    });
    final response = await widget.service.availability(
      MuffinAvailabilityRequest(
        mode: _activeMode,
        context: _activeContext.copyWith(contextKey: contextKey),
        actions: actions,
      ),
    );
    if (!mounted || serial != _availabilitySerial) return;
    if (!_isStillVisibleContext(contextKey)) {
      setState(() => _availabilityLoading = false);
      return;
    }
    setState(() {
      _availability = Map<MuffinAction, MuffinActionAvailability>.of(
        response.actions,
      );
      _availabilityLoading = false;
    });
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
    final contextOverride = config.contextOverride?.call(_activeContext);
    final requestContext = (contextOverride ?? _activeContext).copyWith(
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
      mode: _activeMode,
      action: config.action,
      context: requestContext,
      expectCached: _isSavedFree(config),
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
    var shouldRefreshAvailability = false;
    setState(() {
      _loadingAction = null;
      _walletBitesOverride = response.currentBites ?? _walletBitesOverride;
      if (response.responseType == MuffinResponseType.error) {
        _errorMessage = response.message;
        if (response.resultSource == 'cached_help_unavailable') {
          _availability = {..._availability}..remove(config.action);
          shouldRefreshAvailability = true;
        }
      } else {
        _response = response;
        _previousMuffinResponse = response.message;
        if (_canPreviewSaved(config.action) &&
            response.resultSource != 'cached_help_unavailable') {
          _availability = {
            ..._availability,
            config.action: const MuffinActionAvailability(
              cached: true,
              biteCost: 0,
            ),
          };
        }
        final turn = _turnFromResponse(response);
        if (turn != null) {
          _currentTurn = turn;
          _previousTurns.add(turn);
          _logDisplayedTurn(turn);
        }
      }
    });
    if (shouldRefreshAvailability) {
      _refreshAvailability();
    }
  }

  void _logRequestContext(MuffinContext requestContext) {
    if (!kDebugMode || requestContext.currentScreen != 'quiz') return;
    debugPrint('Visible quiz question: ${_activeContext.questionId}');
    debugPrint('Muffin request question: ${requestContext.questionId}');
    assert(requestContext.questionId == _activeContext.questionId);
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
    final contextOverride = config.contextOverride?.call(_activeContext);
    final target = (contextOverride ?? _activeContext).targetLanguage ??
        _activeContext.targetLanguage ??
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
        mode: _activeMode,
        action: MuffinAction.translate,
        context: _activeContext.copyWith(
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
      _walletBitesOverride = response.currentBites ?? _walletBitesOverride;
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
    if (widgetOverride == null) {
      return [
        _activeContext.currentScreen ?? _activeMode.name,
        _activeContext.subjectId,
        _activeContext.chapterId,
        _activeContext.lessonHeading,
        _activeContext.currentQuestion,
      ].whereType<String>().join('_');
    }
    final source = widgetOverride;
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
        final sourceWallet = snapshot.data ?? MuffinWallet.full;
        final wallet = _walletBitesOverride == null
            ? sourceWallet
            : sourceWallet.copyWith(currentBites: _walletBitesOverride);
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
                      child: const Center(
                        child: MuffinMascotIcon(size: 30),
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
                if (wallet.isDailyLimitReached) ...[
                  const SizedBox(height: 8),
                  Text(
                    wallet.dailyRestText(DateTime.now()),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else if (wallet.currentBites == 1) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Muffin is getting a little tired.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else if (wallet.currentBites == 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Muffin is recharging.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'A Bite is only used when Muffin creates new help. Saved help is free to revisit.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 18),
                for (final action in _activeActions)
                  if (_shouldShowAction(action))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed:
                              _isLoading || _isActionBlocked(action, wallet)
                                  ? null
                                  : () => _ask(action),
                          child: _loadingAction == action.action
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : _ActionCostLabel(
                                  label: _labelForAction(action),
                                  costLabel: _costLabelForAction(action),
                                  isLoading: _isCostLoading(action),
                                ),
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
                              : () => _ask(_activeActions.first),
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
        action.contextOverride?.call(_activeContext).targetLanguage ??
            _activeContext.targetLanguage ??
            'Bahasa Melayu';
    return _languageCode(target) ==
        _languageCode(_nextResponseTranslationTarget());
  }

  bool _isActionBlocked(MuffinActionConfig action, MuffinWallet wallet) {
    if (_isFreeAction(action.action) || _isSavedFree(action)) return false;
    return !wallet.hasBites || wallet.isDailyLimitReached;
  }

  bool _isFreeAction(MuffinAction action) {
    return action == MuffinAction.translate;
  }

  bool _isSavedFree(MuffinActionConfig action) {
    return _canPreviewSaved(action.action) &&
        _availability[action.action]?.cached == true;
  }

  bool _canPreviewSaved(MuffinAction action) {
    return switch (action) {
      MuffinAction.askMuffin ||
      MuffinAction.explainSimply ||
      MuffinAction.stillConfused ||
      MuffinAction.smallHint ||
      MuffinAction.explainConcept ||
      MuffinAction.identifyPattern ||
      MuffinAction.guideQuestion =>
        true,
      MuffinAction.translate ||
      MuffinAction.anotherExample ||
      MuffinAction.generateSimilarQuestion =>
        false,
    };
  }

  bool _isCostLoading(MuffinActionConfig action) {
    return !_isFreeAction(action.action) &&
        _canPreviewSaved(action.action) &&
        _availabilityLoading &&
        !_availability.containsKey(action.action);
  }

  String? _costLabelForAction(MuffinActionConfig action) {
    if (_isFreeAction(action.action)) return null;
    final availability = _availability[action.action];
    if (_canPreviewSaved(action.action) && availability?.cached == true) {
      return 'Saved · Free';
    }
    return '🍪1';
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

  @override
  Future<MuffinAvailabilityResponse> availability(
    MuffinAvailabilityRequest request,
  ) {
    return MuffinServiceFactory.create().availability(request);
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

// ignore: unused_element
class _ActionLabel extends StatelessWidget {
  const _ActionLabel({required this.label, required this.showCost});

  final String label;
  final bool showCost;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label)),
        if (showCost) ...[
          const SizedBox(width: 8),
          const Text('🍪1'),
        ],
      ],
    );
  }
}

class _ActionCostLabel extends StatelessWidget {
  const _ActionCostLabel({
    required this.label,
    required this.costLabel,
    required this.isLoading,
  });

  final String label;
  final String? costLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(label)),
        if (isLoading) ...[
          const SizedBox(width: 8),
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ] else if (costLabel != null) ...[
          const SizedBox(width: 8),
          Text(costLabel!),
        ],
      ],
    );
  }
}
