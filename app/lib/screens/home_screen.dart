import 'package:flutter/material.dart';

import '../models/student.dart';
import '../models/subject.dart';
import '../services/firestore_service.dart';
import '../widgets/info_chip.dart';
import '../widgets/subject_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<Student>(
          stream: _service.watchQidah(),
          builder: (context, studentSnapshot) {
            if (studentSnapshot.hasError) {
              return _ErrorState(message: studentSnapshot.error.toString());
            }
            if (!studentSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final student = studentSnapshot.data!;
            return RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                children: [
                  Text('Hi Qidah',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text('Let’s take one gentle step today.',
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      InfoChip(
                        icon: Icons.timer_outlined,
                        label: 'Daily target',
                        value: '${student.dailyTargetMinutes} min',
                      ),
                      const SizedBox(width: 12),
                      InfoChip(
                        icon: Icons.translate_rounded,
                        label: 'Language',
                        value: student.preferredLanguage,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Card(
                    color: const Color(0xFFE5EEE8),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Continue learning',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          const Text(
                            'Your next lesson will appear here when learning modules are ready.',
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Learning modules are coming soon.'),
                                ),
                              );
                            },
                            child: const Text('Continue'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE6D5),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.pets_rounded,
                                color: Color(0xFFA45E37)),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Muffin',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                                SizedBox(height: 3),
                                Text('Your study companion is getting ready.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('Subjects',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  StreamBuilder<List<Subject>>(
                    stream: _service.watchSubjects(),
                    builder: (context, subjectSnapshot) {
                      if (subjectSnapshot.hasError) {
                        return _InlineError(
                            message: subjectSnapshot.error.toString());
                      }
                      if (!subjectSnapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final subjects = subjectSnapshot.data!;
                      if (subjects.isEmpty) {
                        return const _InlineError(
                          message: 'No subjects have been added yet.',
                        );
                      }
                      return Column(
                        children: [
                          for (final subject in subjects) ...[
                            SubjectCard(subject: subject),
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48),
            const SizedBox(height: 16),
            Text('We could not load StudySis',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(message),
      ),
    );
  }
}
