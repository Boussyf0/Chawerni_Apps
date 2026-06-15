import 'lang.dart';

/// Une chaîne trilingue. La darija réutilise souvent l'arabe pour les contenus
/// juridiques (la loi cite en arabe classique ; la darija explique).
class L3 {
  final String fr;
  final String ar;
  final String da;
  const L3(this.fr, this.ar, [String? da]) : da = da ?? ar;

  String call(Lang l) {
    switch (l) {
      case Lang.fr:
        return fr;
      case Lang.ar:
        return ar;
      case Lang.da:
        return da;
    }
  }
}

/// Source citée : un article de loi réel, avec extrait, texte intégral, date.
class LegalSource {
  final L3 num;
  final L3 code;
  final L3 date;
  final L3 excerpt;
  final L3 hier;
  final L3 full;
  const LegalSource({
    required this.num,
    required this.code,
    required this.date,
    required this.excerpt,
    required this.hier,
    required this.full,
  });
}

/// Bandeau « enjeu grave » optionnel sous une réponse.
class GraveBanner {
  final L3 title;
  final L3 body;
  const GraveBanner({required this.title, required this.body});
}

/// Un scénario de chat jouable depuis un chip.
class Scenario {
  final String id;
  final L3 chip;
  final L3 reply;
  final List<LegalSource> sources;
  final GraveBanner? banner;
  final L3? followUp;
  final bool honest; // hors corpus : réponse honnête, zéro source
  const Scenario({
    required this.id,
    required this.chip,
    required this.reply,
    this.sources = const [],
    this.banner,
    this.followUp,
    this.honest = false,
  });
}

/// Scénarios — textes de loi RÉELS tirés du corpus (corpus/chunks/*.jsonl),
/// avec leurs vraies dates de version. Porté de `data.jsx` (CHW_SCENARIOS).
const List<Scenario> kScenarios = [
  Scenario(
    id: 'licenciement',
    chip: L3(
      'Mes droits si je suis licencié',
      'حقوقي إذا فُصلت من العمل',
      'شنو حقوقي إلا تفصلت من الخدمة؟',
    ),
    reply: L3(
      'Si tu as un CDI et plus de 6 mois dans la même entreprise, tu as droit à une indemnité de licenciement — et si le licenciement est abusif, à des dommages-intérêts (jusqu\'à 36 mois de salaire). Voilà ce que disent les textes :',
      'إذا كان عقدك غير محدد المدة وقضيت أكثر من 6 أشهر في نفس المقاولة، فلك تعويض عن الفصل — وإذا كان الفصل تعسفياً، فلك تعويض عن الضرر (حتى 36 شهراً من الأجر). هذا ما تقوله النصوص:',
      'إلا عندك عقد غير محدد المدة وداوزتي 6 شهور فنفس الشركة، عندك الحق فتعويض الفصل — وإلا كان الفصل تعسفي، عندك تعويض الضرر (حتى ل36 شهر ديال الأجرة). ها أشنو كتقول النصوص:',
    ),
    sources: [
      LegalSource(
        num: L3('Art. 52', 'المادة 52'),
        code: L3('Code du travail', 'مدونة الشغل'),
        date: L3('10/11/2025', '08/2019'),
        excerpt: L3(
          '« Le salarié lié par un contrat de travail à durée indéterminée a droit à une indemnité, en cas de licenciement après six mois de travail dans la même entreprise… »',
          '« يستحق الأجير المرتبط بعقد شغل غير محدد المدة تعويضاً عند فصله، بعد قضائه ستة أشهر من الشغل داخل نفس المقاولة… »',
        ),
        hier: L3(
          'Livre I › Titre I › Chap. V › Section IV — De l\'indemnité de licenciement',
          'الكتاب الأول › القسم الأول › الباب › الفرع — التعويض عن الفصل',
        ),
        full: L3(
          'Le salarié lié par un contrat de travail à durée indéterminée a droit à une indemnité, en cas de licenciement après six mois de travail dans la même entreprise quels que soient le mode de rémunération et la périodicité du paiement du salaire.',
          'يستحق الأجير المرتبط بعقد شغل غير محدد المدة تعويضاً عند فصله، بعد قضائه ستة أشهر من الشغل داخل نفس المقاولة، بصرف النظر عن الطريقة التي يتقاضى بها أجره وعن دورية أدائه.',
        ),
      ),
      LegalSource(
        num: L3('Art. 41', 'المادة 41'),
        code: L3('Code du travail', 'مدونة الشغل'),
        date: L3('10/11/2025', '08/2019'),
        excerpt: L3(
          '« En cas de rupture abusive du contrat de travail par l\'une des parties, la partie lésée a le droit de demander des dommages-intérêts… »',
          '« في حالة الفسخ التعسفي لعقد الشغل من أحد الطرفين، يحق للطرف المتضرر المطالبة بالتعويض… »',
        ),
        hier: L3(
          'Livre I › Titre I › Chap. V › Section II — Des modes de cessation',
          'الكتاب الأول › عقد الشغل › إنهاء العقد',
        ),
        full: L3(
          'En cas de rupture abusive du contrat de travail par l\'une des parties, la partie lésée a le droit de demander des dommages-intérêts. […] Le tribunal compétent peut statuer, dans le cas d\'un licenciement abusif du salarié, soit par la réintégration du salarié dans son poste ou par des dommages-intérêts dont le montant est fixé sur la base du salaire d\'un mois et demi par année ou fraction d\'année de travail sans toutefois dépasser le plafond de 36 mois.',
          'في حالة الفسخ التعسفي لعقد الشغل من أحد الطرفين، يحق للطرف المتضرر المطالبة بالتعويض. […] يمكن للمحكمة المختصة أن تحكم، في حالة الفصل التعسفي للأجير، إما بإرجاعه إلى منصبه أو بتعويض يحدد مبلغه على أساس أجرة شهر ونصف عن كل سنة أو جزء سنة من العمل، على ألا يتجاوز سقف 36 شهراً.',
        ),
      ),
    ],
    followUp: L3(
      'Et l\'indemnité, elle se calcule comment ?',
      'وكيف يُحسب التعويض؟',
      'والتعويض كيفاش كيتحسب؟',
    ),
  ),
  Scenario(
    id: 'divorce',
    chip: L3(
      'Le divorce par accord, comment ça marche ?',
      'الطلاق بالاتفاق، كيف يتم؟',
      'الطلاق بالاتفاق كيفاش',
    ),
    reply: L3(
      'Vous pouvez vous mettre d\'accord pour mettre fin au mariage, avec ou sans conditions — tant que ça ne nuit pas aux intérêts des enfants. La demande se dépose au tribunal, qui tente d\'abord une conciliation :',
      'يمكن للزوجين أن يتفقا على إنهاء العلاقة الزوجية، بشروط أو بدونها — ما دامت لا تضر بمصالح الأطفال. يُقدَّم الطلب إلى المحكمة التي تحاول الصلح أولاً:',
      'تقدرو تتفقو على إنهاء الزواج، بشروط ولا بلا شروط — المهم ما تضرّش مصالح الأطفال. الطلب كيتقدم للمحكمة اللي كتحاول الصلح أولاً:',
    ),
    sources: [
      LegalSource(
        num: L3('Art. 114', 'المادة 114'),
        code: L3('Moudawana — Code de la famille', 'مدونة الأسرة'),
        date: L3('12/12/2024', '25/05/2026'),
        excerpt: L3(
          '« Les deux époux peuvent se mettre d\'accord sur le principe de mettre fin à leur union conjugale, soit sans conditions, soit avec conditions… »',
          '« يمكن للزوجين أن يتفقا على مبدإ إنهاء العلاقة الزوجية دون شروط، أو بشروط لا تتنافى مع أحكام هذه المدونة، ولا تضر بمصالح الأطفال… »',
        ),
        hier: L3(
          'Livre II › Titre V — Du divorce par consentement mutuel',
          'الكتاب الثاني › القسم الخامس › الباب الأول — الطلاق بالاتفاق',
        ),
        full: L3(
          'Les deux époux peuvent se mettre d\'accord sur le principe de mettre fin à leur union conjugale, soit sans conditions, soit avec conditions, sous réserve que celles-ci ne soient pas incompatibles avec les dispositions du présent Code et ne portent pas préjudice aux intérêts des enfants. En cas d\'accord, la demande de divorce est présentée au tribunal par les deux conjoints ou l\'un d\'eux […]. Le tribunal tente de concilier les deux époux autant que possible et si la conciliation s\'avère impossible, il autorise que soit pris acte du divorce et qu\'il soit instrumenté.',
          'يمكن للزوجين أن يتفقا على مبدإ إنهاء العلاقة الزوجية دون شروط، أو بشروط لا تتنافى مع أحكام هذه المدونة، ولا تضر بمصالح الأطفال. عند وقوع هذا الاتفاق، يقدم الطرفان أو أحدهما طلب التطليق للمحكمة مرفقاً به للإذن بتوثيقه. تحاول المحكمة الإصلاح بينهما ما أمكن، فإذا تعذر الإصلاح، أذنت بالإشهاد على الطلاق وتوثيقه.',
        ),
      ),
    ],
    banner: GraveBanner(
      title: L3('هاد الموضوع مهم بزاف', 'هاد الموضوع مهم بزاف'),
      body: L3(
        'Garde des enfants, pension… pour ça, un avocat est indispensable.',
        'حضانة الأطفال، النفقة… لهذا، المحامي ضروري.',
        'الحضانة، النفقة… لهادشي، المحامي ضروري.',
      ),
    ),
  ),
  Scenario(
    id: 'kra',
    honest: true,
    chip: L3(
      'Je dois payer le loyer si je pars avant ?',
      'هل أدفع الكراء إن غادرت قبل الموعد؟',
      'واش خصني نخلص الكراء إلا خرجت قبل الوقت؟',
    ),
    reply: L3(
      'Je n\'ai pas trouvé de texte applicable à ton cas précis dans mon corpus — je préfère te le dire que d\'inventer. Le bail d\'habitation (loi 67-12) n\'est pas encore dans mes textes ; il arrive bientôt.',
      'لم أجد نصاً قانونياً واضحاً على حالتك بالضبط في النصوص المتوفرة لدي — أفضل أن أقول لك ذلك على أن أخترع. قانون الكراء السكني (67-12) ليس بعد ضمن نصوصي؛ قريباً.',
      'ما لقيتش نص قانوني واضح على هادشي فالنصوص اللي عندي — نفضّل نقولها ليك على ما نخترع. قانون الكراء السكني (67-12) مازال ما كاينش عندي؛ غادي يجي قريباً.',
    ),
  ),
];

/// Code juridique de la bibliothèque (hors-ligne).
class LegalCode {
  final String titleAr;
  final String titleFr;
  final String accent;
  final String date;
  final L3 dahir;
  const LegalCode({
    required this.titleAr,
    required this.titleFr,
    required this.accent,
    required this.date,
    required this.dahir,
  });
}

/// Codes officiels — porté de `data.jsx` (CHW_CODES), dates réelles du manifest.
const List<LegalCode> kCodes = [
  LegalCode(
    titleAr: 'مجموعة القانون الجنائي',
    titleFr: 'Code pénal',
    accent: 'penal',
    date: '28/04/2026',
    dahir: L3(
      'Dahir n° 1-59-413 portant approbation du texte du code pénal.',
      'ظهير رقم 1-59-413 بالمصادقة على نص القانون الجنائي.',
    ),
  ),
  LegalCode(
    titleAr: 'مدونة الأسرة',
    titleFr: 'Moudawana',
    accent: 'famille',
    date: '25/05/2026',
    dahir: L3(
      'Loi n° 70-03 portant Code de la famille (dahir n° 1-04-22).',
      'القانون رقم 70-03 بمثابة مدونة الأسرة.',
    ),
  ),
  LegalCode(
    titleAr: 'مدونة الشغل',
    titleFr: 'Code du travail',
    accent: 'travail',
    date: '10/11/2025',
    dahir: L3(
      'Loi n° 65-99 relative au Code du travail (dahir n° 1-03-194).',
      'القانون رقم 65-99 المتعلق بمدونة الشغل.',
    ),
  ),
  LegalCode(
    titleAr: 'قانون الالتزامات والعقود',
    titleFr: 'D.O.C.',
    accent: 'civil',
    date: '15/12/2025',
    dahir: L3(
      'Dahir des obligations et des contrats du 9 ramadan 1331 (1913).',
      'ظهير الالتزامات والعقود المؤرخ في 9 رمضان 1331 (1913).',
    ),
  ),
  LegalCode(
    titleAr: 'مدونة التجارة',
    titleFr: 'Code de commerce',
    accent: 'civil',
    date: '25/05/2026',
    dahir: L3(
      'Loi n° 15-95 formant Code de commerce.',
      'القانون رقم 15-95 المتعلق بمدونة التجارة.',
    ),
  ),
  LegalCode(
    titleAr: 'دستور المملكة 2011',
    titleFr: 'Constitution 2011',
    accent: 'civil',
    date: '25/12/2025',
    dahir: L3(
      'Dahir n° 1-11-91 du 27 chaabane 1432 (29 juillet 2011).',
      'ظهير رقم 1-11-91 بتنفيذ دستور 2011.',
    ),
  ),
];
