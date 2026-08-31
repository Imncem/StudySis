import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/muffin.dart';
import 'muffin_safety_policy.dart';

abstract class MuffinService {
  Future<MuffinResponse> ask(MuffinRequest request);

  Future<MuffinAvailabilityResponse> availability(
    MuffinAvailabilityRequest request,
  );
}

class MuffinServiceFactory {
  static final MockMuffinService _mock = MockMuffinService();

  static MuffinService create() {
    const useMock = bool.fromEnvironment(
      'MUFFIN_USE_MOCK',
      defaultValue: true,
    );
    const endpoint = String.fromEnvironment('MUFFIN_ENDPOINT');
    if (useMock || endpoint.isEmpty) return _mock;
    return RemoteMuffinService(
      endpoint: Uri.parse(endpoint),
      availabilityEndpoint: _availabilityEndpoint(endpoint),
    );
  }

  static Uri _availabilityEndpoint(String endpoint) {
    const explicit = String.fromEnvironment('MUFFIN_AVAILABILITY_ENDPOINT');
    if (explicit.isNotEmpty) return Uri.parse(explicit);
    final askMuffinSuffix = RegExp(r'askMuffin/?$');
    if (askMuffinSuffix.hasMatch(endpoint)) {
      return Uri.parse(
        endpoint.replaceFirst(
          askMuffinSuffix,
          'getMuffinActionAvailability',
        ),
      );
    }
    return Uri.parse(endpoint);
  }
}

class MockMuffinService implements MuffinService {
  MockMuffinService({MuffinSafetyPolicy policy = const MuffinSafetyPolicy()})
      : _policy = policy;

  final MuffinSafetyPolicy _policy;
  final Map<String, int> _exampleIndices = {};
  final Set<String> _cachedActions = {};

  static const _examples = [
    _MockExample(
      id: 'example_1',
      en: 'Example 1: 2, 4, 6, 8 grows by adding 2 each time.',
      ms: 'Contoh 1: 2, 4, 6, 8 bertambah dengan menambah 2 setiap kali.',
    ),
    _MockExample(
      id: 'example_2',
      en: 'Example 2: 5, 10, 15, 20 grows by adding 5 each time.',
      ms: 'Contoh 2: 5, 10, 15, 20 meningkat dengan menambah 5 setiap kali.',
    ),
    _MockExample(
      id: 'example_3',
      en: 'Example 3: 3, 6, 12, 24 grows by multiplying by 2 each time.',
      ms: 'Contoh 3: 3, 6, 12, 24 meningkat dengan mendarab 2 setiap kali.',
    ),
    _MockExample(
      id: 'example_4',
      en: 'Example 4: 20, 17, 14, 11 changes by subtracting 3 each time.',
      ms: 'Contoh 4: 20, 17, 14, 11 berubah dengan menolak 3 setiap kali.',
    ),
    _MockExample(
      id: 'example_5',
      en: 'Example 5: 1, 3, 5, 7 grows by adding 2 each time.',
      ms: 'Contoh 5: 1, 3, 5, 7 meningkat dengan menambah 2 setiap kali.',
    ),
  ];

  @override
  Future<MuffinResponse> ask(MuffinRequest request) async {
    final refusal = _policy.validate(request);
    if (refusal != null) return refusal;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final cacheKey = _mockCacheKey(request);
    final cached = _cachedActions.contains(cacheKey);
    if (request.expectCached && !cached) {
      return const MuffinResponse(
        responseType: MuffinResponseType.error,
        message: 'Saved help is no longer available. Tap again to use 🍪1.',
        resultSource: 'cached_help_unavailable',
        biteCharged: 0,
      );
    }
    final response = switch (request.action) {
      MuffinAction.askMuffin => const MuffinResponse(
          responseType: MuffinResponseType.explanation,
          message:
              'I can help with your current lesson, translation, revision, or a short practice question.',
        ),
      MuffinAction.explainSimply => MuffinResponse(
          responseType: MuffinResponseType.explanation,
          message: _explanationForContext(request.context),
          suggestedNextAction: 'Try saying the rule aloud.',
        ),
      MuffinAction.translate => _mockTranslation(request),
      MuffinAction.anotherExample => _mockExampleResponse(request),
      MuffinAction.stillConfused => const MuffinResponse(
          responseType: MuffinResponseType.explanation,
          message:
              'That is okay. Let us slow down: look at one change first, then say what happened in your own words.',
        ),
      MuffinAction.smallHint => MuffinResponse(
          responseType: MuffinResponseType.hint,
          message: _hintForContext(request.context),
        ),
      MuffinAction.explainConcept => MuffinResponse(
          responseType: MuffinResponseType.explanation,
          message: _conceptForContext(request.context),
        ),
      MuffinAction.identifyPattern => const MuffinResponse(
          responseType: MuffinResponseType.hint,
          message:
              'Compare the numbers or terms beside each other. Is the change adding, subtracting, multiplying, or dividing?',
        ),
      MuffinAction.guideQuestion => MuffinResponse(
          responseType: MuffinResponseType.hint,
          message: _guideForContext(request.context),
        ),
      MuffinAction.generateSimilarQuestion => const MuffinResponse(
          responseType: MuffinResponseType.generatedQuestion,
          message:
              'Generated by Muffin. Try this similar question for practice.',
          generatedQuestion: MuffinGeneratedQuestion(
            question: 'Which sequence adds the same amount each time?',
            options: ['2, 4, 6, 8', '1, 2, 4, 8', '9, 7, 4, 0', '3, 3, 6, 9'],
            correctOptionIndex: 0,
            explanation: '2, 4, 6, 8 adds 2 each time.',
            difficulty: 'easy',
            topic: 'patterns',
            generatedByMuffin: true,
          ),
        ),
    };
    if (request.action != MuffinAction.translate &&
        request.action != MuffinAction.anotherExample) {
      _cachedActions.add(cacheKey);
    }
    return MuffinResponse(
      responseType: response.responseType,
      message: response.message,
      detectedLanguage: response.detectedLanguage,
      translatedText: response.translatedText,
      generatedQuestion: response.generatedQuestion,
      suggestedNextAction: response.suggestedNextAction,
      resultSource: cached ? 'cache' : 'local',
      biteCharged: cached || request.action == MuffinAction.translate ? 0 : 1,
    );
  }

  @override
  Future<MuffinAvailabilityResponse> availability(
    MuffinAvailabilityRequest request,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    return MuffinAvailabilityResponse(
      actions: {
        for (final action in request.actions)
          action: MuffinActionAvailability(
            cached: _cachedActions.contains(
              _mockCacheKey(
                MuffinRequest(
                  mode: request.mode,
                  action: action,
                  context: request.context,
                ),
              ),
            ),
            biteCost: _cachedActions.contains(
              _mockCacheKey(
                MuffinRequest(
                  mode: request.mode,
                  action: action,
                  context: request.context,
                ),
              ),
            )
                ? 0
                : action == MuffinAction.translate
                    ? 0
                    : 1,
          ),
      },
    );
  }

  MuffinResponse _mockTranslation(MuffinRequest request) {
    final target = request.context.targetLanguage ??
        request.context.preferredLanguage ??
        'Bahasa Melayu';
    final source = request.context.currentMuffinContent ??
        request.context.originalScreenContent ??
        request.context.currentQuestion ??
        request.context.lessonBody ??
        '';
    final translated = target == 'English'
        ? _englishTranslation(source)
        : _malayTranslation(source);
    return MuffinResponse(
      responseType: MuffinResponseType.translation,
      message: 'Here is a gentle $target translation.',
      translatedText: translated,
    );
  }

  MuffinResponse _mockExampleResponse(MuffinRequest request) {
    final example = _nextExample(request.context);
    return MuffinResponse(
      responseType: MuffinResponseType.example,
      message: example.en,
      suggestedNextAction: example.id,
    );
  }

  String _mockCacheKey(MuffinRequest request) {
    return [
      request.mode.name,
      request.action.name,
      request.context.subjectId,
      request.context.chapterId,
      request.context.questionId,
      request.context.cardId,
      request.context.contextKey,
      request.context.displayedLanguage,
      request.context.currentQuestion,
      request.context.lessonHeading,
      request.context.lessonBody,
      request.context.originalScreenContent,
      request.context.currentMuffinContent,
    ].whereType<String>().join('|');
  }

  _MockExample _nextExample(MuffinContext context) {
    final contextKey = context.contextKey ??
        context.currentQuestion ??
        context.lessonHeading ??
        context.currentScreen ??
        context.mode.name;
    final previous = context.previousExampleIds ?? const <String>[];
    for (var attempt = 0; attempt < _examples.length; attempt++) {
      final cursor = _exampleIndices[contextKey] ?? 0;
      _exampleIndices[contextKey] = cursor + 1;
      final example = _examples[cursor % _examples.length];
      if (!previous.contains(example.id) && !previous.contains(example.en)) {
        return example;
      }
    }
    final index = _exampleIndices[contextKey] ?? 0;
    final example = _examples[index % _examples.length];
    _exampleIndices[contextKey] = index + 1;
    return example;
  }

  String _explanationForContext(MuffinContext context) {
    final language = _responseLanguage(context);
    final text = _contextText(context);
    if (_containsAny(
        text, ['beza tetap', 'beza sepunya', 'common difference'])) {
      return language == 'ms'
          ? 'Kad ini tentang beza sepunya. Bandingkan nombor berturutan dan lihat sama ada bezanya kekal sama.'
          : 'This card is about common difference. Compare neighboring numbers and check whether the difference stays the same.';
    }
    if (_containsAny(text, ['jujukan', 'sequence'])) {
      return language == 'ms'
          ? 'Kad ini tentang jujukan. Jujukan ialah senarai nombor yang disusun mengikut urutan atau peraturan tertentu.'
          : 'This card is about sequences. A sequence is a list of numbers arranged in order using a rule.';
    }
    if (_containsAny(text, ['pola', 'pattern'])) {
      return language == 'ms'
          ? 'Kad ini tentang pola. Pola ialah susunan nombor, bentuk, atau objek yang mengikut peraturan tertentu.'
          : 'This card is about patterns. A pattern is an arrangement of numbers, shapes, or objects that follows a rule.';
    }
    return language == 'ms'
        ? 'Fikirkan idea ini dalam langkah kecil. Perhatikan apa yang berubah, kemudian terangkan peraturannya dengan kata-kata sendiri.'
        : 'Think of this idea in smaller steps. First, notice what changes. Then describe the rule in your own words.';
  }

  String _hintForContext(MuffinContext context) {
    final language = _responseLanguage(context);
    final text = _contextText(context);
    if (_containsAny(
        text, ['7, 12, 17, 22', 'beza sepunya', 'common difference'])) {
      return language == 'ms'
          ? 'Bandingkan dua nombor berturutan. Cuba kira beza antara 12 dan 7, kemudian semak beza nombor seterusnya.'
          : 'Compare two neighboring numbers. Try the difference between 12 and 7, then check the next pair.';
    }
    if (_containsAny(text, ['4, 8, 12, 16'])) {
      return language == 'ms'
          ? 'Lihat perubahan daripada satu nombor ke nombor seterusnya dan cari perubahan yang sama.'
          : 'Look at how one number changes to the next and find the repeated change.';
    }
    return language == 'ms'
        ? 'Mula dengan melihat apa yang berubah daripada satu bahagian ke bahagian seterusnya.'
        : 'Start by looking for what changes from one part to the next.';
  }

  String _conceptForContext(MuffinContext context) {
    final language = _responseLanguage(context);
    final text = _contextText(context);
    if (_containsAny(
        text, ['beza tetap', 'beza sepunya', 'common difference'])) {
      return language == 'ms'
          ? 'Beza sepunya ialah perubahan yang sama antara dua nombor berturutan dalam jujukan.'
          : 'A common difference is the same change between neighboring numbers in a sequence.';
    }
    if (_containsAny(text, ['jujukan', 'sequence'])) {
      return language == 'ms'
          ? 'Jujukan menggunakan susunan. Untuk memahaminya, cari peraturan yang menghubungkan setiap nombor.'
          : 'A sequence uses order. To understand it, find the rule that connects each number.';
    }
    return language == 'ms'
        ? 'Konsep ini tentang mencari hubungan, kemudian menggunakan hubungan itu dengan teliti.'
        : 'This concept is about finding a relationship, then using that relationship carefully.';
  }

  String _guideForContext(MuffinContext context) {
    final language = _responseLanguage(context);
    final text = _contextText(context);
    if (_containsAny(
        text, ['7, 12, 17, 22', 'beza sepunya', 'common difference'])) {
      return language == 'ms'
          ? 'Bandingkan dua nombor berturutan. Cuba kira beza antara 12 dan 7, kemudian semak sama ada beza yang sama berlaku pada nombor seterusnya.'
          : 'Compare two neighboring numbers. Try the difference between 12 and 7, then check whether the same difference appears in the next numbers.';
    }
    if (_containsAny(text, ['4, 8, 12, 16'])) {
      return language == 'ms'
          ? 'Baca soalan dan fokus pada jujukan. Bandingkan 8 dengan 4, kemudian semak sama ada perubahan yang sama berulang.'
          : 'Read the question and focus on the sequence. Compare 8 with 4, then check whether the same change repeats.';
    }
    return language == 'ms'
        ? 'Baca soalan, gariskan apa yang ditanya, kemudian bandingkan nilai yang diberi langkah demi langkah.'
        : 'Read the question, underline what it is asking, then compare the given values step by step.';
  }

  String _responseLanguage(MuffinContext context) {
    final target = context.targetLanguage?.toLowerCase();
    if (target != null) {
      if (target.contains('english')) return 'en';
      if (target.contains('melayu') || target.contains('malay')) return 'ms';
    }
    final displayed = context.displayedLanguage?.toLowerCase();
    if (displayed != null) {
      if (displayed == 'en' || displayed.contains('english')) return 'en';
      if (displayed == 'ms' ||
          displayed.contains('melayu') ||
          displayed.contains('malay')) {
        return 'ms';
      }
    }
    final text = _contextText(context);
    final malaySignals =
        RegExp(r'\b(apakah|ialah|dan|yang|dengan|nombor|pola|beza|jujukan)\b')
            .allMatches(text)
            .length;
    final englishSignals =
        RegExp(r'\b(what|is|the|and|with|number|pattern|difference|sequence)\b')
            .allMatches(text)
            .length;
    if (malaySignals > englishSignals) return 'ms';
    return 'en';
  }

  String _contextText(MuffinContext context) {
    return [
      context.currentQuestion,
      context.lessonHeading,
      context.lessonBody,
      context.originalScreenContent,
      ...?context.answerOptions,
      ...?context.relevantFlashcards,
      ...?context.relevantNotes,
    ].whereType<String>().join(' ').toLowerCase();
  }

  bool _containsAny(String text, List<String> needles) {
    return needles.any((needle) => text.contains(needle.toLowerCase()));
  }

  String _malayTranslation(String source) {
    for (final example in _examples) {
      if (source.contains(example.id) || source.contains(example.en)) {
        return example.ms;
      }
    }
    if (source.contains('2, 4, 6, 8')) {
      return 'Contoh: 2, 4, 6, 8 bertambah dengan menambah 2 setiap kali.';
    }
    if (source.contains('smaller steps')) {
      return 'Fikirkan idea ini dalam langkah yang lebih kecil. Mula-mula, perhatikan apa yang berubah. Kemudian terangkan peraturannya dengan kata-kata sendiri.';
    }
    if (source.contains('slow down')) {
      return 'Tidak mengapa. Mari perlahan-lahan: lihat satu perubahan dahulu, kemudian katakan apa yang berlaku dengan kata-kata sendiri.';
    }
    return 'Terjemahan: perhatikan corak, kekalkan nombor dan simbol, kemudian cari peraturannya.';
  }

  String _englishTranslation(String source) {
    for (final example in _examples) {
      if (source.contains(example.id) || source.contains(example.ms)) {
        return example.en;
      }
    }
    if (source.contains('langkah yang lebih kecil')) {
      return 'Think of this idea in smaller steps. First, notice what changes. Then describe the rule in your own words.';
    }
    if (source.contains('perlahan-lahan')) {
      return 'That is okay. Let us slow down: look at one change first, then say what happened in your own words.';
    }
    if (source.contains('semak sama ada beza yang sama')) {
      return 'Compare two neighboring numbers. Try the difference between 12 and 7, then check whether the same difference appears in the next numbers.';
    }
    if (source.contains('Cuba kira beza antara 12 dan 7') ||
        source.contains('cuba kira beza antara 12 dan 7')) {
      return 'Compare two neighboring numbers. Try the difference between 12 and 7, then check the next pair.';
    }
    return 'Translation: notice the pattern, keep the numbers and symbols, then find the rule.';
  }
}

class _MockExample {
  const _MockExample({
    required this.id,
    required this.en,
    required this.ms,
  });

  final String id;
  final String en;
  final String ms;
}

class RemoteMuffinService implements MuffinService {
  RemoteMuffinService({
    required Uri endpoint,
    required Uri availabilityEndpoint,
    FirebaseAuth? auth,
    http.Client? httpClient,
    Future<String?> Function()? idTokenProvider,
    MuffinSafetyPolicy policy = const MuffinSafetyPolicy(),
    Duration timeout = const Duration(seconds: 20),
  })  : _endpoint = endpoint,
        _availabilityEndpoint = availabilityEndpoint,
        _auth = auth,
        _httpClient = httpClient ?? http.Client(),
        _idTokenProvider = idTokenProvider,
        _policy = policy,
        _timeout = timeout;

  final Uri _endpoint;
  final Uri _availabilityEndpoint;
  final FirebaseAuth? _auth;
  final http.Client _httpClient;
  final Future<String?> Function()? _idTokenProvider;
  final MuffinSafetyPolicy _policy;
  final Duration _timeout;

  @override
  Future<MuffinResponse> ask(MuffinRequest request) async {
    final refusal = _policy.validate(request);
    if (refusal != null) return refusal;
    final token = await _getIdToken();
    if (token == null || token.isEmpty) {
      return const MuffinResponse(
        responseType: MuffinResponseType.error,
        message: 'Muffin could not respond right now.',
      );
    }
    final requestId = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final stopwatch = Stopwatch()..start();
    _logRemoteRequest(requestId, request);
    try {
      final response = await _httpClient
          .post(
            _endpoint,
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          debugPrint(
            '[StudySis][muffin] requestId=$requestId failed category=http_${response.statusCode}',
          );
        }
        return const MuffinResponse(
          responseType: MuffinResponseType.error,
          message:
              'Muffin could not respond right now. Your learning progress is safe. Please try again.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid Muffin response.');
      }
      final muffinResponse = MuffinResponse.fromJson(decoded);
      if (kDebugMode) {
        debugPrint(
          '[StudySis][muffin] requestId=$requestId success '
          'durationMs=${stopwatch.elapsedMilliseconds} '
          'responseType=${muffinResponse.responseType.name}',
        );
      }
      return muffinResponse;
    } on TimeoutException {
      if (kDebugMode) {
        debugPrint('[StudySis][muffin] requestId=$requestId failed timeout');
      }
      return const MuffinResponse(
        responseType: MuffinResponseType.error,
        message:
            'Muffin is taking a little longer than usual. Please try again.',
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[StudySis][muffin] requestId=$requestId failed: $error');
        debugPrint('[StudySis][muffin] stackTrace=$stackTrace');
      }
      return const MuffinResponse(
        responseType: MuffinResponseType.error,
        message:
            'Muffin could not respond right now. Your learning progress is safe. Please try again.',
      );
    }
  }

  @override
  Future<MuffinAvailabilityResponse> availability(
    MuffinAvailabilityRequest request,
  ) async {
    final token = await _getIdToken();
    if (token == null || token.isEmpty) {
      return const MuffinAvailabilityResponse(actions: {});
    }
    final requestId = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    try {
      final response = await _httpClient
          .post(
            _availabilityEndpoint,
            headers: {
              'content-type': 'application/json',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (kDebugMode) {
          debugPrint(
            '[StudySis][muffin] availability requestId=$requestId failed category=http_${response.statusCode}',
          );
        }
        return const MuffinAvailabilityResponse(actions: {});
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid Muffin availability response.');
      }
      return MuffinAvailabilityResponse.fromJson(decoded);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[StudySis][muffin] availability requestId=$requestId failed: $error',
        );
        debugPrint('[StudySis][muffin] availability stackTrace=$stackTrace');
      }
      return const MuffinAvailabilityResponse(actions: {});
    }
  }

  Future<String?> _getIdToken() {
    final provider = _idTokenProvider;
    if (provider != null) return provider();
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    return user?.getIdToken() ?? Future<String?>.value();
  }

  void _logRemoteRequest(String requestId, MuffinRequest request) {
    if (!kDebugMode) return;
    final context = request.context;
    final fields = <String>[
      if (context.lessonHeading?.trim().isNotEmpty == true)
        'lessonHeading="${context.lessonHeading}"',
      if (context.lessonBody?.trim().isNotEmpty == true)
        'lessonBody="${context.lessonBody}"',
      if (context.currentQuestion?.trim().isNotEmpty == true)
        'currentQuestion="${context.currentQuestion}"',
      if (context.originalScreenContent?.trim().isNotEmpty == true)
        'originalScreenContent="${context.originalScreenContent}"',
    ];
    final payload = context.toJson();
    final prohibited = [
      'correctOptionIndex',
      'correctAnswer',
      'answer',
      'explanation',
    ].where(payload.containsKey).join(',');
    debugPrint(
      '[StudySis][muffin] MUFFIN REQUEST requestId=$requestId '
      'mode=${request.mode.name} action=${request.action.name} '
      'contextKey=${context.contextKey} subject=${context.subjectId} '
      'chapter=${context.chapterId} questionId=${context.questionId} '
      'cardId=${context.cardId} language=${context.displayedLanguage} '
      'fieldCount=${payload.length} prohibitedAnswerData=${prohibited.isNotEmpty}',
    );
    for (final field in fields) {
      debugPrint('[StudySis][muffin] requestId=$requestId $field');
    }
  }
}
