import 'lang.dart';

/// Contenu d'interface trilingue (fr / ar / da).
/// Porté de `ui_kits/app/data.jsx` (CHW_STRINGS) — micro-copy signature comprise.
class T {
  final Lang lang;
  const T(this.lang);

  String _pick(String fr, String ar, String da) {
    switch (lang) {
      case Lang.fr:
        return fr;
      case Lang.ar:
        return ar;
      case Lang.da:
        return da;
    }
  }

  String get appName => _pick('Chawerni', 'شاورني', 'شاورني');

  String get placeholder =>
      _pick('Pose ta question…', 'اطرح سؤالك…', 'سوّل اللي بغيتي…');

  String get emptyTitle =>
      _pick('Par quoi on commence ?', 'من أين نبدأ؟', 'منين نبداو؟');

  String get emptySub => _pick(
    'Chaque réponse cite la loi — avec sa date de version.',
    'كل جواب يستشهد بالقانون — مع تاريخ نسخته.',
    'كل جواب كيعطيك النص القانوني — بتاريخ النسخة ديالو.',
  );

  List<String> get thinking => _pick(
    'Je fouille les textes…|أنا كنقلّب في النصوص…',
    'أبحث في النصوص…|أنا كنقلّب في النصوص…',
    'أنا كنقلّب في النصوص…|كنجدد النصوص…',
  ).split('|');

  // Onglets
  String get tabChat => _pick('Chat', 'المحادثة', 'الشات');
  String get tabLib => _pick('Bibliothèque', 'المكتبة', 'المكتبة');
  String get tabHoquqi => _pick('Hoquqi', 'حقوقي', 'حقوقي');
  String get tabSettings => _pick('Réglages', 'الإعدادات', 'الإعدادات');

  // Bibliothèque
  String get libTitle =>
      _pick('Bibliothèque', 'المكتبة القانونية', 'المكتبة القانونية');
  String get libSub => _pick(
    '13 codes officiels du Royaume · consultables hors-ligne.',
    '13 نصاً رسمياً للمملكة · متاحة دون إنترنت.',
    '13 نص رسمي ديال المملكة · كاينين بلا إنترنت.',
  );
  String get searchPlaceholder => _pick(
    'Article (« 446 ») ou mot-clé…',
    'رقم المادة (« 446 ») أو كلمة مفتاحية…',
    'رقم المادة (« 446 ») ولا كلمة…',
  );
  String get consult => _pick('Consulter', 'تصفّح', 'تصفّح');

  // Hoquqi
  String get hoquqiTitle => _pick('Hoquqi', 'حقوقي', 'حقوقي');
  String get hoquqiSoon => _pick(
    'Des fiches pratiques par situation : licenciement, divorce, location…',
    'بطاقات عملية حسب الحالة: الفصل من العمل، الطلاق، الكراء…',
    'بطاقات عملية على حسب الحالة: الفصل من الخدمة، الطلاق، الكراء…',
  );
  String get soon => _pick('Bientôt', 'قريباً', 'قريباً');

  // Réglages
  String get settingsTitle => _pick('Réglages', 'الإعدادات', 'الإعدادات');
  String get settingLang => _pick('Langue', 'اللغة', 'اللغة');
  String get settingTextSize =>
      _pick('Taille de texte', 'حجم الخط', 'حجم الكتابة');
  String get settingAbout => _pick('À propos', 'حول التطبيق', 'على التطبيق');
  String get settingPrivacy => _pick('Confidentialité', 'الخصوصية', 'الخصوصية');

  // Bottom sheet article
  String get sheetCopy => _pick('Copier la référence', 'نسخ المرجع', 'نسخ المرجع');
  String get copied => _pick('Copié', 'تم النسخ', 'تنسخ');
  static const String faith = 'النص العربي هو المعتمد قانونياً';

  // Onboarding — 3 pages (titre + sous-titre)
  List<List<String>> get onb => _pick(
    [
      'شاورني قبل ما توقّع‖Consulte-moi avant de signer. Comprendre avant d\'agir — contrat, bail, licenciement.',
      'Chaque réponse cite la loi.‖Zéro invention : l\'article exact, sa hiérarchie, sa date de version.',
      'بالدارجة، بالعربية، en français‖La loi dans TA langue. La darija explique, la loi cite.',
    ].join('¶'),
    [
      'شاورني قبل ما توقّع‖افهم قبل أن تتصرف — عقد، كراء، فصل من العمل.',
      'كل جواب يستشهد بالقانون.‖لا اختلاق: المادة بالضبط، تسلسلها، وتاريخ نسختها.',
      'بالدارجة، بالعربية، en français‖القانون بلغتك أنت.',
    ].join('¶'),
    [
      'شاورني قبل ما توقّع‖افهم قبل ما دير أي حاجة — عقد، كراء، فصل من الخدمة.',
      'كل جواب كيستشهد بالقانون.‖والو من عندنا: المادة بالضبط، التسلسل ديالها، وتاريخ النسخة.',
      'بالدارجة، بالعربية، en français‖القانون باللغة ديالك انت.',
    ].join('¶'),
  ).split('¶').map((e) => e.split('‖')).toList();

  String get next => _pick('Suivant', 'التالي', 'من بعد');
  String get start => _pick('C\'est parti', 'هيا بنا', 'يالاه نبداو');
  String get skip => _pick('Passer', 'تخطّى', 'فوّت');

  // Disclaimer
  String get discTitle =>
      _pick('Avant de commencer', 'قبل أن نبدأ', 'قبل ما نبداو');
  String get discBody => _pick(
    'Chawerni t\'informe sur ce que disent les textes de loi marocains. Ce n\'est pas un avis juridique : pour une décision importante, consulte un avocat ou un professionnel agréé.',
    'شاورني يخبرك بما تقوله نصوص القانون المغربية. هذا ليس رأياً قانونياً: لقرار مهم، استشر محامياً أو مهنياً معتمداً.',
    'شاورني كيقول ليك أشنو كتقول النصوص القانونية المغربية. هادشي ماشي استشارة قانونية: لقرار مهم، شاور محامي ولا مهني معتمد.',
  );
  String get discBtn => 'فهمت — J\'ai compris';
  String get discLink => _pick(
    'Trouver un avocat près de chez toi',
    'ابحث عن محامٍ قريب منك',
    'لقا محامي قريب ليك',
  );

  static const String sent = 'شاورني فاش بغيتي 🤝';
  String get findLawyer => _pick('Trouver un avocat', 'ابحث عن محامٍ', 'لقا محامي');

  // Réseau / divers
  String get netError => _pick(
    'Connexion perdue',
    'انقطع الاتصال',
    'الكونيكسيون قاطعة، عاود من بعد',
  );
  String get refresh =>
      _pick('Mise à jour des textes', 'تحديث النصوص', 'كنجدد النصوص');
  String get aboutTagline => _pick(
    'L\'information juridique, jamais le conseil.',
    'معلومة قانونية، وليست استشارة.',
    'معلومة قانونية، ماشي استشارة.',
  );
}
