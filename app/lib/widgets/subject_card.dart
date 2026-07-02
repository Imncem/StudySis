import 'package:flutter/material.dart';

import '../models/subject.dart';

class SubjectCard extends StatelessWidget {
  const SubjectCard({required this.subject, super.key});

  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(subject.themeColor);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_iconFor(subject.iconName), color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(subject.displayName,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(subject.shortName,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: subject.isComingSoon
                    ? const Color(0xFFF1EFEA)
                    : color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                subject.isComingSoon
                    ? 'Coming soon'
                    : _statusLabel(subject.contentStatus),
                style: TextStyle(
                  color: subject.isComingSoon ? const Color(0xFF756F66) : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _parseColor(String value) {
    final hex = value.replaceAll('#', '');
    final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return parsed == null ? const Color(0xFF7B8F72) : Color(parsed);
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
