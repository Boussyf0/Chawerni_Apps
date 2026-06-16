import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Coordonnées du fondateur + de l'app (page « À propos »), et helpers pour
/// ouvrir tél / WhatsApp / e-mail / Maps / liens externes.
class Contact {
  static const founderName = 'Abderrahim Boussyf';
  static const email = 'boussyf0@gmail.com';
  static const linkedin =
      'https://www.linkedin.com/in/abderrahim-boussyf-167539175/';
  static const privacyUrl = 'https://164.90.216.143.nip.io/privacy';
  static const apiBase = 'https://164.90.216.143.nip.io';
}

/// Ouvre une URL externe (navigateur, tél, mail…). Renvoie false si impossible
/// (affiche alors un SnackBar discret pour ne pas laisser l'utilisateur sans retour).
Future<void> openExternal(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  final ok = await canLaunchUrl(uri) &&
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Action indisponible sur cet appareil.')),
    );
  }
}

/// Raccourcis typés.
Future<void> openTel(BuildContext c, String phone) =>
    openExternal(c, 'tel:$phone');

Future<void> openWhatsApp(BuildContext c, String number, {String? text}) =>
    openExternal(c,
        'https://wa.me/$number${text != null ? '?text=${Uri.encodeComponent(text)}' : ''}');

Future<void> openEmail(BuildContext c, String email, {String? subject}) =>
    openExternal(c,
        'mailto:$email${subject != null ? '?subject=${Uri.encodeComponent(subject)}' : ''}');

Future<void> openMaps(BuildContext c, String query) => openExternal(
    c, 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}');
