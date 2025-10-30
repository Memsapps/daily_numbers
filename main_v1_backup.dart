import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const DailyNumbersApp());
}

class DailyNumbersApp extends StatelessWidget {
  const DailyNumbersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daily Numbers — demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        dialogTheme: const DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// ---------------------------
/// Simple in-memory game state
/// ---------------------------
class GameState {
  GameState._();
  static final GameState I = GameState._();

  // Per-day key like 20250923
  String todayKey = _yyyymmdd(DateTime.now());

  // Secrets per length 3..8 (computed lazily for today)
  final Map<int, String> _secrets = {};

  // History per round length
  final Map<int, List<GuessRow>> history = {for (var n in [3,4,5,6,7,8]) n: []};

  // Largest N solved today (0 if none). (Memory only for this demo.)
  int completedUpTo = 0;

  void resetIfNewDay() {
    final nowKey = _yyyymmdd(DateTime.now());
    if (nowKey != todayKey) {
      todayKey = nowKey;
      _secrets.clear();
      history.values.forEach((list) => list.clear());
      completedUpTo = 0;
    }
  }

  String secretFor(int length) {
    return _secrets.putIfAbsent(length, () => _dailySecretForLength(todayKey, length));
  }

  static String _yyyymmdd(DateTime dt) {
    String two(int v) => v < 10 ? '0$v' : '$v';
    return '${dt.year}${two(dt.month)}${two(dt.day)}';
  }

  // Deterministic digits by date + length (keeps leading zeros)
  static String _dailySecretForLength(String todayKey, int length) {
    // Simple non-crypto LCG with seed from todayKey+length (no imports)
    int seed = 0;
    for (int i = 0; i < todayKey.length; i++) {
      seed = (seed * 131 + todayKey.codeUnitAt(i)) & 0x7fffffff;
    }
    seed = (seed * 131 + length) & 0x7fffffff;
    final buf = StringBuffer();
    for (int i = 0; i < length; i++) {
      seed = (1103515245 * seed + 12345) & 0x7fffffff;
      buf.write((seed % 10).toString());
    }
    return buf.toString();
  }
}

class GuessRow {
  GuessRow({required this.guess, required this.tiles, required this.arrow});
  final String guess;        // e.g., "012"
  final List<int> tiles;     // 0=grey,1=orange,2=green
  final String arrow;        // 'up' | 'down' | '' (equal)
}

/// ---------------------------
/// Home
/// ---------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _timer;
  int _secs = _secondsUntilLocalMidnight();

  @override
  void initState() {
    super.initState();
    GameState.I.resetIfNewDay();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = _secs - 1;
      if (next <= 0) {
        setState(() {
          GameState.I.resetIfNewDay();
          _secs = _secondsUntilLocalMidnight();
        });
      } else {
        setState(() => _secs = next);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static int _secondsUntilLocalMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now).inSeconds;
  }

  String _hhmmss(int s) {
    String two(int v) => v < 10 ? '0$v' : '$v';
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final ss = s % 60;
    return '${two(h)}:${two(m)}:${two(ss)}';
  }

  // Simple day ordinal for title (days since 2025-01-01)
  String _dayOrdinal() {
    final base = DateTime(2025, 1, 1);
    final today = DateTime.now();
    final days = today.difference(base).inDays + 1;
    return '#$days';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Numbers — demo'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text(
                    'Play today’s rounds (3–8)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(_hhmmss(_secs), style: const TextStyle(fontFeatures: [])),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final startN = GameState.I.completedUpTo == 0
                      ? 3
                      : (GameState.I.completedUpTo < 8 ? GameState.I.completedUpTo + 1 : 8);
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RoundPage(n: startN, dayOrdinal: _dayOrdinal()),
                  ));
                },
                child: const Text('Play today’s rounds'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _showHowTo(context),
                child: const Text('How to Play'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('How to Play'),
        content: const Text(
          "- Guess the secret number.\n"
          "- Colors: Green = correct place; Orange = wrong place; Grey = not present.\n"
          "- Arrow shows whether your whole guess is lower (↑) or higher (↓). When equal, no arrow.\n"
          "- Some digits can appear more than once.\n"
          "- Enter is only enabled when the row has exactly N digits.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

/// ---------------------------
/// Round page
/// ---------------------------
class RoundPage extends StatefulWidget {
  const RoundPage({super.key, required this.n, required this.dayOrdinal});
  final int n;
  final String dayOrdinal;

  @override
  State<RoundPage> createState() => _RoundPageState();
}

class _RoundPageState extends State<RoundPage> {
  final ScrollController _scroll = ScrollController();
  String entry = '';

  @override
  Widget build(BuildContext context) {
    final gs = GameState.I;
    gs.resetIfNewDay();
    final secret = gs.secretFor(widget.n);
    final rows = gs.history[widget.n]!;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: Text('Day ${widget.dayOrdinal} — ${widget.n}-digit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHowTo(context),
            tooltip: 'How to Play',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // History + entry list
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: rows.length + 1,
                itemBuilder: (context, index) {
                  if (index < rows.length) {
                    final r = rows[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GuessRowWidget(
                        n: widget.n,
                        digits: r.guess.characters.toList(),
                        colors: r.tiles,
                        arrow: r.arrow,
                      ),
                    );
                  } else {
                    // Entry row (neutral)
                    final chars = entry.padRight(widget.n).characters.toList();
                    return _EntryRowWidget(n: widget.n, digits: chars);
                  }
                },
              ),
            ),

            // Keypad
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(top: BorderSide(color: cs.outlineVariant)),
              ),
              child: SafeArea(
                top: false,
                child: _Keypad(
                  onDigit: (d) {
                    if (entry.length < widget.n) {
                      setState(() => entry = '$entry$d');
                    }
                  },
                  onBackspace: () {
                    if (entry.isNotEmpty) setState(() => entry = entry.substring(0, entry.length - 1));
                  },
                  onEnter: entry.length == widget.n
                      ? () {
                          final tiles = _scoreTiles(secret, entry);
                          final arrow = _compareArrow(secret, entry); // '' when equal
                          rows.add(GuessRow(guess: entry, tiles: tiles, arrow: arrow));
                          setState(() => entry = '');
                          // scroll to bottom after frame
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_scroll.hasClients) {
                              _scroll.animateTo(
                                _scroll.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                              );
                            }
                          });

                          if (arrow.isEmpty) {
                            // Solved
                            GameState.I.completedUpTo = widget.n > GameState.I.completedUpTo
                                ? widget.n
                                : GameState.I.completedUpTo;
                            _showWin(context, guesses: rows.length);
                          }
                        }
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHowTo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('How to Play'),
        content: Text(
          "- Guess the secret number.\n"
          "- Colors: Green = correct place; Orange = wrong place; Grey = not present.\n"
          "- Arrow shows whether your whole guess is lower (↑) or higher (↓). When equal, no arrow.\n"
          "- Some digits can appear more than once.\n"
          "- Enter is only enabled when the row has exactly N digits.",
        ),
      ),
    );
  }

  void _showWin(BuildContext context, {required int guesses}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Nice!'),
        content: Text('You solved the ${widget.n}-digit number in $guesses guesses.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog
              if (widget.n < 8) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RoundPage(n: widget.n + 1, dayOrdinal: _dayOrdinal()),
                  ),
                );
              } else {
                // After 8-digit, return Home
                Navigator.pop(context);
              }
            },
            child: const Text('Play next'),
          ),
        ],
      ),
    );
  }

  String _dayOrdinal() {
    final base = DateTime(2025, 1, 1);
    final today = DateTime.now();
    final days = today.difference(base).inDays + 1;
    return '#$days';
  }
}

/// ---------------------------
/// Widgets for rows/keypad
/// ---------------------------

class _GuessRowWidget extends StatelessWidget {
  const _GuessRowWidget({
    required this.n,
    required this.digits,
    required this.colors,
    required this.arrow,
  });

  final int n;
  final List<String> digits;
  final List<int> colors; // 0 grey, 1 orange, 2 green
  final String arrow;     // 'up' | 'down' | ''

  static const double _arrowWidth = 40;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    assert(digits.length == n && colors.length == n);
    final cs = Theme.of(context).colorScheme;

    Color tileColor(int state) {
      switch (state) {
        case 2: return const Color(0xFFBFE8C0); // green
        case 1: return const Color(0xFFFFD49C); // orange
        default: return const Color(0xFFE9E7EE); // grey
      }
    }

    Widget arrowWidget() {
      if (arrow == 'up') return const Icon(Icons.arrow_upward);
      if (arrow == 'down') return const Icon(Icons.arrow_downward);
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final available = total - _arrowWidth - _gap * (n - 1);
        final double size = (available / n).floorToDouble();
        final leftWidth = size * n + _gap * (n - 1);

        List<Widget> tiles = [];
        for (int i = 0; i < n; i++) {
          tiles.add(Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tileColor(colors[i]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              digits[i],
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ));
          if (i != n - 1) tiles.add(const SizedBox(width: _gap));
        }

        return Row(
          children: [
            SizedBox(width: leftWidth, child: Row(children: tiles)),
            const Spacer(),
            SizedBox(
              width: _arrowWidth,
              child: Center(
                child: IconTheme(
                  data: IconThemeData(color: cs.onSurfaceVariant),
                  child: arrowWidget(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EntryRowWidget extends StatelessWidget {
  const _EntryRowWidget({required this.n, required this.digits});
  final int n;
  final List<String> digits;

  static const double _arrowWidth = 40;
  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final available = total - _arrowWidth - _gap * (n - 1);
        final double size = (available / n).floorToDouble();
        final leftWidth = size * n + _gap * (n - 1);

        List<Widget> tiles = [];
        for (int i = 0; i < n; i++) {
          final ch = i < digits.length ? digits[i] : '';
          tiles.add(Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE9E7EE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Text(
              ch,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ));
          if (i != n - 1) tiles.add(const SizedBox(width: _gap));
        }

        return Row(
          children: [
            SizedBox(width: leftWidth, child: Row(children: tiles)),
            const Spacer(),
            const SizedBox(width: _arrowWidth), // empty gutter
          ],
        );
      },
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onEnter,
  });

  final void Function(int d) onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onEnter;

  Widget _padButton(BuildContext context, String label, {VoidCallback? onTap}) {
    final enabled = onTap != null;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              color: enabled ? null : Theme.of(context).disabledColor,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _padButton(context, '1', onTap: () => onDigit(1)),
            _padButton(context, '2', onTap: () => onDigit(2)),
            _padButton(context, '3', onTap: () => onDigit(3)),
          ],
        ),
        Row(
          children: [
            _padButton(context, '4', onTap: () => onDigit(4)),
            _padButton(context, '5', onTap: () => onDigit(5)),
            _padButton(context, '6', onTap: () => onDigit(6)),
          ],
        ),
        Row(
          children: [
            _padButton(context, '7', onTap: () => onDigit(7)),
            _padButton(context, '8', onTap: () => onDigit(8)),
            _padButton(context, '9', onTap: () => onDigit(9)),
          ],
        ),
        Row(
          children: [
            _padButton(context, '⌫', onTap: onBackspace),
            _padButton(context, '0', onTap: () => onDigit(0)),
            _padButton(context, 'Enter', onTap: onEnter),
          ],
        ),
      ],
    );
  }
}

/// ---------------------------
/// Core logic (two-pass + arrow)
/// ---------------------------

List<int> _scoreTiles(String secret, String guess) {
  final n = secret.length;
  final result = List<int>.filled(n, 0); // 0 grey, 1 orange, 2 green
  final counts = List<int>.filled(10, 0);
  for (var i = 0; i < n; i++) {
    counts[int.parse(secret[i])] += 1;
  }
  // pass 1: greens
  for (var i = 0; i < n; i++) {
    if (guess[i] == secret[i]) {
      result[i] = 2;
      final d = int.parse(guess[i]);
      counts[d] -= 1;
    }
  }
  // pass 2: oranges
  for (var i = 0; i < n; i++) {
    if (result[i] == 0) {
      final d = int.parse(guess[i]);
      if (counts[d] > 0) {
        result[i] = 1;
        counts[d] -= 1;
      }
    }
  }
  return result;
}

// Returns 'up' if guess < secret, 'down' if guess > secret, '' if equal
String _compareArrow(String secret, String guess) {
  final s = int.parse(secret);
  final g = int.parse(guess);
  if (g < s) return 'up';
  if (g > s) return 'down';
  return '';
}
