// main_clean_v1_3_0.dart
// Daily Numbers — single-file demo build
// v1.3.0

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const DailyNumbersApp());
}

// ===== App root =============================================================

class DailyNumbersApp extends StatelessWidget {
  const DailyNumbersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Daily Numbers',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6750A4)),
        scaffoldBackgroundColor: const Color(0xFFF5F5F7), // light neutral
        dialogTheme: const DialogTheme(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

// ===== Shared keys & helpers ===============================================

const _kLengths = [3, 4, 5, 6, 7, 8];
const _kVersion = 'v1.3.0';

// persistent keys
String _keyBest(int n) => 'best_len$n';
String _keyAvgCount(int n) => 'plays_len$n';
String _keyAvgSum(int n) => 'totalGuesses_len$n';
String _keyTodayCount(int n) => 'today_count_len$n';
String _keyTodayRows(int n) => 'today_rows_len$n';
const _keySeenHowTo = 'seen_how_to';
const _keyTodayStamp = 'today_yyyymmdd';
const _keyCompletedUpTo = 'completed_upto_len';

int dayNumber(DateTime now) {
  // Day #001 anchor — adjust if you want a different “start of epoch”
  final start = DateTime(2023, 12, 1);
  return now.difference(DateTime(start.year, start.month, start.day)).inDays + 1;
}

String yyyymmdd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

// seeded RNG per day+length to keep the same secret for everyone for that day
List<int> dailySecret(int length, int dayNum) {
  final seed = dayNum * 997 + length * 101; // simple mixed seed
  final rnd = Random(seed);
  return List<int>.generate(length, (_) => rnd.nextInt(10));
}

int digitsToInt(List<int> digits) {
  var v = 0;
  for (final d in digits) {
    v = v * 10 + d;
  }
  return v;
}

List<int> scoreGuess(List<int> secret, List<int> guess) {
  // 0 = grey, 1 = orange (present wrong place), 2 = green (correct)
  final n = secret.length;
  final out = List<int>.filled(n, 0);
  final used = List<bool>.filled(n, false);

  // greens
  for (var i = 0; i < n; i++) {
    if (guess[i] == secret[i]) {
      out[i] = 2;
      used[i] = true;
    }
  }
  // oranges
  for (var i = 0; i < n; i++) {
    if (out[i] == 2) continue;
    for (var j = 0; j < n; j++) {
      if (!used[j] && guess[i] == secret[j]) {
        out[i] = 1;
        used[j] = true;
        break;
      }
    }
  }
  return out;
}

// ===== Home ================================================================

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Timer _timer;
  late DateTime _now;
  bool _finishedAllToday = false;
  String _countdown = '';

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _refreshCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
        _refreshCountdown();
      });
    });
    _checkResetAndProgress();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _checkResetAndProgress() async {
    final prefs = await SharedPreferences.getInstance();
    // daily reset for "today_*" stats
    final todayKey = yyyymmdd(DateTime.now());
    final last = prefs.getString(_keyTodayStamp);
    if (last != todayKey) {
      for (final n in _kLengths) {
        await prefs.remove(_keyTodayCount(n));
        await prefs.remove(_keyTodayRows(n));
      }
      await prefs.setString(_keyTodayStamp, todayKey);
      await prefs.setInt(_keyCompletedUpTo, 0);
    }
    final upto = prefs.getInt(_keyCompletedUpTo) ?? 0;
    setState(() {
      _finishedAllToday = upto >= 8;
    });
  }

  void _refreshCountdown() {
    final tomorrow = DateTime(_now.year, _now.month, _now.day + 1);
    final diff = tomorrow.difference(_now);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    _countdown = '$h:$m:$s';
  }

  Future<void> _maybeShowHowTo() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_keySeenHowTo) ?? false)) {
      final dont = await showDialog<bool>(
        context: context,
        builder: (c) => const HowToDialog(),
      );
      if (dont == true) {
        await prefs.setBool(_keySeenHowTo, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dn = dayNumber(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Numbers'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _finishedAllToday
                  ? Chip(
                      label: const Text('Come back tomorrow'),
                      side: const BorderSide(color: Colors.transparent),
                      backgroundColor: const Color(0xFFEDEFF3),
                    )
                  : Chip(
                      label: Text('New challenge in $_countdown'),
                      side: const BorderSide(color: Colors.transparent),
                      backgroundColor: const Color(0xFFEDEFF3),
                    ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Play today’s rounds (3–8) — Day #$dn',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () async {
                await _maybeShowHowTo();
                if (!mounted) return;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RoundPage(length: 3, dayNum: dn),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Text('Play'),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AttemptsPage()),
                );
              },
              child: const Text('View today’s attempts'),
            ),
            TextButton(
              onPressed: () async {
                final dont = await showDialog<bool>(
                  context: context,
                  builder: (_) => const HowToDialog(),
                );
                if (dont == true) {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool(_keySeenHowTo, true);
                }
              },
              child: const Text('How to Play'),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== How to Play dialog ===================================================

class HowToDialog extends StatefulWidget {
  const HowToDialog({super.key});

  @override
  State<HowToDialog> createState() => _HowToDialogState();
}

class _HowToDialogState extends State<HowToDialog> {
  bool dontShow = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AlertDialog(
      title: const Text('How to Play'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('- Guess the secret number.', style: t.bodyMedium),
          const SizedBox(height: 8),
          Text('- Colours: Green = correct place; Orange = wrong place; Grey = not present.',
              style: t.bodyMedium),
          const SizedBox(height: 8),
          Text('- The arrow shows whether your whole guess is lower (↑) or higher (↓). When equal, no arrow.',
              style: t.bodyMedium),
          const SizedBox(height: 8),
          Text('- Enter is only enabled when the row is filled.', style: t.bodyMedium),
          const SizedBox(height: 8),
          Text('- Some digits may appear more than once…', style: t.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Checkbox(
                value: dontShow,
                onChanged: (v) => setState(() => dontShow = v ?? false),
              ),
              const Text("Don’t show again"),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(dontShow),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

// ===== Round page ===========================================================

class RoundPage extends StatefulWidget {
  final int length;
  final int dayNum;
  final bool readOnly;
  final List<List<int>>? initialRows; // for read-only view

  const RoundPage({
    super.key,
    required this.length,
    required this.dayNum,
    this.readOnly = false,
    this.initialRows,
  });

  @override
  State<RoundPage> createState() => _RoundPageState();
}

class _RoundPageState extends State<RoundPage> with SingleTickerProviderStateMixin {
  late List<int> _secret;
  final List<List<int>> _rows = [];
  final List<int> _current = [];
  int _arrow = 0; // -1 lower, 0 equal, +1 higher
  late final AnimationController _pulse;
  late final Animation<double> _scale;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _secret = dailySecret(widget.length, widget.dayNum);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      lowerBound: 0.96,
      upperBound: 1.04,
    );
    _scale = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
    if (widget.readOnly && widget.initialRows != null) {
      _rows.addAll(widget.initialRows!);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _onDigit(int d) async {
    if (widget.readOnly) return;
    if (_current.length >= widget.length) return;
    setState(() => _current.add(d));
  }

  Future<void> _onBackspace() async {
    if (widget.readOnly) return;
    if (_current.isNotEmpty) {
      setState(() => _current.removeLast());
    }
  }

  Future<void> _onEnter() async {
    if (widget.readOnly) return;
    if (_current.length != widget.length) return;

    final guess = List<int>.from(_current);
    final sVal = digitsToInt(_secret);
    final gVal = digitsToInt(guess);
    final score = scoreGuess(_secret, guess);
    setState(() {
      _rows.add(guess);
      _current.clear();
      _arrow = gVal < sVal ? 1 : (gVal > sVal ? -1 : 0);
    });
    // pulse the arrow chip
    _pulse
      ..reset()
      ..forward();

    // persist today's rows for Attempts view
    final prefs = await SharedPreferences.getInstance();
    final keyRows = _keyTodayRows(widget.length);
    final existing = (prefs.getString(keyRows));
    final list = existing == null
        ? <List<int>>[]
        : (jsonDecode(existing) as List).map<List<int>>((e) => (e as List).cast<int>()).toList();
    list.add(guess);
    await prefs.setString(keyRows, jsonEncode(list));

    // solved?
    if (score.every((e) => e == 2)) {
      await _onSolved(list.length);
    }

    // scroll a bit to keep recent visible
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (_scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _onSolved(int guessesThisRound) async {
    final prefs = await SharedPreferences.getInstance();
    final n = widget.length;

    final best = prefs.getInt(_keyBest(n));
    if (best == null || guessesThisRound < best) {
      await prefs.setInt(_keyBest(n), guessesThisRound);
    }
    final plays = (prefs.getInt(_keyAvgCount(n)) ?? 0) + 1;
    final sum = (prefs.getInt(_keyAvgSum(n)) ?? 0) + guessesThisRound;
    await prefs.setInt(_keyAvgCount(n), plays);
    await prefs.setInt(_keyAvgSum(n), sum);

    final today = (prefs.getInt(_keyTodayCount(n)) ?? 0);
    await prefs.setInt(_keyTodayCount(n), today > 0 ? min(today, guessesThisRound) : guessesThisRound);

    // bump progress
    final upto = prefs.getInt(_keyCompletedUpTo) ?? 0;
    if (n > upto) await prefs.setInt(_keyCompletedUpTo, n);

    // stats message
    final bestNow = prefs.getInt(_keyBest(n)) ?? guessesThisRound;
    final avg = (prefs.getInt(_keyAvgSum(n)) ?? 0) / max((prefs.getInt(_keyAvgCount(n)) ?? 1), 1);
    final avgRounded = avg.round();

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nice!'),
        content: Text('You solved the $n-digit number in $guessesThisRound guesses.\n'
            'Stats — This round: $guessesThisRound · Best: $bestNow · Average: $avgRounded'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // go next or summary
    if (n < 8) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RoundPage(length: n + 1, dayNum: widget.dayNum),
        ),
      );
    } else {
      // end-of-day summary
      if (!mounted) return;
      await _showSummaryDialog();
    }
  }

  Future<void> _showSummaryDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final lines = <String>[];
    var todaySum = 0;
    var todayCount = 0;
    for (final n in _kLengths) {
      final g = prefs.getInt(_keyTodayCount(n));
      if (g != null) {
        lines.add('$n-digit: $g guesses');
        todaySum += g;
        todayCount += 1;
      } else {
        lines.add('$n-digit: —');
      }
    }
    final avgToday = todayCount == 0 ? '—' : (todaySum / todayCount).round().toString();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Today’s Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines) Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(l),
            ),
            const SizedBox(height: 8),
            Text('Average today: $avgToday'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const AttemptsPage()),
              );
            },
            child: const Text('View attempts'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).popUntil((r) => r.isFirst); // back to Home
            },
            child: const Text('Home'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final n = widget.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Day #${widget.dayNum} • $_kVersion'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ScaleTransition(
              scale: _scale,
              child: Chip(
                avatar: Icon(
                  _arrow == 0 ? Icons.remove : (_arrow > 0 ? Icons.arrow_upward : Icons.arrow_downward),
                  size: 16,
                  color: t.colorScheme.primary,
                ),
                label: Text(_arrow == 0 ? 'Equal' : (_arrow > 0 ? 'Higher' : 'Lower')),
                side: const BorderSide(color: Colors.transparent),
                backgroundColor: const Color(0xFFE7EBF5),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              showDialog(context: context, builder: (_) => const HowToDialog());
            },
            icon: const Icon(Icons.help_outline),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${n} / 8 digits today', style: t.textTheme.bodyMedium),
            const SizedBox(height: 8),
            // History (scrolls)
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                itemCount: _rows.length,
                itemBuilder: (c, i) {
                  final guess = _rows[i];
                  final sc = scoreGuess(_secret, guess);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _AttemptRow(
                      digits: guess,
                      score: sc,
                      len: n,
                    ),
                  );
                },
              ),
            ),
            // Current input row (not scrollable)
            const SizedBox(height: 8),
            _CurrentRow(
              entered: _current,
              len: n,
            ),
            const SizedBox(height: 12),
            // Keypad
            _Keypad(
              onDigit: _onDigit,
              onBackspace: _onBackspace,
              onEnter: _current.length == n ? _onEnter : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ===== UI pieces ============================================================

const _kGap = 8.0;
const _kTileGrey = Color(0xFFDDE0E6);
const _kTileGhost = Color(0xFFE7E8EE);
const _kTileGreen = Color(0xFF7DC57D);
const _kTileOrange = Color(0xFFFFB66B);

class _AttemptRow extends StatelessWidget {
  final List<int> digits;
  final List<int> score;
  final int len;
  const _AttemptRow({required this.digits, required this.score, required this.len});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final totalGaps = _kGap * (8 - 1);
    final size = ((width - 32 - totalGaps) / 8).clamp(36.0, 56.0);

    return Row(
      children: [
        for (int j = 0; j < len; j++)
          Padding(
            padding: EdgeInsets.only(right: j == len - 1 ? 0 : _kGap),
            child: _TileBox(
              size: size,
              label: digits[j].toString(),
              color: score[j] == 2
                  ? _kTileGreen
                  : score[j] == 1
                      ? _kTileOrange
                      : _kTileGrey,
            ),
          ),
        for (int j = 0; j < 8 - len; j++)
          Padding(
            padding: EdgeInsets.only(left: j == 0 ? _kGap : _kGap),
            child: _TileBox(
              size: size,
              label: '×',
              color: _kTileGhost,
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontWeight: FontWeight.w800,
                fontSize: size * 0.65, // bigger white X
              ),
              semanticsEnabled: false,
            ),
          ),
      ],
    );
  }
}

class _CurrentRow extends StatelessWidget {
  final List<int> entered;
  final int len;
  const _CurrentRow({required this.entered, required this.len});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final totalGaps = _kGap * (8 - 1);
    final size = ((width - 32 - totalGaps) / 8).clamp(36.0, 56.0);

    return Row(
      children: [
        for (int i = 0; i < len; i++)
          Padding(
            padding: EdgeInsets.only(right: i == len - 1 ? 0 : _kGap),
            child: _TileBox(
              size: size,
              label: i < entered.length ? entered[i].toString() : '',
              color: _kTileGrey,
            ),
          ),
        for (int j = 0; j < 8 - len; j++)
          Padding(
            padding: EdgeInsets.only(left: _kGap),
            child: _TileBox(
              size: size,
              label: '×',
              color: _kTileGhost,
              labelStyle: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontWeight: FontWeight.w800,
                fontSize: size * 0.65,
              ),
              semanticsEnabled: false,
            ),
          ),
      ],
    );
  }
}

class _TileBox extends StatelessWidget {
  final double size;
  final String label;
  final Color color;
  final TextStyle? labelStyle;
  final bool semanticsEnabled;
  const _TileBox({
    required this.size,
    required this.label,
    required this.color,
    this.labelStyle,
    this.semanticsEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsEnabled ? label : null,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: labelStyle ??
              TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: size * 0.5,
                color: Colors.black87,
              ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(int d) onDigit;
  final VoidCallback onBackspace;
  final Future<void> Function()? onEnter;
  const _Keypad({required this.onDigit, required this.onBackspace, required this.onEnter});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final btnStyle = FilledButton.styleFrom(
      backgroundColor: const Color(0xFFE9E9F0),
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      padding: const EdgeInsets.symmetric(vertical: 18),
    );
    Widget num(int d) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: FilledButton(
              style: btnStyle,
              onPressed: () => onDigit(d),
              child: Text('$d', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        );

    return Column(
      children: [
        Row(children: [num(1), num(2), num(3)]),
        Row(children: [num(4), num(5), num(6)]),
        Row(children: [num(7), num(8), num(9)]),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FilledButton(
                  style: btnStyle,
                  onPressed: onBackspace,
                  child: const Icon(Icons.backspace_outlined),
                ),
              ),
            ),
            num(0),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FilledButton(
                  style: btnStyle.copyWith(
                    backgroundColor: WidgetStatePropertyAll(
                        onEnter == null ? const Color(0xFFD8D8DF) : t.colorScheme.surfaceContainerHighest),
                    foregroundColor:
                        WidgetStatePropertyAll(onEnter == null ? Colors.grey : t.colorScheme.onSurfaceVariant),
                  ),
                  onPressed: onEnter,
                  child: const Text('Enter'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ===== Attempts page ========================================================

class AttemptsPage extends StatefulWidget {
  const AttemptsPage({super.key});

  @override
  State<AttemptsPage> createState() => _AttemptsPageState();
}

class _AttemptsPageState extends State<AttemptsPage> {
  Map<int, int> today = {};
  Map<int, int> best = {};
  Map<int, double> avg = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final t = <int, int>{};
    final b = <int, int>{};
    final a = <int, double>{};
    for (final n in _kLengths) {
      final tg = prefs.getInt(_keyTodayCount(n));
      if (tg != null) t[n] = tg;
      final be = prefs.getInt(_keyBest(n));
      if (be != null) b[n] = be;
      final plays = prefs.getInt(_keyAvgCount(n)) ?? 0;
      final sum = prefs.getInt(_keyAvgSum(n)) ?? 0;
      a[n] = plays == 0 ? 0 : sum / plays;
    }
    setState(() {
      today = t;
      best = b;
      avg = a;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Today’s attempts')),
      body: ListView.builder(
        itemCount: _kLengths.length,
        itemBuilder: (c, i) {
          final n = _kLengths[i];
          final lineToday = today.containsKey(n) ? '${today[n]} guesses' : '—';
          final lineBest = best.containsKey(n) ? best[n].toString() : '—';
          final lineAvg = (avg[n] ?? 0).toStringAsFixed(1);
          return ListTile(
            title: Text('$n-digit'),
            subtitle: Text('Today: $lineToday • Best: $lineBest • Avg: $lineAvg'),
          );
        },
      ),
    );
  }
}
