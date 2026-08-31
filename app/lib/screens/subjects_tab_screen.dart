import 'package:flutter/material.dart';

import '../models/subject.dart';
import '../repositories/engagement_repository.dart';
import '../repositories/learning_repository.dart';
import '../repositories/student_progress_repository.dart';
import '../repositories/study_pet_repository.dart';
import '../services/firestore_service.dart';
import '../widgets/subject_card.dart';
import 'progress_screen.dart';
import 'subject_screen.dart';

class SubjectsTabScreen extends StatelessWidget {
  const SubjectsTabScreen({
    this.subjectsStream,
    this.learningRepository,
    this.progressRepository,
    this.engagementRepository,
    this.petRepository,
    super.key,
  });

  final Stream<List<Subject>>? subjectsStream;
  final LearningRepository? learningRepository;
  final StudentProgressRepository? progressRepository;
  final EngagementRepository? engagementRepository;
  final StudyPetRepository? petRepository;

  @override
  Widget build(BuildContext context) {
    final learningRepository = this.learningRepository ?? LearningRepository();
    final progressRepository =
        this.progressRepository ?? StudentProgressRepository();
    final engagementRepository =
        this.engagementRepository ?? EngagementRepository();
    final petRepository = this.petRepository ?? StudyPetRepository();
    return Scaffold(
      body: SafeArea(
        child: StreamBuilder<List<Subject>>(
          stream: subjectsStream ?? FirestoreService().watchSubjects(),
          builder: (context, snapshot) {
            final subjects = snapshot.data ?? const <Subject>[];
            return ListView(
              key: const PageStorageKey<String>('subjects-tab-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Text('Subjects',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Choose what you want to learn today.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProgressScreen(
                          learningRepository: learningRepository,
                          progressRepository: progressRepository,
                          engagementRepository: engagementRepository,
                          petRepository: petRepository,
                        ),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(Icons.insights_rounded),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'View Progress',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snapshot.hasError)
                  Text('Subjects could not load: ${snapshot.error}')
                else if (subjects.isEmpty)
                  const Text('Subjects are being prepared.')
                else ...[
                  Text(
                    '${subjects.where((subject) => !subject.isComingSoon).length} subject ready',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  for (final subject in subjects) ...[
                    SubjectCard(
                      subject: subject,
                      onTap: subject.isComingSoon
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SubjectScreen(
                                    subject: subject,
                                    repository: learningRepository,
                                    progressRepository: progressRepository,
                                    engagementRepository: engagementRepository,
                                    petRepository: petRepository,
                                  ),
                                ),
                              ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
