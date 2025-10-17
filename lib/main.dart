// main.dart — Board scroll + top status arrow (no side arrows), ghost tiles to 8-wide.
// Flutter 3.32.x / Dart 3.9.x compatible.
// Requires: shared_preferences in pubspec.yaml

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DailyNumbersApp());
}

/// === Brand palette (neutral; no seeded M3 purple) ===
const kBg      = Color(0xFFF3F4F6); // page background
const kSurface = Color(0xFFFFFFFF); // dialogs/cards
const kText    = Color(0xFF111827); // near-black text
const kKeyBg   = Color(0xFFE9E7EE); // keypad/neutral buttons

// Tile swatches (soft, readable)
const kTileGreen  = Color(0xFFBFE8C0); // correct place
const kTileOrange = Color(0xFFFFD49C); // wrong place
const kTileGrey   = Color(0xFFE9E7EE); // not present
const kTileGhost  = Color(0xFFD8DADF); // ghost (unused columns), shows ×

// Status colours
const kBlueHigher = Color(0xFF2563EB);
const kRedLower   = Color(0xFFDC2626);
const kGreenOk    = Color(0xFF16A34A);

class DailyNumbersApp extends StatelessWidget {
  const DailyNumbersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Daily Numbers — demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          background: kBg,
          surface: kSurface,
          primary: Colors.black87,
          onBackground: kText,
          onSurface: kText,
          onPrimary: Colors.white,
        ),
        scaffoldBackgroundColor: kBg,
        dialogTheme: const DialogThemeData(
          backgroundColor: kSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kBg,
          foregroundColor: kText,
          elevation: 0,
        ),
        // Keypad & filled buttons: neutral key colour
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: kKeyBg,
            foregroundColor: kText,
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            minimumSize: const Size(88, 56),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: kText,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        textTheme: const TextTheme().apply(
          bodyColor: kText,
          displayColor: kText,
        ),
      ),
      home: const HomePage(),
    );
  }
}

// === Feature flags (OFF — placeholders) ========================================================
const bool adsEnabled = false;
const bool premiumEnabled = false;

// === Keys & constants ==========================================================================
const _kCompletedUpTo = 'completedUpTo';        // int (largest N solved today)
const _kTodayKey = 'todayKey';                  // string YYYYMMDD
const _kHasSeenHowTo = 'hasSeenHowTo';          // bool (first-run dialog)

String _kBestLen(int n) => 'best_len$n';        // int
String _kPlaysLen(int n) => 'plays_len$n';      // int
String _kTotalGuessesLen(int n) => 'totalGuesses_len$n'; // int
String _kTodayGuessesLen(int n) => 'today_guesses_len$n'; // int

const List<int> _roundLengths = [3, 4, 5, 6, 7, 8];
const int _boardMaxColumns = 8; // always render 8 columns (ghost tiles for the rest)
const double _gap = 8.0;

String _todayKey(DateTime now) {
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y$m$d';
}

int _dayNumber(DateTime now) {
  final start = DateTime(2023, 12, 1);
  return now.difference(DateTime(start.year, start.month, start.day)).inDays + 1;
}

// === HOME ======================================================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Timer _timer;
  Duration _remaining = Duration.zero;
  int _completedUpTo = 0;
  bool _hasSeenHowTo = false;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _initPrefs().then((_) => _tickCountdown());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
        _tickCountdown();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _initPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey(DateTime.now());
    final stored = prefs.getString(_kTodayKey);
    if (stored != today) {
      await prefs.setString(_kTodayKey, today);
      await prefs.setInt(_kCompletedUpTo, 0);
      for (final n in _roundLengths) {
        await prefs.setInt(_kTodayGuessesLen(n), 0);
      }
    }
    _completedUpTo = prefs.getInt(_kCompletedUpTo) ?? 0;
    _hasSeenHowTo = prefs.getBool(_kHasSeenHowTo) ?? false;
    if (mounted) setState(() {});
  }

  void _tickCountdown() {
    final midnight = DateTime(_now.year, _now.month, _now.day).add(const Duration(days: 1));
    _remaining = midnight.difference(_now);
  }

  String _formatDur(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  int _nextIncompleteLength() {
    for (final n in _roundLengths) {
      if (n > _completedUpTo) return n;
    }
    return 8;
  }

  Future<void> _onPlayTap() async {
    if (!_hasSeenHowTo) {
      final res = await showDialog<_HowToResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _HowToDialog(firstRun: true),
      );
      if (res == _HowToResult.cancelled) return;
      if (res == _HowToResult.okDontShow) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kHasSeenHowTo, true);
        _hasSeenHowTo = true;
      }
    }

    final nextLen = _nextIncompleteLength();
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final finished = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RoundPage(length: nextLen, dayNumber: _dayNumber(DateTime.now())),
      ),
    );
    if (finished == true) {
      final completedUpTo = prefs.getInt(_kCompletedUpTo) ?? 0;
      setState(() => _completedUpTo = completedUpTo);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dayNo = _dayNumber(_now);
    final finishedAll = _completedUpTo >= 8;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Numbers — demo'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAEAF1).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text(
                  'New challenge in ${_formatDur(_remaining)}',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6E7782)),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Play today’s rounds (3–8) — Day #$dayNo',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _onPlayTap,
                child: Text(finishedAll ? 'Replay today' : 'Play'),
              ),
              const Spacer(),
              if (adsEnabled) ...[
                const SizedBox(height: 8),
                Container(
                  height: 60,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black26),
                  ),
                  child: const Text('Ad banner (disabled)'),
                ),
              ] else
                const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

// === ROUND =====================================================================================
enum RoundStatus { neutral, higher, lower, correct }

class RoundPage extends StatefulWidget {
  final int length;
  final int dayNumber;
  const RoundPage({super.key, required this.length, required this.dayNumber});

  @override
  State<RoundPage> createState() => _RoundPageState();
}

class _RoundPageState extends State<RoundPage> {
  late String _secret;
  final List<String> _rows = [];
  String _entry = '';

  final ScrollController _scrollController = ScrollController();
  RoundStatus _status = RoundStatus.neutral;

  @override
  void initState() {
    super.initState();
    _secret = _generateSecretForLength(widget.length);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _generateSecretForLength(int len) {
    final now = DateTime.now();
    final key = _todayKey(now);
    final seed = _hash('$key-$len');
    final rnd = Random(seed);
    final buf = StringBuffer();
    for (int i = 0; i < len; i++) {
      buf.write(rnd.nextInt(10));
    }
    return buf.toString();
  }

  int _hash(String s) {
    int h = 0;
    for (final c in s.codeUnits) {
      h = (h * 131 + c) & 0x7fffffff;
    }
    return h;
  }

  List<int> _score(String secret, String guess) {
    final n = secret.length;
    final res = List<int>.filled(n, 0); // 0 grey, 1 orange, 2 green
    final count = List<int>.filled(10, 0);
    for (int i = 0; i < n; i++) {
      count[int.parse(secret[i])]++;
    }
    for (int i = 0; i < n; i++) {
      if (guess[i] == secret[i]) {
        res[i] = 2;
        count[int.parse(guess[i])]--;
      }
    }
    for (int i = 0; i < n; i++) {
      if (res[i] == 0) {
        final d = int.parse(guess[i]);
        if (count[d] > 0) {
          res[i] = 1;
          count[d]--;
        }
      }
    }
    return res;
  }

  Future<void> _submit() async {
    if (_entry.length != widget.length) {
      HapticFeedback.selectionClick();
      return;
    }
    final guess = _entry;
    setState(() {
      _rows.add(guess);
      _entry = '';
    });

    // Update top status
    final s = int.parse(_secret);
    final g = int.parse(guess);
    setState(() {
      if (g == s) {
        _status = RoundStatus.correct;
      } else if (g < s) {
        _status = RoundStatus.higher;
      } else {
        _status = RoundStatus.lower;
      }
    });

    // Auto-scroll to bottom after a short delay to ensure the new item laid out
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });

    if (g == s) {
      final prefs = await SharedPreferences.getInstance();
      // Update lifetime stats
      final bestKey = _kBestLen(widget.length);
      final playsKey = _kPlaysLen(widget.length);
      final totalKey = _kTotalGuessesLen(widget.length);

      final best = prefs.getInt(bestKey) ?? 0;
      final plays = (prefs.getInt(playsKey) ?? 0) + 1;
      final total = (prefs.getInt(totalKey) ?? 0) + _rows.length;

      final newBest = (best == 0) ? _rows.length : (_rows.length < best ? _rows.length : best);

      await prefs.setInt(playsKey, plays);
      await prefs.setInt(totalKey, total);
      await prefs.setInt(bestKey, newBest);

      // Update today's per-length guesses
      await prefs.setInt(_kTodayGuessesLen(widget.length), _rows.length);

      // mark completion for this length
      final current = prefs.getInt(_kCompletedUpTo) ?? 0;
      final nextVal = max(current, widget.length);
      await prefs.setInt(_kCompletedUpTo, nextVal);

      await _showWin();
    }
  }

  Future<void> _showWin() async {
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt(_kBestLen(widget.length)) ?? 0;
    final plays = prefs.getInt(_kPlaysLen(widget.length)) ?? 0;
    final total = prefs.getInt(_kTotalGuessesLen(widget.length)) ?? 0;
    final avg = (plays > 0) ? (total / plays).round() : _rows.length;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Nice!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You solved the ${widget.length}-digit number in ${_rows.length} guesses.'),
            const SizedBox(height: 10),
            Text(
              'Stats — This round: ${_rows.length} · Best: $best · Average: $avg',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6E7782)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              if (widget.length < 8) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoundPage(length: widget.length + 1, dayNumber: widget.dayNumber),
                  ),
                );
              } else {
                _showEndOfDay();
              }
            },
            child: Text(widget.length < 8 ? 'Play next' : 'Finish'),
          )
        ],
      ),
    );
  }

  Future<void> _showEndOfDay() async {
    final prefs = await SharedPreferences.getInstance();
    final todayGuesses = <int, int>{};
    int sum = 0;
    int count = 0;
    for (final n in _roundLengths) {
      final g = prefs.getInt(_kTodayGuessesLen(n)) ?? 0;
      todayGuesses[n] = g;
      if (g > 0) {
        sum += g;
        count += 1;
      }
    }
    final avgToday = count > 0 ? (sum / count).round() : 0;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Today's summary"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final n in _roundLengths) Text('${n}-digit: ${todayGuesses[n] ?? 0} guesses'),
            const SizedBox(height: 8),
            Text('Average today: $avgToday'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close summary
              Navigator.pop(context, true); // pop RoundPage, notify Home
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onDigit(int d) {
    if (_entry.length >= widget.length) return;
    setState(() => _entry += d.toString());
  }

  void _onBackspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final title = 'Day #${widget.dayNumber} — ${widget.length}-digit';

    // Build top animated status pill (in AppBar.actions)
    Widget statusPill() {
      String label = '';
      Color c = kText;
      IconData? icon;
      switch (_status) {
        case RoundStatus.higher:
          label = 'Higher';
          c = kBlueHigher;
          icon = Icons.arrow_upward;
          break;
        case RoundStatus.lower:
          label = 'Lower';
          c = kRedLower;
          icon = Icons.arrow_downward;
          break;
        case RoundStatus.correct:
          label = 'Correct!';
          c = kGreenOk;
          icon = Icons.check;
          break;
        case RoundStatus.neutral:
          label = '';
          icon = null;
      }
      if (icon == null) return const SizedBox.shrink();
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kKeyBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.withOpacity(0.6)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: c),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: kText, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: FadeTransition(opacity: anim, child: child)),
                child: KeyedSubtree(
                  key: ValueKey(_status),
                  child: statusPill(),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () async {
              final res = await showDialog<_HowToResult>(
                context: context,
                builder: (_) => const _HowToDialog(firstRun: false),
              );
              if (res == _HowToResult.okDontShow) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(_kHasSeenHowTo, true);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Optional tiny legend for ghost tiles
              if (widget.length < _boardMaxColumns)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0, left: 2),
                  child: Text(
                    '${widget.length} / $_boardMaxColumns digits today',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6E7782)),
                  ),
                ),
              // History (scrollable)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    // Always compute size for 8 columns (ghost tiles fill the rest)
                    final double available = c.maxWidth;
                    final double size = ((available - _gap * (_boardMaxColumns - 1)) / _boardMaxColumns)
                        .clamp(36.0, 56.0);
                    return ListView.builder(
                      controller: _scrollController,
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final guess = _rows[index];
                        final score = _score(_secret, guess);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              // Active N tiles
                              for (int i = 0; i < widget.length; i++)
                                Padding(
                                  padding: EdgeInsets.only(right: i == widget.length - 1 ? 0 : _gap),
                                  child: _TileBox(
                                    size: size,
                                    label: guess[i],
                                    color: score[i] == 2
                                        ? kTileGreen
                                        : score[i] == 1
                                            ? kTileOrange
                                            : kTileGrey,
                                  ),
                                ),
                              // Ghost tiles to reach 8-wide
                              for (int i = 0; i < _boardMaxColumns - widget.length; i++)
                                Padding(
                                  padding: EdgeInsets.only(left: _gap),
                                  child: _TileBox(
                                    size: size,
                                    label: '×',
                                    color: kTileGhost,
                                    labelStyle: const TextStyle(
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    semanticsEnabled: false,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              // Current entry row (non-scroll)
              LayoutBuilder(
                builder: (context, c) {
                  final double available = c.maxWidth;
                  final double size = ((available - _gap * (_boardMaxColumns - 1)) / _boardMaxColumns)
                      .clamp(36.0, 56.0);
                  return Row(
                    children: [
                      for (int i = 0; i < widget.length; i++)
                        Padding(
                          padding: EdgeInsets.only(right: i == widget.length - 1 ? 0 : _gap),
                          child: _TileBox(
                            size: size,
                            label: i < _entry.length ? _entry[i] : '',
                            color: kTileGrey,
                          ),
                        ),
                      for (int i = 0; i < _boardMaxColumns - widget.length; i++)
                        Padding(
                          padding: EdgeInsets.only(left: _gap),
                          child: _TileBox(
                            size: size,
                            label: '×',
                            color: kTileGhost,
                            labelStyle: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                            semanticsEnabled: false,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              _Keypad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                onEnter: _entry.length == widget.length ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// === HOW TO PLAY DIALOG (UK copy + "Don't show again") ========================================
enum _HowToResult { ok, okDontShow, cancelled }

class _HowToDialog extends StatefulWidget {
  final bool firstRun;
  const _HowToDialog({required this.firstRun});

  @override
  State<_HowToDialog> createState() => _HowToDialogState();
}

class _HowToDialogState extends State<_HowToDialog> {
  bool _dontShow = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('How to Play'),
      content: const SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('- Guess the secret number.'),
            SizedBox(height: 8),
            Text('- Colours: Green = correct place; Orange = wrong place; Grey = not present.'),
            SizedBox(height: 8),
            Text('- The arrow shows whether your whole guess is lower (↑) or higher (↓). When equal, no arrow.'),
            SizedBox(height: 8),
            Text('- Enter is only enabled when the row is filled.'),
            SizedBox(height: 8),
            Text('- Some digits may appear more than once...'),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Checkbox(
                    value: _dontShow,
                    onChanged: (v) => setState(() => _dontShow = v ?? false),
                  ),
                  const Flexible(child: Text("Don't show again")),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(_dontShow ? _HowToResult.okDontShow : _HowToResult.ok);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ],
    );
  }
}

// === WIDGETS: Tile & Keypad ====================================================================
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
    final tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          label,
          style: labelStyle ?? const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
    if (!semanticsEnabled) return ExcludeSemantics(child: tile);
    return tile;
  }
}

class _Keypad extends StatelessWidget {
  final void Function(int) onDigit;
  final VoidCallback onBackspace;
  final Future<void> Function()? onEnter;
  const _Keypad({required this.onDigit, required this.onBackspace, required this.onEnter});

  @override
  Widget build(BuildContext context) {
    final keys = [
      [1, 2, 3],
      [4, 5, 6],
      [7, 8, 9],
    ];
    return Column(
      children: [
        for (final row in keys)
          Row(
            children: [
              for (final k in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: FilledButton.tonal(
                      onPressed: () => onDigit(k),
                      child: Text('$k'),
                    ),
                  ),
                ),
            ],
          ),
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: FilledButton.tonal(
                  onPressed: onBackspace,
                  child: const Icon(Icons.backspace_outlined),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: FilledButton.tonal(
                  onPressed: () => onDigit(0),
                  child: const Text('0'),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: FilledButton(
                  onPressed: onEnter == null ? null : () => onEnter!(),
                  child: const Text('Enter'),
                ),
              ),
            ),
          ],
        )
      ],
    );
  }
}
