import 'package:cloud_firestore/cloud_firestore.dart';

class MuffinWallet {
  const MuffinWallet({
    required this.maxBites,
    required this.currentBites,
    required this.regenIntervalMinutes,
    required this.dailyUsedRequests,
    required this.dailySoftLimit,
    required this.dailyHardLimit,
    required this.status,
    this.lastRegenAt,
    this.dailyResetDate,
    this.nextProviderResetAt,
  });

  static const empty = MuffinWallet(
    maxBites: 5,
    currentBites: 0,
    regenIntervalMinutes: 60,
    dailyUsedRequests: 0,
    dailySoftLimit: 17,
    dailyHardLimit: 20,
    status: 'active',
  );

  static const full = MuffinWallet(
    maxBites: 5,
    currentBites: 5,
    regenIntervalMinutes: 60,
    dailyUsedRequests: 0,
    dailySoftLimit: 17,
    dailyHardLimit: 20,
    status: 'active',
  );

  final int maxBites;
  final int currentBites;
  final int regenIntervalMinutes;
  final DateTime? lastRegenAt;
  final String? dailyResetDate;
  final int dailyUsedRequests;
  final int dailySoftLimit;
  final int dailyHardLimit;
  final String status;
  final DateTime? nextProviderResetAt;

  bool get isDailyLimitReached =>
      status == 'daily_limit' || dailyUsedRequests >= dailySoftLimit;
  bool get hasBites => currentBites > 0;

  MuffinWallet copyWith({
    int? maxBites,
    int? currentBites,
    int? regenIntervalMinutes,
    DateTime? lastRegenAt,
    String? dailyResetDate,
    int? dailyUsedRequests,
    int? dailySoftLimit,
    int? dailyHardLimit,
    String? status,
    DateTime? nextProviderResetAt,
  }) {
    return MuffinWallet(
      maxBites: maxBites ?? this.maxBites,
      currentBites: currentBites ?? this.currentBites,
      regenIntervalMinutes: regenIntervalMinutes ?? this.regenIntervalMinutes,
      lastRegenAt: lastRegenAt ?? this.lastRegenAt,
      dailyResetDate: dailyResetDate ?? this.dailyResetDate,
      dailyUsedRequests: dailyUsedRequests ?? this.dailyUsedRequests,
      dailySoftLimit: dailySoftLimit ?? this.dailySoftLimit,
      dailyHardLimit: dailyHardLimit ?? this.dailyHardLimit,
      status: status ?? this.status,
      nextProviderResetAt: nextProviderResetAt ?? this.nextProviderResetAt,
    );
  }

  MuffinWallet effectiveAt(DateTime now) {
    if (currentBites >= maxBites) {
      return copyWith(
        currentBites: maxBites,
        lastRegenAt: now,
        status: isDailyLimitReached ? status : 'active',
      );
    }
    final anchor = lastRegenAt;
    if (anchor == null) return this;
    final elapsed = now.difference(anchor);
    if (elapsed.isNegative) return this;
    final interval = Duration(minutes: regenIntervalMinutes);
    if (interval.inMilliseconds <= 0) return this;
    final regenerated = elapsed.inMilliseconds ~/ interval.inMilliseconds;
    if (regenerated <= 0) return this;
    final nextBites = (currentBites + regenerated).clamp(0, maxBites);
    final nextAnchor = nextBites >= maxBites
        ? now
        : anchor.add(Duration(
            milliseconds: regenerated * interval.inMilliseconds,
          ));
    return copyWith(
      currentBites: nextBites,
      lastRegenAt: nextAnchor,
      status: isDailyLimitReached
          ? status
          : nextBites > 0
              ? 'active'
              : status,
    );
  }

  Duration? cooldownRemaining(DateTime now) {
    if (currentBites >= maxBites) return null;
    final anchor = lastRegenAt;
    if (anchor == null) return Duration(minutes: regenIntervalMinutes);
    final elapsed = now.difference(anchor);
    final remaining = Duration(minutes: regenIntervalMinutes) - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String cooldownText(DateTime now) {
    final remaining = cooldownRemaining(now);
    if (remaining == null || remaining == Duration.zero) {
      return 'Muffin is recharging. Next Bite soon.';
    }
    final minutes = remaining.inMinutes <= 0 ? 1 : remaining.inMinutes;
    return 'Muffin is recharging. Next Bite in $minutes min.';
  }

  String dailyRestText(DateTime now) {
    final reset = nextProviderResetAt;
    if (reset == null) {
      return 'Muffin has finished helping for today. More Bites will be available tomorrow.';
    }
    final remaining = reset.difference(now);
    final minutes = remaining.inMinutes <= 0 ? 1 : remaining.inMinutes + 1;
    final text = minutes < 60
        ? '$minutes min'
        : minutes % 60 == 0
            ? '${minutes ~/ 60} hr'
            : '${minutes ~/ 60} hr ${minutes % 60} min';
    return 'Muffin has finished helping for today. More Bites will be available in $text.';
  }

  factory MuffinWallet.fromJson(Map<String, dynamic> data) {
    return MuffinWallet(
      maxBites: (data['maxBites'] as num?)?.toInt() ?? 5,
      currentBites: (data['currentBites'] as num?)?.toInt() ?? 5,
      regenIntervalMinutes:
          (data['regenIntervalMinutes'] as num?)?.toInt() ?? 60,
      lastRegenAt: _dateTime(data['lastRegenAt']),
      dailyResetDate: data['dailyResetDate']?.toString(),
      dailyUsedRequests: (data['dailyUsedRequests'] as num?)?.toInt() ?? 0,
      dailySoftLimit: (data['dailySoftLimit'] as num?)?.toInt() ?? 17,
      dailyHardLimit: (data['dailyHardLimit'] as num?)?.toInt() ?? 20,
      status: data['status']?.toString() ?? 'active',
      nextProviderResetAt: _dateTime(data['nextProviderResetAt']),
    );
  }

  static DateTime? _dateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}
