import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'lang.dart';

/// Noms affichables des 13 codes (la clé interne `code` n'est pas présentable).
const Map<String, List<String>> kCodeLabels = {
  // code_key: [FR, AR]
  'accidents_travail': ['Accidents du travail', 'حوادث الشغل'],
  'code_commerce': ['Code de commerce', 'مدونة التجارة'],
  'code_penal': ['Code pénal', 'القانون الجنائي'],
  'code_route': ['Code de la route', 'مدونة السير'],
  'code_travail': ['Code du travail', 'مدونة الشغل'],
  'constitution_2011': ['Constitution 2011', 'دستور 2011'],
  'doc': ['D.O.C.', 'قانون الالتزامات والعقود'],
  'droits_reels': ['Droits réels', 'مدونة الحقوق العينية'],
  'immatriculation_fonciere': ['Immatriculation foncière', 'التحفيظ العقاري'],
  'moudawana': ['Moudawana', 'مدونة الأسرة'],
  'organisation_judiciaire': ['Organisation judiciaire', 'التنظيم القضائي'],
  'procedure_penale': ['Procédure pénale', 'المسطرة الجنائية'],
  'travailleurs_domestiques': ['Travailleurs domestiques', 'العمال المنزليين'],
};

String codeLabel(String code, Lang lang) {
  final pair = kCodeLabels[code];
  if (pair == null) return code;
  return lang == Lang.fr ? pair[0] : pair[1];
}

/// Accent par matière de chaque code (couleurs Bibliothèque).
const Map<String, String> _kCodeAccent = {
  'accidents_travail': 'travail',
  'code_commerce': 'civil',
  'code_penal': 'penal',
  'code_route': 'civil',
  'code_travail': 'travail',
  'constitution_2011': 'civil',
  'doc': 'civil',
  'droits_reels': 'civil',
  'immatriculation_fonciere': 'civil',
  'moudawana': 'famille',
  'organisation_judiciaire': 'civil',
  'procedure_penale': 'penal',
  'travailleurs_domestiques': 'travail',
};

String kCodeAccent(String code) => _kCodeAccent[code] ?? 'civil';

/// Source citée renvoyée par l'API (carte cliquable).
class ApiSource {
  final String code;
  final String articleNum;
  final String marqueur;
  final String version;
  final String langue;
  final String citation;
  final String excerpt;

  ApiSource.fromJson(Map<String, dynamic> j)
      : code = j['code'] ?? '',
        articleNum = '${j['article_num'] ?? ''}',
        marqueur = j['marqueur'] ?? '',
        version = j['version'] ?? '',
        langue = j['langue'] ?? '',
        citation = j['citation'] ?? '',
        excerpt = j['excerpt'] ?? '';
}

/// Réponse de /ask : texte + sources + drapeaux de sécurité.
class ApiAnswer {
  final String answer;
  final List<ApiSource> sources;
  final bool refused;
  final bool grave;
  final String? lawyerBanner;
  final String disclaimer;
  final String langue;

  ApiAnswer.fromJson(Map<String, dynamic> j)
      : answer = j['answer'] ?? '',
        sources = ((j['sources'] ?? []) as List)
            .map((s) => ApiSource.fromJson(s as Map<String, dynamic>))
            .toList(),
        refused = j['refused'] ?? false,
        grave = j['grave'] ?? false,
        lawyerBanner = j['lawyer_banner'],
        disclaimer = j['disclaimer'] ?? '',
        langue = j['langue'] ?? 'fr';
}

/// Un code de la bibliothèque (/codes).
class ApiCode {
  final String code;
  final String titleFr;
  final String titleAr;
  final String accent;
  final String version;
  final int articles;

  ApiCode.fromJson(Map<String, dynamic> j)
      : code = j['code'] ?? '',
        titleFr = j['titleFr'] ?? '',
        titleAr = j['titleAr'] ?? '',
        accent = j['accent'] ?? 'civil',
        version = j['version'] ?? '',
        articles = j['articles'] ?? 0;
}

/// Un article dans la liste de parcours d'un code.
class ApiArticleItem {
  final String articleNum;
  final String marqueur;
  final String excerpt;
  final String version;

  ApiArticleItem.fromJson(Map<String, dynamic> j)
      : articleNum = '${j['article_num'] ?? ''}',
        marqueur = j['marqueur'] ?? '',
        excerpt = j['excerpt'] ?? '',
        version = j['version'] ?? '';
}

/// Une page de parcours d'articles (/codes/{code}/articles).
class ApiArticlePage {
  final int total;
  final int offset;
  final int limit;
  final List<ApiArticleItem> articles;

  ApiArticlePage.fromJson(Map<String, dynamic> j)
      : total = j['total'] ?? 0,
        offset = j['offset'] ?? 0,
        limit = j['limit'] ?? 0,
        articles = ((j['articles'] ?? []) as List)
            .map((a) => ApiArticleItem.fromJson(a as Map<String, dynamic>))
            .toList();
}

/// Texte intégral d'un article (/sources/{code}/{article}).
class ApiArticle {
  final String code;
  final String articleNum;
  final String marqueur;
  final Map<String, dynamic> hierarchie;
  final String texte;
  final String version;
  final String langue;

  ApiArticle.fromJson(Map<String, dynamic> j)
      : code = j['code'] ?? '',
        articleNum = '${j['article_num'] ?? ''}',
        marqueur = j['marqueur'] ?? '',
        hierarchie = (j['hierarchie'] ?? {}) as Map<String, dynamic>,
        texte = j['texte'] ?? '',
        version = j['version'] ?? '',
        langue = j['langue'] ?? '';
}

/// Erreur réseau/serveur — l'UI affiche la micro-copy « connexion perdue ».
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
}

/// Client de l'API Chawerni.
class ApiService {
  static const _timeout = Duration(seconds: 30);

  Future<ApiAnswer> ask(String question, Lang lang) async {
    final uri = Uri.parse('${AppConfig.apiBase}/ask');
    try {
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'question': question,
              'langue': lang == Lang.fr ? 'fr' : 'ar',
            }),
          )
          .timeout(_timeout);
      if (resp.statusCode != 200) {
        throw ApiException('HTTP ${resp.statusCode}');
      }
      return ApiAnswer.fromJson(
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('$e');
    }
  }

  Future<List<ApiCode>> codes() async {
    final uri = Uri.parse('${AppConfig.apiBase}/codes');
    try {
      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) throw ApiException('HTTP ${resp.statusCode}');
      final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
      return list.map((e) => ApiCode.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('$e');
    }
  }

  Future<ApiArticlePage> codeArticles(String code, String langue,
      {int offset = 0, int limit = 30}) async {
    final uri = Uri.parse(
        '${AppConfig.apiBase}/codes/$code/articles?langue=$langue&offset=$offset&limit=$limit');
    try {
      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) throw ApiException('HTTP ${resp.statusCode}');
      return ApiArticlePage.fromJson(
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('$e');
    }
  }

  Future<List<ApiSource>> search(String q, {String? code, String? langue}) async {
    final params = {
      'q': q,
      if (code != null) 'code': code,
      if (langue != null) 'langue': langue,
    };
    final uri = Uri.parse('${AppConfig.apiBase}/search')
        .replace(queryParameters: params);
    try {
      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) throw ApiException('HTTP ${resp.statusCode}');
      final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
      return list.map((e) => ApiSource.fromJson(e as Map<String, dynamic>)).toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('$e');
    }
  }

  Future<ApiArticle> source(String code, String article, String langue) async {
    final uri = Uri.parse(
        '${AppConfig.apiBase}/sources/$code/$article?langue=$langue');
    try {
      final resp = await http.get(uri).timeout(_timeout);
      if (resp.statusCode != 200) {
        throw ApiException('HTTP ${resp.statusCode}');
      }
      return ApiArticle.fromJson(
          jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('$e');
    }
  }
}
