import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/fizz_themes.dart';

/// Persisted settings + stats for Bubble Pop. Survives app restarts.
///
/// Stores: audio toggles, the renameable player profile (ONE JSON string —
/// never setStringList, which Android backs with an unordered StringSet),
/// theme/appearance choices (incl. custom theme colors), mode setup
/// (levels/endless, difficulty), Pro unlock state, and lifetime stats.
class FizzSettings extends ChangeNotifier {
  static const _kMusic = 'bubblepop_music_on';
  static const _kSfx = 'bubblepop_sfx_on';
  static const _kVolume = 'bubblepop_volume';
  static const _kProfile = 'bubblepop_player_names_json';
  // Legacy keys from earlier builds — migrated once, then removed.
  static const _kLegacyProfileMap = 'bubblepop_profile_json';
  static const _kLegacyName = 'bubblepop_player_name';
  static const _kLegacyNames = 'bubblepop_player_names';
  static const _kTheme = 'bubblepop_theme_id';
  static const _kBubbleStyle = 'bubblepop_bubble_style';
  static const _kLauncherStyle = 'bubblepop_launcher_style';
  static const _kMode = 'bubblepop_mode'; // 0 = levels, 1 = endless
  static const _kDifficulty = 'bubblepop_difficulty'; // 0 easy 1 normal 2 hard
  static const _kBestLevels = 'bubblepop_best_levels';
  static const _kBestEndless = 'bubblepop_best_endless';
  static const _kGames = 'bubblepop_games_played';
  static const _kPops = 'bubblepop_total_pops';
  static const _kBestCombo = 'bubblepop_best_combo';
  static const _kIsPro = 'bubblepop_is_pro';
  static const _kCustomPrefix = 'bubblepop_custom_';

  static const defaultName = 'Popper';

  /// Encode the player names as ONE order-preserving JSON array string.
  /// Never a StringList — Android's SharedPreferences backs StringLists
  /// with an unordered StringSet, scrambling slot order across restarts.
  static String encodeProfile(List<String> names) => jsonEncode(names);

  static String _cleanName(Object? v) {
    final s = v is String ? v.trim() : '';
    return s.isEmpty ? defaultName : s;
  }

  /// Decode the persisted profile; falls back to defaults on missing/corrupt
  /// data. Migrates legacy keys ([legacyMap] = the earlier {"name": …} JSON
  /// object) when the array key is absent.
  static Map<String, Object> decodeProfile(String? raw,
      {String? legacyMap, String? legacyName, List<String>? legacyNames}) {
    String? fromArray(String? s) {
      if (s == null) return null;
      try {
        final d = jsonDecode(s);
        if (d is List && d.isNotEmpty) return _cleanName(d.first);
      } catch (_) {}
      return null;
    }

    var name = fromArray(raw) ?? fromArray(legacyMap);
    if (name == null && legacyMap != null) {
      try {
        final d = jsonDecode(legacyMap);
        if (d is Map && d['name'] != null) name = _cleanName(d['name']);
      } catch (_) {}
    }
    name ??= legacyNames != null && legacyNames.isNotEmpty
        ? _cleanName(legacyNames.first)
        : (legacyName != null ? _cleanName(legacyName) : defaultName);
    return {'name': name};
  }

  bool musicOn = true;
  bool sfxOn = true;
  double volume = 0.8;
  String playerName = defaultName;
  String themeId = 'sodaclassic';
  int bubbleStyle = 0;
  int launcherStyle = 0;
  int mode = 0; // 0 = levels, 1 = endless
  int difficulty = 1; // 1 = normal default
  int bestLevelsScore = 0;
  int bestEndlessScore = 0;
  int gamesPlayed = 0;
  int totalPops = 0;
  int bestCombo = 0;
  bool isPro = false;

  /// Custom theme colors (ARGB ints). Defaults mirror Soda Classic.
  Map<String, int> customColors = Map.of(_defaultCustomColors);

  static const Map<String, int> _defaultCustomColors = {
    'bgDeep': 0xFF2E1D12,
    'bgMid': 0xFF4A2E1A,
    'accent': 0xFFC9A227,
    'accentLight': 0xFFF0D98A,
    'accentDark': 0xFF8A6D1A,
    'ivory': 0xFFF8F1E2,
    'woodDark': 0xFF3B2416,
    'woodMid': 0xFF5C3A21,
    'b0': 0xFFE23E57,
    'b1': 0xFF3FA7E8,
    'b2': 0xFF4CC96F,
    'b3': 0xFFFFC93C,
    'b4': 0xFF9B5DE5,
    'b5': 0xFFFF8C42,
  };

  /// Builds the user-designed custom theme from stored colors.
  FizzThemeDef get customTheme {
    Color c(String k) => Color(customColors[k] ?? 0xFF000000);
    return FizzThemeDef(
      id: 'custom',
      name: 'My Creation',
      bgDeep: c('bgDeep'),
      bgMid: c('bgMid'),
      accent: c('accent'),
      accentLight: c('accentLight'),
      accentDark: c('accentDark'),
      ivory: c('ivory'),
      woodDark: c('woodDark'),
      woodMid: c('woodMid'),
      bubbleColors: [c('b0'), c('b1'), c('b2'), c('b3'), c('b4'), c('b5')],
      bubbleColorNames: const [
        'Custom 1',
        'Custom 2',
        'Custom 3',
        'Custom 4',
        'Custom 5',
        'Custom 6'
      ],
    );
  }

  SharedPreferences? _prefs;
  bool get loaded => _prefs != null;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    musicOn = p.getBool(_kMusic) ?? true;
    sfxOn = p.getBool(_kSfx) ?? true;
    volume = p.getDouble(_kVolume) ?? 0.8;
    // Profile: prefer the order-safe JSON key; migrate legacy keys once.
    final profile = decodeProfile(
      p.getString(_kProfile),
      legacyMap: p.getString(_kLegacyProfileMap),
      legacyName: p.getString(_kLegacyName),
      legacyNames: p.getStringList(_kLegacyNames),
    );
    playerName = profile['name'] as String;
    themeId = p.getString(_kTheme) ?? 'sodaclassic';
    bubbleStyle = (p.getInt(_kBubbleStyle) ?? 0).clamp(0, 9);
    launcherStyle = (p.getInt(_kLauncherStyle) ?? 0).clamp(0, 5);
    mode = (p.getInt(_kMode) ?? 0).clamp(0, 1);
    difficulty = (p.getInt(_kDifficulty) ?? 1).clamp(0, 2);
    bestLevelsScore = p.getInt(_kBestLevels) ?? 0;
    bestEndlessScore = p.getInt(_kBestEndless) ?? 0;
    gamesPlayed = p.getInt(_kGames) ?? 0;
    totalPops = p.getInt(_kPops) ?? 0;
    bestCombo = p.getInt(_kBestCombo) ?? 0;
    isPro = p.getBool(_kIsPro) ?? false;
    for (final k in _defaultCustomColors.keys) {
      customColors[k] = p.getInt('$_kCustomPrefix$k') ?? _defaultCustomColors[k]!;
    }
    _enforceFreeLimits(silent: true);
    notifyListeners();
  }

  Future<void> _save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setBool(_kMusic, musicOn);
    await p.setBool(_kSfx, sfxOn);
    await p.setDouble(_kVolume, volume);
    await p.setString(_kProfile, encodeProfile([playerName]));
    await p.remove(_kLegacyProfileMap); // drop legacy keys for good
    await p.remove(_kLegacyName);
    await p.remove(_kLegacyNames);
    await p.setString(_kTheme, themeId);
    await p.setInt(_kBubbleStyle, bubbleStyle);
    await p.setInt(_kLauncherStyle, launcherStyle);
    await p.setInt(_kMode, mode);
    await p.setInt(_kDifficulty, difficulty);
    await p.setInt(_kBestLevels, bestLevelsScore);
    await p.setInt(_kBestEndless, bestEndlessScore);
    await p.setInt(_kGames, gamesPlayed);
    await p.setInt(_kPops, totalPops);
    await p.setInt(_kBestCombo, bestCombo);
    await p.setBool(_kIsPro, isPro);
    for (final e in customColors.entries) {
      await p.setInt('$_kCustomPrefix${e.key}', e.value);
    }
  }

  /// Free-tier limits: clamp pro-only choices back when not Pro.
  void _enforceFreeLimits({bool silent = false}) {
    if (isPro) return;
    var changed = false;
    if (themeId == 'custom' || FizzThemes.isProTheme(themeId)) {
      themeId = 'sodaclassic';
      changed = true;
    }
    if (BubbleStyles.isPro(bubbleStyle)) {
      bubbleStyle = 0;
      changed = true;
    }
    if (LauncherStyles.isPro(launcherStyle)) {
      launcherStyle = 0;
      changed = true;
    }
    if (difficulty > 1) {
      difficulty = 1;
      changed = true;
    }
    if (changed && !silent) {
      notifyListeners();
      _save();
    }
  }

  Future<void> setPro(bool v) async {
    isPro = v;
    if (!v) _enforceFreeLimits();
    notifyListeners();
    await _save();
  }

  Future<void> setCustomColor(String key, int argb) async {
    if (!isPro) return; // custom theme creator is a Pro feature
    if (!_defaultCustomColors.containsKey(key)) return;
    customColors[key] = argb;
    notifyListeners();
    await _save();
  }

  Future<void> resetCustomColors() async {
    customColors = Map.of(_defaultCustomColors);
    notifyListeners();
    await _save();
  }

  Future<void> setMusic(bool v) async {
    musicOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setSfx(bool v) async {
    sfxOn = v;
    notifyListeners();
    await _save();
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    notifyListeners();
    await _save();
  }

  Future<void> setPlayerName(String name) async {
    final clean = name.trim();
    playerName = clean.isEmpty ? defaultName : clean;
    notifyListeners();
    await _save();
  }

  Future<void> setTheme(String id) async {
    // Pro-only themes (incl. the custom theme creator) require Pro;
    // silently ignore otherwise (UI shows lock).
    if (!isPro && (id == 'custom' || FizzThemes.isProTheme(id))) return;
    themeId = id;
    notifyListeners();
    await _save();
  }

  Future<void> setBubbleStyle(int v) async {
    v = v.clamp(0, BubbleStyles.names.length - 1);
    if (!isPro && BubbleStyles.isPro(v)) return;
    bubbleStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setLauncherStyle(int v) async {
    v = v.clamp(0, LauncherStyles.names.length - 1);
    if (!isPro && LauncherStyles.isPro(v)) return;
    launcherStyle = v;
    notifyListeners();
    await _save();
  }

  Future<void> setMode(int v) async {
    mode = v.clamp(0, 1);
    notifyListeners();
    await _save();
  }

  Future<void> setDifficulty(int v) async {
    v = v.clamp(0, 2);
    // Hard is a Pro feature.
    if (!isPro && v > 1) return;
    difficulty = v;
    notifyListeners();
    await _save();
  }

  /// Record a finished run. [endless] picks the score table.
  Future<void> recordGame(
      {required bool endless,
      required int score,
      required int pops,
      required int combo}) async {
    gamesPlayed++;
    totalPops += pops;
    if (combo > bestCombo) bestCombo = combo;
    if (endless) {
      if (score > bestEndlessScore) bestEndlessScore = score;
    } else {
      if (score > bestLevelsScore) bestLevelsScore = score;
    }
    notifyListeners();
    await _save();
  }
}
