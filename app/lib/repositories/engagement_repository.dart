import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/engagement.dart';
import '../models/learning_location.dart';
import '../models/pet_cosmetic.dart';
import '../models/quiz_question.dart';
import '../services/trusted_progress_service.dart';

class EngagementRepository {
  EngagementRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    String Function()? uidProvider,
    DateTime Function()? nowProvider,
    TrustedProgressService? trustedProgressService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth,
        _uidProvider = uidProvider,
        _nowProvider = nowProvider ?? DateTime.now,
        _trustedProgressService =
            trustedProgressService ?? RemoteTrustedProgressService(auth: auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth? _auth;
  final String Function()? _uidProvider;
  final DateTime Function() _nowProvider;
  final TrustedProgressService _trustedProgressService;

  Stream<EngagementState> watchState() {
    final uid = _maybeUid;
    final today = malaysiaDateKey(_nowProvider());
    if (uid == null) return Stream.value(EngagementState.initial(today));
    return _stateRef(uid).snapshots().map(
          (snapshot) => EngagementState.fromMap(
            snapshot.data(),
            todayDateKey: malaysiaDateKey(_nowProvider()),
          ),
        );
  }

  Future<EngagementState> readState() async {
    final uid = _maybeUid;
    final today = malaysiaDateKey(_nowProvider());
    if (uid == null) return EngagementState.initial(today);
    return EngagementState.fromMap(
      (await _stateRef(uid).get()).data(),
      todayDateKey: today,
    );
  }

  Future<EngagementCreditResult> creditLearnCompletion({
    required String subjectId,
    required String chapterId,
    String moduleId = 'notes',
  }) {
    return credit(
      EngagementCredit(
        activityKey: 'learn_${subjectId}_${chapterId}_$moduleId',
        studyPoints: 2,
        xp: 20,
        lifetimeCredit: true,
      ),
    );
  }

  Future<EngagementCreditResult> creditFlashcardReview({
    required String subjectId,
    required String chapterId,
    required Set<String> reviewedCardIds,
  }) {
    if (reviewedCardIds.length < 5) return _noCredit();
    final today = malaysiaDateKey(_nowProvider());
    return credit(
      EngagementCredit(
        activityKey: 'flashcards_${subjectId}_${chapterId}_$today',
        studyPoints: 1,
        xp: 10,
      ),
    );
  }

  Future<EngagementCreditResult> creditPracticeQuestions({
    required String subjectId,
    required String chapterId,
    required int completedQuestionCount,
    String? sessionId,
  }) {
    if (completedQuestionCount < 5) return _noCredit();
    final today = malaysiaDateKey(_nowProvider());
    return credit(
      EngagementCredit(
        activityKey: 'practice_${subjectId}_${chapterId}_${sessionId ?? today}',
        studyPoints: 2,
        xp: 20,
      ),
    );
  }

  Future<EngagementCreditResult> creditQuizCompletion({
    required String subjectId,
    required String chapterId,
    String quizId = 'quiz',
  }) {
    final today = malaysiaDateKey(_nowProvider());
    return credit(
      EngagementCredit(
        activityKey: 'quiz_${subjectId}_${chapterId}_${quizId}_$today',
        studyPoints: 3,
        xp: 40,
      ),
    );
  }

  Future<EngagementCreditResult> creditSavedFlashcardReview({
    required Set<String> reviewedSavedCardIds,
  }) async {
    if (reviewedSavedCardIds.length < 3) return _noCredit();
    return _trustedResult(
      await _trustedProgressService.record(
        'recordSavedFlashcardMilestone',
        {'savedCardIds': reviewedSavedCardIds.toList()..sort()},
      ),
    );
  }

  Future<EngagementCreditResult> creditLocationLearnCompletion({
    required LearningLocation location,
    String moduleId = 'notes',
  }) async {
    return _trustedResult(
      await _trustedProgressService.record(
        'recordModuleCompletion',
        _locationPayload(location, moduleId),
      ),
    );
  }

  Future<EngagementCreditResult> creditLocationFlashcardReview({
    required LearningLocation location,
    required String moduleId,
    required Set<String> reviewedCardIds,
  }) async {
    return _trustedResult(
      await _trustedProgressService.record(
        'recordFlashcardMilestone',
        {
          ..._locationPayload(location, moduleId),
          'reviewedCardIds': reviewedCardIds.toList()..sort(),
        },
      ),
    );
  }

  Future<EngagementCreditResult> creditLocationPracticeQuestions({
    required LearningLocation location,
    required String moduleId,
    required Map<String, int> answers,
  }) async {
    return _trustedResult(
      await _trustedProgressService.record(
        'submitPracticeAttempt',
        {
          ..._locationPayload(location, moduleId),
          'answers': answers,
        },
      ),
    );
  }

  Future<EngagementCreditResult> creditLocationQuizCompletion({
    required LearningLocation location,
    required String moduleId,
    required Map<String, int> answers,
  }) async {
    return _trustedResult(
      await _trustedProgressService.record(
        'submitQuizAttempt',
        {
          ..._locationPayload(location, moduleId),
          'answers': answers,
        },
      ),
    );
  }

  Future<EngagementCreditResult> creditLocationTestCompletion({
    required LearningLocation location,
    required String moduleId,
    required Map<String, int> answers,
  }) async {
    return _trustedResult(
      await _trustedProgressService.record(
        'submitTestAttempt',
        {
          ..._locationPayload(location, moduleId),
          'answers': answers,
        },
      ),
    );
  }

  Future<List<QuizQuestion>> loadLocationTestQuestions({
    required LearningLocation location,
    required String moduleId,
  }) async {
    final response = await _trustedProgressService.record(
      'getTestQuestions',
      _locationPayload(location, moduleId),
    );
    final rawQuestions = response['questions'];
    if (rawQuestions is! List) return const <QuizQuestion>[];
    return rawQuestions
        .whereType<Map>()
        .map((raw) {
          final data = Map<String, dynamic>.from(raw);
          return QuizQuestion.fromMap((data['id'] ?? '').toString(), data);
        })
        .where((question) => question.isActive && question.hasUsablePrompt)
        .toList(growable: false);
  }

  Future<EngagementCreditResult> creditLocationReviewCompletion({
    required LearningLocation location,
    required String moduleId,
  }) async {
    return _trustedResult(
      await _trustedProgressService.record(
        'recordReviewCompletion',
        _locationPayload(location, moduleId),
      ),
    );
  }

  Map<String, Object?> _locationPayload(
    LearningLocation location,
    String moduleId,
  ) =>
      {
        'subjectId': location.subjectId,
        'parentKind': location.parentKind,
        'parentId': location.parentId,
        if (location.containerId != null) 'containerId': location.containerId,
        'moduleId': moduleId,
      };

  EngagementCreditResult _trustedResult(Map<String, dynamic> response) {
    final today = malaysiaDateKey(_nowProvider());
    final stateData = response['state'];
    final state = EngagementState.fromMap(
      stateData is Map ? Map<String, dynamic>.from(stateData) : null,
      todayDateKey: today,
    );
    return EngagementCreditResult(
      credited: response['credited'] == true,
      studyPointsAwarded:
          (response['studyPointsAwarded'] as num?)?.toInt() ?? 0,
      xpAwarded: (response['xpAwarded'] as num?)?.toInt() ?? 0,
      pawCoinsAwarded: (response['pawCoinsAwarded'] as num?)?.toInt() ?? 0,
      previousTotalXp:
          (response['previousTotalXp'] as num?)?.toInt() ?? state.totalXp,
      previousLevel:
          (response['previousLevel'] as num?)?.toInt() ?? state.level,
      state: state,
      streakNewlySecured: response['streakNewlySecured'] == true,
      score: response['score'] is Map
          ? Map<String, dynamic>.from(response['score'] as Map)
          : null,
    );
  }

  Future<EngagementCreditResult> credit(EngagementCredit credit) async {
    final uid = _uid;
    final today = malaysiaDateKey(_nowProvider());
    final yesterday = previousMalaysiaDateKey(today);
    final stateRef = _stateRef(uid);
    final dayRef = _dayRef(uid, today);
    final economyRef = _economyRef(uid);

    return _firestore.runTransaction((transaction) async {
      final stateSnapshot = await transaction.get(stateRef);
      final daySnapshot = await transaction.get(dayRef);
      final economySnapshot = await transaction.get(economyRef);
      final stateData = stateSnapshot.data();
      final dayData = daySnapshot.data() ?? <String, dynamic>{};
      final economy = PetEconomyState.fromMap(economySnapshot.data());
      final current = EngagementState.fromMap(
        stateData,
        todayDateKey: today,
      );
      final lifetimeCredited = _boolMap(stateData?['creditedActivities']);
      final dailyCredited = _boolMap(dayData['creditedActivities']);
      if (credit.lifetimeCredit &&
          lifetimeCredited[credit.activityKey] == true) {
        return EngagementCreditResult(
          credited: false,
          studyPointsAwarded: 0,
          xpAwarded: 0,
          pawCoinsAwarded: 0,
          previousTotalXp: current.totalXp,
          previousLevel: current.level,
          state: current,
          streakNewlySecured: false,
        );
      }
      if (dailyCredited[credit.activityKey] == true) {
        return EngagementCreditResult(
          credited: false,
          studyPointsAwarded: 0,
          xpAwarded: 0,
          pawCoinsAwarded: 0,
          previousTotalXp: current.totalXp,
          previousLevel: current.level,
          state: current,
          streakNewlySecured: false,
        );
      }

      final nextPoints = current.todayStudyPoints + credit.studyPoints;
      final nextXp = current.totalXp + credit.xp;
      final streakUpdate = _calculateStreakUpdate(
        current: current,
        nextPoints: nextPoints,
        today: today,
        yesterday: yesterday,
      );

      final nextState = current.copyWith(
        totalXp: nextXp,
        currentStreak: streakUpdate.currentStreak,
        longestStreak: streakUpdate.longestStreak,
        lastQualifiedDate: streakUpdate.lastQualifiedDate,
        todayDateKey: today,
        todayStudyPoints: nextPoints,
        todayStreakSecured: streakUpdate.todayStreakSecured,
      );

      final nextDailyCredited = {
        ...dailyCredited,
        credit.activityKey: true,
      };
      final nextLifetimeCredited = {
        ...lifetimeCredited,
        if (credit.lifetimeCredit) credit.activityKey: true,
      };
      final coinAward = pawCoinRewardForActivityKey(credit.activityKey);
      final nextCoinActivities = {
        ...economy.creditedCoinActivities,
        if (coinAward > 0) credit.activityKey: true,
      };

      transaction.set(
          stateRef,
          {
            'totalXp': nextState.totalXp,
            'level': nextState.level,
            'currentStreak': nextState.currentStreak,
            'longestStreak': nextState.longestStreak,
            'lastQualifiedDate': nextState.lastQualifiedDate,
            'todayDateKey': today,
            'todayStudyPoints': nextState.todayStudyPoints,
            'dailyStudyTarget': nextState.dailyStudyTarget,
            'todayStreakSecured': nextState.todayStreakSecured,
            'creditedActivities': nextLifetimeCredited,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      transaction.set(
          dayRef,
          {
            'studyPoints': nextState.todayStudyPoints,
            'xpEarned': (dayData['xpEarned'] as num? ?? 0).toInt() + credit.xp,
            'streakSecured': nextState.todayStreakSecured,
            if (streakUpdate.newlySecured)
              'qualifiedAt': FieldValue.serverTimestamp(),
            'creditedActivities': nextDailyCredited,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      if (coinAward > 0) {
        transaction.set(
            economyRef,
            {
              'schemaVersion': 1,
              'pawCoins': economy.pawCoins + coinAward,
              'lifetimePawCoinsEarned':
                  economy.lifetimePawCoinsEarned + coinAward,
              'totalPawCoinsSpent': economy.totalPawCoinsSpent,
              'creditedCoinActivities': nextCoinActivities,
              'ownedCosmeticIds': economy.ownedCosmeticIds.toList()..sort(),
              'equippedCosmetics': economy.equippedCosmeticIds,
              'lastPurchasedItemId': economy.lastPurchasedItemId,
              'lastPurchasedAt': economy.lastPurchasedAt == null
                  ? null
                  : Timestamp.fromDate(economy.lastPurchasedAt!),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      } else if (!economySnapshot.exists) {
        transaction.set(economyRef, defaultPetEconomyPayload());
      }

      return EngagementCreditResult(
        credited: true,
        studyPointsAwarded: credit.studyPoints,
        xpAwarded: credit.xp,
        pawCoinsAwarded: coinAward,
        previousTotalXp: current.totalXp,
        previousLevel: current.level,
        state: nextState,
        streakNewlySecured: streakUpdate.newlySecured,
      );
    });
  }

  Future<EngagementCreditResult> _noCredit() async {
    final uid = _maybeUid;
    final today = malaysiaDateKey(_nowProvider());
    final state =
        uid == null ? EngagementState.initial(today) : await readState();
    return EngagementCreditResult(
      credited: false,
      studyPointsAwarded: 0,
      xpAwarded: 0,
      pawCoinsAwarded: 0,
      previousTotalXp: state.totalXp,
      previousLevel: state.level,
      state: state,
      streakNewlySecured: false,
    );
  }

  DocumentReference<Map<String, dynamic>> _stateRef(String uid) {
    return _firestore.doc('student_progress/$uid/engagement/state');
  }

  DocumentReference<Map<String, dynamic>> _dayRef(String uid, String dateKey) {
    return _firestore.doc('student_progress/$uid/engagement_days/$dateKey');
  }

  DocumentReference<Map<String, dynamic>> _economyRef(String uid) {
    return _firestore.doc('student_progress/$uid/pet_economy/state');
  }

  String get _uid {
    final uid = _maybeUid;
    if (uid != null) return uid;
    throw StateError('Student authentication is required for engagement.');
  }

  String? get _maybeUid {
    final provided = _uidProvider?.call();
    if (provided != null && provided.trim().isNotEmpty) return provided.trim();
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    return user?.uid;
  }
}

_StreakUpdate _calculateStreakUpdate({
  required EngagementState current,
  required int nextPoints,
  required String today,
  required String yesterday,
}) {
  var nextStreak = current.currentStreak;
  var nextLongest = current.longestStreak;
  var lastQualified = current.lastQualifiedDate;
  var streakSecured = current.todayStreakSecured;
  var newlySecured = false;

  if (streakSecured && lastQualified == today && nextStreak < 1) {
    nextStreak = 1;
  }

  if (!streakSecured && nextPoints >= current.dailyStudyTarget) {
    streakSecured = true;
    if (lastQualified == today) {
      nextStreak = nextStreak < 1 ? 1 : nextStreak;
    } else {
      newlySecured = true;
      nextStreak = lastQualified == yesterday ? nextStreak + 1 : 1;
      if (nextStreak < 1) nextStreak = 1;
      lastQualified = today;
    }
  }

  if (streakSecured && nextStreak < 1) nextStreak = 1;
  if (nextStreak > nextLongest) nextLongest = nextStreak;

  return _StreakUpdate(
    currentStreak: nextStreak,
    longestStreak: nextLongest,
    lastQualifiedDate: lastQualified,
    todayStreakSecured: streakSecured,
    newlySecured: newlySecured,
  );
}

class _StreakUpdate {
  const _StreakUpdate({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastQualifiedDate,
    required this.todayStreakSecured,
    required this.newlySecured,
  });

  final int currentStreak;
  final int longestStreak;
  final String? lastQualifiedDate;
  final bool todayStreakSecured;
  final bool newlySecured;
}

Map<String, bool> _boolMap(Object? value) {
  if (value is! Map) return <String, bool>{};
  return value.map((key, value) => MapEntry(key.toString(), value == true));
}

String malaysiaDateKey(DateTime now) {
  final malaysia = now.toUtc().add(const Duration(hours: 8));
  final year = malaysia.year.toString().padLeft(4, '0');
  final month = malaysia.month.toString().padLeft(2, '0');
  final day = malaysia.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String previousMalaysiaDateKey(String dateKey) {
  final parts = dateKey.split('-').map(int.parse).toList();
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  final previous = date.subtract(const Duration(days: 1));
  final year = previous.year.toString().padLeft(4, '0');
  final month = previous.month.toString().padLeft(2, '0');
  final day = previous.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
