import 'package:cloud_firestore/cloud_firestore.dart';

class EngagementState {
  const EngagementState({
    required this.totalXp,
    required this.level,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastQualifiedDate,
    required this.todayDateKey,
    required this.todayStudyPoints,
    required this.dailyStudyTarget,
    required this.todayStreakSecured,
  });

  final int totalXp;
  final int level;
  final int currentStreak;
  final int longestStreak;
  final String? lastQualifiedDate;
  final String todayDateKey;
  final int todayStudyPoints;
  final int dailyStudyTarget;
  final bool todayStreakSecured;

  static EngagementState initial(String todayDateKey) {
    return EngagementState(
      totalXp: 0,
      level: 1,
      currentStreak: 0,
      longestStreak: 0,
      lastQualifiedDate: null,
      todayDateKey: todayDateKey,
      todayStudyPoints: 0,
      dailyStudyTarget: 3,
      todayStreakSecured: false,
    );
  }

  factory EngagementState.fromMap(
    Map<String, dynamic>? data, {
    required String todayDateKey,
  }) {
    if (data == null) return EngagementState.initial(todayDateKey);
    final storedDate = data['todayDateKey']?.toString() ?? todayDateKey;
    final isToday = storedDate == todayDateKey;
    final totalXp = _intValue(data['totalXp']);
    final lastQualifiedDate = data['lastQualifiedDate']?.toString();
    final rawCurrentStreak = _intValue(data['currentStreak']);
    final todayStreakSecured =
        isToday ? data['todayStreakSecured'] == true : false;
    final currentStreak =
        todayStreakSecured && lastQualifiedDate == todayDateKey
            ? (rawCurrentStreak < 1 ? 1 : rawCurrentStreak)
            : rawCurrentStreak;
    return EngagementState(
      totalXp: totalXp,
      level: calculateLevel(totalXp),
      currentStreak: currentStreak,
      longestStreak: _intValue(data['longestStreak']),
      lastQualifiedDate: lastQualifiedDate,
      todayDateKey: todayDateKey,
      todayStudyPoints: isToday ? _intValue(data['todayStudyPoints']) : 0,
      dailyStudyTarget: _intValue(data['dailyStudyTarget'], fallback: 3),
      todayStreakSecured: todayStreakSecured,
    );
  }

  int get xpForCurrentLevel => xpRequiredForLevel(level);
  int get xpForNextLevel => xpRequiredForLevel(level + 1);
  int get xpIntoLevel => totalXp - xpForCurrentLevel;
  int get xpNeededForLevel => xpForNextLevel - xpForCurrentLevel;
  double get levelProgress =>
      xpNeededForLevel <= 0 ? 1 : (xpIntoLevel / xpNeededForLevel).clamp(0, 1);
  int get clampedTodayStudyPoints =>
      todayStudyPoints.clamp(0, dailyStudyTarget);

  EngagementState copyWith({
    int? totalXp,
    int? currentStreak,
    int? longestStreak,
    String? lastQualifiedDate,
    String? todayDateKey,
    int? todayStudyPoints,
    int? dailyStudyTarget,
    bool? todayStreakSecured,
  }) {
    final nextXp = totalXp ?? this.totalXp;
    return EngagementState(
      totalXp: nextXp,
      level: calculateLevel(nextXp),
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastQualifiedDate: lastQualifiedDate ?? this.lastQualifiedDate,
      todayDateKey: todayDateKey ?? this.todayDateKey,
      todayStudyPoints: todayStudyPoints ?? this.todayStudyPoints,
      dailyStudyTarget: dailyStudyTarget ?? this.dailyStudyTarget,
      todayStreakSecured: todayStreakSecured ?? this.todayStreakSecured,
    );
  }
}

class EngagementCredit {
  const EngagementCredit({
    required this.activityKey,
    required this.studyPoints,
    required this.xp,
    this.lifetimeCredit = false,
  });

  final String activityKey;
  final int studyPoints;
  final int xp;
  final bool lifetimeCredit;
}

class EngagementCreditResult {
  const EngagementCreditResult({
    required this.credited,
    required this.studyPointsAwarded,
    required this.xpAwarded,
    required this.previousTotalXp,
    required this.previousLevel,
    required this.state,
    required this.streakNewlySecured,
  });

  final bool credited;
  final int studyPointsAwarded;
  final int xpAwarded;
  final int previousTotalXp;
  final int previousLevel;
  final EngagementState state;
  final bool streakNewlySecured;
  int get newTotalXp => state.totalXp;
  int get newLevel => state.level;
  bool get levelUp => newLevel > previousLevel;
}

int calculateLevel(int totalXp) {
  if (totalXp < 100) return 1;
  if (totalXp < 250) return 2;
  if (totalXp < 450) return 3;
  if (totalXp < 700) return 4;
  if (totalXp < 1000) return 5;
  return 5 + ((totalXp - 1000) ~/ 400) + 1;
}

int xpRequiredForLevel(int level) {
  if (level <= 1) return 0;
  const thresholds = {
    2: 100,
    3: 250,
    4: 450,
    5: 700,
    6: 1000,
  };
  final configured = thresholds[level];
  if (configured != null) return configured;
  return 1000 + ((level - 6) * 400);
}

int _intValue(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

DateTime? timestampToDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}
