import 'package:flutter/material.dart';

import '../models/student.dart';
import '../services/firestore_service.dart';
import '../theme/theme_controller_scope.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    this.studentStream,
    super.key,
  });

  final Stream<Student>? studentStream;

  @override
  Widget build(BuildContext context) {
    final controller = ThemeControllerScope.maybeOf(context);
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<Student>(
          stream: studentStream ?? FirestoreService().watchQidah(),
          builder: (context, snapshot) {
            final student = snapshot.data ??
                const Student(
                  id: 'qidah',
                  name: 'Qidah',
                  preferredLanguage: 'Mixed',
                  dailyTargetMinutes: 30,
                  status: 'active',
                );
            return ListView(
              key: const PageStorageKey<String>('profile-tab-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Text('Profile',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            student.name.characters.first.toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student.name,
                                style: Theme.of(context).textTheme.titleLarge),
                            const Text('Student'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                _ProfileSection(
                  title: 'Preferences',
                  children: [
                    _ProfileRow(
                      icon: Icons.translate_rounded,
                      label: 'Language',
                      value: student.preferredLanguage,
                    ),
                    _ProfileRow(
                      icon: Icons.timer_outlined,
                      label: 'Daily target',
                      value: '${student.dailyTargetMinutes} min',
                    ),
                    _ProfileRow(
                      icon: controller?.isDark == true
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      label: 'Appearance',
                      value: controller?.isDark == true ? 'Dark' : 'Light',
                      onTap: controller?.toggle,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _ProfileSection(
                  title: 'Settings',
                  children: [
                    _ProfileRow(
                      icon: Icons.info_outline_rounded,
                      label: 'About StudySis',
                      value: 'Sprint 3',
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            if (onTap != null) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
