import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/audio_service.dart';
import '../services/iap_service.dart';
import '../services/settings_service.dart';
import '../theme/fizz_art.dart';
import '../theme/fizz_themes.dart';
import 'custom_theme_screen.dart';
import 'pro_screen.dart';

/// Settings — soda-shop counter metaphor, theme-aware.
class SettingsScreen extends StatefulWidget {
  final FizzAudio audio;
  final FizzSettings settings;
  const SettingsScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StoreService _store = StoreService();

  FizzThemeDef get _t => FizzThemes.byId(widget.settings.themeId,
      custom: widget.settings.customTheme);

  @override
  void initState() {
    super.initState();
    _store.init().then((_) {
      if (mounted) setState(() {});
    });
    _store.lastThanks.addListener(_onThanks);
    _store.proPurchased.addListener(_onPro);
  }

  void _onThanks() {
    final msg = _store.lastThanks.value;
    if (msg == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: Fizz.body(15, theme: _t)),
        backgroundColor: _t.bgMid,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _store.lastThanks.value = null;
  }

  void _onPro() {
    if (_store.proPurchased.value && mounted) {
      widget.settings.setPro(true);
      _store.proPurchased.value = false;
    }
  }

  @override
  void dispose() {
    _store.lastThanks.removeListener(_onThanks);
    _store.proPurchased.removeListener(_onPro);
    _store.dispose();
    super.dispose();
  }

  void _configureAudio() {
    final s = widget.settings;
    widget.audio.configure(
        musicOn: s.musicOn, sfxOn: s.sfxOn, volume: s.volume);
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final s = widget.settings;
    final audio = widget.audio;
    return SodaBackdrop(
      theme: t,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: t.accentLight),
            onPressed: () {
              audio.click();
              Navigator.of(context).pop();
            },
          ),
          title: Text('Settings', style: Fizz.display(22, theme: t)),
          centerTitle: true,
        ),
        body: ListenableBuilder(
          listenable: s,
          builder: (_, _) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Sound', t),
                SettingRow(
                  theme: t,
                  label: 'Music',
                  control: FizzToggle(
                    theme: t,
                    value: s.musicOn,
                    onChanged: (v) async {
                      audio.click();
                      await s.setMusic(v);
                      _configureAudio();
                      if (v) {
                        audio.startMenuMusic();
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
                    value: s.sfxOn,
                    onChanged: (v) async {
                      await s.setSfx(v);
                      _configureAudio();
                      if (v) audio.click();
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Text('Volume', style: Fizz.body(16, theme: t)),
                BeadSlider(
                  theme: t,
                  value: s.volume,
                  onChanged: (v) async {
                    await s.setVolume(v);
                    _configureAudio();
                  },
                ),
                const SizedBox(height: 10),
                _SectionTitle('Bubble Pop PRO', t),
                SettingRow(
                  theme: t,
                  label: s.isPro ? 'PRO active ✦' : 'Unlock PRO',
                  control: GestureDetector(
                    onTap: () {
                      audio.click();
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProScreen(
                          audio: audio,
                          settings: s,
                          store: _store,
                        ),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: s.isPro
                            ? t.accent.withValues(alpha: 0.85)
                            : Colors.black.withValues(alpha: 0.3),
                        border: Border.all(
                            color: t.accentLight, width: 2),
                      ),
                      child: Text(
                        s.isPro ? '✦ PRO' : 'View',
                        style: Fizz.label(13,
                            theme: t,
                            color: s.isPro ? t.bgDeep : t.ivory),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _SectionTitle('Appearance', t),
                Text('Theme', style: Fizz.body(16, theme: t)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final th in FizzThemes.all)
                      _miniThemeTile(t, th, s, audio),
                    _miniThemeTile(t, s.customTheme, s, audio,
                        custom: true),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Bubble style', style: Fizz.body(16, theme: t)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0;
                        i < BubbleStyles.names.length;
                        i++)
                      _MiniChip(
                        theme: t,
                        label:
                            '${BubbleStyles.isPro(i) && !s.isPro ? '🔒 ' : ''}${BubbleStyles.names[i]}',
                        selected: s.bubbleStyle == i,
                        onTap: () async {
                          audio.click();
                          if (BubbleStyles.isPro(i) && !s.isPro) {
                            await _goPro();
                            return;
                          }
                          await s.setBubbleStyle(i);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Launcher style', style: Fizz.body(16, theme: t)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0;
                        i < LauncherStyles.names.length;
                        i++)
                      _MiniChip(
                        theme: t,
                        label:
                            '${LauncherStyles.isPro(i) && !s.isPro ? '🔒 ' : ''}${LauncherStyles.names[i]}',
                        selected: s.launcherStyle == i,
                        onTap: () async {
                          audio.click();
                          if (LauncherStyles.isPro(i) && !s.isPro) {
                            await _goPro();
                            return;
                          }
                          await s.setLauncherStyle(i);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                _SectionTitle('Support', t),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: t.bgDeep.withValues(alpha: 0.65),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Bubble Pop is 100% free. Tips keep the soda flowing!',
                        style: Fizz.body(14, theme: t),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Builder(builder: (_) {
                        final tips = [
                          _store.coffeeProduct,
                          _store.chocolateProduct,
                        ].whereType<ProductDetails>().toList();
                        if (!_store.storeReady) {
                          return Text(
                            _store.error ?? 'Loading…',
                            style: Fizz.body(13,
                                theme: t,
                                color:
                                    t.ivory.withValues(alpha: 0.6)),
                            textAlign: TextAlign.center,
                          );
                        }
                        if (tips.isEmpty) {
                          return Text('Tips coming soon.',
                              style: Fizz.body(13,
                                  theme: t,
                                  color: t.ivory
                                      .withValues(alpha: 0.6)));
                        }
                        return Wrap(
                          spacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final p in tips)
                              _MiniChip(
                                theme: t,
                                label: p.id == StoreService.chocolateId
                                    ? '🍫 ${p.price}'
                                    : '☕ ${p.price}',
                                selected: false,
                                onTap: () {
                                  audio.click();
                                  _store.buyTip(p);
                                },
                              ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _SectionTitle('About', t),
                Text(
                  'Bubble Pop — Soda Shop edition.\nVersion 2.0.0 • Made with ♥ by WAJIHA',
                  style: Fizz.body(13,
                      theme: t,
                      color: t.ivory.withValues(alpha: 0.65)),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniThemeTile(FizzThemeDef t, FizzThemeDef th, FizzSettings s,
      FizzAudio audio,
      {bool custom = false}) {
    final id = custom ? 'custom' : th.id;
    final locked = !s.isPro &&
        (custom || FizzThemes.isProTheme(th.id));
    return GestureDetector(
      onTap: () async {
        audio.click();
        if (locked) {
          await _goPro();
          return;
        }
        if (custom) {
          await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                CustomThemeScreen(audio: audio, settings: s),
          ));
          return;
        }
        await s.setTheme(id);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 64,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(colors: [
                th.bgMid,
                th.accent,
              ]),
              border: Border.all(
                color: s.themeId == id
                    ? th.accentLight
                    : th.accent.withValues(alpha: 0.3),
                width: s.themeId == id ? 3 : 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < 2; i++)
                  Container(
                    width: 10,
                    height: 10,
                    margin:
                        const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: th.bubbleColors[i],
                    ),
                  ),
              ],
            ),
          ),
          if (locked)
            Container(
              width: 64,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: Icon(Icons.lock,
                  color: t.accentLight, size: 18),
            ),
        ],
      ),
    );
  }

  Future<void> _goPro() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProScreen(
        audio: widget.audio,
        settings: widget.settings,
        store: _store,
      ),
    ));
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final FizzThemeDef theme;
  const _SectionTitle(this.text, this.theme);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(text, style: Fizz.display(19, theme: theme)),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final FizzThemeDef theme;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MiniChip(
      {required this.theme,
      required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: selected
              ? theme.accent.withValues(alpha: 0.85)
              : Colors.black.withValues(alpha: 0.3),
          border: Border.all(
            color: selected
                ? theme.accentLight
                : theme.accent.withValues(alpha: 0.5),
            width: selected ? 2.5 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: Fizz.label(13,
              theme: theme,
              color: selected ? theme.bgDeep : theme.ivory),
        ),
      ),
    );
  }
}
