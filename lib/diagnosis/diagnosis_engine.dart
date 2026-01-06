import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:crypto/crypto.dart';

class DiagnosisResult {
  final String mainId;     // e.g. "sakura"
  final String mainLabel;  // e.g. "さくら団子"
  final String subId;      // e.g. "A-01" / "AB-02" / "ABC-EX"
  final String subLabel;   // e.g. "ふんわり"
  final String subPattern; // "A" / "AB" / "ABC"
  final String finalLabel; // e.g. "ふんわりさくら団子タイプ"

  DiagnosisResult({
    required this.mainId,
    required this.mainLabel,
    required this.subId,
    required this.subLabel,
    required this.subPattern,
    required this.finalLabel,
  });
}

class DiagnosisEngine {
  final Map<String, dynamic> cfg;
  DiagnosisEngine(this.cfg);

  static Future<DiagnosisEngine> loadFromAssets({
    String path = 'assets/config/diagnosis_config.json',
  }) async {
    final s = await rootBundle.loadString(path);
    final m = jsonDecode(s) as Map<String, dynamic>;
    return DiagnosisEngine(m);
  }

  DiagnosisResult run({
    required Map<int, String> answers,
    required String userSeed,
  }) {
    final sub = _calcSub(answers: answers, userSeed: userSeed);
    final main = _calcMain(answers: answers);

    final subLabel = sub['subLabel']!;
    final mainLabel = main['mainLabel']!;
    final finalLabel = '$subLabel${mainLabel}タイプ';

    return DiagnosisResult(
      mainId: main['mainId']!,
      mainLabel: mainLabel,
      subId: sub['subId']!,
      subLabel: subLabel,
      subPattern: sub['subPattern']!,
      finalLabel: finalLabel,
    );
  }

  // -------------------------
  // MAIN (Q11-20)
  // -------------------------
  Map<String, String> _calcMain({required Map<int, String> answers}) {
    final mainTypes =
        (cfg['types']['main'] as List).cast<Map<String, dynamic>>();

    final scores = <String, int>{};
    for (final t in mainTypes) {
      scores[t['id'] as String] = 0;
    }

    final mainCfg = cfg['scoring']['main'] as Map<String, dynamic>;
    final questions =
        (mainCfg['questions'] as List).cast<Map<String, dynamic>>();

    for (final q in questions) {
      final qid = q['id'] as int;
      final pick = answers[qid];
      if (pick == null) continue;

      final choices = q['choices'] as Map<String, dynamic>;
      final choice = choices[pick] as Map<String, dynamic>?;
      if (choice == null) continue;

      final add = (choice['add'] as Map<String, dynamic>);
      add.forEach((k, v) {
        scores[k] = (scores[k] ?? 0) + (v as int);
      });
    }

    final priority = (mainCfg['tie_break_priority'] as List).cast<String>();

    final sorted = scores.entries.toList()
      ..sort((a, b) {
        final s = b.value.compareTo(a.value);
        if (s != 0) return s;
        return priority.indexOf(a.key).compareTo(priority.indexOf(b.key));
      });

    final mainId = sorted.first.key;
    final mainLabel = mainTypes
        .firstWhere((t) => t['id'] == mainId)['label'] as String;

    return {'mainId': mainId, 'mainLabel': mainLabel};
  }

  // -------------------------
  // SUB (Q1-10)
  // -------------------------
  Map<String, String> _calcSub({
    required Map<int, String> answers,
    required String userSeed,
  }) {
    int a = 0, b = 0, c = 0, d = 0;
    for (int qid = 1; qid <= 10; qid++) {
      final pick = answers[qid];
      if (pick == 'A') a++;
      if (pick == 'B') b++;
      if (pick == 'C') c++;
      if (pick == 'D') d++;
    }

    final pairs = <Map<String, dynamic>>[
      {'k': 'A', 's': a},
      {'k': 'B', 's': b},
      {'k': 'C', 's': c},
      {'k': 'D', 's': d},
    ]..sort((x, y) => (y['s'] as int).compareTo(x['s'] as int));

    final key1 = pairs[0]['k'] as String;
    final s1 = pairs[0]['s'] as int;
    final key2 = pairs[1]['k'] as String;
    final s2 = pairs[1]['s'] as int;
    final key3 = pairs[2]['k'] as String;
    final s3 = pairs[2]['s'] as int;

    final subRules =
        cfg['scoring']['sub']['pattern_rules'] as Map<String, dynamic>;

    // 1) tri_ex
    final tri = subRules['tri_ex'] as Map<String, dynamic>;
    if (tri['enabled'] == true) {
      final top3Min = tri['top3_min'] as int;
      final top3Max = tri['top3_max'] as int;
      final s1MinusS3Max = tri['s1_minus_s3_max'] as int;
      final top3SumMin = tri['top3_sum_min'] as int;

      final top3Ok = (s1 >= top3Min && s1 <= top3Max) &&
          (s2 >= top3Min && s2 <= top3Max) &&
          (s3 >= top3Min && s3 <= top3Max);
      final diffOk = (s1 - s3) <= s1MinusS3Max;
      final sumOk = (s1 + s2 + s3) >= top3SumMin;

      if (top3Ok && diffOk && sumOk) {
        final triKey = _sortedKey([key1, key2, key3]); // "ABC"/"ABD"/...
        final triMap =
            (cfg['types']['sub']['tri_ex'] as Map<String, dynamic>)[triKey]
                as Map<String, dynamic>?;
        if (triMap != null) {
          return {
            'subPattern': triKey,
            'subId': triMap['id'] as String,
            'subLabel': triMap['label'] as String,
          };
        }
      }
    }

    // 2) single
    bool isSingle = false;
    final single = subRules['single'] as Map<String, dynamic>;
    if (single['enabled'] == true) {
      final rules = (single['rule_any_of'] as List).cast<Map<String, dynamic>>();
      for (final r in rules) {
        final s1Min = r['s1_min'] as int;
        final s1MinusS2Min = r['s1_minus_s2_min'] as int;
        if (s1 >= s1Min && (s1 - s2) >= s1MinusS2Min) {
          isSingle = true;
          break;
        }
      }
    }
    if (isSingle) {
      return _pickSubLabelForPattern(
        pattern: key1,
        userSeed: userSeed,
        mode: 'single',
      );
    }

    // 3) pair
    final pair = subRules['pair'] as Map<String, dynamic>;
    if (pair['enabled'] == true) {
      final top2Min = pair['top2_min'] as int;
      final s1MinusS2Max = pair['s1_minus_s2_max'] as int;
      if (s1 >= top2Min && s2 >= top2Min && (s1 - s2) <= s1MinusS2Max) {
        final p = _sortedKey([key1, key2]);
        return _pickSubLabelForPattern(
          pattern: p,
          userSeed: userSeed,
          mode: 'pair',
        );
      }
    }

    final fallbackPair = _sortedKey([key1, key2]);
    return _pickSubLabelForPattern(
      pattern: fallbackPair,
      userSeed: userSeed,
      mode: 'pair',
    );
  }

  Map<String, String> _pickSubLabelForPattern({
    required String pattern,
    required String userSeed,
    required String mode, // "single" or "pair"
  }) {
    final rarity = cfg['rarity'] as Map<String, dynamic>;
    final overrides = rarity['rarity_overrides'] as Map<String, dynamic>;

    final r = _stableRand01('$userSeed|sub|$pattern|${cfg['version']}');

    if (mode == 'single') {
      final singleOverrides = overrides['single'] as Map<String, dynamic>;
      final o = singleOverrides[pattern] as Map<String, dynamic>?;
      if (o != null) {
        final baseP = (o['base'] as num).toDouble();
        final single =
            (cfg['types']['sub']['single'] as Map<String, dynamic>)[pattern]
                as Map<String, dynamic>;
        final base = single['base'] as Map<String, dynamic>;
        final rare = (single['rare'] as List).cast<Map<String, dynamic>>();

        if (r < baseP) {
          return {'subPattern': pattern, 'subId': base['id'], 'subLabel': base['label']};
        } else {
          final rr = (r - baseP) / (1.0 - baseP);
          final picked = _pickWeighted((o['rare'] as List).cast<Map<String, dynamic>>(), rr);
          final match = rare.firstWhere((x) => x['id'] == picked['id']);
          return {'subPattern': pattern, 'subId': match['id'], 'subLabel': match['label']};
        }
      }

      final baseProb = (rarity['sub']['single_base_prob'] as num).toDouble();
      final single =
          (cfg['types']['sub']['single'] as Map<String, dynamic>)[pattern]
              as Map<String, dynamic>;
      final base = single['base'] as Map<String, dynamic>;
      final rare = (single['rare'] as List).cast<Map<String, dynamic>>();

      if (r < baseProb) {
        return {'subPattern': pattern, 'subId': base['id'], 'subLabel': base['label']};
      } else {
        final idx = ((r - baseProb) / (1.0 - baseProb) * rare.length)
            .floor()
            .clamp(0, rare.length - 1);
        return {'subPattern': pattern, 'subId': rare[idx]['id'], 'subLabel': rare[idx]['label']};
      }
    }

    // pair
    final pairOverrides = overrides['pairs'] as Map<String, dynamic>;
    final o = pairOverrides[pattern] as Map<String, dynamic>?;
    final pair =
        (cfg['types']['sub']['pairs'] as Map<String, dynamic>)[pattern]
            as Map<String, dynamic>;
    final base = pair['base'] as Map<String, dynamic>;
    final rare = (pair['rare'] as List).cast<Map<String, dynamic>>();

    if (o != null) {
      final baseP = (o['base'] as num).toDouble();
      if (r < baseP) {
        return {'subPattern': pattern, 'subId': base['id'], 'subLabel': base['label']};
      } else {
        final rr = (r - baseP) / (1.0 - baseP);
        final picked = _pickWeighted((o['rare'] as List).cast<Map<String, dynamic>>(), rr);
        final match = rare.firstWhere((x) => x['id'] == picked['id']);
        return {'subPattern': pattern, 'subId': match['id'], 'subLabel': match['label']};
      }
    }

    final baseProb = (rarity['sub']['pair_base_prob'] as num).toDouble();
    if (r < baseProb) {
      return {'subPattern': pattern, 'subId': base['id'], 'subLabel': base['label']};
    } else {
      final idx = ((r - baseProb) / (1.0 - baseProb) * rare.length)
          .floor()
          .clamp(0, rare.length - 1);
      return {'subPattern': pattern, 'subId': rare[idx]['id'], 'subLabel': rare[idx]['label']};
    }
  }

  String _sortedKey(List<String> keys) {
    final k = [...keys]..sort();
    return k.join();
  }

  double _stableRand01(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes).bytes;
    int v = 0;
    for (int i = 0; i < 8; i++) {
      v = (v << 8) | digest[i];
    }
    final max = pow(2, 64).toDouble();
    return (v.toDouble() % max) / max;
  }

  Map<String, dynamic> _pickWeighted(
      List<Map<String, dynamic>> items, double rr01) {
    double acc = 0;
    for (final it in items) {
      acc += (it['p'] as num).toDouble();
      if (rr01 <= acc) return it;
    }
    return items.last;
  }
}
