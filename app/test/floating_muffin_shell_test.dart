import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:studysis/models/muffin.dart';
import 'package:studysis/models/muffin_wallet.dart';
import 'package:studysis/models/page_translation.dart';
import 'package:studysis/services/muffin_context_registry.dart';
import 'package:studysis/services/muffin_wallet_service.dart';
import 'package:studysis/widgets/floating_muffin_shell.dart';
import 'package:studysis/widgets/muffin_assist_sheet.dart';
import 'package:studysis/widgets/page_translation_scope.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MuffinContextRegistry.instance.resetToHome();
  });

  testWidgets('floating Muffin appears on student screens', (tester) async {
    await tester.pumpWidget(_app(enabled: true));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Open Muffin learning assistant'),
        findsOneWidget);
  });

  testWidgets('floating Muffin does not appear on admin or disabled screens',
      (tester) async {
    await tester.pumpWidget(_app(enabled: false));
    await tester.pumpAndSettle();

    expect(
        find.bySemanticsLabel('Open Muffin learning assistant'), findsNothing);
  });

  testWidgets('tapping floating Muffin on Home opens default actions',
      (tester) async {
    await tester.pumpWidget(_app(enabled: true));
    await tester.pumpAndSettle();

    await _tapMuffin(tester);

    expect(find.text('Terjemah halaman ke Bahasa Melayu'), findsOneWidget);
    expect(find.text('Ask Muffin'), findsOneWidget);
    expect(find.text('What should I revise?'), findsOneWidget);
    expect(find.text('Create a quick practice question'), findsOneWidget);
    expect(find.text('5 Muffin Bites left'), findsOneWidget);
    expect(find.text('🍪1'), findsNWidgets(3));
  });

  testWidgets('floating Muffin has no Bite badge and uses dog identity',
      (tester) async {
    await tester.pumpWidget(_app(
      enabled: true,
      wallet: const MuffinWallet(
        maxBites: 5,
        currentBites: 3,
        regenIntervalMinutes: 60,
        dailyUsedRequests: 0,
        dailySoftLimit: 17,
        dailyHardLimit: 20,
        status: 'active',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsNothing);
    expect(find.bySemanticsLabel('Muffin dog mascot'), findsOneWidget);
  });

  testWidgets('empty Muffin wallet disables paid menu actions', (tester) async {
    final controller = PageTranslationController();
    await tester.pumpWidget(_app(
      enabled: true,
      wallet: MuffinWallet.empty,
      controller: controller,
    ));
    await tester.pumpAndSettle();

    await _tapMuffin(tester);

    expect(find.textContaining('Muffin is recharging'), findsOneWidget);
    await tester.tap(find.text('Terjemah halaman ke Bahasa Melayu'));
    await tester.pumpAndSettle();
    expect(controller.state.isTranslated, isTrue);

    await _tapMuffin(tester);
    final button = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'What should I revise?'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('daily budget message uses wallet provider reset timestamp',
      (tester) async {
    await tester.pumpWidget(_app(
      enabled: true,
      wallet: MuffinWallet(
        maxBites: 5,
        currentBites: 5,
        regenIntervalMinutes: 60,
        dailyUsedRequests: 0,
        dailySoftLimit: 17,
        dailyHardLimit: 20,
        status: 'daily_limit',
        nextProviderResetAt: DateTime.now().add(const Duration(minutes: 90)),
      ),
    ));
    await tester.pumpAndSettle();

    await _tapMuffin(tester);

    expect(find.textContaining('finished helping for today'), findsOneWidget);
    expect(find.textContaining('available in'), findsOneWidget);
  });

  testWidgets('tapping floating Muffin on Learn opens Learn actions',
      (tester) async {
    MuffinContextRegistry.instance.set(_context(
      screen: 'learn',
      mode: MuffinMode.learn,
      actions: const [
        MuffinActionConfig(
          action: MuffinAction.explainSimply,
          label: 'Explain this simply',
        ),
        MuffinActionConfig(
          action: MuffinAction.translate,
          label: 'Translate this section',
        ),
        MuffinActionConfig(
          action: MuffinAction.anotherExample,
          label: 'Show another example',
        ),
        MuffinActionConfig(
          action: MuffinAction.stillConfused,
          label: "I'm still confused",
        ),
      ],
    ));
    await tester.pumpWidget(_app(enabled: true));
    await tester.pumpAndSettle();

    await _tapMuffin(tester);

    expect(find.text('Explain this simply'), findsOneWidget);
    expect(find.text('Terjemah halaman ke Bahasa Melayu'), findsOneWidget);
    expect(find.text('Translate this section'), findsNothing);
    expect(find.text('Show another example'), findsOneWidget);
    expect(find.text("I'm still confused"), findsOneWidget);
  });

  testWidgets('tapping floating Muffin on Flashcards opens Flashcard actions',
      (tester) async {
    MuffinContextRegistry.instance.set(_context(
      screen: 'flashcards',
      actions: const [
        MuffinActionConfig(
          action: MuffinAction.explainSimply,
          label: 'Explain this card',
        ),
        MuffinActionConfig(
          action: MuffinAction.translate,
          label: 'Translate this card',
        ),
        MuffinActionConfig(
          action: MuffinAction.anotherExample,
          label: 'Give another example',
        ),
      ],
    ));
    await tester.pumpWidget(_app(enabled: true));
    await tester.pumpAndSettle();

    await _tapMuffin(tester);

    expect(find.text('Explain this card'), findsOneWidget);
    expect(find.text('Terjemah halaman ke Bahasa Melayu'), findsOneWidget);
    expect(find.text('Translate this card'), findsNothing);
    expect(find.text('Give another example'), findsOneWidget);
  });

  testWidgets('tapping floating Muffin on Practice opens Practice actions',
      (tester) async {
    MuffinContextRegistry.instance.set(_context(
      screen: 'practice',
      actions: const [
        MuffinActionConfig(
          action: MuffinAction.smallHint,
          label: 'Give me a small hint',
        ),
        MuffinActionConfig(
          action: MuffinAction.explainConcept,
          label: 'Explain the concept',
        ),
        MuffinActionConfig(
          action: MuffinAction.generateSimilarQuestion,
          label: 'Create a similar question',
        ),
      ],
    ));
    await tester.pumpWidget(_app(enabled: true));
    await tester.pumpAndSettle();

    await _tapMuffin(tester);

    expect(find.text('Give me a small hint'), findsOneWidget);
    expect(find.text('Explain the concept'), findsOneWidget);
    expect(find.text('Create a similar question'), findsOneWidget);
  });

  testWidgets('tapping floating Muffin on Quiz opens Quiz-safe actions',
      (tester) async {
    MuffinContextRegistry.instance.set(_context(
      screen: 'quiz',
      mode: MuffinMode.quiz,
      actions: const [
        MuffinActionConfig(
          action: MuffinAction.smallHint,
          label: 'Give me a small hint',
        ),
        MuffinActionConfig(
          action: MuffinAction.explainConcept,
          label: 'Explain the concept',
        ),
        MuffinActionConfig(
          action: MuffinAction.guideQuestion,
          label: 'Guide me through the question',
        ),
      ],
    ));
    await tester.pumpWidget(_app(enabled: true));
    await tester.pumpAndSettle();

    await _tapMuffin(tester);

    expect(find.text('Give me a small hint'), findsOneWidget);
    expect(find.text('Explain the concept'), findsOneWidget);
    expect(find.text('Guide me through the question'), findsOneWidget);
    expect(find.text('Correct answer'), findsNothing);
  });

  testWidgets('large drag does not open the sheet', (tester) async {
    await tester.pumpWidget(_app(enabled: true));
    await tester.pumpAndSettle();

    final button = find.bySemanticsLabel('Open Muffin learning assistant');
    await tester.drag(button, const Offset(-220, -120));
    await tester.pumpAndSettle();

    expect(find.text('Ask Muffin'), findsNothing);
    final topLeft = tester.getTopLeft(button);
    expect(topLeft.dx, greaterThanOrEqualTo(0));
    expect(topLeft.dy, greaterThanOrEqualTo(0));
  });

  testWidgets('small movement still counts as a tap', (tester) async {
    await tester.pumpWidget(_app(enabled: true));
    await tester.pumpAndSettle();

    final button = find.bySemanticsLabel('Open Muffin learning assistant');
    final gesture = await tester.startGesture(tester.getCenter(button));
    await gesture.moveBy(const Offset(3, 4));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('Ask Muffin'), findsOneWidget);
  });

  testWidgets('missing registered context opens the fallback menu',
      (tester) async {
    MuffinContextRegistry.instance.clear();
    await tester.pumpWidget(_app(enabled: true));
    await tester.pumpAndSettle();

    await _tapMuffin(tester);

    expect(find.text('Ask Muffin'), findsOneWidget);
    expect(find.text('Terjemah halaman ke Bahasa Melayu'), findsOneWidget);
  });

  testWidgets('floating Muffin hides while action sheet is open',
      (tester) async {
    MuffinContextRegistry.instance.set(_context(
      screen: 'learn',
      mode: MuffinMode.learn,
      actions: const [
        MuffinActionConfig(
          action: MuffinAction.explainSimply,
          label: 'Explain this simply',
        ),
      ],
    ));
    await tester.pumpWidget(_app(enabled: true));
    await tester.pumpAndSettle();

    await _tapMuffin(tester);
    await tester.tap(find.text('Explain this simply'));
    await tester.pumpAndSettle();

    expect(
        find.bySemanticsLabel('Open Muffin learning assistant'), findsNothing);
  });

  testWidgets('closing the sheet allows it to be opened again', (tester) async {
    await tester.pumpWidget(_app(enabled: true));
    await tester.pumpAndSettle();

    await _tapMuffin(tester);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await _tapMuffin(tester);

    expect(find.text('Ask Muffin'), findsOneWidget);
  });

  testWidgets('dragging does not permanently disable tapping', (tester) async {
    await tester.pumpWidget(_app(enabled: true));
    await tester.pumpAndSettle();

    final button = find.bySemanticsLabel('Open Muffin learning assistant');
    await tester.drag(button, const Offset(-180, 0));
    await tester.pumpAndSettle();
    await _tapMuffin(tester);

    expect(find.text('Ask Muffin'), findsOneWidget);
  });

  testWidgets('no duplicate sheet opens from repeated rapid taps',
      (tester) async {
    await tester.pumpWidget(_app(enabled: true));
    await tester.pumpAndSettle();

    final button = find.bySemanticsLabel('Open Muffin learning assistant');
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Terjemah halaman ke Bahasa Melayu'), findsOneWidget);
  });

  testWidgets('floating Muffin can open page translation', (tester) async {
    final controller = PageTranslationController();
    controller.setContent(
      const TranslatablePageContent(
        pageType: 'home',
        pageId: 'home_dashboard',
        sourceLanguage: TranslationLanguage.english,
        fields: [
          PageTranslationField(
            id: 'greeting',
            type: 'heading',
            text: 'Hi Qidah',
          ),
        ],
      ),
    );
    await tester.pumpWidget(_app(enabled: true, controller: controller));
    await tester.pumpAndSettle();

    await _tapMuffin(tester);
    await tester.tap(find.text('Terjemah halaman ke Bahasa Melayu'));
    await tester.pumpAndSettle();

    expect(controller.state.isTranslated, isTrue);
    expect(controller.text('greeting', 'Hi Qidah'), 'Hai Qidah');
  });

  testWidgets('keyboard hides floating Muffin temporarily', (tester) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(_app(
      enabled: true,
      withInput: true,
    ));
    await tester.pumpAndSettle();

    expect(
        find.bySemanticsLabel('Open Muffin learning assistant'), findsNothing);
  });
}

Future<void> _tapMuffin(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Open Muffin learning assistant'));
  await tester.pumpAndSettle();
}

MuffinScreenContext _context({
  required String screen,
  MuffinMode mode = MuffinMode.practice,
  required List<MuffinActionConfig> actions,
}) {
  return MuffinScreenContext(
    mode: mode,
    subtitle: '$screen actions',
    context: MuffinContext(
      mode: mode,
      currentScreen: screen,
      currentQuestion: screen == 'quiz' ? 'Question text only' : null,
      answerOptions: screen == 'quiz' ? const ['A', 'B', 'C'] : null,
    ),
    actions: actions,
  );
}

Widget _app({
  required bool enabled,
  bool withInput = false,
  PageTranslationController? controller,
  EdgeInsets viewInsets = EdgeInsets.zero,
  MuffinWallet wallet = MuffinWallet.full,
}) {
  final navigatorKey = GlobalKey<NavigatorState>();
  final translationController = controller ?? PageTranslationController();
  translationController.setContent(
    const TranslatablePageContent(
      pageType: 'home',
      pageId: 'home_dashboard',
      sourceLanguage: TranslationLanguage.english,
      fields: [
        PageTranslationField(
          id: 'greeting',
          type: 'heading',
          text: 'Hi Qidah',
        ),
      ],
    ),
  );
  return MaterialApp(
    navigatorKey: navigatorKey,
    builder: (context, child) => PageTranslationScope(
      controller: translationController,
      child: FloatingMuffinShell(
        navigatorKey: navigatorKey,
        translationController: translationController,
        walletService: StaticMuffinWalletService(wallet),
        enabled: enabled,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
    home: MediaQuery(
      data: MediaQueryData(viewInsets: viewInsets),
      child: Scaffold(
        body: withInput ? const TextField() : const Text('Student screen'),
      ),
    ),
  );
}
