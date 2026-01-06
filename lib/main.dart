import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'diagnosis/diagnosis_engine.dart';

/// RouteObserver（画面復帰時にHomeを更新するため）
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

/// =======================
/// SharedPreferences Keys
/// =======================
const _kInstallId = 'install_id';

const _kDiagDone = 'diag_done';
const _kMainId = 'diag_main_id';
const _kMainLabel = 'diag_main_label';
const _kSubId = 'diag_sub_id';
const _kSubLabel = 'diag_sub_label';
const _kSubPattern = 'diag_sub_pattern';
const _kFinalLabel = 'diag_final_label';

const _kFortuneDate = 'fortune_date';
const _kFortunePayload = 'fortune_payload';

/// =======================
/// 共通：背景 + 左上name固定
/// =======================
class AppScaffoldBg extends StatelessWidget {
  final Widget child;
  final bool showName;
  final String? appBarTitle;
  final List<Widget>? appBarActions;
  final VoidCallback? onBack;

  const AppScaffoldBg({
    super.key,
    required this.child,
    this.showName = true,
    this.appBarTitle,
    this.appBarActions,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: appBarTitle == null
          ? null
          : AppBar(
              title: Text(appBarTitle!),
              leading: onBack == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: onBack,
                    ),
              actions: appBarActions,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ✅ 背景（部屋）
          Positioned.fill(
            child: Image.asset(
              'assets/ui/back.png',
              fit: BoxFit.cover,
            ),
          ),

          // ✅ うっすら白いフィルター（読みやすくする）
          Positioned.fill(
            child: Container(color: Colors.white.withOpacity(0.70)),
          ),

          // ✅ 画面の中身
          SafeArea(child: child),

          // ✅ 左上にname固定表示
          if (showName)
            Positioned(
              left: 12,
              top: 8,
              child: Image.asset(
                'assets/ui/name.png',
                height: 120, // 好きに調整
              ),
            ),
        ],
      ),
    );
  }
}


// 将来：課金で true にする（今はロックUIだけ）
const _kPaidRetake = 'paid_retake';

class DiagnosisTextRepo {
  final Map<String, dynamic> mainJson;
  final Map<String, dynamic> subJson;

  DiagnosisTextRepo({required this.mainJson, required this.subJson});

  Map<String, dynamic> get mainTypes =>
      (mainJson['main_types'] as Map<String, dynamic>);
  Map<String, dynamic> get subTypes =>
      (subJson['sub_types'] as Map<String, dynamic>);

  static Future<DiagnosisTextRepo> loadFromAssets({
    String mainPath = 'assets/config/personality_main.json',
    String subPath = 'assets/config/personality_sub.json',
  }) async {
    final mainStr = await rootBundle.loadString(mainPath);
    final subStr = await rootBundle.loadString(subPath);
    return DiagnosisTextRepo(
      mainJson: jsonDecode(mainStr) as Map<String, dynamic>,
      subJson: jsonDecode(subStr) as Map<String, dynamic>,
    );
  }
}

/// グローバルキャッシュ（起動時に必ず埋める）
DiagnosisTextRepo? _diagRepo;

/// =======================
/// Theme helper colors
/// =======================
const _kBgPink = Color(0xFFFFF6F7);
const _kCardPink = Color(0xFFF8F1F2);
const _kBorderPink = Color(0xFFE6D6D8);

void main() {
  runApp(const DangoFortuneApp());
}

class DangoFortuneApp extends StatelessWidget {
  const DangoFortuneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '『あなだん』',
      navigatorObservers: [routeObserver], // ★追加
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
        useMaterial3: true,
      ),
      home: const BootScreen(),
    );
  }
}

/// =======================
/// Questions JSON Models
/// =======================
class QuizQuestion {
  final int id;
  final String text;
  final List<QuizChoice> choices;

  QuizQuestion({required this.id, required this.text, required this.choices});

  factory QuizQuestion.fromJson(Map<String, dynamic> j) {
    final id = j['id'] as int;
    final text = j['text'] as String;

    final rawChoices = (j['choices'] as Map<String, dynamic>);
    const keys = ['A', 'B', 'C', 'D'];
    for (final k in keys) {
      if (!rawChoices.containsKey(k)) {
        throw FormatException('questions.json: id=$id choices missing key=$k');
      }
    }

    final choices = keys
        .map((k) => QuizChoice(key: k, label: rawChoices[k] as String))
        .toList();

    return QuizQuestion(id: id, text: text, choices: choices);
  }
}

class QuizChoice {
  final String key; // "A" "B" "C" "D"
  final String label;

  QuizChoice({required this.key, required this.label});
}

Future<List<QuizQuestion>> loadQuestionsFromAssets({
  String path = 'assets/config/questions.json',
}) async {
  final s = await rootBundle.loadString(path);
  final decoded = jsonDecode(s);

  final List<dynamic> list;
  if (decoded is List) {
    list = decoded;
  } else if (decoded is Map<String, dynamic> && decoded['questions'] is List) {
    list = decoded['questions'] as List<dynamic>;
  } else {
    throw FormatException(
      'questions.json must be a List or { "questions": [...] }',
    );
  }

  final qs =
      list.map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  const requiredIds = [
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
  ];
  final gotIds = qs.map((q) => q.id).toSet();
  for (final id in requiredIds) {
    if (!gotIds.contains(id)) {
      throw FormatException('questions.json: missing question id=$id');
    }
  }

  final filtered = qs.where((q) => requiredIds.contains(q.id)).toList()
    ..sort((a, b) => a.id.compareTo(b.id));

  if (filtered.length != 20) {
    throw FormatException(
      'questions.json: expected 20 questions, got ${filtered.length}',
    );
  }
  return filtered;
}

/// =======================
/// Stored Diagnosis (for persistence)
/// =======================
class StoredDiagnosis {
  final String finalLabel;
  final String mainId;
  final String mainLabel;
  final String subId;
  final String subLabel;
  final String subPattern;

  const StoredDiagnosis({
    required this.finalLabel,
    required this.mainId,
    required this.mainLabel,
    required this.subId,
    required this.subLabel,
    required this.subPattern,
  });

  /// ★診断済み判定は「保存データがちゃんと揃ってるか」で決める（ここが真）
  static Future<StoredDiagnosis?> load() async {
    final prefs = await SharedPreferences.getInstance();

    final finalLabel = prefs.getString(_kFinalLabel);
    final mainId = prefs.getString(_kMainId);
    final mainLabel = prefs.getString(_kMainLabel);
    final subId = prefs.getString(_kSubId);
    final subLabel = prefs.getString(_kSubLabel);
    final subPattern = prefs.getString(_kSubPattern);

    if (finalLabel == null ||
        mainId == null ||
        mainLabel == null ||
        subId == null ||
        subLabel == null ||
        subPattern == null) {
      // 壊れてる/未保存 → 診断済み扱いにしない
      return null;
    }

    return StoredDiagnosis(
      finalLabel: finalLabel,
      mainId: mainId,
      mainLabel: mainLabel,
      subId: subId,
      subLabel: subLabel,
      subPattern: subPattern,
    );
  }

  static Future<void> saveFromResult(DiagnosisResult r) async {
    final prefs = await SharedPreferences.getInstance();

    // ★互換用：従来の bool も立てる（ただし判定は load() を正とする）
    await prefs.setBool(_kDiagDone, true);

    await prefs.setString(_kFinalLabel, r.finalLabel);
    await prefs.setString(_kMainId, r.mainId);
    await prefs.setString(_kMainLabel, r.mainLabel);
    await prefs.setString(_kSubId, r.subId);
    await prefs.setString(_kSubLabel, r.subLabel);
    await prefs.setString(_kSubPattern, r.subPattern);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDiagDone);
    await prefs.remove(_kFinalLabel);
    await prefs.remove(_kMainId);
    await prefs.remove(_kMainLabel);
    await prefs.remove(_kSubId);
    await prefs.remove(_kSubLabel);
    await prefs.remove(_kSubPattern);

    // fortuneは「診断消したら再生成される」方が自然なので消してOK
    await prefs.remove(_kFortuneDate);
    await prefs.remove(_kFortunePayload);
  }
}

/// =======================
/// Boot Screen
/// =======================
class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  DiagnosisEngine? engine;
  List<QuizQuestion>? questions;
  String? installId;
  String? err;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final e = await DiagnosisEngine.loadFromAssets();
      // ★追加：診断テキストJSONをロード
      final repo = await DiagnosisTextRepo.loadFromAssets();

      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_kInstallId);
      id ??= _makeInstallId();
      await prefs.setString(_kInstallId, id);

      final stored = await StoredDiagnosis.load();
      if (stored != null) {
        await prefs.setBool(_kDiagDone, true);
      }

      final qs = await loadQuestionsFromAssets();

      setState(() {
        engine = e;
        installId = id;
        questions = qs;

        // ★追加：グローバルキャッシュに保持
        _diagRepo = repo;
      });
    } catch (e) {
      setState(() => err = e.toString());
    }
  }

  String _makeInstallId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  Widget build(BuildContext context) {
    if (err != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('起動エラー')),
        body: Padding(padding: const EdgeInsets.all(16), child: Text(err!)),
      );
    }
    if (engine == null || installId == null || questions == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return HomeScreen(
      engine: engine!,
      installId: installId!,
      questions: questions!,
    );
  }
}

/// =======================
/// Home
/// - 診断済みなら「今日の占いへ」
/// - 未診断なら「診断をはじめる」
/// - 診断済みなら「診断結果を見る🍡」も出す
/// =======================
class HomeScreen extends StatefulWidget {
  final DiagnosisEngine engine;
  final String installId;
  final List<QuizQuestion> questions;

  const HomeScreen({
    super.key,
    required this.engine,
    required this.installId,
    required this.questions,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  late Future<bool> _diagnosedFuture;

  @override
  void initState() {
    super.initState();
    _diagnosedFuture = _isDiagnosed();
  }

  Future<bool> _isDiagnosed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kDiagDone) ?? false;
  }

  void _refreshDiagnosed() {
    setState(() {
      _diagnosedFuture = _isDiagnosed();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // ★別画面から戻ってきた時に呼ばれる
  @override
  void didPopNext() {
    _refreshDiagnosed();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldBg(
      showName: true,
      child: FutureBuilder<bool>(
        future: _diagnosedFuture,
        builder: (context, dSnap) {
          if (!dSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final diagnosed = dSnap.data ?? false;

          return FutureBuilder<StoredDiagnosis?>(
            future: diagnosed ? StoredDiagnosis.load() : Future.value(null),
            builder: (context, sSnap) {
              final stored = sSnap.data;

              final mainId = stored?.mainId ?? 'dango';
              final dangoAsset = _dangoAssetForMainId(mainId) ?? 'assets/dango/dango.png';

              // ✅ 診断前だけだんごを大きくする（診断後は現状維持）
              final diagnosedByStored = stored != null;
              final dangoWidth  = diagnosedByStored ? 260.0 : 340.0;
              final dangoBottom = diagnosedByStored ? 50.0  : 60.0;   // 必要なら微調整
              final stackHeight = diagnosedByStored ? 280.0 : 340.0;  // 大きくした分、切れ防止


              final titleText = diagnosed && stored != null
                  ? 'ちょっぴり硬めの\n${stored.finalLabel}'
                  : 'まだ診断してないよ\nまずは性格診断をやろう';

              return SafeArea(
                child: Stack(
                  children: [

                    // ② 中央：診断結果カード + ボタン
                    Align(
                      alignment: Alignment.center,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 120, 18, 210),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 斜めの「あなたは」
                            Transform.rotate(
                              angle: -0.20,
                              child: const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'あなたは',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    shadows: [
                                      Shadow(blurRadius: 6, offset: Offset(0, 2), color: Color(0x66000000)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.72),
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    titleText,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black87,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const SizedBox(height: 10),

                                  // 診断結果を見る
                                  TextButton(
                                    onPressed: () async {
                                      if (!diagnosed) {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => QuizScreen(
                                              engine: widget.engine,
                                              installId: widget.installId,
                                              questions: widget.questions,
                                            ),
                                          ),
                                        );
                                        _refreshDiagnosed();
                                        return;
                                      }

                                      final s = await StoredDiagnosis.load();
                                      if (s == null) return;

                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => StoredResultScreen(stored: s),
                                        ),
                                      );
                                      _refreshDiagnosed();
                                    },
                                    child: const Text(
                                      '診断結果を見る',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // 今日の占いへ
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.35),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                                onPressed: diagnosed
                                    ? () async {
                                        final s = await StoredDiagnosis.load();
                                        if (s == null) return;
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => FortuneScreen(
                                              installId: widget.installId,
                                              stored: s,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                child: const Text(
                                  '今日の占いへ 🔮',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ③ 下：だんご + 水晶
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 0),
                        child: SizedBox(
                          height: stackHeight,
                          child: Stack(
                            alignment: Alignment.bottomCenter,
                            children: [
                              // だんご（奥）
                              Positioned(
                                bottom: dangoBottom,
                                child: Image.asset(
                                  dangoAsset,
                                  width: dangoWidth,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              // 水晶（手前）
                              Positioned(
                                bottom: -20,
                                child: Image.asset(
                                  'assets/ui/suishou.png',
                                  width: 220,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}


/// =======================
/// Stored Result Screen（診断結果をいつでも見れる）
/// ※ 既存の DiagnosisResult に依存しない安全版
/// =======================
class StoredResultScreen extends StatelessWidget {
  final StoredDiagnosis stored;
  const StoredResultScreen({super.key, required this.stored});

  @override
  Widget build(BuildContext context) {
    final asset = _dangoAssetForMainId(stored.mainId);

    return Scaffold(
      backgroundColor: _kBgPink,
      appBar: AppBar(title: const Text('診断結果🍡')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 上：診断タイトル
              Text(
                stored.finalLabel,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // 中：団子の画像
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: const Color(0xFFFFEEF2),
                  height: 220,
                  child: asset == null
                      ? const Center(
                          child: Text('🍡', style: TextStyle(fontSize: 48)),
                        )
                      : Image.asset(
                          asset,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) {
                            return const Center(
                              child: Text('🍡', style: TextStyle(fontSize: 48)),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // ✅ 診断の詳細（ここにメイン/サブ情報も含めるので上の重複表示は無し）
              _Section(
                title: '恋愛分析レポート',
                child: Text(
                  _diagnosisDetailFor(
                    mainId: stored.mainId,
                    subPattern: stored.subPattern,
                    mainLabel: stored.mainLabel,
                    subLabel: stored.subLabel,
                    subId: stored.subId,
                  ),
                  style: const TextStyle(height: 1.65),
                ),
              ),

              const SizedBox(height: 16),

              // 戻るボタン
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('戻る'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// Quiz
/// =======================
class QuizScreen extends StatefulWidget {
  final DiagnosisEngine engine;
  final String installId;
  final List<QuizQuestion> questions;

  const QuizScreen({
    super.key,
    required this.engine,
    required this.installId,
    required this.questions,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizQuestion> questions;
  final Map<int, String> answers = {};
  int idx = 0;

  @override
  void initState() {
    super.initState();
    questions = widget.questions;
    _guardRetake(); // ★追加：診断済みなら再診断を封じる
  }

  Future<void> _guardRetake() async {
    final prefs = await SharedPreferences.getInstance();
    final paid = prefs.getBool(_kPaidRetake) ?? false;

    // ★診断済みの「正」は StoredDiagnosis が取れるか
    final stored = await StoredDiagnosis.load();
    final done = stored != null;

    // 診断済み＆未課金なら、Quiz画面を開かせない（最終止め）
    if (done && !paid) {
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => AlertDialog(
          title: const Text('診断は一度きりです'),
          content: const Text('診断のやり直しは課金で解放されます。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context); // Quiz を閉じる
    }
  }

  Future<void> _pick(String key) async {
    final q = questions[idx];
    setState(() {
      answers[q.id] = key;
    });

    if (idx < questions.length - 1) {
      setState(() => idx++);
      return;
    }

    final result = widget.engine.run(
      answers: answers,
      userSeed: widget.installId,
    );

    // ★ 初回診断を保存（以後は固定）
    await StoredDiagnosis.saveFromResult(result);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ResultScreen(result: result, installId: widget.installId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = questions[idx];
    final progress = '${idx + 1} / ${questions.length}';

    return Scaffold(
      backgroundColor: _kBgPink,
      appBar: AppBar(title: Text('診断中  $progress')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              q.text,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...q.choices.map((c) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ElevatedButton(
                  onPressed: () => _pick(c.key),
                  child: Text(c.label),
                ),
              );
            }),
            const Spacer(),
            if (idx > 0)
              TextButton(
                onPressed: () {
                  setState(() => idx = max(0, idx - 1));
                },
                child: const Text('ひとつ戻る'),
              ),
          ],
        ),
      ),
    );
  }
}

/// =======================
/// Result (性格診断結果)
/// - 下ボタンは「占いへ進む」
/// - 再診断は課金要素なので出さない
/// =======================
class ResultScreen extends StatelessWidget {
  final DiagnosisResult result;
  final String installId;

  const ResultScreen({
    super.key,
    required this.result,
    required this.installId,
  });

  @override
  Widget build(BuildContext context) {
    final asset = _dangoAssetForMainId(result.mainId);

    return Scaffold(
      backgroundColor: _kBgPink,
      appBar: AppBar(title: const Text('結果🍡')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 上：診断タイトル
              Text(
                result.finalLabel,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // 中：団子の画像
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: const Color(0xFFFFEEF2),
                  height: 220,
                  child: asset == null
                      ? const Center(
                          child: Text('🍡', style: TextStyle(fontSize: 48)),
                        )
                      : Image.asset(
                          asset,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) {
                            return const Center(
                              child: Text('🍡', style: TextStyle(fontSize: 48)),
                            );
                          },
                        ),
                ),
              ),
              const SizedBox(height: 12),

              // ✅ 超詳細：恋愛分析レポート
              _Section(
                title: '恋愛分析レポート',
                child: Text(
                  _diagnosisDetailFor(
                    mainId: result.mainId,
                    subPattern: result.subPattern,
                    mainLabel: result.mainLabel,
                    subLabel: result.subLabel,
                    subId: result.subId,
                  ),
                  style: const TextStyle(height: 1.65),
                ),
              ),

              const SizedBox(height: 12),

              // ✅ 「占いに進む」ボタン（機能維持）
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final stored = await StoredDiagnosis.load();
                    if (stored == null) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('診断情報が見つかりませんでした。もう一度診断してください。'),
                        ),
                      );
                      return;
                    }
                    if (!context.mounted) return;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            FortuneScreen(installId: installId, stored: stored),
                      ),
                    );
                  },
                  child: const Text('占いに進む🔮'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardPink,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderPink),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

String _formatYmdJa(String ymd) {
  // ymd: "20251229"
  final y = int.parse(ymd.substring(0, 4));
  final m = int.parse(ymd.substring(4, 6));
  final d = int.parse(ymd.substring(6, 8));
  final dt = DateTime(y, m, d);
  const w = ['月', '火', '水', '木', '金', '土', '日'];
  final wd = w[dt.weekday - 1];
  return '${y}年${m}月${d}日（$wd）';
}

/// =======================
/// Fortune Screen (毎日の運勢)
/// - installId + 日付 + 診断結果で固定
/// - 再診断は課金ロック（UIだけ実装）
/// =======================
class FortuneScreen extends StatefulWidget {
  final String installId;
  final StoredDiagnosis stored;

  const FortuneScreen({
    super.key,
    required this.installId,
    required this.stored,
  });

  @override
  State<FortuneScreen> createState() => _FortuneScreenState();
}

class _FortuneScreenState extends State<FortuneScreen> {
  Map<String, dynamic>? fortuneJson;
  Map<String, dynamic>? todayFortune; // 今日の結果（保存/復元）
  String? err;

  @override
  void initState() {
    super.initState();
    _loadFortuneJson();
  }

  Future<void> _loadFortuneJson() async {
    try {
      final s = await rootBundle.loadString('assets/config/fortune_daily.json');
      final j = jsonDecode(s) as Map<String, dynamic>;
      setState(() => fortuneJson = j);

      // JSONが読めたら「今日の占い」を復元 or 生成
      await _loadOrCreateTodayFortune();
    } catch (e) {
      setState(() => err = e.toString());
    }
  }

  int _stableHash(String s) {
    // FNV-1a (stable)
    var h = 2166136261;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 16777619) & 0x7fffffff;
    }
    return h;
  }

  String _ymd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  T _pickFromList<T>(List<T> list, int h, int salt) {
    if (list.isEmpty) throw StateError('empty list');
    return list[(h + salt) % list.length];
  }

  Future<void> _loadOrCreateTodayFortune() async {
    if (fortuneJson == null) return;

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final ymd = _ymd(now);

    final savedDate = prefs.getString(_kFortuneDate);
    final savedPayload = prefs.getString(_kFortunePayload);

    // ① 保存済みがあれば復元
    if (savedDate == ymd && savedPayload != null) {
      try {
        final decoded = jsonDecode(savedPayload) as Map<String, dynamic>;
        setState(() => todayFortune = decoded);
        return;
      } catch (_) {}
    }

    // ② なければ新規生成
    final s = widget.stored;
    final seed =
        '${widget.installId}|$ymd|${s.mainId}|${s.subId}|${s.subPattern}';
    final h = _stableHash(seed);

    // 新JSON：by_main
    final byMain = (fortuneJson!['by_main'] as Map<String, dynamic>);
    final mainBlock =
        (byMain[s.mainId] as Map<String, dynamic>?) ??
        (byMain['anko'] as Map<String, dynamic>);

    List<String> _listFromMain(String key) =>
        ((mainBlock[key] as List).map((e) => e.toString())).toList();

    final dayThemeList = _listFromMain('day_theme');
    final moveList = _listFromMain('recommended_move');
    final actionList = _listFromMain('recommended_action');
    final cautionList = _listFromMain('caution');

    final loveFortuneList = _listFromMain('love_fortune');
    final workFortuneList = _listFromMain('work_fortune');
    final moneyFortuneList = _listFromMain('money_fortune');
    final crushAdviceList = _listFromMain('crush_advice');

    final luckTipList = _listFromMain('luck_tip');

    // 新JSON：by_sub_pattern
    final bySub = (fortuneJson!['by_sub_pattern'] as Map<String, dynamic>);
    final subBlock =
        (bySub[s.subPattern] as Map<String, dynamic>?) ??
        (bySub['A'] as Map<String, dynamic>);

    List<String> _listFromSub(String key) =>
        ((subBlock[key] as List).map((e) => e.toString())).toList();

    final luckyColorList = _listFromSub('lucky_color');
    final luckyItemList = _listFromSub('lucky_item');

    // lucky_number は int のリストでも来るので toStringせず取り出す
    final luckyNumberRaw = (subBlock['lucky_number'] as List);
    final luckyNumberList = luckyNumberRaw
        .map((e) => int.parse(e.toString()))
        .toList();

    final payload = <String, dynamic>{
      'ymd': ymd,

      // UI見出しに対応
      'recommended_move': _pickFromList(moveList, h, 7),
      'day_theme': _pickFromList(dayThemeList, h, 11),
      'recommended_action': _pickFromList(actionList, h, 29),
      'caution': _pickFromList(cautionList, h, 53),

      // 読み物（長文）
      'love_fortune': _pickFromList(loveFortuneList, h, 97),
      'work_fortune': _pickFromList(workFortuneList, h, 131),
      'money_fortune': _pickFromList(moneyFortuneList, h, 173),
      'crush_advice': _pickFromList(crushAdviceList, h, 199),

      // ラッキー系
      'lucky_color': _pickFromList(luckyColorList, h, 223),
      'lucky_item': _pickFromList(luckyItemList, h, 251),
      'lucky_number': _pickFromList(luckyNumberList, h, 277),

      // コツ
      'luck_tip': _pickFromList(luckTipList, h, 307),
    };

    await prefs.setString(_kFortuneDate, ymd);
    await prefs.setString(_kFortunePayload, jsonEncode(payload));
    setState(() => todayFortune = payload);
  }

  Future<void> _resetTodayFortuneForTest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFortuneDate);
    await prefs.remove(_kFortunePayload);
    await _loadOrCreateTodayFortune();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1) 今日の日付キー（yyyy-mm-dd）をここで必ず作る
    final now = DateTime.now();
    final ymd =
        '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    if (err != null) {
      return Scaffold(
        backgroundColor: _kBgPink,
        appBar: AppBar(title: const Text('今日の占い🔮')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('fortune_daily.json 読み込み失敗: $err'),
        ),
      );
    }

    if (fortuneJson == null || todayFortune == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ✅ 2) 型安全に取り出す（JSONが欠けても落ちない）
    String pickStr(String key, {String fallback = '（データ未設定）'}) {
      final v = todayFortune![key];
      if (v == null) return fallback;
      return v.toString();
    }

    int pickInt(String key, {int fallback = 0}) {
      final v = todayFortune![key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      final s = v?.toString();
      return int.tryParse(s ?? '') ?? fallback;
    }

    final s = widget.stored;

    final recommendedMove = pickStr('recommended_move');
    final dayTheme = pickStr('day_theme');
    final recommendedAction = pickStr('recommended_action');
    final caution = pickStr('caution');

    final loveFortune = pickStr('love_fortune');
    final workFortune = pickStr('work_fortune');
    final moneyFortune = pickStr('money_fortune');
    final crushAdvice = pickStr('crush_advice');

    final luckyColor = pickStr('lucky_color');
    final luckyItem = pickStr('lucky_item');
    final luckyNumber = pickInt('lucky_number');

    final luckTip = pickStr('luck_tip');

    return Scaffold(
      backgroundColor: _kBgPink,
      appBar: AppBar(
        title: const Text('今日の占い🔮'),
        actions: [
          IconButton(
            tooltip: '【テスト】今日の占いをリセット',
            icon: const Icon(Icons.bug_report),
            onPressed: () async {
              await _resetTodayFortuneForTest();
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('今日の占いを作り直しました')));
            },
          ),
          IconButton(
            tooltip: '診断やり直し（課金）',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final paid = prefs.getBool(_kPaidRetake) ?? false;

              if (!paid) {
                if (!context.mounted) return;
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('診断やり直しは有料です'),
                    content: const Text('診断は一度きりの仕様です。\nやり直し機能は課金で解放されます。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('閉じる'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('課金して解放（未実装）'),
                      ),
                    ],
                  ),
                );
                return;
              }

              await StoredDiagnosis.clear();
              if (!context.mounted) return;
              Navigator.popUntil(context, (r) => r.isFirst);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '今日の運勢',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _formatYmdJa(ymd),
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 12),

          Text(
            s.finalLabel,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _SectionCard(title: 'こんな行動がおすすめ！', body: recommendedMove),
          const SizedBox(height: 12),

          _SectionCard(title: '今日はこんな日になるかも', body: dayTheme),
          const SizedBox(height: 12),

          _SectionCard(title: 'おすすめ行動！', body: recommendedAction),
          const SizedBox(height: 12),

          _SectionCard(title: 'これに注意！', body: caution),
          const SizedBox(height: 12),

          _SectionCard(title: '恋愛運', body: loveFortune),
          const SizedBox(height: 12),

          _SectionCard(title: '仕事運', body: workFortune),
          const SizedBox(height: 12),

          _SectionCard(title: '金運', body: moneyFortune),
          const SizedBox(height: 12),

          _SectionCard(title: '気になるあの人に対して', body: crushAdvice),
          const SizedBox(height: 12),

          _SectionCard(title: 'ラッキーカラー', body: luckyColor),
          const SizedBox(height: 12),

          _SectionCard(title: 'ラッキーアイテム', body: luckyItem),
          const SizedBox(height: 12),

          _SectionCard(title: 'ラッキーナンバー', body: luckyNumber.toString()),
          const SizedBox(height: 12),

          _SectionCard(title: '運気上昇のコツ', body: luckTip),

          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('診断結果へ戻る'),
          ),
        ],
      ),
    );
  }
}

/// 小さめの見やすいセクションカード
class _SectionCard extends StatelessWidget {
  final String title;
  final String body;
  final List<String> chips;

  const _SectionCard({
    required this.title,
    required this.body,
    this.chips = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(body),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: chips.map((c) => Chip(label: Text(c))).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// =======================
/// Home: あなたの団子カード（かわいく一目でわかる）
/// =======================
class _DangoHeroCard extends StatelessWidget {
  final StoredDiagnosis stored;
  const _DangoHeroCard({required this.stored});

  @override
  Widget build(BuildContext context) {
    final asset = _dangoAssetForMainId(stored.mainId);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardPink,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorderPink),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 6),
            color: Color(0x14000000),
          ),
        ],
      ),
      child: Row(
        children: [
          // 左：団子画像
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 84,
              height: 84,
              color: const Color(0xFFECE7E8),
              child: asset == null
                  ? const Center(
                      child: Text('🍡', style: TextStyle(fontSize: 34)),
                    )
                  : Image.asset(
                      asset,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) {
                        return const Center(
                          child: Text('🍡', style: TextStyle(fontSize: 34)),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // 右：タイプ表示
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  stored.finalLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// =======================
/// mainId → asset の対応表
/// ★あなたの現状 assets/dango のファイル名に完全一致
/// =======================
String? _dangoAssetForMainId(String mainId) {
  switch (mainId) {
    case 'anko':
      return 'assets/dango/anko.png';
    case 'goma':
      return 'assets/dango/goma.png';
    case 'kinako':
      return 'assets/dango/kinako.png';
    case 'mitarashi':
      return 'assets/dango/mitarashi.png';
    case 'sakura':
      return 'assets/dango/sakura.png';
    case 'sanshoku':
      return 'assets/dango/sanshoku.png';
    case 'yomogi':
      return 'assets/dango/yomogi.png';
    case 'zunda':
      return 'assets/dango/zunda.png';
    default:
      return null;
  }
}

String _diagnosisDetailFor({
  required String mainId,
  required String subPattern,
  required String mainLabel,
  required String subLabel,
  required String subId,
}) {
  // repo未ロード保険（本来はBootで必ず入る）
  final repo = _diagRepo;
  if (repo == null) {
    return '診断データ準備中です…\n（アプリ再起動で直る場合があります）';
  }

  final main = repo.mainTypes[mainId] as Map<String, dynamic>?;
  final sub = repo.subTypes[subId] as Map<String, dynamic>?;

  if (main == null || sub == null) {
    return '診断データが見つかりませんでした。\nmainId=$mainId / subId=$subId';
  }

  // subはJSONのpatternを優先（storedのsubPatternとズレてもOK）
  final actualPattern = (sub['pattern'] ?? subPattern).toString();

  // main: core / love_pattern / strength / weakness / pitfall / best_match / keywords / tone_hint
  final core = (main['core'] ?? '').toString();
  final lovePattern = (main['love_pattern'] is List)
      ? (main['love_pattern'] as List).map((e) => '・$e').join('\n')
      : '';
  final strength = (main['strength'] is List)
      ? (main['strength'] as List).map((e) => '・$e').join('\n')
      : '';
  final weakness = (main['weakness'] is List)
      ? (main['weakness'] as List).map((e) => '・$e').join('\n')
      : '';
  final pitfall = (main['pitfall'] ?? '').toString();
  final bestMatch = (main['best_match'] is List)
      ? (main['best_match'] as List).map((e) => '・$e').join('\n')
      : '';
  final keywords = (main['keywords'] is List)
      ? (main['keywords'] as List).map((e) => '#$e').join(' ')
      : '';
  final toneHint = (main['tone_hint'] ?? '').toString();

  // sub: nuance / tone_tags
  final nuance = (sub['nuance'] ?? '').toString();
  final toneTags = (sub['tone_tags'] is List)
      ? (sub['tone_tags'] as List).map((e) => '・$e').join('\n')
      : '';

  return [
    '■ あなたはこんな性格',
    core,
    '',
    '■ 恋をしたらこんな風になる',
    lovePattern,
    '',
    '■ あなたの人より強いところ',
    strength,
    '',
    '■ 気をつけなきゃいけないところ',
    weakness,
    if (pitfall.isNotEmpty) ...['', '■ 落とし穴', pitfall],
    '',
    '■ 恋が始まるときはこんな感じ',
    nuance,
    if (toneTags.isNotEmpty) ...['', '■ あなたを一言で表すなら', toneTags],
    if (bestMatch.isNotEmpty) ...['', '■ あなたと相性がいいタイプ', bestMatch],
  ].join('\n');
}