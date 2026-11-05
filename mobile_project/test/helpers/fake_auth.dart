import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_project/core/api/api_error.dart';
import 'package:mobile_project/core/session/session_controller.dart';
import 'package:mobile_project/features/favorites/favorites_controller.dart';
import 'package:mobile_project/features/listings/models.dart' hide Page;

/// Session factice : enregistre les appels OTP ; erreurs programmables (une par appel).
class FakeAuthSession extends SessionController {
  FakeAuthSession({this.initial, this.isNewUser = true, List<String>? log}) : log = log ?? [];
  final Me? initial;
  final bool isNewUser;

  /// Ordre des appels, partagé avec les autres fakes.
  final List<String> log;
  final otpRequests = <String>[];
  final verifications = <(String, String, String?)>[];
  final requestErrors = <Object>[];
  final verifyErrors = <Object>[];

  @override
  Future<Me?> build() async => initial;

  @override
  Future<OtpRequestResult> requestOtp(String phone, {String channel = 'sms'}) async {
    otpRequests.add(phone);
    log.add('requestOtp');
    if (requestErrors.isNotEmpty) throw requestErrors.removeAt(0);
    return (expiresInSeconds: 300, isNewUser: isNewUser);
  }

  @override
  Future<Me> verifyOtp(String phone, String code, {String? name}) async {
    verifications.add((phone, code, name));
    log.add('verify');
    if (verifyErrors.isNotEmpty) throw verifyErrors.removeAt(0);
    final me = Me(id: 'u1', name: name ?? 'Awa', phone: phone, isSeller: false, createdAt: DateTime(2026));
    state = AsyncData(me);
    return me;
  }
}

class FakeFavorites extends FavoritesController {
  FakeFavorites(this.log, {this.fail = false});
  final List<String> log;
  final bool fail;

  @override
  Future<List<ListingCard>> build() async => const [];

  @override
  Future<void> mergeLocalIntoAccount() async {
    log.add('favorites');
    if (fail) throw const ApiError.network();
  }
}

Me signedInUser() =>
    Me(id: 'u9', name: 'Awa Traoré', phone: '+2250712345678', isSeller: false, createdAt: DateTime(2026));

const otpInvalid = ApiError(status: 401, code: 'OTP_INVALID', message: 'Code incorrect ou expiré.');
const otpTooMany = ApiError(status: 429, code: 'OTP_TOO_MANY_ATTEMPTS', message: 'Trop d’essais. Demandez un nouveau code.');
const otpTooSoon =
    ApiError(status: 429, code: 'OTP_RESEND_TOO_SOON', message: 'Patientez une minute avant de demander un nouveau code.');
const nameMissing = ApiError(
  status: 400,
  code: 'VALIDATION_ERROR',
  message: 'Certaines informations sont invalides.',
  details: [FieldError('name', 'Indiquez votre nom (2 caractères minimum).')],
);
