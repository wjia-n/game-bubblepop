import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';

class _Flying {
  Offset pos;
  Offset vel;
  final Color color;
  _Flying(this.pos, this.vel, this.color);
}

class _Pop {
  Offset pos;
  final Color color;
  double t = 0;
  _Pop(this.pos, this.color);
}

class BubblePopScreen extends StatefulWidget {
  final List<Player> players;
  final GameCallbacks callbacks;
  const BubblePopScreen({super.key, required this.players, required this.callbacks});

  @override
  State<BubblePopScreen> createState() => _BubblePopScreenState();
}

class _BubblePopScreenState extends State<BubblePopScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Size _area = Size.zero;

  final Map<Point<int>, Color> _grid = {};
  final List<_Flying> _flying = [];
  final List<_Pop> _pops = [];

  int _level = 1, _shots = 0, _combo = 0;
  double _aim = -pi / 2; // radians, straight up
  bool _over = false;
  String _banner = '';
  double _bannerT = 0;
  late Color _current, _next;
  final _rnd = Random();

  static const _palette = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.amber,
    Colors.purpleAccent,
    Colors.cyanAccent,
  ];

  int get _cols => 9;
  int get _maxRows => 16;
  double get _r => _area == Size.zero ? 16 : _area.width / (_cols * 2 + 1);
  double get _deathY => _area.height - 120;

  List<Color> get _levelColors => _palette.sublist(0, min(3 + _level ~/ 4, 6));

  @override
  void initState() {
    super.initState();
    _buildLevel();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  int _colsForRow(int row) => row.isEven ? _cols : _cols - 1;

  bool _inBounds(Point<int> p) =>
      p.y >= 0 && p.y < _maxRows && p.x >= 0 && p.x < _colsForRow(p.y);

  Offset _center(Point<int> p) {
    final r = _r;
    return Offset(r + p.x * 2 * r + (p.y.isOdd ? r : 0), r + 8 + p.y * r * 1.732);
  }

  List<Point<int>> _neighbors(Point<int> p) {
    final even = p.y.isEven;
    final d = even
        ? const [Point(-1, -1), Point(0, -1), Point(-1, 0), Point(1, 0), Point(-1, 1), Point(0, 1)]
        : const [Point(0, -1), Point(1, -1), Point(-1, 0), Point(1, 0), Point(0, 1), Point(1, 1)];
    return [for (final o in d) Point(p.x + o.x, p.y + o.y)].where(_inBounds).toList();
  }

  void _buildLevel() {
    _grid.clear();
    _flying.clear();
    final rows = min(3 + _level ~/ 3, 7);
    final colors = _levelColors;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < _colsForRow(r); c++) {
        _grid[Point(c, r)] = colors[_rnd.nextInt(colors.length)];
      }
    }
    _shots = 0;
    _combo = 0;
    _current = colors[_rnd.nextInt(colors.length)];
    _next = colors[_rnd.nextInt(colors.length)];
    _banner = 'LEVEL $_level';
    _bannerT = 1.6;
  }

  void _addScore(int pts) {
    widget.players[0].score += pts;
    widget.callbacks.refreshHud();
  }

  void _fire() {
    if (_over || _flying.isNotEmpty || _area == Size.zero) return;
    final from = Offset(_area.width / 2, _area.height - 56);
    final v = Offset(cos(_aim), sin(_aim));
    _flying.add(_Flying(from, v * 620, _current));
    _current = _next;
    final boardColors = _grid.values.toSet();
    final pool = boardColors.isEmpty ? _levelColors : boardColors.toList();
    _next = pool[_rnd.nextInt(pool.length)];
    _shots++;
    Sfx.move();
    if (_shots % 6 == 0) _dropCeiling();
  }

  void _dropCeiling() {
    final moved = <Point<int>, Color>{};
    for (final e in _grid.entries) {
      moved[Point(e.key.x, e.key.y + 1)] = e.value;
    }
    _grid
      ..clear()
      ..addAll(moved);
    final colors = _levelColors;
    for (var c = 0; c < _colsForRow(0); c++) {
      _grid[Point(c, 0)] = colors[_rnd.nextInt(colors.length)];
    }
    _banner = 'CEILING DROPS!';
    _bannerT = 1.2;
    Sfx.lose();
    _checkDeath();
  }

  void _checkDeath() {
    for (final e in _grid.entries) {
      if (_center(e.key).dy + _r > _deathY) {
        _finish(false);
        return;
      }
    }
  }

  void _snap(_Flying f) {
    // nearest attachable empty cell
    Point<int>? best;
    var bestD = double.infinity;
    for (var r = 0; r < _maxRows; r++) {
      for (var c = 0; c < _colsForRow(r); c++) {
        final p = Point(c, r);
        if (_grid.containsKey(p)) continue;
        final attachable = r == 0 || _neighbors(p).any(_grid.containsKey);
        if (!attachable) continue;
        final d = (_center(p) - f.pos).distanceSquared;
        if (d < bestD) {
          bestD = d;
          best = p;
        }
      }
    }
    best ??= const Point(0, 0);
    _grid[best] = f.color;

    // pop matches
    final group = _flood(best, f.color);
    if (group.length >= 3) {
      for (final p in group) {
        _pops.add(_Pop(_center(p), _grid[p]!));
        _grid.remove(p);
      }
      _combo++;
      _addScore(group.length * 10 * _combo);
      Sfx.win();
    } else {
      _combo = 0;
    }

    // drop floaters
    final anchored = <Point<int>>{};
    final queue = <Point<int>>[];
    for (final p in _grid.keys.where((p) => p.y == 0)) {
      anchored.add(p);
      queue.add(p);
    }
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      for (final n in _neighbors(p)) {
        if (_grid.containsKey(n) && anchored.add(n)) queue.add(n);
      }
    }
    final floaters = _grid.keys.where((p) => !anchored.contains(p)).toList();
    for (final p in floaters) {
      _pops.add(_Pop(_center(p), _grid[p]!));
      _grid.remove(p);
    }
    if (floaters.isNotEmpty) {
      _addScore(floaters.length * 5);
      Sfx.click();
    }

    _checkDeath();
    if (!_over && _grid.isEmpty) {
      if (_level >= 15) {
        _finish(true);
      } else {
        _level++;
        _buildLevel();
        Sfx.win();
      }
    }
  }

  Set<Point<int>> _flood(Point<int> start, Color color) {
    final seen = <Point<int>>{start};
    final queue = <Point<int>>[start];
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      for (final n in _neighbors(p)) {
        if (_grid[n] == color && seen.add(n)) queue.add(n);
      }
    }
    return seen;
  }

  void _finish(bool won) {
    if (_over) return;
    _over = true;
    _ticker.stop();
    final s = widget.players[0].score;
    if (won) {
      Sfx.win();
      widget.callbacks.finish(
        headline: 'Pop Master! 🫧🏆',
        subline: 'All 15 levels cleared with $s points of fizz.',
      );
    } else {
      Sfx.lose();
      widget.callbacks.finish(
        headline: 'The bubbles took over!',
        subline: 'Final score: $s. Aim a little higher next time!',
      );
    }
  }

  void _tick(Duration now) {
    if (_over || _area == Size.zero) {
      _last = now;
      return;
    }
    final dt = min((now - _last).inMicroseconds / 1e6, 1 / 30);
    _last = now;
    _bannerT = max(0, _bannerT - dt);

    for (final p in _pops) {
      p.t += dt * 3;
    }
    _pops.removeWhere((p) => p.t >= 1);

    if (_flying.isNotEmpty) {
      final f = _flying.single;
      var remaining = 620 * dt;
      var snapped = false;
      while (remaining > 0 && !snapped) {
        final step = min(remaining, 7.0);
        f.pos = f.pos + f.vel / 620 * step;
        remaining -= step;
        // walls
        if (f.pos.dx < _r) {
          f.pos = Offset(_r, f.pos.dy);
          f.vel = Offset(-f.vel.dx, f.vel.dy);
        } else if (f.pos.dx > _area.width - _r) {
          f.pos = Offset(_area.width - _r, f.pos.dy);
          f.vel = Offset(-f.vel.dx, f.vel.dy);
        }
        // top
        if (f.pos.dy <= _r + 8) {
          snapped = true;
          break;
        }
        // bubble hit
        for (final e in _grid.entries) {
          if ((_center(e.key) - f.pos).distance < _r * 1.9) {
            snapped = true;
            break;
          }
        }
      }
      if (snapped) {
        _flying.clear();
        _snap(f);
      } else if (f.pos.dy > _area.height) {
        _flying.clear();
      }
    }

    if (mounted) setState(() {});
  }

  void _aimAt(Offset local, Size size) {
    final from = Offset(size.width / 2, size.height - 56);
    var a = atan2(local.dy - from.dy, local.dx - from.dx);
    // keep aiming upward-ish
    a = a.clamp(-pi + 0.25, -0.25);
    setState(() => _aim = a);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.of(context).theme;
    return Column(
      children: [
        ScoreChips(players: widget.players, activeIndex: 0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('LEVEL $_level / 15', style: TextStyle(color: theme.muted, fontWeight: FontWeight.bold)),
              if (_combo > 1)
                Text('🔥 COMBO ×$_combo', style: TextStyle(color: theme.accent, fontWeight: FontWeight.bold)),
              Text('Shots: $_shots', style: TextStyle(color: theme.muted)),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _area = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onPanStart: (d) => _aimAt(d.localPosition, _area),
                onPanUpdate: (d) => _aimAt(d.localPosition, _area),
                onPanEnd: (_) => _fire(),
                onTap: _fire,
                child: CustomPaint(
                  painter: _PopPainter(
                    grid: _grid,
                    center: _center,
                    r: _r,
                    flying: _flying.isEmpty ? null : _flying.single,
                    pops: _pops,
                    aim: _aim,
                    current: _current,
                    next: _next,
                    shooterY: _area.height - 56,
                    areaW: _area.width,
                    deathY: _deathY,
                    banner: _bannerT > 0 ? _banner : '',
                    bg: theme.background,
                    accent: theme.accent,
                  ),
                  size: Size.infinite,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text('Drag to aim, release to fire 🫧', style: TextStyle(color: theme.muted)),
        ),
      ],
    );
  }
}

class _PopPainter extends CustomPainter {
  final Map<Point<int>, Color> grid;
  final Offset Function(Point<int>) center;
  final double r;
  final _Flying? flying;
  final List<_Pop> pops;
  final double aim;
  final Color current, next;
  final double shooterY, areaW, deathY;
  final String banner;
  final Color bg, accent;

  _PopPainter({
    required this.grid,
    required this.center,
    required this.r,
    required this.flying,
    required this.pops,
    required this.aim,
    required this.current,
    required this.next,
    required this.shooterY,
    required this.areaW,
    required this.deathY,
    required this.banner,
    required this.bg,
    required this.accent,
  });

  void _bubble(Canvas canvas, Offset c, Color color, double radius) {
    canvas.drawCircle(c, radius, Paint()..color = color);
    canvas.drawCircle(
      c + Offset(-radius * 0.3, -radius * 0.3),
      radius * 0.35,
      Paint()..color = Colors.white.withValues(alpha: 0.45),
    );
    canvas.drawCircle(c, radius, Paint()..style = PaintingStyle.stroke..color = Colors.black26..strokeWidth = 1.5);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);

    for (final e in grid.entries) {
      _bubble(canvas, center(e.key), e.value, r);
    }

    for (final p in pops) {
      final a = (1 - p.t).clamp(0.0, 1.0);
      canvas.drawCircle(
        p.pos,
        r * (1 + p.t * 0.9),
        Paint()
          ..color = p.color.withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // death line
    canvas.drawLine(
      Offset(0, deathY),
      Offset(size.width, deathY),
      Paint()
        ..color = Colors.red.withValues(alpha: 0.5)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    final shooter = Offset(areaW / 2, shooterY);
    // aim guide with one bounce
    if (flying == null) {
      var p = shooter;
      var dir = Offset(cos(aim), sin(aim));
      final paint = Paint()
        ..color = accent.withValues(alpha: 0.6)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var seg = 0; seg < 2; seg++) {
        var t = 160.0;
        if (dir.dx > 0) t = min(t, (size.width - r - p.dx) / dir.dx);
        if (dir.dx < 0) t = min(t, (p.dx - r) / -dir.dx);
        if (dir.dy < 0) t = min(t, (p.dy - r) / -dir.dy);
        final end = p + dir * t;
        canvas.drawLine(p, end, paint);
        if (seg == 0 && (end.dx <= r + 1 || end.dx >= size.width - r - 1)) {
          p = end;
          dir = Offset(-dir.dx, dir.dy);
        } else {
          break;
        }
      }
    }

    // shooter
    _bubble(canvas, shooter, current, r * 1.15);
    _bubble(canvas, shooter + const Offset(44, 10), next, r * 0.7);

    if (flying != null) _bubble(canvas, flying!.pos, flying!.color, r);

    if (banner.isNotEmpty) {
      final tp = TextPainter(
        text: TextSpan(text: banner, style: TextStyle(color: accent, fontWeight: FontWeight.w900, fontSize: 30)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((size.width - tp.width) / 2, size.height * 0.42));
    }
  }

  @override
  bool shouldRepaint(covariant _PopPainter old) => true;
}
