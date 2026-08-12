import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../models/page_translation.dart';
import '../services/page_translation_service.dart';

class PageTranslationController extends ChangeNotifier {
  PageTranslationController({
    PageTranslationService? service,
    int maxCacheEntries = 20,
  })  : _service = service ?? PageTranslationServiceFactory.create(),
        _maxCacheEntries = maxCacheEntries;

  final PageTranslationService _service;
  final int _maxCacheEntries;
  final Map<String, PageTranslationResult> _cache = {};
  PageTranslationState _state = const PageTranslationState();
  Object? _ownerToken;

  PageTranslationState get state => _state;
  Object? get ownerToken => _ownerToken;

  void setContent(TranslatablePageContent content) {
    registerPage(ownerToken: null, content: content);
  }

  void registerPage({
    required Object? ownerToken,
    required TranslatablePageContent content,
    String? routeName,
  }) {
    if (_state.originalContent?.pageId == content.pageId &&
        _state.originalContent?.contentHash == content.contentHash &&
        _ownerToken == ownerToken) {
      return;
    }
    _ownerToken = ownerToken;
    if (kDebugMode) {
      debugPrint(
        'Page translation registered: pageId=${content.pageId} '
        'pageType=${content.pageType} fields=${content.fields.length} '
        'sourceLanguage=${content.sourceLanguage} route=${routeName ?? 'unknown'}',
      );
    }
    _state = PageTranslationState(
      pageId: content.pageId,
      sourceLanguage: content.sourceLanguage,
      originalContent: content,
    );
    notifyListeners();
  }

  void clearContent() {
    unregisterPage(ownerToken: _ownerToken);
  }

  void resetForPageChange() {
    if (kDebugMode) {
      debugPrint(
          'Page translation reset for content change: pageId=${_state.pageId}');
    }
    _ownerToken = null;
    _state = const PageTranslationState();
    notifyListeners();
  }

  void unregisterPage({required Object? ownerToken}) {
    if (_ownerToken != ownerToken) {
      if (kDebugMode) {
        debugPrint('Page translation unregister ignored for stale owner.');
      }
      return;
    }
    if (kDebugMode) {
      debugPrint('Page translation unregistered: pageId=${_state.pageId}');
    }
    _ownerToken = null;
    _state = const PageTranslationState();
    notifyListeners();
  }

  Future<void> translateCurrentPage({String? targetLanguage}) async {
    final content = _state.originalContent;
    if (content == null) {
      if (kDebugMode) {
        debugPrint('Page translation request failed: no active content.');
      }
      _state = const PageTranslationState(
        status: PageTranslationStatus.error,
        errorMessage:
            'Muffin could not find translatable content on this page.',
      );
      notifyListeners();
      return;
    }
    final target = targetLanguage ?? _defaultTargetLanguage(content);
    final requestPageId = content.pageId;
    final requestHash = content.contentHash;
    if (kDebugMode) {
      debugPrint(
        'Translation request start: pageId=${content.pageId} '
        'pageType=${content.pageType} fields=${content.fields.length} '
        'sourceLanguage=${content.sourceLanguage} targetLanguage=$target',
      );
      if (content.pageType == 'quiz') {
        debugPrint(
          'Quiz translation fields: ${content.fields.map((field) => field.id).join(',')}',
        );
        for (final field in content.fields) {
          debugPrint(
            'Quiz translation original: ${field.id}="${field.text}" '
            'normalized="${normalizePageTranslationText(field.text)}"',
          );
        }
      }
    }
    final key = _cacheKey(content, target);
    final cached = _cache[key];
    if (cached != null) {
      _state = _state.copyWith(
        status: PageTranslationStatus.translated,
        targetLanguage: target,
        translatedContent: cached,
        clearError: true,
      );
      notifyListeners();
      return;
    }
    _state = _state.copyWith(
      status: PageTranslationStatus.loading,
      targetLanguage: target,
      clearError: true,
    );
    notifyListeners();
    try {
      final localFields = <String, String>{};
      final remoteFields = <PageTranslationField>[];
      for (final field in content.fields) {
        final local = localizeStaticPageText(field.text, target);
        if (local != null) {
          localFields[field.id] = local;
        } else {
          remoteFields.add(field);
        }
      }
      final serviceResult = remoteFields.isEmpty
          ? PageTranslationResult(
              sourceLanguage: content.sourceLanguage,
              targetLanguage: target,
              fields: const {},
              totalFieldCount: 0,
            )
          : await _service.translate(
              PageTranslationRequest(
                content: TranslatablePageContent(
                  pageType: content.pageType,
                  pageId: content.pageId,
                  sourceLanguage: content.sourceLanguage,
                  fields: remoteFields,
                ),
                targetLanguage: target,
              ),
            );
      if (!_isCurrentTranslationRequest(requestPageId, requestHash)) {
        if (kDebugMode) {
          debugPrint(
            'Discarded stale page translation: requestPageId=$requestPageId currentPageId=${_state.pageId}',
          );
        }
        return;
      }
      final result = _sanitizeResult(
        content: content,
        targetLanguage: target,
        localFields: localFields,
        serviceFields: serviceResult.fields,
      );
      if (kDebugMode) {
        debugPrint(
          'Translation completed: returnedFields=${result.fields.length} '
          'ids=${result.fields.keys.join(',')} '
          'translated=${result.translatedFieldCount} '
          'unchanged=${result.unchangedFieldCount} '
          'failed=${result.failedFieldCount}',
        );
      }
      if (result.translatedFieldCount == 0) {
        _state = _state.copyWith(
          status: PageTranslationStatus.error,
          errorMessage:
              'Muffin could not translate this page right now.\nThe original content is still shown.',
          clearTranslation: true,
        );
        notifyListeners();
        return;
      }
      _cache[key] = result;
      _trimCache();
      _state = _state.copyWith(
        status: PageTranslationStatus.translated,
        targetLanguage: target,
        translatedContent: result,
        clearError: true,
      );
    } catch (_) {
      if (!_isCurrentTranslationRequest(requestPageId, requestHash)) {
        if (kDebugMode) {
          debugPrint(
            'Discarded stale page translation error: requestPageId=$requestPageId currentPageId=${_state.pageId}',
          );
        }
        return;
      }
      _state = _state.copyWith(
        status: PageTranslationStatus.error,
        errorMessage:
            'Muffin could not translate this page right now.\nYour original lesson is still available.',
        clearTranslation: true,
      );
    }
    notifyListeners();
  }

  bool _isCurrentTranslationRequest(String pageId, String contentHash) {
    final current = _state.originalContent;
    return current?.pageId == pageId && current?.contentHash == contentHash;
  }

  void showOriginal() {
    _state = _state.copyWith(
      status: PageTranslationStatus.idle,
      clearTranslation: true,
      clearError: true,
    );
    notifyListeners();
  }

  Future<void> changeLanguage(String targetLanguage) {
    return translateCurrentPage(targetLanguage: targetLanguage);
  }

  String text(String id, String original) {
    if (!_state.isTranslated) return original;
    final translated = _state.translatedContent?.fields[id];
    if (kDebugMode) {
      debugPrint(
        translated == null
            ? 'Missing translated field: $id'
            : 'Rendered translated field: $id',
      );
    }
    return translated ?? original;
  }

  PageTranslationResult _sanitizeResult({
    required TranslatablePageContent content,
    required String targetLanguage,
    required Map<String, String> localFields,
    required Map<String, String> serviceFields,
  }) {
    final fields = <String, String>{};
    var translated = 0;
    var unchanged = 0;
    var failed = 0;

    for (final field in content.fields) {
      final candidate = localFields[field.id] ?? serviceFields[field.id];
      if (candidate == null) {
        if (_canPreserveUnchanged(field.text, targetLanguage)) {
          fields[field.id] = field.text;
          unchanged += 1;
        } else {
          if (kDebugMode) {
            debugPrint(
              'Translation sanitizer rejected ${field.id}: missing candidate',
            );
          }
          failed += 1;
        }
        continue;
      }
      if (_hasFakePrefix(candidate)) {
        if (kDebugMode) {
          debugPrint(
            'Translation sanitizer rejected ${field.id}: fake prefix',
          );
        }
        failed += 1;
        continue;
      }
      final original = field.text;
      final trimmedCandidate = candidate.trim();
      final trimmedOriginal = original.trim();
      if (trimmedCandidate == trimmedOriginal) {
        if (_canPreserveUnchanged(original, targetLanguage)) {
          fields[field.id] = original;
          unchanged += 1;
        } else {
          if (kDebugMode) {
            debugPrint(
              'Translation sanitizer rejected ${field.id}: unchanged text is not preservable',
            );
          }
          failed += 1;
        }
        continue;
      }
      fields[field.id] = trimmedCandidate;
      translated += 1;
    }

    return PageTranslationResult(
      sourceLanguage: content.sourceLanguage,
      targetLanguage: targetLanguage,
      fields: fields,
      translatedFieldCount: translated,
      unchangedFieldCount: unchanged,
      failedFieldCount: failed,
      totalFieldCount: content.fields.length,
      isComplete: failed == 0,
    );
  }

  bool _hasFakePrefix(String value) {
    return RegExp(r'^\s*(english|malay|bahasa melayu)\s*:',
            caseSensitive: false)
        .hasMatch(value);
  }

  bool _canPreserveUnchanged(String value, String targetLanguage) {
    final text = value.trim();
    if (RegExp(r'^[A-D]$|^\d+(\s*/\s*\d+)?$|^\d+%$|^[\d\s,+\-*/=.xX()%]+$')
        .hasMatch(text)) {
      return true;
    }
    if (RegExp(r'\bQidah\b').hasMatch(text)) return true;
    if (targetLanguage == TranslationLanguage.english &&
        RegExp(r'^(chapter|question|quiz|practice|flashcards?|learn)(\b|\s+\d)',
                caseSensitive: false)
            .hasMatch(text)) {
      return true;
    }
    if (targetLanguage == TranslationLanguage.malay &&
        RegExp(r'^(bab|soalan|kuiz|latihan|kad|belajar)(\b|\s+\d)',
                caseSensitive: false)
            .hasMatch(text)) {
      return true;
    }
    return false;
  }

  String _defaultTargetLanguage(TranslatablePageContent content) {
    if (content.sourceLanguage == TranslationLanguage.malay) {
      return TranslationLanguage.english;
    }
    return TranslationLanguage.malay;
  }

  String _cacheKey(TranslatablePageContent content, String targetLanguage) {
    return [
      content.pageId,
      content.contentHash,
      content.sourceLanguage,
      targetLanguage,
    ].join('|');
  }

  void _trimCache() {
    while (_cache.length > _maxCacheEntries) {
      _cache.remove(_cache.keys.first);
    }
  }
}

class PageTranslationScope
    extends InheritedNotifier<PageTranslationController> {
  const PageTranslationScope({
    required PageTranslationController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static PageTranslationController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PageTranslationScope>()
        ?.notifier;
  }

  static PageTranslationController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'PageTranslationScope is missing.');
    return controller!;
  }

  static String text(BuildContext context, String id, String original) {
    return maybeOf(context)?.text(id, original) ?? original;
  }
}

class PageTranslationBanner extends StatelessWidget {
  const PageTranslationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PageTranslationScope.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final state = controller.state;
    if (state.status == PageTranslationStatus.idle) {
      return const SizedBox.shrink();
    }
    final target = state.targetLanguage ?? TranslationLanguage.english;
    final isMalay = target == TranslationLanguage.malay;
    final message = state.isLoading
        ? (isMalay
            ? 'Muffin sedang menterjemah...'
            : 'Muffin is translating...')
        : state.status == PageTranslationStatus.error
            ? (state.errorMessage ??
                'Muffin could not translate this page right now.')
            : isMalay
                ? 'Diterjemahkan ke Bahasa Melayu oleh Muffin'
                : 'Translated to English by Muffin';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: state.status == PageTranslationStatus.error
            ? const Color(0xFFFFEDE7)
            : const Color(0xFFE5EEE8),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(Icons.translate_rounded, size: 18),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      message,
                      softWrap: true,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (state.isTranslated) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 0,
                  children: [
                    TextButton(
                      onPressed: controller.showOriginal,
                      child:
                          Text(isMalay ? 'Papar teks asal' : 'Show original'),
                    ),
                    TextButton(
                      onPressed: () => controller.changeLanguage(
                        isMalay
                            ? TranslationLanguage.english
                            : TranslationLanguage.malay,
                      ),
                      child: Text(isMalay ? 'Tukar bahasa' : 'Change language'),
                    ),
                  ],
                ),
              ] else if (state.status == PageTranslationStatus.error) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => controller.translateCurrentPage(),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
