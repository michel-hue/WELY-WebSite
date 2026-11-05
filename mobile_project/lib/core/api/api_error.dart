import 'package:dio/dio.dart';

class FieldError {
  const FieldError(this.field, this.message);
  final String field;
  final String message;
}

const networkMessage = 'Connexion impossible. Vérifiez votre réseau.';

class ApiError implements Exception {
  const ApiError({this.status, required this.code, required this.message, this.details = const []});

  const ApiError.network() : this(code: 'NETWORK', message: networkMessage);

  final int? status;
  final String code;
  final String message;
  final List<FieldError> details;

  bool get isNetwork => code == 'NETWORK';

  /// Message du premier détail portant sur [field], s'il existe.
  String? fieldMessage(String field) {
    for (final d in details) {
      if (d.field == field) return d.message;
    }
    return null;
  }

  factory ApiError.fromDio(DioException e) {
    final res = e.response;
    if (res == null) {
      // Timeouts, pas de connexion, DNS, socket... : tout ce qui n'a pas de réponse.
      return const ApiError.network();
    }
    final data = res.data;
    final body = data is Map ? data['error'] : null;
    if (body is Map) {
      final raw = body['details'];
      return ApiError(
        status: res.statusCode,
        code: (body['code'] ?? 'ERROR').toString(),
        message: (body['message'] ?? 'Une erreur est survenue.').toString(),
        details: raw is List
            ? [
                for (final d in raw)
                  if (d is Map) FieldError((d['field'] ?? '').toString(), (d['message'] ?? '').toString()),
              ]
            : const [],
      );
    }
    return ApiError(status: res.statusCode, code: 'ERROR', message: 'Une erreur est survenue.');
  }

  /// Convertit n'importe quelle erreur levée par le client en [ApiError].
  static ApiError of(Object e) {
    if (e is ApiError) return e;
    if (e is DioException) {
      final inner = e.error;
      if (inner is ApiError) return inner;
      return ApiError.fromDio(e);
    }
    return const ApiError(code: 'ERROR', message: 'Une erreur est survenue.');
  }

  @override
  String toString() => 'ApiError($status, $code, $message)';
}
