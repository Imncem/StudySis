import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

abstract class TrustedProgressService {
  Future<Map<String, dynamic>> record(
    String functionName,
    Map<String, Object?> payload,
  );
}

class RemoteTrustedProgressService implements TrustedProgressService {
  RemoteTrustedProgressService({
    FirebaseAuth? auth,
    http.Client? client,
    Uri? functionsBaseUri,
  })  : _auth = auth,
        _client = client ?? http.Client(),
        _functionsBaseUri = functionsBaseUri;

  final FirebaseAuth? _auth;
  final http.Client _client;
  final Uri? _functionsBaseUri;

  @override
  Future<Map<String, dynamic>> record(
    String functionName,
    Map<String, Object?> payload,
  ) async {
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null) {
      throw const TrustedProgressException(
        'Authentication is required to save progress.',
      );
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const TrustedProgressException(
        'Authentication is required to save progress.',
      );
    }

    try {
      final response = await _client
          .post(
            _endpoint(functionName),
            headers: {
              'authorization': 'Bearer $token',
              'content-type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(response.body);
      final body =
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['success'] != true) {
        throw TrustedProgressException(
          (body['message'] ?? 'Progress could not be saved. Please try again.')
              .toString(),
          code: body['code']?.toString(),
        );
      }
      return body;
    } on TrustedProgressException {
      rethrow;
    } on TimeoutException {
      throw const TrustedProgressException(
        'Progress needs an internet connection. Reconnect and try again.',
        code: 'offline',
      );
    } on http.ClientException {
      throw const TrustedProgressException(
        'Progress needs an internet connection. Reconnect and try again.',
        code: 'offline',
      );
    } on FormatException {
      throw const TrustedProgressException(
        'Progress could not be saved. Please try again.',
        code: 'invalid-response',
      );
    }
  }

  Uri _endpoint(String functionName) {
    final base = _functionsBaseUri ?? _defaultFunctionsBaseUri();
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}/$functionName',
    );
  }

  Uri _defaultFunctionsBaseUri() {
    const configured = String.fromEnvironment('PROGRESSION_FUNCTIONS_BASE_URL');
    if (configured.isNotEmpty) return Uri.parse(configured);
    final projectId = Firebase.app().options.projectId;
    return Uri.parse('https://us-central1-$projectId.cloudfunctions.net');
  }
}

class TrustedProgressException implements Exception {
  const TrustedProgressException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}
