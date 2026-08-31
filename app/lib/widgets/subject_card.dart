import 'package:flutter/material.dart';

import '../models/subject.dart';
import '../theme/app_theme.dart';

class SubjectCard extends StatelessWidget {
  const SubjectCard({required this.subject, this.onTap, super.key});

  final Subject subject;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subjectTheme = StudySisSubjectTheme.forSubject(
      id: subject.id,
      displayName: subject.displayName,
      iconName: subject.iconName,
      fallbackHex: subject.themeColor,
    );
    final color = subjectTheme.accent(context);
    final soft = subjectTheme.softSurface(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(24),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: soft,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(_iconFor(subject.iconName), color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.displayName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subject.shortName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: subject.isComingSoon
                          ? scheme.surfaceContainerHighest
                          : soft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      subject.isComingSoon
                          ? 'Coming soon'
                          : _statusLabel(subject.contentStatus),
                      style: TextStyle(
                        color: subject.isComingSoon
                            ? Theme.of(context).textTheme.bodySmall?.color
                            : color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    subject.isComingSoon
                        ? Icons.lock_outline_rounded
                        : Icons.chevron_right_rounded,
                    color: subject.isComingSoon
                        ? Theme.of(context).textTheme.bodySmall?.color
                        : color,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _statusLabel(String value) {
    if (value == 'available' || value == 'ready') return 'Ready';
    return value.replaceAll('_', ' ');
  }

  static IconData _iconFor(String name) {
    const icons = <String, IconData>{
      'book': Icons.menu_book_rounded,
      'math': Icons.calculate_rounded,
      'science': Icons.science_rounded,
      'language': Icons.translate_rounded,
      'history': Icons.history_edu_rounded,
      'geography': Icons.public_rounded,
      'computer': Icons.computer_rounded,
      'art': Icons.palette_rounded,
      'music': Icons.music_note_rounded,
      'sports': Icons.sports_rounded,
      'islamic': Icons.mosque_rounded,
    };
    return icons[name.toLowerCase()] ?? Icons.auto_stories_rounded;
  }
}
