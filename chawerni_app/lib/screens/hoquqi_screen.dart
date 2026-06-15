import 'package:flutter/material.dart';

import '../data/lang.dart';
import '../state/app_scope.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/chw_icon.dart';
import '../widgets/zellij_frieze.dart';

/// Une situation pratique : titre + question envoyée au Chat (RAG).
class _Situation {
  final String titleFr;
  final String titleAr;
  final String accent; // matière → couleur
  final String qFr;
  final String qAr;
  final String qDa;
  const _Situation(this.titleFr, this.titleAr, this.accent, this.qFr, this.qAr, this.qDa);

  String title(Lang l) => l == Lang.fr ? titleFr : titleAr;
  String question(Lang l) => switch (l) {
        Lang.fr => qFr,
        Lang.ar => qAr,
        Lang.da => qDa,
      };
}

const List<_Situation> _situations = [
  _Situation('Licenciement', 'الفصل من العمل', 'travail',
      'Quels sont mes droits si je suis licencié ?',
      'ما هي حقوقي عند الفصل من العمل؟',
      'شنو حقوقي إلا تفصلت من الخدمة؟'),
  _Situation('Indemnité & salaire', 'الأجر والتعويض', 'travail',
      'Comment se calcule l\'indemnité de licenciement ?',
      'كيف يُحسب التعويض عن الفصل؟',
      'كيفاش كيتحسب تعويض الفصل؟'),
  _Situation('Congés', 'العطل', 'travail',
      'Combien de jours de congé annuel ai-je droit ?',
      'كم يوماً من العطلة السنوية لي الحق فيها؟',
      'شحال من نهار ديال العطلة عندي فالعام؟'),
  _Situation('Divorce', 'الطلاق', 'famille',
      'Le divorce par consentement mutuel, comment ça marche ?',
      'كيف يتم الطلاق بالاتفاق؟',
      'الطلاق بالاتفاق كيفاش كيتدار؟'),
  _Situation('Garde des enfants', 'حضانة الأطفال', 'famille',
      'À qui revient la garde des enfants après un divorce ?',
      'لمن تُسند حضانة الأطفال بعد الطلاق؟',
      'منشكون كتمشي ليه الحضانة ديال الدراري؟'),
  _Situation('Mariage', 'الزواج', 'famille',
      'À quel âge peut-on se marier au Maroc ?',
      'ما هو سن الزواج في المغرب؟',
      'فأي سن يقدر يتزوج الواحد فالمغرب؟'),
  _Situation('Loyer & bail', 'الكراء', 'civil',
      'Je dois payer le loyer si je pars avant la fin du bail ?',
      'هل أدفع الكراء إن غادرت قبل نهاية العقد؟',
      'واش خصني نخلص الكراء إلا خرجت قبل الوقت؟'),
  _Situation('Vol & agression', 'السرقة والاعتداء', 'penal',
      'Quelle est la peine pour un vol ?',
      'ما عقوبة السرقة في القانون المغربي؟',
      'شحال كياخد اللي سرق ديال عقوبة؟'),
];

/// Hoquqi (حقوقي / « mes droits ») — fiches pratiques par situation.
/// Au tap, la question part dans le Chat et est traitée par le RAG.
class HoquqiScreen extends StatelessWidget {
  const HoquqiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final lang = app.lang;
    final isFr = lang == Lang.fr;

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête à frise zellige (hauteur = contenu).
          Stack(
            children: [
              const ZellijFrieze.dark(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Row(
                        children: [
                          Text(isFr ? 'Hoquqi' : 'حقوقي',
                              style: Typo.style(
                                  size: Typo.lg, weight: Typo.bold, color: C.nila)),
                          const SizedBox(width: 8),
                          const ZellijDiamond(size: 12, color: C.zaafran),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isFr
                            ? 'Tes droits par situation — on cherche dans la loi pour toi.'
                            : 'حقوقك حسب الحالة — كنقلّبو على النص القانوني عوضك.',
                        style: Typo.style(size: Typo.sm, color: C.midad60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                // Assez haut pour un titre sur 2 lignes même sur écran étroit.
                childAspectRatio: 1.15,
              ),
              itemCount: _situations.length,
              itemBuilder: (context, i) {
                final s = _situations[i];
                return _SituationCard(
                  situation: s,
                  lang: lang,
                  onTap: () => app.askInChat(s.question(lang)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SituationCard extends StatelessWidget {
  final _Situation situation;
  final Lang lang;
  final VoidCallback onTap;
  const _SituationCard(
      {required this.situation, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = C.matiere(situation.accent);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: C.surfaceCard,
          borderRadius: BorderRadius.circular(S.radiusCard),
          border: Border.all(color: C.borderCard),
          boxShadow: S.shadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Center(
                child: Transform.rotate(
                  angle: 0.7853981633974483,
                  child: Container(width: 11, height: 11, color: color),
                ),
              ),
            ),
            const Spacer(),
            Text(
              situation.title(lang),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Typo.style(size: Typo.base, weight: Typo.citation, color: C.midad),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  lang == Lang.fr ? 'Demander' : 'اسأل',
                  style: Typo.style(size: Typo.xs, weight: Typo.medium, color: color),
                ),
                const SizedBox(width: 4),
                ChwIcon('chevron', size: 13, color: color, mirrorInRtl: true),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
