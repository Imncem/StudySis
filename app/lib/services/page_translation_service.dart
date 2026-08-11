import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/page_translation.dart';

abstract class PageTranslationService {
  Future<PageTranslationResult> translate(PageTranslationRequest request);
}

class PageTranslationServiceFactory {
  PageTranslationServiceFactory._();

  static PageTranslationService? _override;

  static void override(PageTranslationService? service) {
    _override = service;
  }

  static PageTranslationService create() {
    if (_override != null) return _override!;
    const useMock = bool.fromEnvironment(
      'MUFFIN_USE_MOCK',
      defaultValue: true,
    );
    const explicitEndpoint = String.fromEnvironment(
      'MUFFIN_TRANSLATION_ENDPOINT',
    );
    const muffinEndpoint = String.fromEnvironment('MUFFIN_ENDPOINT');
    final endpoint = explicitEndpoint.isNotEmpty
        ? explicitEndpoint
        : _translationEndpointFrom(muffinEndpoint);
    if (useMock || endpoint.isEmpty) return const MockPageTranslationService();
    return RemotePageTranslationService(endpoint: Uri.parse(endpoint));
  }

  static String _translationEndpointFrom(String muffinEndpoint) {
    if (muffinEndpoint.isEmpty) return '';
    final askMuffinSuffix = RegExp(r'askMuffin/?$');
    if (!askMuffinSuffix.hasMatch(muffinEndpoint)) return '';
    return muffinEndpoint.replaceFirst(askMuffinSuffix, 'translateMuffinPage');
  }
}

class MockPageTranslationService implements PageTranslationService {
  const MockPageTranslationService();

  @override
  Future<PageTranslationResult> translate(
      PageTranslationRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return PageTranslationResult(
      sourceLanguage: request.content.sourceLanguage,
      targetLanguage: request.targetLanguage,
      totalFieldCount: request.content.fields.length,
      fields: {
        for (final field in request.content.fields)
          field.id: _translateText(field.text, request.targetLanguage),
      },
    );
  }

  String _translateText(String text, String targetLanguage) {
    if (_preserve(text)) return text;
    final normalized = _normalize(text);
    final exact = targetLanguage == TranslationLanguage.english
        ? _msToEn[normalized]
        : _enToMs[normalized];
    if (exact != null) return exact;
    return _translateLines(text, targetLanguage);
  }

  bool _preserve(String text) {
    return RegExp(r'^[A-D]$|^\d+(\s*/\s*\d+)?$|^\d+%$|^[\d\s,+\-*/=.xX()%]+$')
        .hasMatch(text.trim());
  }

  String _translateLines(String text, String targetLanguage) {
    final lines = text.split('\n');
    var changed = false;
    final translated = <String>[];
    for (final line in lines) {
      final normalized = _normalize(line);
      final mapped = targetLanguage == TranslationLanguage.english
          ? _msToEn[normalized]
          : _enToMs[normalized];
      if (mapped != null) {
        changed = true;
        translated.add(mapped);
      } else {
        translated.add(line);
      }
    }
    return changed ? translated.join('\n') : text;
  }
}

class PageTranslationException implements Exception {
  const PageTranslationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RemotePageTranslationService implements PageTranslationService {
  RemotePageTranslationService({
    required Uri endpoint,
    FirebaseAuth? auth,
    HttpClient? httpClient,
    Duration timeout = const Duration(seconds: 25),
  })  : _endpoint = endpoint,
        _auth = auth,
        _httpClient = httpClient ?? HttpClient(),
        _timeout = timeout;

  final Uri _endpoint;
  final FirebaseAuth? _auth;
  final HttpClient _httpClient;
  final Duration _timeout;

  @override
  Future<PageTranslationResult> translate(
    PageTranslationRequest request,
  ) async {
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null) {
      throw const PageTranslationException(
        'Muffin could not translate this page right now.',
      );
    }
    final requestId = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final stopwatch = Stopwatch()..start();
    if (kDebugMode) {
      debugPrint(
        '[StudySis][page-translation] requestId=$requestId '
        'pageId=${request.content.pageId} pageType=${request.content.pageType} '
        'fields=${request.content.fields.length}',
      );
    }
    try {
      final token = await user.getIdToken();
      final httpRequest =
          await _httpClient.postUrl(_endpoint).timeout(_timeout);
      httpRequest.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token');
      httpRequest.write(jsonEncode(request.toJson()));
      final response = await httpRequest.close().timeout(_timeout);
      final body = await utf8.decodeStream(response).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const PageTranslationException(
          'Muffin could not translate this page right now.',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid page translation response.');
      }
      final result = PageTranslationResult.fromJson(decoded);
      if (kDebugMode) {
        debugPrint(
          '[StudySis][page-translation] requestId=$requestId '
          'durationMs=${stopwatch.elapsedMilliseconds} '
          'fields=${result.fields.length}',
        );
      }
      return result;
    } on TimeoutException {
      throw const PageTranslationException(
        'Muffin could not translate this page right now.',
      );
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint(
          '[StudySis][page-translation] requestId=$requestId failed: $error',
        );
        debugPrint('[StudySis][page-translation] stackTrace=$stackTrace');
      }
      throw const PageTranslationException(
        'Muffin could not translate this page right now.',
      );
    }
  }
}

String normalizePageTranslationText(String text) {
  return text
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('“', '"')
      .replaceAll('”', '"')
      .replaceAll('’', "'")
      .toLowerCase();
}

String _normalize(String text) => normalizePageTranslationText(text);

String? localizeStaticPageText(String text, String targetLanguage) {
  final normalized = _normalize(text);
  return targetLanguage == TranslationLanguage.english
      ? _msToEn[normalized]
      : _enToMs[normalized];
}

const _msToEn = {
  'apa itu pola': 'What is a Pattern?',
  'apa itu pola?': 'What is a Pattern?',
  'apakah pola': 'What is a Pattern?',
  'apakah itu pola?': 'What is a pattern?',
  'apakah pattern?': 'What is a pattern?',
  'pola ialah susunan nombor, bentuk, atau objek yang mengikut peraturan tertentu.':
      'A pattern is an arrangement of numbers, shapes, or objects that follows a specific rule.',
  'pola ialah susunan nombor, bentuk atau objek yang mengikut satu peraturan tertentu.':
      'A pattern is an arrangement of numbers, shapes, or objects that follows a specific rule.',
  'pola ialah susunan nombor atau objek yang mengikut peraturan tertentu.':
      'A pattern is an arrangement of numbers or objects that follows a rule.',
  '2, 4, 6, 8 ialah pola kerana setiap nombor bertambah 2.':
      '2, 4, 6, 8 is a pattern because each number increases by 2.',
  'apa itu jujukan': 'What is a sequence?',
  'apa itu jujukan?': 'What is a sequence?',
  'apakah itu jujukan?': 'What is a sequence?',
  'jujukan ialah senarai nombor yang disusun mengikut urutan tertentu.':
      'A sequence is a list of numbers arranged in a particular order.',
  '5, 10, 15, 20 ialah jujukan dengan beza tetap 5.':
      '5, 10, 15, 20 is a sequence with a constant difference of 5.',
  'apakah nombor seterusnya dalam jujukan berikut?':
      'What is the next number in the following sequence?',
  'apakah beza sepunya bagi jujukan berikut?':
      'What is the common difference of the following sequence?',
  'apakah beza tetap bagi jujukan berikut?':
      'What is the constant difference of the following sequence?',
  'beza sepunya': 'Common difference',
  'beza tetap': 'Constant difference',
  'nombor': 'Number',
  'huruf': 'Letter',
  'abjad': 'Alphabet',
  'simbol': 'Symbol',
  'fikirkan "susunan yang mempunyai peraturan."':
      'Think of an arrangement that follows a rule.',
  'hint: fikirkan "susunan yang mempunyai peraturan."':
      'Hint: Think of an arrangement that follows a rule.',
  'petunjuk: fikirkan "susunan yang mempunyai peraturan."':
      'Hint: Think of an arrangement that follows a rule.',
  'pola dan jujukan': 'Patterns and Sequences',
  'bab 1': 'Chapter 1',
  'matematik': 'Mathematics',
  'latihan': 'Practice',
  'kuiz': 'Quiz',
  'soalan': 'Question',
  'jawapan': 'Answer',
  'petunjuk': 'Hint',
  'tanya muffin': 'Ask Muffin',
  'hantar jawapan': 'Submit Answer',
  'simpan': 'Save',
  'faham': 'Got it',
};

const _enToMs = {
  'hi qidah': 'Hai Qidah',
  "let's take one gentle step today.":
      'Mari ambil satu langkah mudah hari ini.',
  'daily target': 'Sasaran harian',
  'language': 'Bahasa',
  'continue learning': 'Teruskan pembelajaran',
  'your next step': 'Langkah Seterusnya',
  'progress': 'Kemajuan',
  'see your saved learning progress.':
      'Lihat kemajuan pembelajaran yang disimpan.',
  'subjects': 'Subjek',
  'practice': 'Latihan',
  'quiz': 'Kuiz',
  'question': 'Soalan',
  'submit answer': 'Hantar Jawapan',
  'hint': 'Petunjuk',
  'ask muffin': 'Tanya Muffin',
  'show original': 'Papar teks asal',
  'change language': 'Tukar bahasa',
  'card': 'Kad',
  'answer': 'Jawapan',
  'mathematics': 'Matematik',
  'patterns and sequences': 'Pola dan Jujukan',
  'need a little help?': 'Perlukan sedikit bantuan?',
  'swipe left to reveal answer': 'Leret ke kiri untuk melihat jawapan',
  'swipe right to return': 'Leret ke kanan untuk kembali',
  'got it': 'Faham',
  'save': 'Simpan',
  'next': 'Seterusnya',
  'previous': 'Sebelumnya',
  'submit quiz': 'Hantar Kuiz',
  'next question': 'Soalan Seterusnya',
  'what is a pattern': 'Apakah itu pola',
  'what is a pattern?': 'Apakah itu pola?',
  'a pattern is an arrangement of numbers, shapes, or objects that follows a specific rule.':
      'Pola ialah susunan nombor, bentuk atau objek yang mengikut satu peraturan tertentu.',
  '2, 4, 6, 8 is a pattern because each number increases by 2.':
      '2, 4, 6, 8 ialah pola kerana setiap nombor bertambah 2.',
  'what is a sequence?': 'Apakah itu jujukan?',
  'a sequence is a list of numbers arranged in a particular order.':
      'Jujukan ialah senarai nombor yang disusun mengikut urutan tertentu.',
  '5, 10, 15, 20 is a sequence with a constant difference of 5.':
      '5, 10, 15, 20 ialah jujukan dengan beza tetap 5.',
  'what is the next number in the following sequence?':
      'Apakah nombor seterusnya dalam jujukan berikut?',
  'what is the common difference of the following sequence?':
      'Apakah beza sepunya bagi jujukan berikut?',
  'what is the constant difference of the following sequence?':
      'Apakah beza tetap bagi jujukan berikut?',
  'common difference': 'Beza sepunya',
  'constant difference': 'Beza tetap',
  'number': 'Nombor',
  'letter': 'Huruf',
  'alphabet': 'Abjad',
  'symbol': 'Simbol',
  'think of an arrangement that follows a rule.':
      'Fikirkan "susunan yang mempunyai peraturan."',
  'hint: think of an arrangement that follows a rule.':
      'Petunjuk: Fikirkan "susunan yang mempunyai peraturan."',
};
