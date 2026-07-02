class Student {
  const Student({
    required this.id,
    required this.name,
    required this.preferredLanguage,
    required this.dailyTargetMinutes,
    required this.status,
  });

  final String id;
  final String name;
  final String preferredLanguage;
  final int dailyTargetMinutes;
  final String status;

  factory Student.fromMap(String id, Map<String, dynamic> data) {
    return Student(
      id: id,
      name: (data['name'] ?? data['displayName'] ?? 'Qidah').toString(),
      preferredLanguage:
          (data['preferredLanguage'] ?? 'Bahasa Melayu').toString(),
      dailyTargetMinutes: (data['dailyTargetMinutes'] as num?)?.toInt() ?? 20,
      status: (data['status'] ?? 'active').toString(),
    );
  }
}
