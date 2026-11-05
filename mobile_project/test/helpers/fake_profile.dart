import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_project/core/session/session_controller.dart';

import 'fake_auth.dart';

Me copyMe(Me me, {String? name, String? whatsappPhone, bool clearWhatsapp = false, bool? isSeller}) => Me(
      id: me.id,
      name: name ?? me.name,
      phone: me.phone,
      whatsappPhone: clearWhatsapp ? null : (whatsappPhone ?? me.whatsappPhone),
      avatarUrl: me.avatarUrl,
      isSeller: isSeller ?? me.isSeller,
      createdAt: me.createdAt,
    );

/// Session factice pour le Profil : mode vendeur, profil, déconnexion,
/// suppression ; appels enregistrés dans [log], erreur programmable.
class FakeProfileSession extends FakeAuthSession {
  FakeProfileSession({super.initial, super.log});

  Object? actionError;

  Me get _me => state.value!;

  @override
  Future<Me> setSellerMode(bool enabled) async {
    log.add('seller:$enabled');
    if (actionError != null) throw actionError!;
    final me = copyMe(_me, isSeller: enabled);
    state = AsyncData(me);
    return me;
  }

  @override
  Future<Me> updateProfile({String? name, String? whatsappPhone, bool clearWhatsapp = false}) async {
    log.add('update:${name ?? ''}:${clearWhatsapp ? 'clear' : whatsappPhone ?? ''}');
    if (actionError != null) throw actionError!;
    final me = copyMe(_me, name: name, whatsappPhone: whatsappPhone, clearWhatsapp: clearWhatsapp);
    state = AsyncData(me);
    return me;
  }

  @override
  Future<void> logout() async {
    log.add('logout');
    state = const AsyncData(null);
  }

  @override
  Future<void> deleteAccount() async {
    log.add('delete');
    if (actionError != null) throw actionError!;
    state = const AsyncData(null);
  }
}
