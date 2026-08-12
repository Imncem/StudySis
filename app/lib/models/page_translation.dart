enum PageTranslationStatus { idle, loading, translated, error }

class TranslationLanguage {
  const TranslationLanguage._();

  static const english = 'en';
  static const malay = 'ms';
  static const unknown = 'unknown';

  static String label(String code) {
    return switch (code) {
      english => 'English',
      malay => 'Bahasa Melayu',
      _ => 'Unknown',
    };
  }
}

class PageTranslationField {
  const PageTranslationField({
    required this.id,
    required this.type,
    required this.text,
  });

  final String id;
  final String type;
  final String text;

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type,
        'text': text,
      };
}

class TranslatablePageContent {
  const TranslatablePageContent({
    required this.pageType,
    required this.pageId,
    required this.sourceLanguage,
    required this.fields,
  });

  final String pageType;
  final String pageId;
  final String sourceLanguage;
  final List<PageTranslationField> fields;

  String get contentHash => fields
      .map((field) => '${field.id}:${field.type}:${field.text}')
      .join('|')
      .hashCode
      .toUnsigned(32)
      .toRadixString(16);

  Map<String, Object?> toJson({required String targetLanguage}) => {
        'pageType': pageType,
        'pageId': pageId,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'fields': fields.map((field) => field.toJson()).toList(),
      };
}

class PageTranslationRequest {
  const PageTranslationRequest({
    required this.content,
    required this.targetLanguage,
  });

  final TranslatablePageContent content;
  final String targetLanguage;

  Map<String, Object?> toJson() => content.toJson(
        targetLanguage: targetLanguage,
      );
}

class PageTranslationResult {
  const PageTranslationResult({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.fields,
    this.translatedFieldCount = 0,
    this.unchangedFieldCount = 0,
    this.failedFieldCount = 0,
    this.totalFieldCount,
    this.isComplete,
  });

  final String sourceLanguage;
  final String targetLanguage;
  final Map<String, String> fields;
  final int translatedFieldCount;
  final int unchangedFieldCount;
  final int failedFieldCount;
  final int? totalFieldCount;
  final bool? isComplete;

  factory PageTranslationResult.fromJson(Map<String, dynamic> data) {
    final fields = <String, String>{};
    final responseFields = data['fields'] as List<dynamic>? ??
        data['translations'] as List<dynamic>? ??
        const [];
    for (final field in responseFields) {
      if (field is! Map) continue;
      final id = field['id']?.toString();
      final translatedText = field['translatedText']?.toString();
      if (id == null || translatedText == null) continue;
      fields[id] = translatedText;
    }
    return PageTranslationResult(
      sourceLanguage:
          data['sourceLanguage']?.toString() ?? TranslationLanguage.unknown,
      targetLanguage:
          data['targetLanguage']?.toString() ?? TranslationLanguage.english,
      fields: fields,
      translatedFieldCount:
          (data['translatedFieldCount'] as num?)?.toInt() ?? fields.length,
      unchangedFieldCount: (data['unchangedFieldCount'] as num?)?.toInt() ?? 0,
      failedFieldCount: (data['failedFieldCount'] as num?)?.toInt() ?? 0,
      totalFieldCount: (data['totalFieldCount'] as num?)?.toInt(),
      isComplete: data['isComplete'] as bool?,
    );
  }

  Map<String, Object?> toJson() => {
        'success': true,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'translatedFieldCount': translatedFieldCount,
        'unchangedFieldCount': unchangedFieldCount,
        'failedFieldCount': failedFieldCount,
        if (totalFieldCount != null) 'totalFieldCount': totalFieldCount,
        if (isComplete != null) 'isComplete': isComplete,
        'fields': fields.entries
            .map((entry) => {
                  'id': entry.key,
                  'translatedText': entry.value,
                })
            .toList(),
      };
}

class PageTranslationState {
  const PageTranslationState({
    this.status = PageTranslationStatus.idle,
    this.pageId,
    this.sourceLanguage,
    this.targetLanguage,
    this.originalContent,
    this.translatedContent,
    this.errorMessage,
  });

  final PageTranslationStatus status;
  final String? pageId;
  final String? sourceLanguage;
  final String? targetLanguage;
  final TranslatablePageContent? originalContent;
  final PageTranslationResult? translatedContent;
  final String? errorMessage;

  bool get isTranslated => status == PageTranslationStatus.translated;
  bool get isLoading => status == PageTranslationStatus.loading;

  PageTranslationState copyWith({
    PageTranslationStatus? status,
    String? pageId,
    String? sourceLanguage,
    String? targetLanguage,
    TranslatablePageContent? originalContent,
    PageTranslationResult? translatedContent,
    String? errorMessage,
    bool clearTranslation = false,
    bool clearError = false,
  }) {
    return PageTranslationState(
      status: status ?? this.status,
      pageId: pageId ?? this.pageId,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      originalContent: originalContent ?? this.originalContent,
      translatedContent:
          clearTranslation ? null : translatedContent ?? this.translatedContent,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
