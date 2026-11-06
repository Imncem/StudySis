class LearningLocation {
  const LearningLocation({
    required this.subjectId,
    required this.subjectName,
    required this.parentKind,
    required this.parentId,
    required this.parentTitle,
    required this.parentNumber,
    required this.parentOrder,
    required this.structureLabel,
    this.containerKind,
    this.containerId,
    this.containerTitle,
    this.containerNumber,
  });

  final String subjectId;
  final String subjectName;
  final String parentKind;
  final String parentId;
  final String parentTitle;
  final String parentNumber;
  final int parentOrder;
  final String structureLabel;
  final String? containerKind;
  final String? containerId;
  final String? containerTitle;
  final String? containerNumber;

  String get identityKey => [
        subjectId,
        containerKind ?? '',
        containerId ?? '',
        parentKind,
        parentId,
      ].map((part) => '${part.length}:$part').join();

  String get progressDocumentId {
    if (containerId == null) return '${subjectId}_$parentId';
    return [subjectId, containerKind, containerId, parentKind, parentId]
        .map((part) {
      final encoded = Uri.encodeComponent(part ?? '');
      return '${encoded.length}:$encoded';
    }).join();
  }

  String get displayTitle => '$structureLabel $parentNumber: $parentTitle';

  Map<String, Object?> toProgressFields() => {
        'parentKind': parentKind,
        'parentId': parentId,
        'parentTitle': parentTitle,
        'parentNumber': parentNumber,
        'parentOrder': parentOrder,
        if (containerKind != null) 'containerKind': containerKind,
        if (containerId != null) 'containerId': containerId,
        if (containerTitle != null) 'containerTitle': containerTitle,
        if (containerNumber != null) 'containerNumber': containerNumber,
      };
}
