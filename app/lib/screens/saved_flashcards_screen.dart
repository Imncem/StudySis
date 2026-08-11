import 'package:flutter/material.dart';

import '../models/chapter.dart';
import '../models/flashcard.dart';
import '../models/saved_flashcard.dart';
import '../repositories/learning_repository.dart';
import '../services/saved_flashcard_service.dart';

class SavedFlashcardsScreen extends StatefulWidget {
  const SavedFlashcardsScreen({
    this.learningRepository,
    this.savedFlashcardService,
    super.key,
  });

  final LearningRepository? learningRepository;
  final SavedFlashcardService? savedFlashcardService;

  @override
  State<SavedFlashcardsScreen> createState() => _SavedFlashcardsScreenState();
}

class _SavedFlashcardsScreenState extends State<SavedFlashcardsScreen> {
  late final LearningRepository _learningRepository;
  late final SavedFlashcardService _savedFlashcardService;
  final Set<String> _revealed = {};

  @override
  void initState() {
    super.initState();
    _learningRepository = widget.learningRepository ?? LearningRepository();
    _savedFlashcardService =
        widget.savedFlashcardService ?? SavedFlashcardServiceFactory.create();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Flashcards'),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: StreamBuilder<List<SavedFlashcardRef>>(
          stream: _savedFlashcardService.watchSavedFlashcards(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _SavedFlashcardsState(
                icon: Icons.cloud_off_rounded,
                title: 'Saved flashcards could not load.',
                message: 'Your learning progress is safe. Try again soon.',
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final refs = snapshot.data ?? const <SavedFlashcardRef>[];
            if (refs.isEmpty) {
              return const _SavedFlashcardsState(
                icon: Icons.bookmark_border_rounded,
                title: 'No saved flashcards yet',
                message:
                    "Save useful cards while studying and they'll appear here.",
              );
            }
            return FutureBuilder<List<SavedFlashcardItem>>(
              future: _resolve(refs),
              builder: (context, itemSnapshot) {
                if (!itemSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = itemSnapshot.data ?? const <SavedFlashcardItem>[];
                if (items.isEmpty) {
                  return const _SavedFlashcardsState(
                    icon: Icons.bookmark_border_rounded,
                    title: 'No saved flashcards yet',
                    message:
                        "Save useful cards while studying and they'll appear here.",
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    for (final group in _groups(items)) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 10, bottom: 8),
                        child: Text(
                          '${group.subjectName} - ${group.chapter.title}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      for (final item in group.items) ...[
                        _SavedFlashcardCard(
                          item: item,
                          isRevealed: _revealed.contains(item.documentId),
                          onToggleReveal: () {
                            setState(() {
                              if (!_revealed.add(item.documentId)) {
                                _revealed.remove(item.documentId);
                              }
                            });
                          },
                          onUnsave: () => _unsave(item),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<List<SavedFlashcardItem>> _resolve(
      List<SavedFlashcardRef> refs) async {
    final items = <SavedFlashcardItem>[];
    for (final ref in refs) {
      final subjectName =
          await _learningRepository.getSubjectName(ref.subjectId);
      final chapter = await _learningRepository.getChapter(
        subjectId: ref.subjectId,
        chapterId: ref.chapterId,
      );
      final card = await _learningRepository.getFlashcard(
        subjectId: ref.subjectId,
        chapterId: ref.chapterId,
        cardId: ref.cardId,
      );
      if (chapter == null || card == null) continue;
      items.add(SavedFlashcardItem(
        ref: ref,
        subjectName: subjectName,
        chapter: chapter,
        card: card,
      ));
    }
    return items;
  }

  List<_SavedFlashcardGroup> _groups(List<SavedFlashcardItem> items) {
    final groups = <String, _SavedFlashcardGroup>{};
    for (final item in items) {
      final key = '${item.ref.subjectId}_${item.ref.chapterId}';
      groups.putIfAbsent(
        key,
        () => _SavedFlashcardGroup(
          subjectName: item.subjectName,
          chapter: item.chapter,
          items: [],
        ),
      );
      groups[key]!.items.add(item);
    }
    return groups.values.toList(growable: false);
  }

  Future<void> _unsave(SavedFlashcardItem item) async {
    await _savedFlashcardService.unsaveFlashcard(
      subjectId: item.ref.subjectId,
      chapterId: item.ref.chapterId,
      cardId: item.ref.cardId,
    );
    setState(() => _revealed.remove(item.documentId));
  }
}

class SavedFlashcardItem {
  const SavedFlashcardItem({
    required this.ref,
    required this.subjectName,
    required this.chapter,
    required this.card,
  });

  final SavedFlashcardRef ref;
  final String subjectName;
  final Chapter chapter;
  final Flashcard card;

  String get documentId => ref.documentId;
}

class _SavedFlashcardGroup {
  _SavedFlashcardGroup({
    required this.subjectName,
    required this.chapter,
    required this.items,
  });

  final String subjectName;
  final Chapter chapter;
  final List<SavedFlashcardItem> items;
}

class _SavedFlashcardCard extends StatelessWidget {
  const _SavedFlashcardCard({
    required this.item,
    required this.isRevealed,
    required this.onToggleReveal,
    required this.onUnsave,
  });

  final SavedFlashcardItem item;
  final bool isRevealed;
  final VoidCallback onToggleReveal;
  final VoidCallback onUnsave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onToggleReveal,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bookmark_rounded, color: Color(0xFFA45E37)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.card.front,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove saved flashcard',
                    onPressed: onUnsave,
                    icon: const Icon(Icons.bookmark_remove_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('${item.subjectName} - ${item.chapter.title}'),
              const SizedBox(height: 10),
              AnimatedCrossFade(
                firstChild: const Text('Tap to reveal answer'),
                secondChild: Text(item.card.back),
                crossFadeState: isRevealed
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 150),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedFlashcardsState extends StatelessWidget {
  const _SavedFlashcardsState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
