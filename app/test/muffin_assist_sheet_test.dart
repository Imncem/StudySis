import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/muffin.dart';
import 'package:studysis/models/muffin_wallet.dart';
import 'package:studysis/services/muffin_context_registry.dart';
import 'package:studysis/services/muffin_service.dart';
import 'package:studysis/services/muffin_wallet_service.dart';
import 'package:studysis/theme/app_theme.dart';
import 'package:studysis/widgets/muffin_assist_sheet.dart';

void main() {
  testWidgets('shows Muffin Bites header and action cost indicator',
      (tester) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(_sheetApp(
      MockMuffinService(),
      wallet: const MuffinWallet(
        maxBites: 5,
        currentBites: 2,
        regenIntervalMinutes: 60,
        dailyUsedRequests: 0,
        dailySoftLimit: 17,
        dailyHardLimit: 20,
        status: 'active',
      ),
    ));
    await tester.tap(find.text('Open Muffin'));
    await tester.pumpAndSettle();

    expect(find.text('🍪 2/5'), findsOneWidget);
    expect(find.text('Give me a small hint'), findsOneWidget);
    expect(find.text('🍪1'), findsOneWidget);
  });

  testWidgets('shows loading state and prevents duplicate requests',
      (tester) async {
    _setLargeSurface(tester);
    final service = _CompletingMuffinService();
    await tester.pumpWidget(_sheetApp(service));
    await tester.tap(find.text('Open Muffin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Give me a small hint'));
    await tester.pump();

    expect(service.requestCount, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    service.complete(
      const MuffinResponse(
        responseType: MuffinResponseType.hint,
        message: 'Try one small step.',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Try one small step.'), findsOneWidget);
  });

  testWidgets('shows error state and retry button', (tester) async {
    _setLargeSurface(tester);
    final service = _QueuedMuffinService([
      const MuffinResponse(
        responseType: MuffinResponseType.error,
        message:
            'Muffin could not respond right now. Your learning progress is safe. Please try again.',
      ),
      const MuffinResponse(
        responseType: MuffinResponseType.hint,
        message: 'Retry worked.',
      ),
    ]);
    await tester.pumpWidget(_sheetApp(service));
    await tester.tap(find.text('Open Muffin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Give me a small hint'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Muffin could not respond right now'),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Retry worked.'), findsOneWidget);
  });

  testWidgets('translates latest generated example', (tester) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(_sheetApp(
      MockMuffinService(),
      actions: const [
        MuffinActionConfig(
          action: MuffinAction.anotherExample,
          label: 'Show another example',
        ),
        MuffinActionConfig(
          action: MuffinAction.translate,
          label: 'Translate to Bahasa Melayu',
          contextOverride: _toMalay,
        ),
      ],
      mode: MuffinMode.learn,
    ));
    await tester.tap(find.text('Open Muffin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show another example'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Example 1:'), findsOneWidget);

    await tester.tap(find.text('Translate this response to Bahasa Melayu'));
    await tester.pumpAndSettle();

    expect(find.textContaining('menambah 2'), findsOneWidget);
  });

  testWidgets('keeps current example identity while translating both ways',
      (tester) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(_sheetApp(
      MockMuffinService(),
      actions: [
        const MuffinActionConfig(
          action: MuffinAction.anotherExample,
          label: 'Show another example',
        ),
        MuffinActionConfig(
          action: MuffinAction.translate,
          label: 'Translate to Bahasa Melayu',
          contextOverride: _toMalay,
        ),
        MuffinActionConfig(
          action: MuffinAction.translate,
          label: 'Translate to English',
          contextOverride: _toEnglish,
        ),
      ],
      mode: MuffinMode.learn,
    ));
    await tester.tap(find.text('Open Muffin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Show another example'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show another example'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Example 2:'), findsOneWidget);

    await tester.tap(find.text('Translate this response to Bahasa Melayu'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Contoh 2: 5, 10, 15, 20 meningkat dengan menambah 5 setiap kali.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Example 3:'), findsNothing);

    await tester.tap(find.text('Translate this response to English'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Example 2:'), findsOneWidget);

    await tester.tap(find.text('Show another example'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Example 3:'), findsOneWidget);
  });

  testWidgets('translates visible guide turn instead of older hint',
      (tester) async {
    _setLargeSurface(tester);
    await tester.pumpWidget(_sheetApp(
      MockMuffinService(),
      mode: MuffinMode.quiz,
      muffinContext: const MuffinContext(
        mode: MuffinMode.quiz,
        currentQuestion: 'Apakah beza sepunya bagi jujukan berikut?',
        originalScreenContent:
            'Apakah beza sepunya bagi jujukan berikut?\n7, 12, 17, 22, ...',
        contextKey: 'quiz_math_chapter-1_q2',
      ),
      actions: [
        const MuffinActionConfig(
          action: MuffinAction.smallHint,
          label: 'Give me a small hint',
        ),
        const MuffinActionConfig(
          action: MuffinAction.guideQuestion,
          label: 'Guide me through the question',
        ),
        MuffinActionConfig(
          action: MuffinAction.translate,
          label: 'Translate to English',
          contextOverride: _toEnglish,
        ),
      ],
    ));
    await tester.tap(find.text('Open Muffin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Give me a small hint'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Cuba kira beza antara 12 dan 7'), findsOneWidget);

    await tester.tap(find.text('Guide me through the question'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('semak sama ada beza yang sama'), findsOneWidget);

    await tester.tap(find.text('Translate this response to English'));
    await tester.pumpAndSettle();

    expect(find.textContaining('check whether the same difference appears'),
        findsOneWidget);
    expect(find.textContaining('check the next pair'), findsNothing);
  });

  testWidgets('discards stale response after visible quiz question changes',
      (tester) async {
    _setLargeSurface(tester);
    addTearDown(MuffinContextRegistry.instance.resetToHome);
    final service = _CompletingMuffinService();
    const q1Context = MuffinContext(
      mode: MuffinMode.quiz,
      currentScreen: 'quiz',
      questionId: 'q1',
      currentQuestion: 'Apakah nombor seterusnya?',
      contextKey: 'quiz_math_chapter-1_q1',
    );
    MuffinContextRegistry.instance.set(
      const MuffinScreenContext(
        mode: MuffinMode.quiz,
        subtitle: 'Quiz',
        context: q1Context,
        actions: [
          MuffinActionConfig(
            action: MuffinAction.guideQuestion,
            label: 'Guide me through the question',
          ),
        ],
      ),
    );
    await tester.pumpWidget(_sheetApp(
      service,
      mode: MuffinMode.quiz,
      muffinContext: q1Context,
      actions: const [
        MuffinActionConfig(
          action: MuffinAction.guideQuestion,
          label: 'Guide me through the question',
        ),
      ],
    ));
    await tester.tap(find.text('Open Muffin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guide me through the question'));
    await tester.pump();

    MuffinContextRegistry.instance.set(
      const MuffinScreenContext(
        mode: MuffinMode.quiz,
        subtitle: 'Quiz',
        context: MuffinContext(
          mode: MuffinMode.quiz,
          currentScreen: 'quiz',
          questionId: 'q2',
          currentQuestion: 'Apakah beza sepunya?',
          contextKey: 'quiz_math_chapter-1_q2',
        ),
        actions: [
          MuffinActionConfig(
            action: MuffinAction.guideQuestion,
            label: 'Guide me through the question',
          ),
        ],
      ),
    );
    service.complete(
      const MuffinResponse(
        responseType: MuffinResponseType.hint,
        message: 'Guidance for old Q1',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guidance for old Q1'), findsNothing);
    expect(find.text('Choose how Muffin can help with this part.'),
        findsOneWidget);
  });

  testWidgets('discards stale response after visible flashcard changes',
      (tester) async {
    _setLargeSurface(tester);
    addTearDown(MuffinContextRegistry.instance.resetToHome);
    final service = _CompletingMuffinService();
    const card2Context = MuffinContext(
      mode: MuffinMode.learn,
      currentScreen: 'flashcards',
      cardId: 'card-2',
      currentQuestion: 'Apakah itu beza tetap?',
      contextKey: 'flashcard_math_chapter-1_card_card-2_front',
    );
    MuffinContextRegistry.instance.set(
      const MuffinScreenContext(
        mode: MuffinMode.learn,
        subtitle: 'Flashcards',
        context: card2Context,
        actions: [
          MuffinActionConfig(
            action: MuffinAction.explainSimply,
            label: 'Explain this card',
          ),
        ],
      ),
    );
    await tester.pumpWidget(_sheetApp(
      service,
      mode: MuffinMode.learn,
      muffinContext: card2Context,
      actions: const [
        MuffinActionConfig(
          action: MuffinAction.explainSimply,
          label: 'Explain this card',
        ),
      ],
    ));
    await tester.tap(find.text('Open Muffin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explain this card'));
    await tester.pump();

    MuffinContextRegistry.instance.set(
      const MuffinScreenContext(
        mode: MuffinMode.learn,
        subtitle: 'Flashcards',
        context: MuffinContext(
          mode: MuffinMode.learn,
          currentScreen: 'flashcards',
          cardId: 'card-3',
          currentQuestion: 'Apakah itu jujukan?',
          contextKey: 'flashcard_math_chapter-1_card_card-3_front',
        ),
        actions: [
          MuffinActionConfig(
            action: MuffinAction.explainSimply,
            label: 'Explain this card',
          ),
        ],
      ),
    );
    service.complete(
      const MuffinResponse(
        responseType: MuffinResponseType.explanation,
        message: 'Explanation for old card 2',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Explanation for old card 2'), findsNothing);
    expect(find.text('Choose how Muffin can help with this part.'),
        findsOneWidget);
  });
}

MuffinContext _toMalay(MuffinContext context) {
  return context.copyWith(targetLanguage: 'Bahasa Melayu');
}

MuffinContext _toEnglish(MuffinContext context) {
  return context.copyWith(targetLanguage: 'English');
}

Widget _sheetApp(
  MuffinService service, {
  MuffinMode mode = MuffinMode.quiz,
  MuffinContext? muffinContext,
  MuffinWallet wallet = MuffinWallet.full,
  List<MuffinActionConfig> actions = const [
    MuffinActionConfig(
      action: MuffinAction.smallHint,
      label: 'Give me a small hint',
    ),
  ],
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => MuffinAssistSheet(
                  title: 'Muffin',
                  subtitle: 'Test sheet',
                  mode: mode,
                  context: muffinContext ?? MuffinContext(mode: mode),
                  service: service,
                  walletService: StaticMuffinWalletService(wallet),
                  actions: actions,
                ),
              );
            },
            child: const Text('Open Muffin'),
          ),
        ),
      ),
    ),
  );
}

void _setLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1000, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _CompletingMuffinService implements MuffinService {
  final _completer = Completer<MuffinResponse>();
  int requestCount = 0;

  @override
  Future<MuffinResponse> ask(MuffinRequest request) {
    requestCount += 1;
    return _completer.future;
  }

  void complete(MuffinResponse response) {
    _completer.complete(response);
  }
}

class _QueuedMuffinService implements MuffinService {
  _QueuedMuffinService(this.responses);

  final List<MuffinResponse> responses;

  @override
  Future<MuffinResponse> ask(MuffinRequest request) async {
    return responses.removeAt(0);
  }
}
