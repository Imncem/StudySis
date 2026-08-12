import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/page_translation.dart';
import 'package:studysis/services/page_translation_service.dart';
import 'package:studysis/widgets/page_translation_scope.dart';

void main() {
  test('page translates in place and show original restores exact text',
      () async {
    final controller = PageTranslationController(
      service: _CountingTranslationService({
        'greeting': 'Hai Qidah',
        'progress': 'Kemajuan',
      }),
    );
    controller.setContent(_homeContent());

    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.malay,
    );

    expect(controller.state.isTranslated, isTrue);
    expect(controller.text('greeting', 'Hi Qidah'), 'Hai Qidah');
    expect(controller.text('progress', 'Progress'), 'Kemajuan');

    controller.showOriginal();
    expect(controller.text('greeting', 'Hi Qidah'), 'Hi Qidah');
    expect(controller.state.isTranslated, isFalse);
  });

  test('translation cache prevents duplicate service calls', () async {
    final service = _CountingTranslationService({'body': 'Translated body'});
    final controller = PageTranslationController(service: service);
    controller.setContent(_dynamicContent());

    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.malay,
    );
    controller.showOriginal();
    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.malay,
    );

    expect(service.calls, 1);
  });

  test('content change invalidates cache', () async {
    final service = _CountingTranslationService({'body': 'Translated body'});
    final controller = PageTranslationController(service: service);
    controller.setContent(_dynamicContent());
    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.malay,
    );
    controller.setContent(_dynamicContent(text: 'Another dynamic paragraph'));
    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.malay,
    );

    expect(service.calls, 2);
  });

  test('stale async translation does not apply to new page', () async {
    final service = _CompletingTranslationService();
    final controller = PageTranslationController(service: service);
    controller.setContent(
      const TranslatablePageContent(
        pageType: 'quiz',
        pageId: 'quiz_math_chapter-1_q1',
        sourceLanguage: TranslationLanguage.malay,
        fields: [
          PageTranslationField(
            id: 'question_q1',
            type: 'question',
            text: 'Soalan lambat q1',
          ),
        ],
      ),
    );

    final pending = controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.english,
    );
    await Future<void>.delayed(Duration.zero);
    controller.resetForPageChange();
    controller.setContent(
      const TranslatablePageContent(
        pageType: 'quiz',
        pageId: 'quiz_math_chapter-1_q2',
        sourceLanguage: TranslationLanguage.malay,
        fields: [
          PageTranslationField(
            id: 'question_q2',
            type: 'question',
            text: 'Soalan baharu q2',
          ),
        ],
      ),
    );
    service.complete({
      'question_q1': 'What is the next number in the following sequence?',
    });
    await pending;

    expect(controller.state.pageId, 'quiz_math_chapter-1_q2');
    expect(controller.state.status, PageTranslationStatus.idle);
    expect(
      controller.text(
        'question_q2',
        'Soalan baharu q2',
      ),
      'Soalan baharu q2',
    );
  });

  test('unsupported page shows friendly error and preserves original',
      () async {
    final controller = PageTranslationController();

    await controller.translateCurrentPage();

    expect(controller.state.status, PageTranslationStatus.error);
    expect(controller.state.errorMessage,
        'Muffin could not find translatable content on this page.');
    expect(controller.text('missing', 'Original'), 'Original');
  });

  test('stale owner cannot replace the active route registration', () {
    final controller = PageTranslationController();
    final homeOwner = Object();
    final learnOwner = Object();

    controller.registerPage(
      ownerToken: homeOwner,
      content: _homeContent(),
    );
    controller.registerPage(
      ownerToken: learnOwner,
      content: _learnContent(),
    );
    controller.unregisterPage(ownerToken: homeOwner);

    expect(controller.state.pageId, 'learn_math_chapter-1_notes');
    expect(controller.ownerToken, learnOwner);
  });

  test('practice and quiz option IDs remain stable in translation result',
      () async {
    const result = PageTranslationResult(
      sourceLanguage: TranslationLanguage.malay,
      targetLanguage: TranslationLanguage.english,
      fields: {
        'option_a': 'Number',
        'option_b': 'Shape',
      },
    );

    expect(result.fields.keys.toList(), ['option_a', 'option_b']);
  });

  test('mock translations preserve equations and student name', () async {
    const service = MockPageTranslationService();
    final result = await service.translate(
      PageTranslationRequest(
        content: const TranslatablePageContent(
          pageType: 'home',
          pageId: 'home',
          sourceLanguage: TranslationLanguage.english,
          fields: [
            PageTranslationField(id: 'name', type: 'label', text: 'Hi Qidah'),
            PageTranslationField(
                id: 'equation', type: 'math', text: '2 + x = 5'),
          ],
        ),
        targetLanguage: TranslationLanguage.malay,
      ),
    );

    expect(result.fields['name'], 'Hai Qidah');
    expect(result.fields['equation'], contains('2 + x = 5'));
  });

  test('mock translation never produces fake language prefixes', () async {
    const service = MockPageTranslationService();
    final result = await service.translate(
      PageTranslationRequest(
        content: const TranslatablePageContent(
          pageType: 'practice',
          pageId: 'practice_demo',
          sourceLanguage: TranslationLanguage.malay,
          fields: [
            PageTranslationField(
              id: 'question',
              type: 'question',
              text: 'Apakah itu pola?',
            ),
            PageTranslationField(
                id: 'option_a', type: 'option', text: 'Nombor'),
            PageTranslationField(id: 'option_b', type: 'option', text: 'Huruf'),
            PageTranslationField(id: 'option_c', type: 'option', text: 'Abjad'),
            PageTranslationField(
                id: 'option_d', type: 'option', text: 'Simbol'),
          ],
        ),
        targetLanguage: TranslationLanguage.english,
      ),
    );

    expect(result.fields['question'], 'What is a pattern?');
    expect(result.fields['option_a'], 'Number');
    expect(result.fields['option_b'], 'Letter');
    expect(result.fields['option_c'], 'Alphabet');
    expect(result.fields['option_d'], 'Symbol');
    for (final value in result.fields.values) {
      expect(value, isNot(startsWith('English:')));
      expect(value, isNot(startsWith('Malay:')));
      expect(value, isNot(startsWith('Bahasa Melayu:')));
    }
  });

  test('zero translated fields does not enter translated state', () async {
    final controller = PageTranslationController(
      service: _CountingTranslationService({'unknown': 'Unknown original'}),
    );
    controller.setContent(
      const TranslatablePageContent(
        pageType: 'learn',
        pageId: 'unknown',
        sourceLanguage: TranslationLanguage.malay,
        fields: [
          PageTranslationField(
            id: 'unknown',
            type: 'paragraph',
            text: 'Unknown original',
          ),
        ],
      ),
    );

    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.english,
    );

    expect(controller.state.status, PageTranslationStatus.error);
    expect(controller.state.isTranslated, isFalse);
    expect(controller.text('unknown', 'Unknown original'), 'Unknown original');
  });

  test('failed fields preserve original while translated fields render',
      () async {
    final controller = PageTranslationController(
      service: _CountingTranslationService({
        'question': 'What is a pattern?',
        'unknown': 'Unknown original',
      }),
    );
    controller.setContent(
      const TranslatablePageContent(
        pageType: 'practice',
        pageId: 'mixed',
        sourceLanguage: TranslationLanguage.malay,
        fields: [
          PageTranslationField(
            id: 'question',
            type: 'question',
            text: 'Apakah itu pola?',
          ),
          PageTranslationField(
            id: 'unknown',
            type: 'paragraph',
            text: 'Unknown original',
          ),
        ],
      ),
    );

    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.english,
    );

    expect(controller.state.isTranslated, isTrue);
    expect(controller.state.translatedContent?.translatedFieldCount, 1);
    expect(controller.state.translatedContent?.failedFieldCount, 1);
    expect(
        controller.text('question', 'Apakah itu pola?'), 'What is a pattern?');
    expect(controller.text('unknown', 'Unknown original'), 'Unknown original');
  });

  test('quiz translation succeeds when numeric fields are preserved', () async {
    final controller = PageTranslationController();
    const question = 'Apakah nombor seterusnya dalam jujukan berikut?\n'
        '4, 8, 12, 16, ...';
    controller.setContent(
      const TranslatablePageContent(
        pageType: 'quiz',
        pageId: 'math_chapter-01_quiz_question_1',
        sourceLanguage: TranslationLanguage.malay,
        fields: [
          PageTranslationField(
            id: 'question_1',
            type: 'question',
            text: question,
          ),
          PageTranslationField(id: 'option_a', type: 'option', text: '18'),
          PageTranslationField(id: 'option_b', type: 'option', text: '20'),
          PageTranslationField(id: 'option_c', type: 'option', text: '22'),
          PageTranslationField(id: 'option_d', type: 'option', text: '24'),
        ],
      ),
    );

    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.english,
    );

    expect(controller.state.status, PageTranslationStatus.translated);
    expect(controller.state.translatedContent?.translatedFieldCount, 1);
    expect(controller.state.translatedContent?.unchangedFieldCount, 4);
    expect(controller.state.translatedContent?.failedFieldCount, 0);
    expect(
      controller.text('question_1', question),
      'What is the next number in the following sequence?\n'
      '4, 8, 12, 16, ...',
    );
    expect(controller.text('option_b', '20'), '20');
  });

  test('real-device quiz pattern maps stable ids and preserves numeric options',
      () async {
    const questionId = 'oUk3WOGFR0V1mlbLsObl';
    const question = 'Apakah nombor seterusnya dalam jujukan berikut?\n'
        '4, 8, 12, 16, ...';
    final controller = PageTranslationController(
      service: _CountingTranslationService({
        'quizTitle': 'Chapter 1 Quiz',
        'questionProgress': 'Question 1',
        'question_$questionId':
            'What is the next number in the following sequence?\n'
                '4, 8, 12, 16, ...',
      }),
    );
    controller.setContent(
      const TranslatablePageContent(
        pageType: 'quiz',
        pageId: 'quiz_math_chapter-01_$questionId',
        sourceLanguage: TranslationLanguage.malay,
        fields: [
          PageTranslationField(
            id: 'quizTitle',
            type: 'heading',
            text: 'Chapter 1 Quiz',
          ),
          PageTranslationField(
            id: 'questionProgress',
            type: 'label',
            text: 'Question 1',
          ),
          PageTranslationField(
            id: 'question_$questionId',
            type: 'question',
            text: question,
          ),
          PageTranslationField(id: 'option_a', type: 'option', text: '18'),
          PageTranslationField(id: 'option_b', type: 'option', text: '20'),
          PageTranslationField(id: 'option_c', type: 'option', text: '22'),
          PageTranslationField(id: 'option_d', type: 'option', text: '24'),
        ],
      ),
    );

    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.english,
    );

    final result = controller.state.translatedContent;
    expect(controller.state.status, PageTranslationStatus.translated);
    expect(result?.totalFieldCount, 7);
    expect(result?.fields.length, 7);
    expect(result?.translatedFieldCount, 1);
    expect(result?.unchangedFieldCount, 6);
    expect(result?.failedFieldCount, 0);
    expect(
      controller.text('question_$questionId', question),
      'What is the next number in the following sequence?\n'
      '4, 8, 12, 16, ...',
    );
    expect(controller.text('quizTitle', 'Chapter 1 Quiz'), 'Chapter 1 Quiz');
    expect(controller.text('option_d', '24'), '24');
  });

  test('learn heading variants translate and restore from original', () async {
    final controller = PageTranslationController();
    controller.setContent(
      const TranslatablePageContent(
        pageType: 'learn',
        pageId: 'learn_math_chapter-1_notes',
        sourceLanguage: TranslationLanguage.malay,
        fields: [
          PageTranslationField(
            id: 'section_section-1_heading',
            type: 'heading',
            text: 'Apa itu Pola',
          ),
          PageTranslationField(
            id: 'section_section-2_heading',
            type: 'heading',
            text: 'Apa itu jujukan?',
          ),
        ],
      ),
    );

    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.english,
    );

    expect(
      controller.text('section_section-1_heading', 'Apa itu Pola'),
      'What is a Pattern?',
    );
    expect(
      controller.text('section_section-2_heading', 'Apa itu jujukan?'),
      'What is a sequence?',
    );

    controller.showOriginal();
    expect(
      controller.text('section_section-1_heading', 'Apa itu Pola'),
      'Apa itu Pola',
    );
  });

  test('quiz question 2 common-difference translation succeeds', () async {
    final controller = PageTranslationController();
    const question = 'Apakah beza sepunya bagi jujukan berikut?\n'
        '7, 12, 17, 22, ...';
    controller.setContent(
      const TranslatablePageContent(
        pageType: 'quiz',
        pageId: 'quiz_math_chapter-1_q2',
        sourceLanguage: TranslationLanguage.malay,
        fields: [
          PageTranslationField(
            id: 'question_q2',
            type: 'question',
            text: question,
          ),
          PageTranslationField(id: 'option_a', type: 'option', text: '3'),
          PageTranslationField(id: 'option_b', type: 'option', text: '5'),
          PageTranslationField(id: 'option_c', type: 'option', text: '7'),
          PageTranslationField(id: 'option_d', type: 'option', text: '12'),
        ],
      ),
    );

    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.english,
    );

    expect(controller.state.status, PageTranslationStatus.translated);
    expect(controller.state.translatedContent?.translatedFieldCount, 1);
    expect(controller.state.translatedContent?.unchangedFieldCount, 4);
    expect(controller.state.translatedContent?.failedFieldCount, 0);
    expect(
      controller.text('question_q2', question),
      'What is the common difference of the following sequence?\n'
      '7, 12, 17, 22, ...',
    );
  });

  testWidgets('translation banner uses responsive two-row layout',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = PageTranslationController(
      service: _CountingTranslationService({'greeting': 'Hai Qidah'}),
    );
    controller.setContent(_homeContent());
    await controller.translateCurrentPage(
      targetLanguage: TranslationLanguage.malay,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: PageTranslationScope(
            controller: controller,
            child: const Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: PageTranslationBanner(),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Diterjemahkan ke Bahasa Melayu oleh Muffin'),
        findsOneWidget);
    expect(find.text('Papar teks asal'), findsOneWidget);
    expect(find.text('Tukar bahasa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

TranslatablePageContent _learnContent() {
  return const TranslatablePageContent(
    pageType: 'learn',
    pageId: 'learn_math_chapter-1_notes',
    sourceLanguage: TranslationLanguage.english,
    fields: [
      PageTranslationField(
        id: 'section_section-1_heading',
        type: 'heading',
        text: 'Pattern',
      ),
    ],
  );
}

TranslatablePageContent _homeContent({String greeting = 'Hi Qidah'}) {
  return TranslatablePageContent(
    pageType: 'home',
    pageId: 'home_dashboard',
    sourceLanguage: TranslationLanguage.english,
    fields: [
      PageTranslationField(id: 'greeting', type: 'heading', text: greeting),
      const PageTranslationField(
        id: 'progress',
        type: 'heading',
        text: 'Progress',
      ),
    ],
  );
}

TranslatablePageContent _dynamicContent({String text = 'Dynamic paragraph'}) {
  return TranslatablePageContent(
    pageType: 'learn',
    pageId: 'dynamic_page',
    sourceLanguage: TranslationLanguage.english,
    fields: [
      PageTranslationField(id: 'body', type: 'paragraph', text: text),
    ],
  );
}

class _CountingTranslationService implements PageTranslationService {
  _CountingTranslationService(this.values);

  final Map<String, String> values;
  int calls = 0;

  @override
  Future<PageTranslationResult> translate(
      PageTranslationRequest request) async {
    calls += 1;
    return PageTranslationResult(
      sourceLanguage: request.content.sourceLanguage,
      targetLanguage: request.targetLanguage,
      fields: {
        for (final field in request.content.fields)
          field.id: values[field.id] ?? field.text,
      },
    );
  }
}

class _CompletingTranslationService implements PageTranslationService {
  final _completer = Completer<Map<String, String>>();

  @override
  Future<PageTranslationResult> translate(
    PageTranslationRequest request,
  ) async {
    final fields = await _completer.future;
    return PageTranslationResult(
      sourceLanguage: request.content.sourceLanguage,
      targetLanguage: request.targetLanguage,
      fields: fields,
    );
  }

  void complete(Map<String, String> fields) {
    _completer.complete(fields);
  }
}
