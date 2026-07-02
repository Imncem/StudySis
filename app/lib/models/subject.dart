class Subject {
  const Subject({
    required this.id,
    required this.displayName,
    required this.shortName,
    required this.contentStatus,
    required this.iconName,
    required this.themeColor,
    required this.order,
  });

  final String id;
  final String displayName;
  final String shortName;
  final String contentStatus;
  final String iconName;
  final String themeColor;
  final int order;

  bool get isComingSoon => contentStatus == 'coming_soon';

  factory Subject.fromMap(String id, Map<String, dynamic> data) {
    return Subject(
      id: id,
      displayName: (data['displayName'] ?? id).toString(),
      shortName: (data['shortName'] ?? data['displayName'] ?? id).toString(),
      contentStatus: (data['contentStatus'] ?? 'coming_soon').toString(),
      iconName: (data['iconName'] ?? 'book').toString(),
      themeColor: (data['themeColor'] ?? '#7B8F72').toString(),
      order: (data['order'] as num?)?.toInt() ?? 999,
    );
  }
}
