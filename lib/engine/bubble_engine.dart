import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Board cell in (col, row) with offset-row hex packing:
/// even rows have [_cols] cells, odd rows [_cols]-1.
const bubbleCols = 9;

/// Engine-owned shot phases. The UI only renders and pumps [update];
/// the engine settles every transition on its own timers. Stuck states are
/// impossible by construction: a watchdog recovers any phase found without
/// a live timer or flight.
enum BubblePhase { aiming, flying, settling, levelClear, over }

/// Events the screen turns into sounds/haptics.
enum BubbleEvent {
  click,
  shoot,
  bounce,
  snap,
  pop, // value = combo (for pitch)
  drop,
  swap,
  miss,
  invalid,
  ceiling,
  levelClear,
  gameWon,
  gameLost,
}

class _Flight {
  Offset pos;
  Offset vel;
  final int colorIdx;
  _Flight(this.pos, this.vel, this.colorIdx);
}

class BubbleEngine extends ChangeNotifier {
  /// 0 = easy, 1 = normal, 2 = hard. Hard is a Pro feature (enforced in UI).
  final int difficulty;
  /// 0 = 30 progressive levels, 1 = endless score attack.
  final int mode;

  static const maxLevel = 30;

  final Random _rand;
  final Map<Point<int>, int> grid = {}; // cell -> color index

  BubblePhase phase = BubblePhase.aiming;
  bool paused = false;
  bool over = false;
  bool won = false;

  int level = 1;
  int score = 0;
  int shots = 0;
  int combo = 0;
  int pops = 0;
  int maxCombo = 0;
  String banner = '';

  /// Aim angle in radians (straight up = -pi/2). UI sets via [setAim].
  double aim = -pi / 2;

  int current = 0; // color index loaded in the launcher
  int next = 1; // color index on deck

  /// Cells popped by the last snap, for the UI's pop animation.
  List<(Offset pos, int colorIdx)> lastPops = [];
  /// Cells dropped (floaters) by the last snap.
  List<(Offset pos, int colorIdx)> lastDrops = [];

  _Flight? _flight;
  Size _board = Size.zero;
  double _r = 16; // bubble radius
  int _maxRows = 14;
  int _deathRow = 11;

  Timer? _timer; // single phase-transition timer
  Timer? _watchdog; // stuck-state recovery
  bool _disposed = false;

  /// UI hook for sounds / haptics. Set by the screen.
  void Function(BubbleEvent event, int value)? onEvent;

  // ------------------------------------------------------------- tuning
  double get _speed => switch (difficulty) {
        0 => 520.0,
        2 => 740.0,
        _ => 620.0,
      };
  int get _maxColors => switch (difficulty) {
        0 => 4,
        2 => 6,
        _ => 5,
      };
  int get _dropEvery => switch (difficulty) {
        0 => 7,
        2 => 5,
        _ => 6,
      };

  /// Color indices available at the current level/mode.
  List<int> get levelColors {
    if (mode == 1) {
      // Endless: palette grows with score.
      final n = (3 + score ~/ 900).clamp(3, _maxColors);
      return List.generate(n, (i) => i);
    }
    final n = (3 + level ~/ 5).clamp(3, _maxColors);
    return List.generate(n, (i) => i);
  }

  /// Ceiling drop cadence (every N shots) for endless mode.
  int get endlessDropEvery => max(4, 7 - score ~/ 1500);

  BubbleEngine(
      {this.difficulty = 1, this.mode = 0, int? seed, String playerName = ''})
      : _rand = Random(seed) {
    banner = mode == 1 ? 'Endless — pop till you drop!' : 'Level 1 — pop away!';
    _buildLevel();
    _watchdog = Timer.periodic(const Duration(seconds: 3), (_) => _recover());
  }

  // ------------------------------------------------------------- geometry
  void setBoardSize(Size s) {
    if (s == _board || s == Size.zero) return;
    _board = s;
    _r = s.width / (bubbleCols * 2 + 1);
    _maxRows = ((_board.height - 120 - _topPad) / _rowH).ceil() + 2;
    _deathRow = ((_board.height - 120 - _topPad) / _rowH).floor() + 1;
    notifyListeners();
  }

  double get r => _r;
  double get _topPad => 10.0;
  double get _rowH => _r * 1.732;
  double get deathY => _topPad + _deathRow * _rowH;
  double get shooterY => _board.height - 64;
  double get boardW => _board.width;

  int _colsForRow(int row) => row.isEven ? bubbleCols : bubbleCols - 1;

  bool _inBounds(Point<int> p) =>
      p.y >= 0 && p.y < _maxRows && p.x >= 0 && p.x < _colsForRow(p.y);

  Offset centerOf(Point<int> p) => Offset(
      _r + p.x * 2 * _r + (p.y.isOdd ? _r : 0), _topPad + _r + p.y * _rowH);

  List<Point<int>> _neighbors(Point<int> p) {
    final even = p.y.isEven;
    final d = even
        ? const [
            Point(-1, -1),
            Point(0, -1),
            Point(-1, 0),
            Point(1, 0),
            Point(-1, 1),
            Point(0, 1)
          ]
        : const [
            Point(0, -1),
            Point(1, -1),
            Point(-1, 0),
            Point(1, 0),
            Point(0, 1),
            Point(1, 1)
          ];
    return [for (final o in d) Point(p.x + o.x, p.y + o.y)]
        .where(_inBounds)
        .toList();
  }

  // ------------------------------------------------------------- setup
  void _buildLevel() {
    grid.clear();
    _flight = null;
    phase = BubblePhase.aiming;
    shots = 0;
    combo = 0;
    final colors = levelColors;
    final rows = mode == 1 ? 4 : min(3 + level ~/ 4, 7);
    for (var row = 0; row < rows; row++) {
      for (var c = 0; c < _colsForRow(row); c++) {
        grid[Point(c, row)] = colors[_rand.nextInt(colors.length)];
      }
    }
    current = colors[_rand.nextInt(colors.length)];
    next = colors[_rand.nextInt(colors.length)];
    banner = mode == 1 ? 'Pop till you drop!' : 'Level $level';
    notifyListeners();
  }

  /// Test hook: force the loaded colors.
  @visibleForTesting
  void forceColors(int cur, int nxt) {
    current = cur;
    next = nxt;
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _watchdog?.cancel();
    super.dispose();
  }

  void _arm(Duration d, void Function() fn) {
    if (_disposed || paused) return;
    _timer?.cancel();
    _timer = Timer(d, () {
      _timer = null;
      if (!_disposed && !paused) fn();
    });
  }

  /// Pause: freeze the phase timer and flight updates.
  void setPaused(bool v) {
    if (paused == v || _disposed) return;
    paused = v;
    if (v) {
      _timer?.cancel();
      _timer = null;
    } else {
      _recover();
    }
    notifyListeners();
  }

  /// Watchdog: if the single phase timer ever dies without progress, recover.
  /// This makes stuck states impossible by construction. Respects [paused].
  void _recover() {
    if (_disposed || over || paused || _timer != null) return;
    switch (phase) {
      case BubblePhase.flying:
        if (_flight == null) {
          // Ball vanished mid-flight: back to aiming, shot refunded.
          phase = BubblePhase.aiming;
          banner = 'Back on aim — fire when ready!';
          notifyListeners();
        }
      case BubblePhase.settling:
        _finishSettle();
      case BubblePhase.levelClear:
        _advanceLevel();
      case BubblePhase.aiming:
      case BubblePhase.over:
        break; // legal resting states
    }
  }

  // ------------------------------------------------------------- actions
  /// UI sets the aim angle (clamped to upward cone).
  void setAim(double a) {
    aim = a.clamp(-pi + 0.22, -0.22);
  }

  /// Swap the loaded bubble with the one on deck (aiming only).
  void swap() {
    if (over || paused || phase != BubblePhase.aiming) {
      onEvent?.call(BubbleEvent.invalid, 0);
      return;
    }
    final t = current;
    current = next;
    next = t;
    onEvent?.call(BubbleEvent.swap, 0);
    notifyListeners();
  }

  /// Fire the loaded bubble along the aim. Guarded: aiming phase only, one
  /// ball in flight at a time — double-fire is impossible by construction.
  void fire() {
    if (over || paused || phase != BubblePhase.aiming || _flight != null) {
      onEvent?.call(BubbleEvent.invalid, 0);
      return;
    }
    final from = Offset(_board.width / 2, shooterY);
    final dir = Offset(cos(aim), sin(aim));
    _flight = _Flight(from, dir * _speed, current);
    current = next;
    next = _pickNextColor();
    phase = BubblePhase.flying;
    onEvent?.call(BubbleEvent.shoot, 0);
    notifyListeners();
  }

  int _pickNextColor() {
    final colors = levelColors;
    final boardColors = grid.values.toSet();
    final pool = boardColors.isEmpty ? colors : boardColors.toList();
    return pool[_rand.nextInt(pool.length)];
  }

  /// Per-frame pump from the screen's ticker. Engine-owned physics.
  void update(double dt) {
    if (over || paused || phase != BubblePhase.flying || _flight == null) {
      return;
    }
    final f = _flight!;
    var remaining = _speed * dt;
    while (remaining > 0) {
      final step = min(remaining, _r * 0.5);
      f.pos = f.pos + f.vel / _speed * step;
      remaining -= step;
      // Walls.
      if (f.pos.dx < _r) {
        f.pos = Offset(_r, f.pos.dy);
        f.vel = Offset(-f.vel.dx, f.vel.dy);
        onEvent?.call(BubbleEvent.bounce, 0);
      } else if (f.pos.dx > _board.width - _r) {
        f.pos = Offset(_board.width - _r, f.pos.dy);
        f.vel = Offset(-f.vel.dx, f.vel.dy);
        onEvent?.call(BubbleEvent.bounce, 0);
      }
      // Ceiling.
      if (f.pos.dy <= _topPad + _r) {
        _snap(f);
        return;
      }
      // Bubble contact.
      bool hit = false;
      for (final e in grid.entries) {
        if ((centerOf(e.key) - f.pos).distance < _r * 1.95) {
          hit = true;
          break;
        }
      }
      if (hit) {
        _snap(f);
        return;
      }
      // Fell back past the launcher: wasted shot, no silent hang.
      if (f.pos.dy > shooterY + _r * 2) {
        _miss(f);
        return;
      }
    }
  }

  void _miss(_Flight f) {
    _flight = null;
    shots++;
    combo = 0;
    banner = 'Missed!';
    onEvent?.call(BubbleEvent.miss, 0);
    _afterShot();
  }

  void _snap(_Flight f) {
    _flight = null;
    // Nearest attachable empty cell (top row, or touching an existing bubble).
    Point<int>? best;
    var bestD = double.infinity;
    for (var row = 0; row < _maxRows; row++) {
      for (var c = 0; c < _colsForRow(row); c++) {
        final p = Point(c, row);
        if (grid.containsKey(p)) continue;
        final attachable = row == 0 || _neighbors(p).any(grid.containsKey);
        if (!attachable) continue;
        final d = (centerOf(p) - f.pos).distanceSquared;
        if (d < bestD) {
          bestD = d;
          best = p;
        }
      }
    }
    if (best == null) {
      // Nowhere to attach (shouldn't happen) — consume the shot, never hang.
      shots++;
      combo = 0;
      _afterShot();
      return;
    }
    grid[best] = f.colorIdx;
    onEvent?.call(BubbleEvent.snap, 0);

    // Pop matching group.
    final group = _flood(best, f.colorIdx);
    lastPops = [];
    lastDrops = [];
    if (group.length >= 3) {
      for (final p in group) {
        lastPops.add((centerOf(p), grid[p]!));
        grid.remove(p);
      }
      combo++;
      maxCombo = max(maxCombo, combo);
      final pts = group.length * 10 * combo;
      score += pts;
      pops += group.length;
      banner = combo > 1 ? 'COMBO x$combo! +$pts' : '+$pts';
      onEvent?.call(BubbleEvent.pop, combo);
    } else {
      combo = 0;
    }

    // Drop floaters (anything not anchored to the top row).
    final anchored = <Point<int>>{};
    final queue = <Point<int>>[];
    for (final p in grid.keys.where((p) => p.y == 0)) {
      anchored.add(p);
      queue.add(p);
    }
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      for (final n in _neighbors(p)) {
        if (grid.containsKey(n) && anchored.add(n)) queue.add(n);
      }
    }
    final floaters = grid.keys.where((p) => !anchored.contains(p)).toList();
    for (final p in floaters) {
      lastDrops.add((centerOf(p), grid[p]!));
      grid.remove(p);
    }
    if (floaters.isNotEmpty) {
      final pts = floaters.length * 15;
      score += pts;
      pops += floaters.length;
      onEvent?.call(BubbleEvent.drop, 0);
    }

    shots++;
    _afterShot();
  }

  /// Shared post-shot bookkeeping: ceiling drops, death, clear, settle.
  void _afterShot() {
    if (_checkDeath()) {
      _finish(false);
      return;
    }
    if (grid.isEmpty) {
      _levelCleared();
      return;
    }
    final dropEvery = mode == 1 ? endlessDropEvery : _dropEvery;
    if (shots % dropEvery == 0) {
      _dropCeiling();
      if (_checkDeath()) {
        _finish(false);
        return;
      }
    }
    // Brief settle so pop/drop animations read before the next shot.
    phase = BubblePhase.settling;
    notifyListeners();
    _arm(const Duration(milliseconds: 260), _finishSettle);
  }

  void _finishSettle() {
    if (over || phase != BubblePhase.settling) return;
    phase = BubblePhase.aiming;
    notifyListeners();
  }

  void _dropCeiling() {
    final moved = <Point<int>, int>{};
    var overflow = false;
    for (final e in grid.entries) {
      final row = e.key.y + 1;
      if (row >= _maxRows) {
        // Pushed off the bottom of the board: it crossed the death line.
        overflow = true;
      } else {
        moved[Point(e.key.x, row)] = e.value;
      }
    }
    grid
      ..clear()
      ..addAll(moved);
    final colors = levelColors;
    for (var c = 0; c < _colsForRow(0); c++) {
      grid[Point(c, 0)] = colors[_rand.nextInt(colors.length)];
    }
    if (overflow) {
      _finish(false);
      return;
    }
    banner = 'Ceiling drops!';
    onEvent?.call(BubbleEvent.ceiling, 0);
    notifyListeners();
  }

  bool _checkDeath() {
    for (final e in grid.entries) {
      if (centerOf(e.key).dy + _r > deathY) return true;
    }
    return false;
  }

  Set<Point<int>> _flood(Point<int> start, int colorIdx) {
    final seen = <Point<int>>{start};
    final queue = <Point<int>>[start];
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      for (final n in _neighbors(p)) {
        if (grid[n] == colorIdx && seen.add(n)) queue.add(n);
      }
    }
    return seen;
  }

  void _levelCleared() {
    final bonus = mode == 1 ? 100 : 100 * level;
    score += bonus;
    if (mode == 1) {
      // Endless never ends by clearing: fresh rack, keep going.
      banner = 'Rack cleared! +$bonus';
      onEvent?.call(BubbleEvent.levelClear, 0);
      phase = BubblePhase.levelClear;
      notifyListeners();
      _arm(const Duration(milliseconds: 1400), _advanceLevel);
    } else if (level >= maxLevel) {
      _finish(true);
    } else {
      banner = 'Level $level cleared! +$bonus';
      onEvent?.call(BubbleEvent.levelClear, 0);
      phase = BubblePhase.levelClear;
      notifyListeners();
      _arm(const Duration(milliseconds: 1500), _advanceLevel);
    }
  }

  void _advanceLevel() {
    if (over || phase != BubblePhase.levelClear) return;
    if (mode == 0) level++;
    _buildLevel();
  }

  void _finish(bool wonGame) {
    if (over) return;
    over = true;
    won = wonGame;
    phase = BubblePhase.over;
    _flight = null;
    banner = wonGame ? 'You win!' : 'The bubbles took over!';
    notifyListeners();
    onEvent?.call(wonGame ? BubbleEvent.gameWon : BubbleEvent.gameLost, 0);
  }

  void restart() {
    _timer?.cancel();
    paused = false;
    over = false;
    won = false;
    level = 1;
    score = 0;
    pops = 0;
    maxCombo = 0;
    combo = 0;
    aim = -pi / 2;
    _buildLevel();
  }

  /// Trace the aim guide: points along the shot path with one wall bounce.
  List<Offset> traceAim() {
    final pts = <Offset>[];
    if (_board == Size.zero) return pts;
    var p = Offset(_board.width / 2, shooterY);
    var dir = Offset(cos(aim), sin(aim));
    pts.add(p);
    for (var seg = 0; seg < 2; seg++) {
      var t = 170.0;
      if (dir.dx > 0) {
        t = min(t, (_board.width - _r - p.dx) / dir.dx);
      } else if (dir.dx < 0) {
        t = min(t, (p.dx - _r) / -dir.dx);
      }
      if (dir.dy < 0) t = min(t, (p.dy - _r) / -dir.dy);
      p = p + dir * t;
      pts.add(p);
      if (seg == 0 && (p.dx <= _r + 1 || p.dx >= _board.width - _r - 1)) {
        dir = Offset(-dir.dx, dir.dy);
      } else {
        break;
      }
    }
    return pts;
  }
}
