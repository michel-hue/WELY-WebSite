import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Canal de contact, tel qu'attendu par `POST /listings/:id/contact-clicks`.
enum ContactChannel { whatsapp, call }

/// Lien `wa.me` avec le message pré-rempli (spec API §7.5).
Uri whatsappUri(String phone, String title) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final text = Uri.encodeComponent('Bonjour, je suis intéressé par « $title » vu sur WELLY');
  return Uri.parse('https://wa.me/$digits?text=$text');
}

/// `tel:` en gardant le `+` international.
Uri telUri(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  return Uri(scheme: 'tel', path: phone.trim().startsWith('+') ? '+$digits' : digits);
}

/// Ouverture de liens externes ; surchargée en test via [urlLauncherProvider].
class UrlLauncher {
  const UrlLauncher();

  Future<bool> canLaunch(Uri uri) async {
    try {
      return await canLaunchUrl(uri);
    } on PlatformException {
      return false;
    }
  }

  /// [appOnly] : n'ouvre que dans une application (pas le navigateur) ; renvoie
  /// `false` si aucune ne prend le lien (ex. WhatsApp absent pour `wa.me`).
  Future<bool> launch(Uri uri, {bool appOnly = false}) async {
    try {
      return await launchUrl(
        uri,
        mode: appOnly ? LaunchMode.externalNonBrowserApplication : LaunchMode.externalApplication,
      );
    } on PlatformException {
      return false;
    }
  }
}

final urlLauncherProvider = Provider<UrlLauncher>((ref) => const UrlLauncher());

/// Ouvre WhatsApp (`wa.me`) ; si WhatsApp n'est pas installé, propose l'appel
/// ([confirmCall], accepté par défaut) au numéro [callPhone] (ou [phone]).
/// Renvoie le canal réellement ouvert, ou `null`.
Future<ContactChannel?> openWhatsAppOrCall(
  UrlLauncher launcher,
  String phone,
  String title, {
  String? callPhone,
  Future<bool> Function()? confirmCall,
}) async {
  if (await launcher.launch(whatsappUri(phone, title), appOnly: true)) return ContactChannel.whatsapp;
  final tel = telUri(callPhone ?? phone);
  if (!await launcher.canLaunch(tel)) return null;
  if (confirmCall != null && !await confirmCall()) return null;
  return await launcher.launch(tel) ? ContactChannel.call : null;
}
