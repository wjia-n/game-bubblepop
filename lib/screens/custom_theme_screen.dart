import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../services/settings_service.dart';
import '../theme/fizz_art.dart';
import '../theme/fizz_themes.dart';

/// Custom theme creator (PRO): pick every soda-shop color + the 6 bubble
/// candy colors. Live preview below the sliders.
class CustomThemeScreen extends StatefulWidget {
  final FizzAudio audio;
  final FizzSettings settings;
  const CustomThemeScreen(
      {super.key, required this.audio, required this.settings});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  FizzSettings get _s => widget.settings;

  static const _groups = [
    ('Counter', ['bgDeep', 'bgMid', 'woodDark', 'woodMid']),
    ('Metal & labels', ['accent', 'accentLight', 'accentDark', 'ivory']),
    ('Bubble candy', ['b0', 'b1', 'b2', 'b3', 'b4', 'b5']),
  ];

  @override
  Widget build(BuildContext context) {
    final t = FizzThemes.byId(_s.themeId, custom: _s.customTheme);
    final preview = _s.customTheme;
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
              widget.audio.click();
              Navigator.of(context).pop();
            },
          ),
          title:
              Text('My Creation', style: Fizz.display(22, theme: t)),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: () async {
                widget.audio.click();
                await _s.resetCustomColors();
              },
              child: Text('Reset', style: Fizz.label(13, theme: t)),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: _s,
          builder: (_, _) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Live preview.
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [preview.bgMid, preview.bgDeep],
                    ),
                    border: Border.all(color: preview.accent, width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final c in preview.bubbleColors)
                        Container(
                          width: 34,
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              center: const Alignment(-0.35, -0.4),
                              colors: [
                                _lighten(c),
                                c,
                              ],
                            ),
                            border: Border.all(
                                color: preview.accentLight, width: 1.5),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: FizzButton(
                    label: _s.themeId == 'custom'
                        ? '✓  Using My Creation'
                        : 'Use My Creation',
                    width: 240,
                    fontSize: 16,
                    theme: t,
                    onTap: () async {
                      widget.audio.click();
                      await _s.setTheme('custom');
                    },
                  ),
                ),
                const SizedBox(height: 14),
                for (final (gname, keys) in _groups) ...[
                  Text(gname, style: Fizz.display(18, theme: t)),
                  const SizedBox(height: 6),
                  for (final k in keys) _ColorRow(colorKey: k),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _lighten(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + 0.35).clamp(0.0, 1.0)).toColor();
  }
}

class _ColorRow extends StatelessWidget {
  final String colorKey;
  const _ColorRow({required this.colorKey});

  static const _labels = {
    'bgDeep': 'Background deep',
    'bgMid': 'Background mid',
    'woodDark': 'Wood dark',
    'woodMid': 'Wood mid',
    'accent': 'Metal accent',
    'accentLight': 'Metal light',
    'accentDark': 'Metal dark',
    'ivory': 'Label ivory',
    'b0': 'Bubble 1',
    'b1': 'Bubble 2',
    'b2': 'Bubble 3',
    'b3': 'Bubble 4',
    'b4': 'Bubble 5',
    'b5': 'Bubble 6',
  };

  @override
  Widget build(BuildContext context) {
    // Reach settings through the nearest CustomThemeScreen state is awkward;
    // use a simple InheritedWidget-free approach: find via context.
    final state =
        context.findAncestorStateOfType<_CustomThemeScreenState>()!;
    final s = state._s;
    final t = FizzThemes.byId(s.themeId, custom: s.customTheme);
    final color = Color(s.customColors[colorKey]!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(color: t.accentLight, width: 1.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_labels[colorKey] ?? colorKey, style: Fizz.body(14, theme: t)),
                _ChannelSlider(
                  theme: t,
                  label: 'R',
                  value: color.red / 255,
                  onChanged: (v) => s.setCustomColor(
                      colorKey, color.withRed((v * 255).round()).value),
                ),
                _ChannelSlider(
                  theme: t,
                  label: 'G',
                  value: color.green / 255,
                  onChanged: (v) => s.setCustomColor(
                      colorKey, color.withGreen((v * 255).round()).value),
                ),
                _ChannelSlider(
                  theme: t,
                  label: 'B',
                  value: color.blue / 255,
                  onChanged: (v) => s.setCustomColor(
                      colorKey, color.withBlue((v * 255).round()).value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelSlider extends StatelessWidget {
  final FizzThemeDef theme;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  const _ChannelSlider(
      {required this.theme,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 26,
      child: Row(
        children: [
          SizedBox(
              width: 14,
              child:
                  Text(label, style: Fizz.label(11, theme: theme))),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: theme.accent,
                inactiveTrackColor:
                    Colors.black.withValues(alpha: 0.4),
                thumbColor: theme.accentLight,
              ),
              child: Slider(value: value, onChanged: onChanged),
            ),
          ),
        ],
      ),
    );
  }
}
