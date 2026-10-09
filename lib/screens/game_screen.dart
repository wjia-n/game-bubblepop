import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import '../engine/bubble_engine.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/fizz_art.dart';
import '../theme/fizz_themes.dart';
import 'settings_screen.dart';

/// Bubble Pop game screen — Soda Shop edition.
///
/// - The engine owns ALL shot phases; the screen only pumps [BubbleEngine.update]
///   from a ticker and renders. The UI can never desync the game.
/// - Every action has juicy visible feedback: pop bursts, drop falls, combo
///   badges, ceiling-drop shake, narration banners.
/// - A watchdog inside the engine recovers any stuck phase by construction.
class GameScreen extends StatefulWidget {
  final BubbleEngine engine;
  final FizzAudio audio;
  final FizzSettings settings;

  const GameScreen({
    super.key,
    required this.engine,
    required this.audio,
    required this.settings,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  late final AnimationController _popCtrl;
  late final AnimationController _bannerCtrl;

  BubbleEngine get _e => widget.engine;
  FizzThemeDef get _t => FizzThemes.byId(widget.settings.themeId,
      custom: widget.settings.customTheme);

  List<(Offset pos, int colorIdx)> _shownPops = const [];
  List<(Offset pos, int colorIdx)> _shownDrops = const [];
  String _shownBanner = '';
  bool _pausedOverlay = false;
  bool _gameOverHandled = false;
  bool _reviewAsked = false;
  Size _boardSize = Size.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _popCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _bannerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300));
    _ticker = createTicker(_tick)..start();
    _e.onEvent = _onEngineEvent;
    _e.addListener(_onEngineChanged);
    widget.audio.startGameMusic();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _popCtrl.dispose();
    _bannerCtrl.dispose();
    _e.removeListener(_onEngineChanged);
    _e.onEvent = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      widget.audio.onAppPaused();
      if (!_e.over && mounted) {
        setState(() {
          _e.setPaused(true);
          _pausedOverlay = true;
        });
      }
    } else if (state == AppLifecycleState.resumed) {
      widget.audio.onAppResumed();
    }
  }

  void _tick(Duration now) {
    if (_last == Duration.zero) {
      _last = now;
      return;
    }
    final dt = min((now - _last).inMicroseconds / 1e6, 1 / 30);
    _last = now;
    if (!_e.paused && mounted) {
      _e.update(dt);
      // Repaint every frame: the flight ball, wobble and anims are live.
      setState(() {});
    }
  }

  void _onEngineChanged() {
    if (!mounted) return;
    // Drive pop/drop animations from the engine's latest snap results.
    if (!identical(_e.lastPops, _shownPops) && _e.lastPops.isNotEmpty) {
      _shownPops = _e.lastPops;
      _popCtrl.forward(from: 0);
    }
    if (!identical(_e.lastDrops, _shownDrops) && _e.lastDrops.isNotEmpty) {
      _shownDrops = _e.lastDrops;
      _popCtrl.forward(from: 0);
    }
    if (_e.banner != _shownBanner && _e.banner.isNotEmpty) {
      _shownBanner = _e.banner;
      _bannerCtrl.forward(from: 0);
    }
    setState(() {});
    if (_e.over && !_gameOverHandled) {
      _gameOverHandled = true;
      _onGameOver();
    }
    // Sensible review moment: first time reaching level 6 (levels mode).
    if (!_reviewAsked && _e.mode == 0 && _e.level >= 6) {
      _reviewAsked = true;
      _maybeReview();
    }
  }

  Future<void> _onEngineEvent(BubbleEvent event, int value) async {
    final a = widget.audio;
    switch (event) {
      case BubbleEvent.click:
        await a.click();
      case BubbleEvent.shoot:
        await a.shoot();
      case BubbleEvent.bounce:
        await a.bounce();
      case BubbleEvent.snap:
        break; // pop/drop sounds carry the feedback
      case BubbleEvent.pop:
        await a.pop(value);
      case BubbleEvent.drop:
        await a.drop();
      case BubbleEvent.swap:
        await a.swap();
      case BubbleEvent.miss:
      case BubbleEvent.invalid:
        await a.invalid();
      case BubbleEvent.ceiling:
        await a.ceiling();
      case BubbleEvent.levelClear:
        await a.levelClear();
      case BubbleEvent.gameWon:
        await a.win();
      case BubbleEvent.gameLost:
        await a.lose();
    }
  }

  Future<void> _maybeReview() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) {
        await review.requestReview();
      }
    } catch (_) {
      // Not from Play / unsupported: stay silent.
    }
  }

  Future<void> _onGameOver() async {
    final endless = _e.mode == 1;
    final won = _e.won;
    await widget.settings.recordGame(
      endless: endless,
      score: _e.score,
      pops: _e.pops,
      combo: _e.maxCombo,
    );
    if (won) _maybeReview(); // sensible moment: a win
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    final best = endless
        ? widget.settings.bestEndlessScore
        : widget.settings.bestLevelsScore;
    final isNewBest = _e.score >= best && _e.score > 0;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final t = _t;
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                  colors: [t.bgMid, t.bgDeep],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter),
              border: Border.all(color: t.accent, width: 3),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 24,
                    offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(won ? '🏆' : '🫧',
                    style: const TextStyle(fontSize: 44)),
                const SizedBox(height: 8),
                Text(
                  won
                      ? 'Pop Master, ${widget.settings.playerName}!'
                      : 'The bubbles took over!',
                  style: Fizz.display(24, theme: t),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text('Score: ${_e.score}',
                    style: Fizz.label(20, theme: t)),
                if (isNewBest)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('✦ NEW BEST! ✦',
                        style: Fizz.label(15, theme: t)),
                  )
                else
                  Text('Best: $best',
                      style: Fizz.body(14,
                          theme: t,
                          color: t.ivory.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                Text(
                  'Pops: ${_e.pops}   •   Best combo: x${_e.maxCombo}${endless ? '' : '   •   Level ${_e.level}'}',
                  style: Fizz.body(13,
                      theme: t,
                      color: t.ivory.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FizzButton(
                  label: '🔄  Play Again',
                  theme: t,
                  width: 220,
                  fontSize: 17,
                  onTap: () {
                    widget.audio.click();
                    Navigator.of(context).pop(true);
                  },
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    widget.audio.click();
                    Navigator.of(context).pop(false);
                  },
                  child: Text('Back to Menu',
                      style: Fizz.label(15, theme: t)),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (again == true) {
      _gameOverHandled = false;
      _shownPops = const [];
      _shownDrops = const [];
      _e.restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _togglePause() {
    widget.audio.click();
    setState(() {
      _pausedOverlay = !_pausedOverlay;
      _e.setPaused(_pausedOverlay);
    });
  }

  void _aimAt(Offset local) {
    final from = Offset(_boardSize.width / 2, _e.shooterY);
    _e.setAim(atan2(local.dy - from.dy, local.dx - from.dx));
    setState(() {});
  }

  void _tapBoard(Offset local) {
    final shooter = Offset(_boardSize.width / 2, _e.shooterY);
    if ((local - shooter).distance < _e.r * 2.4) {
      _e.swap(); // tap the loaded bubble to swap
    } else {
      _e.fire();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final dropEvery = _e.mode == 1 ? _e.endlessDropEvery : switch (_e.difficulty) {
      0 => 7,
      2 => 5,
      _ => 6,
    };
    final shotsLeft = dropEvery - (_e.shots % dropEvery);
    final best = _e.mode == 1
        ? widget.settings.bestEndlessScore
        : widget.settings.bestLevelsScore;
    return SodaBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  // HUD
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                    child: Row(
                      children: [
                        _HudIcon(
                            theme: t,
                            icon: Icons.pause,
                            onTap: _togglePause),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_e.score}',
                                  style: Fizz.display(26, theme: t)),
                              Text(
                                _e.mode == 1
                                    ? 'ENDLESS • best $best'
                                    : 'LEVEL ${_e.level}/${BubbleEngine.maxLevel} • best $best',
                                style: Fizz.label(11, theme: t),
                              ),
                            ],
                          ),
                        ),
                        if (_e.combo > 1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: t.accent.withValues(alpha: 0.9),
                              border: Border.all(
                                  color: t.accentLight, width: 2),
                            ),
                            child: Text('🔥 x${_e.combo}',
                                style: Fizz.label(14,
                                    theme: t, color: t.bgDeep)),
                          ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            Text('CEILING',
                                style: Fizz.label(9, theme: t)),
                            SizedBox(
                              width: 64,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: 1 - shotsLeft / dropEvery,
                                  minHeight: 8,
                                  backgroundColor: Colors.black
                                      .withValues(alpha: 0.45),
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(
                                          shotsLeft <= 2
                                              ? t.bubbleColors[0]
                                              : t.accent),
                                ),
                              ),
                            ),
                            Text('$shotsLeft',
                                style: Fizz.label(10, theme: t)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Board
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        _boardSize = Size(
                            constraints.maxWidth, constraints.maxHeight);
                        _e.setBoardSize(_boardSize);
                        return GestureDetector(
                          onPanStart: (d) => _aimAt(d.localPosition),
                          onPanUpdate: (d) => _aimAt(d.localPosition),
                          onPanEnd: (_) => _e.fire(),
                          onTapDown: (d) => _tapBoard(d.localPosition),
                          child: CustomPaint(
                            painter: _BoardPainter(
                              engine: _e,
                              theme: t,
                              bubbleStyle:
                                  widget.settings.bubbleStyle,
                              launcherStyle:
                                  widget.settings.launcherStyle,
                              popT: _popCtrl.value,
                              bannerT: _bannerCtrl.value,
                              bannerText: _shownBanner,
                              pops: _shownPops,
                              drops: _shownDrops,
                            ),
                            size: Size.infinite,
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Drag to aim, release to fire • tap bubble to swap',
                      style: Fizz.body(12,
                          theme: t,
                          color: t.ivory.withValues(alpha: 0.55)),
                    ),
                  ),
                ],
              ),
              // Pause overlay
              if (_pausedOverlay)
                _PauseOverlay(
                  theme: t,
                  audio: widget.audio,
                  settings: widget.settings,
                  onResume: _togglePause,
                  onRestart: () {
                    widget.audio.click();
                    setState(() {
                      _pausedOverlay = false;
                      _gameOverHandled = false;
                      _shownPops = const [];
                      _shownDrops = const [];
                      _e.restart();
                    });
                  },
                  onQuit: () {
                    widget.audio.click();
                    _e.setPaused(false);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HudIcon extends StatelessWidget {
  final FizzThemeDef theme;
  final IconData icon;
  final VoidCallback onTap;
  const _HudIcon(
      {required this.theme, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.35),
          border: Border.all(color: theme.accent, width: 2),
        ),
        child: Icon(icon, color: theme.accentLight, size: 22),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  final FizzThemeDef theme;
  final FizzAudio audio;
  final FizzSettings settings;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;
  const _PauseOverlay({
    required this.theme,
    required this.audio,
    required this.settings,
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
                colors: [t.bgMid, t.bgDeep],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter),
            border: Border.all(color: t.accent, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Paused', style: Fizz.display(28, theme: t)),
              const SizedBox(height: 16),
              FizzButton(
                  label: '▶  Resume', theme: t, width: 220, fontSize: 17,
                  onTap: onResume),
              const SizedBox(height: 10),
              FizzButton(
                  label: '🔄  Restart', theme: t, width: 220, fontSize: 17,
                  onTap: onRestart),
              const SizedBox(height: 10),
              FizzButton(
                  label: '🏠  Menu', theme: t, width: 220, fontSize: 17,
                  onTap: onQuit),
              const SizedBox(height: 16),
              SettingRow(
                theme: t,
                label: 'Music',
                control: FizzToggle(
                  theme: t,
                  value: settings.musicOn,
                  onChanged: (v) async {
                    audio.click();
                    await settings.setMusic(v);
                    audio.configure(
                        musicOn: settings.musicOn,
                        sfxOn: settings.sfxOn,
                        volume: settings.volume);
                    if (v) {
                      audio.startGameMusic();
                    } else {
                      audio.stopMusic();
                    }
                  },
                ),
              ),
              SettingRow(
                theme: t,
                label: 'Sound effects',
                control: FizzToggle(
                  theme: t,
                  value: settings.sfxOn,
                  onChanged: (v) async {
                    await settings.setSfx(v);
                    audio.configure(
                        musicOn: settings.musicOn,
                        sfxOn: settings.sfxOn,
                        volume: settings.volume);
                    if (v) audio.click();
                  },
                ),
              ),
              TextButton(
                onPressed: () {
                  audio.click();
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                        audio: audio, settings: settings),
                  ));
                },
                child:
                    Text('All settings', style: Fizz.label(14, theme: t)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
class _BoardPainter extends CustomPainter {
  final BubbleEngine engine;
  final FizzThemeDef theme;
  final int bubbleStyle;
  final int launcherStyle;
  final double popT;
  final double bannerT;
  final String bannerText;
  final List<(Offset pos, int colorIdx)> pops;
  final List<(Offset pos, int colorIdx)> drops;

  _BoardPainter({
    required this.engine,
    required this.theme,
    required this.bubbleStyle,
    required this.launcherStyle,
    required this.popT,
    required this.bannerT,
    required this.bannerText,
    required this.pops,
    required this.drops,
  });

  Color _colorOf(int idx) =>
      theme.bubbleColors[idx % theme.bubbleColors.length];

  @override
  void paint(Canvas canvas, Size size) {
    final e = engine;
    final r = e.r;
    // Board panel.
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(6, 4, size.width - 12, size.height - 8),
      const Radius.circular(18),
    );
    canvas.drawRRect(
        panel, Paint()..color = Colors.black.withValues(alpha: 0.35));
    canvas.drawRRect(
      panel,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [theme.bgMid, theme.bgDeep],
        ).createShader(panel.outerRect),
    );
    canvas.drawRRect(
      panel,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = theme.accent.withValues(alpha: 0.6)
        ..strokeWidth = 2.5,
    );

    // Grid bubbles.
    for (final entry in e.grid.entries) {
      paintBubble(canvas, e.centerOf(entry.key), r * 0.98,
          _colorOf(entry.value), bubbleStyle);
    }

    // Pop bursts: expanding fizzy rings.
    for (final (pos, colorIdx) in popT < 1 ? pops : const <(Offset, int)>[]) {
      final a = (1 - popT).clamp(0.0, 1.0);
      canvas.drawCircle(
        pos,
        r * (0.6 + popT * 1.4),
        Paint()
          ..color = _colorOf(colorIdx).withValues(alpha: a * 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 * (1 - popT) + 1,
      );
      canvas.drawCircle(
        pos + Offset(r * 0.3, -r * 0.3),
        r * 0.35 * (1 - popT * 0.5),
        Paint()..color = Colors.white.withValues(alpha: a * 0.7),
      );
    }
    // Dropping floaters: fall with a fade.
    for (final (pos, colorIdx) in popT < 1 ? drops : const <(Offset, int)>[]) {
      final fall = popT * popT * size.height * 0.35;
      final a = (1 - popT).clamp(0.0, 1.0);
      paintBubble(canvas, pos + Offset(0, fall), r * 0.98,
          _colorOf(colorIdx), bubbleStyle,
          alpha: a);
    }

    // Death line.
    canvas.drawLine(
      Offset(10, e.deathY),
      Offset(size.width - 10, e.deathY),
      Paint()
        ..color = theme.bubbleColors[0].withValues(alpha: 0.55)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    for (double x = 20; x < size.width - 20; x += 28) {
      canvas.drawLine(
        Offset(x, e.deathY - 5),
        Offset(x + 8, e.deathY + 5),
        Paint()
          ..color = theme.bubbleColors[0].withValues(alpha: 0.55)
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
    }

    final shooter = Offset(size.width / 2, e.shooterY);
    // Aim guide with one bounce (only while aiming).
    if (e.phase == BubblePhase.aiming) {
      final pts = e.traceAim();
      final paint = Paint()
        ..color = theme.accentLight.withValues(alpha: 0.65)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i + 1 < pts.length; i++) {
        _dashed(canvas, pts[i], pts[i + 1], paint);
      }
    }

    // Launcher.
    paintLauncher(
        canvas, shooter, r, e.aim, launcherStyle, theme);

    // Loaded + next bubbles.
    if (e.phase != BubblePhase.over) {
      paintBubble(canvas, shooter + Offset(0, -r * 0.4), r * 1.02,
          _colorOf(e.current), bubbleStyle,
          wobble: sin(DateTime.now().millisecondsSinceEpoch / 300) * 0.5);
      paintBubble(canvas, shooter + Offset(r * 2.6, r * 0.9), r * 0.62,
          _colorOf(e.next), bubbleStyle);
    }

    // Banner.
    if (bannerText.isNotEmpty && bannerT < 1) {
      final a = (1 - bannerT).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: bannerText,
          style: Fizz.display(30, theme: theme)
              .copyWith(color: theme.accentLight.withValues(alpha: a)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final bgRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.42),
            width: tp.width + 44,
            height: tp.height + 24),
        const Radius.circular(16),
      );
      canvas.drawRRect(
          bgRect,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.55 * a));
      tp.paint(
          canvas,
          Offset((size.width - tp.width) / 2,
              size.height * 0.42 - tp.height / 2));
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 9.0, gap = 7.0;
    final total = (b - a).distance;
    var d = 0.0;
    while (d < total) {
      final p1 = a + (b - a) * (d / total);
      final p2 = a + (b - a) * (min(d + dash, total) / total);
      canvas.drawLine(p1, p2, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _BoardPainter old) => true;
}
