import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class RenderSection {
  final String key;
  final String title;
  final List<String> lines;
  RenderSection({required this.key, required this.title, required this.lines});
}

class RenderedDiagnosis {
  final String title;
  final String mainId;
  final String subId;
  final List<RenderSection> sections;
  final List<String> tags;

  RenderedDiagnosis({
    required this.title,
    required this.mainId,
    required this.subId,
    required this.sections,
    required this.tags,
  });
}

class DiagnosisRenderer {
  final Map<String, dynamic> _mainTypes;
  final Map<String, dynamic> _subTypes;
  final Map<String, dynamic> _templates;

  DiagnosisRenderer._(this._mainTypes, this._subTypes, this._templates);

  static Future<DiagnosisRenderer> loadFromAssets() async {
    final mainJson = jsonDecode(
      await rootBundle.loadString('assets/config/personality_main.json'),
    ) as Map<String, dynamic>;

    final subJson = jsonDecode(
      await rootBundle.loadString('assets/config/personality_sub.json'),
    ) as Map<String, dynamic>;

    final tplJson = jsonDecode(
      await rootBundle.loadString('assets/config/personality_template.json'),
    ) as Map<String, dynamic>;

    return DiagnosisRenderer._(
      (mainJson['main_types'] as Map).cast<String, dynamic>(),
      (subJson['sub_types'] as Map).cast<String, dynamic>(),
      (tplJson['templates'] as Map).cast<String, dynamic>(),
    );
  }

  RenderedDiagnosis render({
    required String mainId,
    required String subId,
  }) {
    final main = _mainTypes[mainId];
    final sub = _subTypes[subId];

    if (main == null) {
      throw StateError('personality_main.json: unknown mainId=$mainId');
    }
    if (sub == null) {
      throw StateError('personality_sub.json: unknown subId=$subId');
    }

    String replaceVars(String s) {
      return s
          .replaceAll('{main.label}', main['label'].toString())
          .replaceAll('{main.core}', main['core'].toString())
          .replaceAll('{main.pitfall}', (main['pitfall'] ?? '').toString())
          .replaceAll('{sub.prefix}', sub['prefix'].toString())
          .replaceAll('{sub.nuance}', sub['nuance'].toString());
    }

    // List系は「・」付きで1行ずつにする
    List<String> listToBullets(dynamic v) {
      if (v == null) return [];
      if (v is List) {
        return v.map((e) => '・${e.toString()}').toList();
      }
      // 文字列が来たらそのまま
      return [v.toString()];
    }

    final title = replaceVars(_templates['title'].toString());

    final rawSections = (_templates['sections'] as List).cast<Map>();
    final sections = <RenderSection>[];

    for (final sec in rawSections) {
      final key = sec['key'].toString();
      final secTitle = sec['title'].toString();
      final body = (sec['body'] as List).map((e) => e.toString()).toList();

      final lines = <String>[];
      for (final b in body) {
        if (b == '{main.love_pattern}') {
          lines.addAll(listToBullets(main['love_pattern']));
          continue;
        }
        if (b == '{main.strength}') {
          lines.addAll(listToBullets(main['strength']));
          continue;
        }
        if (b == '{main.weakness}') {
          lines.addAll(listToBullets(main['weakness']));
          continue;
        }
        if (b == '{main.best_match}') {
          lines.addAll(listToBullets(main['best_match']));
          continue;
        }
        if (b == '{main.keywords}') {
          lines.addAll(listToBullets(main['keywords']));
          continue;
        }
        if (b == '{sub.tone_tags}') {
          lines.addAll(listToBullets(sub['tone_tags']));
          continue;
        }

        final out = replaceVars(b).trim();
        if (out.isNotEmpty) lines.add(out);
      }

      // 空セクションは出さない
      final cleaned = lines.where((x) => x.trim().isNotEmpty).toList();
      if (cleaned.isNotEmpty) {
        sections.add(RenderSection(key: key, title: secTitle, lines: cleaned));
      }
    }

    final tags = <String>[
      ...((main['keywords'] as List?)?.map((e) => e.toString()) ?? const []),
      ...((sub['tone_tags'] as List?)?.map((e) => e.toString()) ?? const []),
    ];

    return RenderedDiagnosis(
      title: title,
      mainId: mainId,
      subId: subId,
      sections: sections,
      tags: tags.toSet().toList(),
    );
  }
}
