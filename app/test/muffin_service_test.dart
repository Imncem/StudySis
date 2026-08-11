import 'package:flutter_test/flutter_test.dart';
import 'package:studysis/models/muffin.dart';
import 'package:studysis/services/muffin_safety_policy.dart';
import 'package:studysis/services/muffin_service.dart';

void main() {
  test('learn request serialization includes current lesson context', () {
    final request = const MuffinRequest(
      mode: MuffinMode.learn,
      action: MuffinAction.explainSimply,
      context: MuffinContext(
        mode: MuffinMode.learn,
        currentScreen: 'learn',
        subjectId: 'math',
        chapterId: 'chapter-1',
        lessonHeading: 'Apa itu Pola',
        lessonBody: 'Pola ialah susunan yang mengikut peraturan.',
        displayedLanguage: 'ms',
        contextKey: 'learn_math_chapter-1_section_section-1',
      ),
    );

    final context = request.toJson()['context']! as Map<String, Object?>;
    expect(context['lessonHeading'], 'Apa itu Pola');
    expect(context['lessonBody'], contains('Pola'));
    expect(context['displayedLanguage'], 'ms');
    expect(context['contextKey'], 'learn_math_chapter-1_section_section-1');
  });

  test('flashcard current-card serialization excludes hidden answer', () {
    final request = const MuffinRequest(
      mode: MuffinMode.learn,
      action: MuffinAction.explainSimply,
      context: MuffinContext(
        mode: MuffinMode.learn,
        currentScreen: 'flashcards',
        subjectId: 'math',
        chapterId: 'chapter-1',
        cardId: 'card-3',
        currentQuestion: 'Apakah beza antara pola dan jujukan?',
        relevantNotes: ['Current side: front'],
        displayedLanguage: 'ms',
        contextKey: 'flashcard_math_chapter-1_card_card-3_front',
      ),
    );

    final context = request.toJson()['context']! as Map<String, Object?>;
    expect(context['cardId'], 'card-3');
    expect(context['currentQuestion'], 'Apakah beza antara pola dan jujukan?');
    expect(context.containsKey('lessonBody'), isFalse);
    expect(context['contextKey'], contains('card-3_front'));
  });

  test('practice request serialization includes generated-question context',
      () {
    final request = const MuffinRequest(
      mode: MuffinMode.practice,
      action: MuffinAction.generateSimilarQuestion,
      context: MuffinContext(
        mode: MuffinMode.practice,
        currentScreen: 'practice',
        subjectId: 'math',
        chapterId: 'chapter-1',
        currentQuestion: 'Apakah nombor seterusnya?',
        answerOptions: ['8', '10', '12', '14'],
        relevantNotes: ['Topic: patterns', 'Difficulty: easy'],
        displayedLanguage: 'ms',
        contextKey: 'practice_math_chapter-1_q1_attempt',
      ),
    );

    final context = request.toJson()['context']! as Map<String, Object?>;
    expect(request.toJson()['action'], 'generateSimilarQuestion');
    expect(context['currentQuestion'], 'Apakah nombor seterusnya?');
    expect(context['answerOptions'], ['8', '10', '12', '14']);
    expect(context['displayedLanguage'], 'ms');
  });

  test('remote service request serialization uses safe context keys', () {
    final request = MuffinRequest(
      mode: MuffinMode.quiz,
      action: MuffinAction.smallHint,
      context: MuffinContext(
        mode: MuffinMode.quiz,
        subjectId: 'math',
        chapterId: 'chapter-1',
        currentQuestion: 'What comes next?',
        answerOptions: const ['2', '4', '6', '8'],
        selectedStudentAnswer: '4',
        questionId: 'q2',
        displayedLanguage: 'ms',
        contextKey: 'quiz_math_chapter-1_question_q2',
      ),
    );

    final json = request.toJson();
    final context = json['context']! as Map<String, Object?>;
    expect(json['mode'], 'quiz');
    expect(json['action'], 'smallHint');
    expect(context['currentQuestion'], 'What comes next?');
    expect(context['answerOptions'], ['2', '4', '6', '8']);
    expect(context.containsKey('correctOptionIndex'), isFalse);
    expect(context.containsKey('correctAnswer'), isFalse);
    expect(context.containsKey('explanation'), isFalse);
    expect(context['questionId'], 'q2');
    expect(context['displayedLanguage'], 'ms');
    expect(context['contextKey'], 'quiz_math_chapter-1_question_q2');
  });

  test('safe context truncates long note content', () {
    final context = MuffinContext(
      mode: MuffinMode.learn,
      lessonBody: List.filled(1200, 'a').join(),
    ).toJson();

    expect((context['lessonBody']! as String).length, lessThanOrEqualTo(903));
    expect(context['lessonBody'], endsWith('...'));
  });

  test('quiz policy refuses unsupported direct-answer style action', () {
    final policy = MuffinSafetyPolicy();
    final response = policy.validate(
      const MuffinRequest(
        mode: MuffinMode.quiz,
        action: MuffinAction.generateSimilarQuestion,
        context: MuffinContext(mode: MuffinMode.quiz),
      ),
    );

    expect(response, isNotNull);
    expect(response!.responseType, MuffinResponseType.refusal);
  });

  test('mock service returns supported action responses', () async {
    final service = MockMuffinService();

    final explanation = await service.ask(
      const MuffinRequest(
        mode: MuffinMode.learn,
        action: MuffinAction.explainSimply,
        context: MuffinContext(mode: MuffinMode.learn),
      ),
    );
    final translation = await service.ask(
      const MuffinRequest(
        mode: MuffinMode.learn,
        action: MuffinAction.translate,
        context: MuffinContext(
          mode: MuffinMode.learn,
          targetLanguage: 'Bahasa Melayu',
        ),
      ),
    );
    final generated = await service.ask(
      const MuffinRequest(
        mode: MuffinMode.practice,
        action: MuffinAction.generateSimilarQuestion,
        context: MuffinContext(mode: MuffinMode.practice),
      ),
    );

    expect(explanation.responseType, MuffinResponseType.explanation);
    expect(translation.responseType, MuffinResponseType.translation);
    expect(translation.translatedText, isNotNull);
    expect(generated.responseType, MuffinResponseType.generatedQuestion);
    expect(generated.generatedQuestion!.generatedByMuffin, isTrue);
  });

  test('generated question parsing keeps answer check fields for practice only',
      () {
    final response = MuffinResponse.fromJson({
      'responseType': 'generatedQuestion',
      'message': 'Generated by Muffin.',
      'detectedLanguage': 'en',
      'generatedQuestion': {
        'question': 'Which is a pattern?',
        'options': ['A', 'B', 'C', 'D'],
        'correctOptionIndex': 1,
        'explanation': 'B follows a clear rule.',
        'difficulty': 'easy',
        'topic': 'patterns',
        'generatedByMuffin': true,
      },
    });

    final json = response.toJson();
    final generated = json['generatedQuestion']! as Map<String, Object?>;
    expect(json['detectedLanguage'], 'en');
    expect(generated['generatedByMuffin'], isTrue);
    expect(generated.containsKey('correctAnswer'), isFalse);
    expect(generated['correctOptionIndex'], 1);
    expect(generated['explanation'], 'B follows a clear rule.');
  });

  test('repeated mock examples are not immediately identical', () async {
    final service = MockMuffinService();
    final first = await service.ask(
      const MuffinRequest(
        mode: MuffinMode.learn,
        action: MuffinAction.anotherExample,
        context: MuffinContext(mode: MuffinMode.learn),
      ),
    );
    final second = await service.ask(
      MuffinRequest(
        mode: MuffinMode.learn,
        action: MuffinAction.anotherExample,
        context: MuffinContext(
          mode: MuffinMode.learn,
          previousExampleIds: [first.message],
        ),
      ),
    );

    expect(second.message, isNot(first.message));
  });

  test('mock translation can translate latest Muffin example to Malay',
      () async {
    final service = MockMuffinService();
    final example = await service.ask(
      const MuffinRequest(
        mode: MuffinMode.learn,
        action: MuffinAction.anotherExample,
        context: MuffinContext(mode: MuffinMode.learn),
      ),
    );
    final translation = await service.ask(
      MuffinRequest(
        mode: MuffinMode.learn,
        action: MuffinAction.translate,
        context: MuffinContext(
          mode: MuffinMode.learn,
          currentMuffinContent: example.message,
          targetLanguage: 'Bahasa Melayu',
        ),
      ),
    );

    expect(translation.translatedText, contains('bertambah'));
  });

  test('mock translation to English does not return Malay content', () async {
    final service = MockMuffinService();
    final translation = await service.ask(
      const MuffinRequest(
        mode: MuffinMode.learn,
        action: MuffinAction.translate,
        context: MuffinContext(
          mode: MuffinMode.learn,
          currentMuffinContent: 'Terjemahan: perhatikan corak.',
          targetLanguage: 'English',
        ),
      ),
    );

    expect(translation.translatedText, contains('Translation:'));
    expect(translation.translatedText, isNot(contains('Terjemahan')));
  });

  test('flashcard explanations use current card content', () async {
    final service = MockMuffinService();
    final pattern = await service.ask(
      const MuffinRequest(
        mode: MuffinMode.learn,
        action: MuffinAction.explainSimply,
        context: MuffinContext(
          mode: MuffinMode.learn,
          currentScreen: 'flashcards',
          currentQuestion: 'Apakah itu pola?',
          contextKey: 'flashcard_math_chapter-1_card_1_front',
        ),
      ),
    );
    final difference = await service.ask(
      const MuffinRequest(
        mode: MuffinMode.learn,
        action: MuffinAction.explainSimply,
        context: MuffinContext(
          mode: MuffinMode.learn,
          currentScreen: 'flashcards',
          currentQuestion: 'Apakah itu beza tetap?',
          contextKey: 'flashcard_math_chapter-1_card_2_front',
        ),
      ),
    );

    expect(pattern.message, contains('pola'));
    expect(difference.message, contains('beza sepunya'));
    expect(pattern.message, isNot(difference.message));
  });

  test('quiz guidance uses current Malay common-difference question', () async {
    final service = MockMuffinService();
    final response = await service.ask(
      const MuffinRequest(
        mode: MuffinMode.quiz,
        action: MuffinAction.guideQuestion,
        context: MuffinContext(
          mode: MuffinMode.quiz,
          currentQuestion: 'Apakah beza sepunya bagi jujukan berikut?',
          answerOptions: ['3', '5', '7', '12'],
          originalScreenContent:
              'Apakah beza sepunya bagi jujukan berikut?\n7, 12, 17, 22, ...',
          contextKey: 'quiz_math_chapter-1_q2',
        ),
      ),
    );

    expect(response.message, contains('12 dan 7'));
    expect(response.message, isNot(contains('jawapan')));
  });
}
