import 'package:flutter/material.dart';

import '../models/learning_content.dart';
import '../models/muffin.dart';
import '../models/note_section.dart';
import '../models/page_translation.dart';
import '../services/muffin_context_registry.dart';
import '../services/muffin_service.dart';
import '../widgets/muffin_assist_sheet.dart';
import '../widgets/page_translation_scope.dart';

enum ModuleReaderExitAction { goToFlashcards }

class ModuleReaderScreen extends StatelessWidget {
  const ModuleReaderScreen({
    required this.learningContent,
    this.muffinService,
    super.key,
  });

  final LearningContent learningContent;
  final MuffinService? muffinService;

  MuffinContext _contextForSection(NoteSection section) {
    return MuffinContext(
      studentProfileId: 'qidah',
      preferredLanguage: 'Mixed',
      subjectId: 'math',
      subjectTitle: learningContent.subjectName,
      chapterId: learningContent.chapter.id,
      chapterTitle: learningContent.chapter.title,
      mode: MuffinMode.learn,
      currentScreen: 'learn',
      lessonHeading: section.heading,
      lessonBody: [
        section.body,
        if (section.example.trim().isNotEmpty) 'Example: ${section.example}',
      ].join('\n\n'),
      originalScreenContent: [
        section.heading,
        section.body,
        if (section.example.trim().isNotEmpty) 'Example: ${section.example}',
      ].join('\n\n'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapter = learningContent.chapter;
    final module = learningContent.module;
    _registerTranslationContent(context);
    if (learningContent.noteSections.isNotEmpty) {
      MuffinContextRegistry.instance.set(
        MuffinScreenContext(
          mode: MuffinMode.learn,
          subtitle: 'I can help explain this lesson gently.',
          context:
              _contextForSection(learningContent.noteSections.first).copyWith(
            contextKey:
                'learn_math_${chapter.id}_section_${learningContent.noteSections.first.id}',
          ),
          actions: [
            const MuffinActionConfig(
              action: MuffinAction.explainSimply,
              label: 'Explain this simply',
            ),
            MuffinActionConfig(
              action: MuffinAction.translate,
              label: 'Translate this section',
              contextOverride: (context) =>
                  context.copyWith(targetLanguage: 'Bahasa Melayu'),
            ),
            MuffinActionConfig(
              action: MuffinAction.translate,
              label: 'Translate this section to English',
              contextOverride: (context) =>
                  context.copyWith(targetLanguage: 'English'),
            ),
            const MuffinActionConfig(
              action: MuffinAction.anotherExample,
              label: 'Show another example',
            ),
            const MuffinActionConfig(
              action: MuffinAction.stillConfused,
              label: "I'm still confused",
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        title: const Text('Learning module'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            const PageTranslationBanner(),
            Text(
              PageTranslationScope.text(
                context,
                'subjectName',
                learningContent.subjectName.toUpperCase(),
              ),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              PageTranslationScope.text(
                context,
                'chapterTitle',
                'Chapter ${chapter.chapterNumber}: ${chapter.title}',
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            Text(
                PageTranslationScope.text(context, 'moduleTitle', module.title),
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ReaderChip(
                  label: PageTranslationScope.text(
                    context,
                    'moduleType',
                    module.typeLabel,
                  ),
                ),
                _ReaderChip(label: '${module.estimatedMinutes} min'),
                _ReaderChip(label: _titleCase(module.difficulty)),
              ],
            ),
            const SizedBox(height: 24),
            if (learningContent.noteSections.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    'This lesson is being prepared.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              for (final section in learningContent.noteSections) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PageTranslationScope.text(
                            context,
                            'section_${section.id}_heading',
                            section.heading,
                          ),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          PageTranslationScope.text(
                            context,
                            'section_${section.id}_body',
                            section.body,
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(height: 1.7),
                        ),
                        if (section.example.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF4F0),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  PageTranslationScope.text(
                                    context,
                                    'section_${section.id}_example_label',
                                    'Example',
                                  ),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                SelectableText(
                                  PageTranslationScope.text(
                                    context,
                                    'section_${section.id}_example_text',
                                    section.example,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context)
                    .pop(ModuleReaderExitAction.goToFlashcards);
              },
              icon: const Icon(Icons.style_rounded),
              label: const Text('Go to Flashcards'),
            ),
          ],
        ),
      ),
    );
  }

  void _registerTranslationContent(BuildContext context) {
    final controller = PageTranslationScope.maybeOf(context);
    if (controller == null) return;
    final route = ModalRoute.of(context);
    if (route?.isCurrent != true) return;
    final fields = <PageTranslationField>[
      PageTranslationField(
        id: 'subjectName',
        type: 'label',
        text: learningContent.subjectName.toUpperCase(),
      ),
      PageTranslationField(
        id: 'chapterTitle',
        type: 'heading',
        text:
            'Chapter ${learningContent.chapter.chapterNumber}: ${learningContent.chapter.title}',
      ),
      PageTranslationField(
        id: 'moduleTitle',
        type: 'heading',
        text: learningContent.module.title,
      ),
      PageTranslationField(
        id: 'moduleType',
        type: 'label',
        text: learningContent.module.typeLabel,
      ),
      for (final section in learningContent.noteSections) ...[
        PageTranslationField(
          id: 'section_${section.id}_heading',
          type: 'heading',
          text: section.heading,
        ),
        PageTranslationField(
          id: 'section_${section.id}_body',
          type: 'paragraph',
          text: section.body,
        ),
        if (section.example.isNotEmpty) ...[
          PageTranslationField(
            id: 'section_${section.id}_example_label',
            type: 'label',
            text: 'Example',
          ),
          PageTranslationField(
            id: 'section_${section.id}_example_text',
            type: 'example',
            text: section.example,
          ),
        ],
      ],
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ModalRoute.of(context)?.isCurrent != true) return;
      controller.registerPage(
        ownerToken: this,
        routeName: ModalRoute.of(context)?.settings.name,
        content: TranslatablePageContent(
          pageType: 'learn',
          pageId:
              '${learningContent.subjectName}_${learningContent.chapter.id}_${learningContent.module.id}_learn',
          sourceLanguage: _detectLanguage(fields),
          fields: fields,
        ),
      );
    });
  }
}

String _detectLanguage(List<PageTranslationField> fields) {
  final text = fields.map((field) => field.text.toLowerCase()).join(' ');
  final malaySignals =
      RegExp(r'\b(ialah|dan|yang|dengan|contoh|nombor|pola|bab)\b')
          .allMatches(text)
          .length;
  final englishSignals =
      RegExp(r'\b(the|and|with|example|number|pattern|chapter)\b')
          .allMatches(text)
          .length;
  if (malaySignals > englishSignals) return TranslationLanguage.malay;
  if (englishSignals > malaySignals) return TranslationLanguage.english;
  return TranslationLanguage.unknown;
}

class _ReaderChip extends StatelessWidget {
  const _ReaderChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

String _titleCase(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
