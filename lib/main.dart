// main.dart — Figma pass with icon pack + collapsible "Today’s Attempts" (no animations)
// - Uses SVG icon assets (see names below) and code‑built UI that matches your Figma
// - Adds accordion Attempts screen (3→8), only meant to be shown after all rounds are finished
// - Gameplay/state logic unchanged. Ads hooks remain disabled.
//
//  REQUIRED ASSETS (put these in assets/icons/ and list the folder in pubspec.yaml):
//    ic_arrow_up.svg, ic_arrow_down.svg, ic_check.svg,
//    ic_backspace.svg, ic_enter.svg, ic_x_small.svg,
//    ic_plus.svg, ic_minus.svg     // used by "Today’s Attempts" headers
//
//  pubspec.yaml (add):
//    dependencies:
//      flutter_svg: ^2.0.9
//    flutter:
//      assets:
//        - assets/icons/
//
//  NOTE: All special glyphs use Unicode escapes (× = \u00D7) so you won’t see mojibake.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DailyNumbersApp());
}

// === Color tokens (match your Figma neutrals; tweak if spec.json differs)
const kBg = Color(0xFFFBF7F1); // warm off‑white background
const kSurface = Colors.white;
const kText = Color(0xFF2E2E2E);
const kSubtle = Color(0xFF7A7F87);
const kStrokeWarm = Color(0xFFE4DED7); // 1px warm stroke

// Tiles
const kTileGreen = Color(0xFFBFE8C0);
const kTileOrange = Color(0xFFFFD49C);
const kTileGrey = Color(0xFFE9E7EE);
const kTileGhost = Color(0xFFD8DADF);

// Status accents
const kOk = Color(0xFF15803D);
const kHigher = Color(0xFF6B7CFF); // soft blue to match Figma chip
const kLower = Color(0xFFFF8A8A); // soft red to match Figma chip

// Glyphs (use escapes to avoid encoding issues)
const kTimes = '\u00D7'; // ×

class DailyNumbersApp extends StatelessWidget {
  const DailyNumbersApp({super.key});
  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true, scaffoldBackgroundColor: kBg);
    final outlinePill = OutlinedButton.styleFrom(
      foregroundColor: kText,
      backgroundColor: kSurface,
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      side: const BorderSide(color: kStrokeWarm, width: 1),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Daily Numbers',
      theme: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          background: kBg, surface: kSurface, onSurface: kText, onBackground: kText, primary: kText,
        ),
        appBarTheme: const AppBarTheme(backgroundColor: kBg, foregroundColor: kText, elevation: 0),
        dialogTheme: const DialogThemeData(
  backgroundColor: kSurface,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(20)),
  ),
),
        textTheme: base.textTheme.apply(bodyColor: kText, displayColor: kText),
        outlinedButtonTheme: OutlinedButtonThemeData(style: outlinePill),
        filledButtonTheme: FilledButtonThemeData(style: outlinePill), // we reuse same visual for simplicity
      ),
      home: const HomePage(),
    );
  }
}

// === Feature flags (stubbed off)
const bool adsEnabled = false; // home bottom banner placeholder
const bool premiumEnabled = false; // never show ads if true
const bool interstitialEnabled = false; // hidden hook after round 7

// === Keys
const _kTodayKey = 'todayKey';
const _kCompletedUpTo = 'completedUpTo'; // max length solved today
String _kBestLen(int n) => 'best_len$n';
String _kPlaysLen(int n) => 'plays_len$n';
String _kTotalGuessesLen(int n) => 'totalGuesses_len$n';
String _kTodayGuessesLen(int n) => 'today_guesses_len$n';
String _kAttemptsLen(int n) => 'attempts_len$n'; // StringList of today guesses
const _kAdShownAfter7For = 'ad_shown_after7_for'; // YYYYMMDD

const _rounds = [3, 4, 5, 6, 7, 8];
const _cols = 8; // board always 8-wide; rounds 3–7 pad with ×

String _todayKey(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

int _dayNumber(DateTime now) => now.difference(DateTime(2023, 12, 1)).inDays + 1;

// === HOME
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _completedUpTo = 0;
  late DateTime _now;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _initPrefs();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    final p = await SharedPreferences.getInstance();
    final today = _todayKey(DateTime.now());
    if (p.getString(_kTodayKey) != today) {
      // midnight reset for today-only data
      await p.setString(_kTodayKey, today);
      await p.setInt(_kCompletedUpTo, 0);
      for (final n in _rounds) {
        await p.setInt(_kTodayGuessesLen(n), 0);
        await p.remove(_kAttemptsLen(n));
      }
      await p.remove(_kAdShownAfter7For);
    }
    setState(() => _completedUpTo = p.getInt(_kCompletedUpTo) ?? 0);
  }

  String _hhmmssUntilMidnight() {
    final m = DateTime(_now.year, _now.month, _now.day).add(const Duration(days: 1));
    final d = m.difference(_now);
    final h = d.inHours.toString().padLeft(2, '0');
    final min = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$min:$s';
  }

  int _nextIncomplete() {
    for (final n in _rounds) {
      if (n > _completedUpTo) return n;
    }
    return 8;
  }

  Future<void> _startPlay() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RoundPage(length: _nextIncomplete(), dayNumber: _dayNumber(DateTime.now())),
      ),
    );
    await _initPrefs();
  }

  @override
  Widget build(BuildContext context) {
    final dayNo = _dayNumber(_now);
    final finished = _completedUpTo >= 8;

    // Per Figma: Home pre‑play has no AppBar and no countdown chip
    return Scaffold(
      appBar: null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text('Guess Today\'s\nDaily Numbers',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Day #$dayNo', style: const TextStyle(color: kSubtle)),
              const SizedBox(height: 24),
              // Centered mini illustration inside a warm frame
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kStrokeWarm),
                ),
                child: const _IllustrationGrid(centered: true, tileSize: 30),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: finished
                    ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttemptsTodayPageCollapsible()))
                    : _startPlay,
                child: Text(finished ? "View today\'s attempts" : "Play Today\'s Rounds"),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HowToPage())),
                child: const Text('How to Play'),
              ),
              const Spacer(),
              if (finished)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFEAEAF1), borderRadius: BorderRadius.circular(28), border: Border.all(color: kStrokeWarm)),
                  child: Text('Come back tomorrow — ${_hhmmssUntilMidnight()}', style: const TextStyle(color: kSubtle)),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// === Illustration on Home
class _IllustrationGrid extends StatelessWidget {
  final bool centered; final double tileSize; const _IllustrationGrid({this.centered = false, this.tileSize = 32});
  @override
  Widget build(BuildContext context) {
    const g = 8.0;
    Widget row(int r) => Row(
          mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            for (int c = 0; c < 3; c++)
              Padding(
                padding: EdgeInsets.only(right: c == 2 ? 0 : g),
                child: _TileBox(size: tileSize, label: '', color: _tileColor(r, c)),
              ),
          ],
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [row(0), const SizedBox(height: g), row(1), const SizedBox(height: g), row(2)]);
  }

  Color _tileColor(int r, int c) {
    if (r == 1 && c == 1) return kTileGreen;
    if (c == 2) return kTileGrey;
    return kTileOrange;
  }
}

// === Round
enum RoundStatus { neutral, higher, lower, correct }

class RoundPage extends StatefulWidget {
  final int length;
  final int dayNumber;
  const RoundPage({super.key, required this.length, required this.dayNumber});
  @override
  State<RoundPage> createState() => _RoundPageState();
}

class _RoundPageState extends State<RoundPage> {
  static const _gap = 8.0;
  final _rows = <String>[];
  String _entry = '';
  late final String _secret;
  final _scroll = ScrollController();
  RoundStatus _status = RoundStatus.neutral;

  @override
  void initState() {
    super.initState();
    _secret = _generateSecret(widget.length);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String _generateSecret(int len) {
    final seed = _hash('${_todayKey(DateTime.now())}#$len');
    final r = Random(seed);
    return List.generate(len, (_) => r.nextInt(10).toString()).join();
  }

  int _hash(String s) { int h = 0; for (final c in s.codeUnits) { h = (h * 131 + c) & 0x7fffffff; } return h; }

  List<int> _score(String secret, String guess) {
    final n = secret.length; final res = List<int>.filled(n, 0); final cnt = List<int>.filled(10, 0);
    for (var i = 0; i < n; i++) cnt[int.parse(secret[i])]++;
    for (var i = 0; i < n; i++) if (guess[i] == secret[i]) { res[i] = 2; cnt[int.parse(guess[i])]--; }
    for (var i = 0; i < n; i++) if (res[i] == 0) { final d = int.parse(guess[i]); if (cnt[d] > 0) { res[i] = 1; cnt[d]--; }}
    return res;
  }

  Future<void> _submit() async {
    if (_entry.length != widget.length) { HapticFeedback.selectionClick(); return; }
    final guess = _entry; setState(() { _rows.add(guess); _entry = ''; });

    // Store attempt for recap
    final prefs = await SharedPreferences.getInstance();
    final key = _kAttemptsLen(widget.length);
    final arr = prefs.getStringList(key) ?? <String>[]; arr.add(guess); await prefs.setStringList(key, arr);

    // Update top status
    final sVal = int.parse(_secret), gVal = int.parse(guess);
    setState(() {
      _status = gVal == sVal ? RoundStatus.correct : (gVal < sVal ? RoundStatus.higher : RoundStatus.lower);
    });

    // Scroll to latest row
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });

    if (gVal == sVal) {
      final prefs = await SharedPreferences.getInstance();
      final bestK = _kBestLen(widget.length), playsK = _kPlaysLen(widget.length), totalK = _kTotalGuessesLen(widget.length);
      final best = prefs.getInt(bestK) ?? 0;
      final plays = (prefs.getInt(playsK) ?? 0) + 1;
      final total = (prefs.getInt(totalK) ?? 0) + _rows.length;
      await prefs.setInt(bestK, best == 0 ? _rows.length : min(best, _rows.length));
      await prefs.setInt(playsK, plays);
      await prefs.setInt(totalK, total);
      await prefs.setInt(_kTodayGuessesLen(widget.length), _rows.length);
      final prev = prefs.getInt(_kCompletedUpTo) ?? 0; await prefs.setInt(_kCompletedUpTo, max(prev, widget.length));
      await _showWin();
    }
  }

  Future<void> _showWin() async {
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt(_kBestLen(widget.length)) ?? 0;
    final plays = prefs.getInt(_kPlaysLen(widget.length)) ?? 0;
    final total = prefs.getInt(_kTotalGuessesLen(widget.length)) ?? 0;
    final avg = plays > 0 ? (total / plays).round() : _rows.length;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Text(widget.length < 8 ? 'Nice! You solved it.' : 'Congratulations!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You solved the ${widget.length}-digit number in ${_rows.length} guesses.'),
            const SizedBox(height: 8),
            Text('Stats — This round: ${_rows.length} · Best: $best · Average: $avg', style: const TextStyle(color: kSubtle)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              if (widget.length < 8) {
                if (widget.length == 7) {
                  final today = _todayKey(DateTime.now());
                  final shown = prefs.getString(_kAdShownAfter7For);
                  if (adsEnabled && interstitialEnabled && !premiumEnabled && shown != today) {
                    await _maybeShowInterstitial();
                    await prefs.setString(_kAdShownAfter7For, today);
                  }
                }
                if (!mounted) return;
                Navigator.pushReplacement(context, MaterialPageRoute(
                  builder: (_) => RoundPage(length: widget.length + 1, dayNumber: widget.dayNumber),
                ));
              } else {
                if (!mounted) return;
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DailySummaryPage()));
              }
            },
            child: Text(widget.length < 8 ? 'Next Round' : 'Daily Summary'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.length}-digit';

    Widget statusPill() {
      String t = ''; String asset = ''; Color b = kSubtle;
      switch (_status) {
        case RoundStatus.higher: t = 'Higher'; asset = 'assets/icons/ic_arrow_up.svg'; b = kHigher; break;
        case RoundStatus.lower: t = 'Lower'; asset = 'assets/icons/ic_arrow_down.svg'; b = kLower; break;
        case RoundStatus.correct: t = 'Correct'; asset = 'assets/icons/ic_check.svg'; b = kOk; break;
        case RoundStatus.neutral: asset = ''; break;
      }
      if (asset.isEmpty) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFEAEAF1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: b.withOpacity(0.6)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SvgPicture.asset(asset, width: 16, height: 16, colorFilter: ColorFilter.mode(b, BlendMode.srcIn)),
          const SizedBox(width: 6),
          Text(t, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 8), child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(key: ValueKey(_status), child: statusPill()))),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${widget.length} / $_cols digits today', style: const TextStyle(fontSize: 12, color: kSubtle)),
            const SizedBox(height: 12),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final avail = c.maxWidth; final size = ((avail - _gap * (_cols - 1)) / _cols).clamp(36.0, 56.0);
                return ListView.builder(
                  controller: _scroll,
                  itemCount: _rows.length + 1,
                  itemBuilder: (context, idx) {
                    if (idx == _rows.length) {
                      // current input row
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(children: [
                          for (int i = 0; i < widget.length; i++)
                            Padding(
                              padding: EdgeInsets.only(right: i == widget.length - 1 ? 0 : _gap),
                              child: _TileBox(
                                size: size,
                                label: i < _entry.length ? _entry[i] : '',
                                color: kTileGrey,
                                borderColor: (i == _entry.length) ? Colors.blueAccent.withOpacity(0.7) : kStrokeWarm,
                              ),
                            ),
                          for (int i = 0; i < _cols - widget.length; i++)
                            Padding(
                              padding: EdgeInsets.only(left: _gap),
                              child: _TileBox(size: size, label: kTimes, color: widget.length < 8 ? kTileGhost : Colors.transparent, labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700), semanticsEnabled: false),
                            ),
                        ]),
                      );
                    }
                    final g = _rows[idx]; final sc = _score(_secret, g);
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        for (int i = 0; i < widget.length; i++)
                          Padding(
                            padding: EdgeInsets.only(right: i == widget.length - 1 ? 0 : _gap),
                            child: _TileBox(size: size, label: g[i], color: sc[i] == 2 ? kTileGreen : (sc[i] == 1 ? kTileOrange : kTileGrey)),
                          ),
                        for (int i = 0; i < _cols - widget.length; i++)
                          Padding(
                            padding: EdgeInsets.only(left: _gap),
                            child: _TileBox(size: size, label: kTimes, color: widget.length < 8 ? kTileGhost : Colors.transparent, labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700), semanticsEnabled: false),
                          ),
                      ]),
                    );
                  },
                );
              }),
            ),
            const SizedBox(height: 8),
            _Keypad(
              onDigit: (d) { if (_entry.length < widget.length) setState(() => _entry += '$d'); },
              onBackspace: () { if (_entry.isNotEmpty) setState(() => _entry = _entry.substring(0, _entry.length - 1)); },
              onEnter: _entry.length == widget.length ? _submit : null,
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _maybeShowInterstitial() async {/* stub no-op */}
}

// === Reusable Tile + Keypad
class _TileBox extends StatelessWidget {
  final double size; final String label; final Color color; final Color? borderColor; final TextStyle? labelStyle; final bool semanticsEnabled;
  const _TileBox({required this.size, required this.label, required this.color, this.borderColor, this.labelStyle, this.semanticsEnabled = true});
  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      excluding: !semanticsEnabled,
      child: Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: (borderColor ?? kStrokeWarm), width: 1),
        ),
        child: Text(label, style: labelStyle ?? const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(int) onDigit; final VoidCallback onBackspace; final Future<void> Function()? onEnter;
  const _Keypad({required this.onDigit, required this.onBackspace, required this.onEnter});
  @override
  Widget build(BuildContext context) {
    final rows = const [
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9],
    ];
    Widget keyChild(String label) => Text(label, style: const TextStyle(fontWeight: FontWeight.w700));
    Widget cap({required Widget child, VoidCallback? onPressed}) => OutlinedButton(onPressed: onPressed, child: child);

    return Column(children: [
      for (final r in rows)
        Row(children: [
          for (final k in r)
            Expanded(child: Padding(padding: const EdgeInsets.all(6), child: cap(onPressed: () => onDigit(k), child: keyChild('$k')))),
        ]),
      Row(children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: cap(
              onPressed: onBackspace,
              child: SvgPicture.asset('assets/icons/ic_backspace.svg', width: 20, height: 20, colorFilter: const ColorFilter.mode(kText, BlendMode.srcIn)),
            ),
          ),
        ),
        Expanded(child: Padding(padding: const EdgeInsets.all(6), child: cap(onPressed: () => onDigit(0), child: keyChild('0')))),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: cap(
              onPressed: onEnter == null ? null : () => onEnter!(),
              child: SvgPicture.asset('assets/icons/ic_enter.svg', width: 20, height: 20, colorFilter: ColorFilter.mode(onEnter == null ? kSubtle : kText, BlendMode.srcIn)),
            ),
          ),
        ),
      ]),
    ]);
  }
}

// === How to Play (page)
class HowToPage extends StatelessWidget {
  const HowToPage({super.key});
  @override
  Widget build(BuildContext context) {
    Widget bulletLine(String text) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('\u2022'), const SizedBox(width: 8), Expanded(child: Text(text))]);
    return Scaffold(
      appBar: AppBar(title: const Text('How to Play')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 8),
          const Text('Guess the secret number.', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 12),
          const Text('Colours:', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          bulletLine('Green = correct digit & position'),
          bulletLine('Orange = right digit, wrong place'),
          bulletLine('Grey = not present'),
          const SizedBox(height: 16),
          const Text('App-bar indicator:', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          bulletLine('Up arrow = Higher than your guess'),
          bulletLine('Down arrow = Lower than your guess'),
          bulletLine('Tick = Your guess is correct'),
          const SizedBox(height: 24),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(padding: const EdgeInsets.all(24), child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))),
      ),
    );
  }
}

// === Daily Summary
class DailySummaryPage extends StatelessWidget {
  const DailySummaryPage({super.key});

  Future<Map<int, int>> _todayGuesses() async {
    final p = await SharedPreferences.getInstance();
    return { for (final n in _rounds) n : (p.getInt(_kTodayGuessesLen(n)) ?? 0) };
  }
  Future<Map<int, List<num>>> _lifetime() async {
    final p = await SharedPreferences.getInstance();
    final m = <int, List<num>>{};
    for (final n in _rounds) {
      final best = p.getInt(_kBestLen(n)) ?? 0;
      final plays = p.getInt(_kPlaysLen(n)) ?? 0;
      final total = p.getInt(_kTotalGuessesLen(n)) ?? 0;
      final avg = plays > 0 ? total / plays : 0.0;
      m[n] = [avg, best.toDouble()];
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([_todayGuesses(), _lifetime()]),
      builder: (context, snap) {
        if (!snap.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final today = snap.data![0] as Map<int, int>;
        final life = snap.data![1] as Map<int, List<num>>;
        return Scaffold(
          appBar: AppBar(title: const Text('Daily Summary')),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(children: const [
                Expanded(child: Text('Category', style: TextStyle(fontWeight: FontWeight.w700))),
                SizedBox(width: 12), SizedBox(width: 70, child: Text('Today', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700))),
                SizedBox(width: 12), SizedBox(width: 70, child: Text('Average', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700))),
                SizedBox(width: 12), SizedBox(width: 70, child: Text('Best', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.w700))),
              ]),
              const Divider(),
              for (final n in _rounds) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(children: [
                    Expanded(child: Text('$n-digit')),
                    const SizedBox(width: 12), SizedBox(width: 70, child: Text('${today[n] ?? 0}', textAlign: TextAlign.right)),
                    const SizedBox(width: 12), SizedBox(width: 70, child: Text('${(life[n]![0]).toStringAsFixed(0)}', textAlign: TextAlign.right)),
                    const SizedBox(width: 12), SizedBox(width: 70, child: Text('${life[n]![1].toInt()}', textAlign: TextAlign.right)),
                  ]),
                ),
                const Divider(height: 1),
              ],
              const SizedBox(height: 24),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(padding: const EdgeInsets.all(24), child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Home'))),
          ),
        );
      },
    );
  }
}

// === Today’s Attempts (collapsible accordion, one screen)
class AttemptsTodayPageCollapsible extends StatefulWidget {
  const AttemptsTodayPageCollapsible({super.key});
  @override
  State<AttemptsTodayPageCollapsible> createState() => _AttemptsTodayPageCollapsibleState();
}

class _AttemptsTodayPageCollapsibleState extends State<AttemptsTodayPageCollapsible> {
  int _open = 3; // 3-digit expanded by default
  late Future<_AttemptsData> _future;
  @override
  void initState() { super.initState(); _future = _load(); }

  Future<_AttemptsData> _load() async {
    final p = await SharedPreferences.getInstance();
    final attempts = <int, List<String>>{ for (final n in _rounds) n : (p.getStringList(_kAttemptsLen(n)) ?? <String>[]) };
    final today = { for (final n in _rounds) n : (p.getInt(_kTodayGuessesLen(n)) ?? 0) };
    final best = { for (final n in _rounds) n : (p.getInt(_kBestLen(n)) ?? 0) };
    final plays = { for (final n in _rounds) n : (p.getInt(_kPlaysLen(n)) ?? 0) };
    final total = { for (final n in _rounds) n : (p.getInt(_kTotalGuessesLen(n)) ?? 0) };
    return _AttemptsData(attempts, today, best, plays, total);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AttemptsData>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snap.data!;
        return Scaffold(
          appBar: AppBar(title: const Text("Today\'s Attempts")),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final n in _rounds) ...[
                _AttemptHeader(
                  label: '$n-digit',
                  open: _open == n,
                  onTap: () => setState(() => _open = _open == n ? -1 : n),
                ),
                const Divider(height: 1),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _ReadOnlyBoard(length: n, guesses: data.attempts[n]!),
                      const SizedBox(height: 8),
                      _StatsRow(
                        thisRound: data.today[n] ?? 0,
                        best: data.best[n] ?? 0,
                        avg: (data.plays[n] ?? 0) > 0 ? ((data.total[n] ?? 0) / (data.plays[n] ?? 1)).round() : 0,
                      ),
                    ]),
                  ),
                  crossFadeState: _open == n ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 180),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(padding: const EdgeInsets.all(16), child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Back to Home'))),
          ),
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int thisRound, best, avg; const _StatsRow({required this.thisRound, required this.best, required this.avg});
  @override
  Widget build(BuildContext context) {
    Text grey(String s) => Text(s, style: const TextStyle(color: kSubtle));
    return Row(children: [
      Expanded(child: grey('This round: $thisRound')),
      Expanded(child: grey('Best: $best')),
      Expanded(child: grey('Avg: $avg')),
    ]);
  }
}

class _AttemptHeader extends StatelessWidget {
  final String label; final bool open; final VoidCallback onTap; const _AttemptHeader({required this.label, required this.open, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          SvgPicture.asset(open ? 'assets/icons/ic_minus.svg' : 'assets/icons/ic_plus.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(kText, BlendMode.srcIn)),
        ]),
      ),
    );
  }
}

class _AttemptsData {
  final Map<int, List<String>> attempts; final Map<int, int> today; final Map<int, int> best; final Map<int, int> plays; final Map<int, int> total;
  _AttemptsData(this.attempts, this.today, this.best, this.plays, this.total);
}

// === Read-only board used in Attempts page
class _ReadOnlyBoard extends StatelessWidget {
  final int length; final List<String> guesses; const _ReadOnlyBoard({required this.length, required this.guesses});
  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    return LayoutBuilder(builder: (context, c) {
      final size = ((c.maxWidth - gap * (_cols - 1)) / _cols).clamp(32.0, 56.0);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final g in guesses)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              for (int i = 0; i < length; i++)
                Padding(padding: EdgeInsets.only(right: i == length - 1 ? 0 : gap), child: _TileBox(size: size, label: g[i], color: kTileGrey)),
              for (int i = 0; i < _cols - length; i++)
                Padding(padding: EdgeInsets.only(left: gap), child: _TileBox(size: size, label: kTimes, color: length < 8 ? kTileGhost : Colors.transparent, labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700), semanticsEnabled: false)),
            ]),
          ),
      ]);
    });
  }
}