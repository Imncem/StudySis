import 'trusted_progress_service.dart';

abstract class SubjectReadinessService {
  Future<Set<String>> usableAssessmentModulePaths(
    Iterable<String> modulePaths,
  );
}

class RemoteSubjectReadinessService implements SubjectReadinessService {
  RemoteSubjectReadinessService({TrustedProgressService? trustedService})
      : _trustedService = trustedService ?? RemoteTrustedProgressService();

  final TrustedProgressService _trustedService;

  @override
  Future<Set<String>> usableAssessmentModulePaths(
    Iterable<String> modulePaths,
  ) async {
    final paths = modulePaths.toSet().toList(growable: false);
    if (paths.isEmpty) return const <String>{};
    final response = await _trustedService.record(
      'getAssessmentReadiness',
      {'modulePaths': paths},
    );
    final rawPaths = response['usableModulePaths'];
    if (rawPaths is! List) return const <String>{};
    return rawPaths.map((path) => path.toString()).toSet();
  }
}
