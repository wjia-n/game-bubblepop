import 'package:flutter/material.dart';

/// Theme, bubble-style and launcher-style catalogs for Bubble Pop.
///
/// Art direction: the corner soda shop — warm wood, brass fittings, ivory
/// labels, and glossy physical candy bubbles. The variety comes from different
/// counter finishes, metal trims and candy color palettes. No neon, no
/// cyberpunk, no generic Material look.
class FizzThemeDef {
  final String id;
  final String name;
  final Color bgDeep; // page background
  final Color bgMid; // board backdrop
  final Color accent; // brass / copper / chrome …
  final Color accentLight;
  final Color accentDark;
  final Color ivory;
  final Color woodDark;
  final Color woodMid;
  final List<Color> bubbleColors; // 6 candy colors
  final List<String> bubbleColorNames;

  const FizzThemeDef({
    required this.id,
    required this.name,
    required this.bgDeep,
    required this.bgMid,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.ivory,
    required this.woodDark,
    required this.woodMid,
    required this.bubbleColors,
    required this.bubbleColorNames,
  });
}

class FizzThemes {
  /// First 4 are the FREE starter themes. The rest are PRO.
  static const List<String> freeThemeIds = [
    'sodaclassic',
    'cherrycola',
    'mintsoda',
    'bluerazz',
  ];

  static const List<FizzThemeDef> all = [
    FizzThemeDef(
      id: 'sodaclassic',
      name: 'Soda Classic',
      bgDeep: Color(0xFF2E1D12),
      bgMid: Color(0xFF4A2E1A),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFF0D98A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF8F1E2),
      woodDark: Color(0xFF3B2416),
      woodMid: Color(0xFF5C3A21),
      bubbleColors: [
        Color(0xFFE23E57), // cherry red
        Color(0xFF3FA7E8), // soda blue
        Color(0xFF4CC96F), // lime
        Color(0xFFFFC93C), // lemon
        Color(0xFF9B5DE5), // grape
        Color(0xFFFF8C42), // orange
      ],
      bubbleColorNames: ['Cherry', 'Soda', 'Lime', 'Lemon', 'Grape', 'Orange'],
    ),
    FizzThemeDef(
      id: 'cherrycola',
      name: 'Cherry Cola',
      bgDeep: Color(0xFF2B1214),
      bgMid: Color(0xFF462024),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF3DC8E),
      accentDark: Color(0xFF96702A),
      ivory: Color(0xFFF8F1E2),
      woodDark: Color(0xFF4A1F14),
      woodMid: Color(0xFF6E2F1C),
      bubbleColors: [
        Color(0xFFD7263D),
        Color(0xFFA31621),
        Color(0xFFF4A7C3),
        Color(0xFF7B2D8B),
        Color(0xFFF49D37),
        Color(0xFF3FA7E8),
      ],
      bubbleColorNames: ['Cola', 'Dark Cherry', 'Fizz', 'Plum', 'Caramel', 'Ice'],
    ),
    FizzThemeDef(
      id: 'mintsoda',
      name: 'Mint Soda',
      bgDeep: Color(0xFF12261E),
      bgMid: Color(0xFF1F4234),
      accent: Color(0xFFB08D3E),
      accentLight: Color(0xFFDFC084),
      accentDark: Color(0xFF7A6128),
      ivory: Color(0xFFF5EFE0),
      woodDark: Color(0xFF2E3B22),
      woodMid: Color(0xFF4A5A34),
      bubbleColors: [
        Color(0xFF57CC99),
        Color(0xFF80ED99),
        Color(0xFF3FA7E8),
        Color(0xFFFFC93C),
        Color(0xFFE23E57),
        Color(0xFFF5F5F5),
      ],
      bubbleColorNames: ['Mint', 'Spearmint', 'Glacier', 'Lemon', 'Cherry', 'Cream'],
    ),
    FizzThemeDef(
      id: 'bluerazz',
      name: 'Blue Razz',
      bgDeep: Color(0xFF101E33),
      bgMid: Color(0xFF1B3358),
      accent: Color(0xFFC0C6D4),
      accentLight: Color(0xFFE8ECF5),
      accentDark: Color(0xFF7E8698),
      ivory: Color(0xFFF2EEE4),
      woodDark: Color(0xFF1C2438),
      woodMid: Color(0xFF2C3A55),
      bubbleColors: [
        Color(0xFF38BDF8),
        Color(0xFF2563EB),
        Color(0xFF7B2D8B),
        Color(0xFF57CC99),
        Color(0xFFFFC93C),
        Color(0xFFE23E57),
      ],
      bubbleColorNames: ['Razz', 'Blueberry', 'Grape', 'Mint', 'Lemon', 'Cherry'],
    ),
    FizzThemeDef(
      id: 'rootbeer',
      name: 'Root Beer',
      bgDeep: Color(0xFF241309),
      bgMid: Color(0xFF3E2413),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFE09E5A),
      accentDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF5EFE0),
      woodDark: Color(0xFF3B2416),
      woodMid: Color(0xFF5C3A21),
      bubbleColors: [
        Color(0xFF8B5E34),
        Color(0xFFC08552),
        Color(0xFFF4E1C1),
        Color(0xFFD7263D),
        Color(0xFFFFC93C),
        Color(0xFF57CC99),
      ],
      bubbleColorNames: ['Brew', 'Foam', 'Cream', 'Cherry', 'Honey', 'Sassafras'],
    ),
    FizzThemeDef(
      id: 'grapefizz',
      name: 'Grape Fizz',
      bgDeep: Color(0xFF1E1433),
      bgMid: Color(0xFF322657),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF5EFE0),
      woodDark: Color(0xFF3A1A2E),
      woodMid: Color(0xFF552842),
      bubbleColors: [
        Color(0xFF9B5DE5),
        Color(0xFF7B2D8B),
        Color(0xFFF4A7C3),
        Color(0xFF38BDF8),
        Color(0xFFFFC93C),
        Color(0xFF4CC96F),
      ],
      bubbleColorNames: ['Grape', 'Concord', 'Blush', 'Glacier', 'Lemon', 'Lime'],
    ),
    FizzThemeDef(
      id: 'lemondrop',
      name: 'Lemon Drop',
      bgDeep: Color(0xFF2E2A12),
      bgMid: Color(0xFF4D4720),
      accent: Color(0xFF8C6A2F),
      accentLight: Color(0xFFD4A94E),
      accentDark: Color(0xFF5F471E),
      ivory: Color(0xFF2E2A18),
      woodDark: Color(0xFF9A6E34),
      woodMid: Color(0xFFB8894A),
      bubbleColors: [
        Color(0xFFFFC93C),
        Color(0xFFFFE66D),
        Color(0xFFFF8C42),
        Color(0xFF4CC96F),
        Color(0xFFE23E57),
        Color(0xFF38BDF8),
      ],
      bubbleColorNames: ['Lemon', 'Zest', 'Orange', 'Lime', 'Cherry', 'Soda'],
    ),
    FizzThemeDef(
      id: 'cottoncandy',
      name: 'Cotton Candy',
      bgDeep: Color(0xFF2E1A26),
      bgMid: Color(0xFF4E2C42),
      accent: Color(0xFFD4AF37),
      accentLight: Color(0xFFF3DC8E),
      accentDark: Color(0xFF96702A),
      ivory: Color(0xFFF8F1E2),
      woodDark: Color(0xFF3F1D24),
      woodMid: Color(0xFF5E2C36),
      bubbleColors: [
        Color(0xFFF4A7C3),
        Color(0xFF9B5DE5),
        Color(0xFF80ED99),
        Color(0xFF38BDF8),
        Color(0xFFFFE66D),
        Color(0xFFFF8C42),
      ],
      bubbleColorNames: ['Pink', 'Lilac', 'Mint', 'Sky', 'Sugar', 'Peach'],
    ),
    FizzThemeDef(
      id: 'colafloat',
      name: 'Cola Float',
      bgDeep: Color(0xFF141210),
      bgMid: Color(0xFF26211C),
      accent: Color(0xFFC0C6D4),
      accentLight: Color(0xFFF0F2F8),
      accentDark: Color(0xFF7E8698),
      ivory: Color(0xFFF2EEE4),
      woodDark: Color(0xFF1A1A1E),
      woodMid: Color(0xFF2A2A30),
      bubbleColors: [
        Color(0xFF5C3A21),
        Color(0xFFF5F5F5),
        Color(0xFFD7263D),
        Color(0xFFFFC93C),
        Color(0xFF38BDF8),
        Color(0xFF9B5DE5),
      ],
      bubbleColorNames: ['Cola', 'Vanilla', 'Cherry', 'Lemon', 'Ice', 'Grape'],
    ),
    FizzThemeDef(
      id: 'icedtea',
      name: 'Iced Tea',
      bgDeep: Color(0xFF2A2013),
      bgMid: Color(0xFF463722),
      accent: Color(0xFFB87333),
      accentLight: Color(0xFFE09E5A),
      accentDark: Color(0xFF7E4F22),
      ivory: Color(0xFFF5EFE0),
      woodDark: Color(0xFF4A3614),
      woodMid: Color(0xFF6E5324),
      bubbleColors: [
        Color(0xFFC08552),
        Color(0xFFFFC93C),
        Color(0xFF8B5E34),
        Color(0xFF57CC99),
        Color(0xFFF4A7C3),
        Color(0xFFE23E57),
      ],
      bubbleColorNames: ['Amber', 'Lemon', 'Brew', 'Mint', 'Peach', 'Berry'],
    ),
    FizzThemeDef(
      id: 'watermelon',
      name: 'Watermelon Cooler',
      bgDeep: Color(0xFF1E2A14),
      bgMid: Color(0xFF354A24),
      accent: Color(0xFFC9A227),
      accentLight: Color(0xFFE8CE7A),
      accentDark: Color(0xFF8A6D1A),
      ivory: Color(0xFFF1EAD8),
      woodDark: Color(0xFF3F4226),
      woodMid: Color(0xFF5E6238),
      bubbleColors: [
        Color(0xFFE23E57),
        Color(0xFF4CC96F),
        Color(0xFFFF8C42),
        Color(0xFFF4A7C3),
        Color(0xFF38BDF8),
        Color(0xFFFFE66D),
      ],
      bubbleColorNames: ['Melon', 'Rind', 'Citrus', 'Pink', 'Cooler', 'Seed'],
    ),
    FizzThemeDef(
      id: 'limerickey',
      name: 'Lime Rickey',
      bgDeep: Color(0xFF12241E),
      bgMid: Color(0xFF1F3E33),
      accent: Color(0xFFB08D3E),
      accentLight: Color(0xFFDFC084),
      accentDark: Color(0xFF7A6128),
      ivory: Color(0xFFF0EDE2),
      woodDark: Color(0xFF1E3A38),
      woodMid: Color(0xFF2E5654),
      bubbleColors: [
        Color(0xFF4CC96F),
        Color(0xFF80ED99),
        Color(0xFFF5F5F5),
        Color(0xFFFFC93C),
        Color(0xFF38BDF8),
        Color(0xFF9B5DE5),
      ],
      bubbleColorNames: ['Lime', 'Zest', 'Fizz', 'Lemon', 'Soda', 'Grape'],
    ),
  ];

  static FizzThemeDef byId(String id, {FizzThemeDef? custom}) {
    if (id == 'custom') {
      return custom ?? all.first;
    }
    return all.firstWhere((t) => t.id == id, orElse: () => all.first);
  }

  static bool isProTheme(String id) =>
      !freeThemeIds.contains(id) && id != 'custom';
}

/// Bubble material styles. 0-3 = FREE, 4+ = PRO.
class BubbleStyles {
  static const names = [
    'Classic Glass',
    'Candy Swirl',
    'Marble',
    'Pearl',
    'Wooden Bead',
    'Frosted Ice',
    'Metallic',
    'Jelly',
    'Rainbow Gum',
    'Obsidian',
  ];
  static const descriptions = [
    'Glossy glass marble with a shine spot',
    'Spun candy stripes in the bubble',
    'Swirled stone veins',
    'Soft nacre sheen, like a real pearl',
    'Turned wooden bead with grain',
    'Matte frosted glass with ice speckle',
    'Polished chrome band around the belly',
    'Translucent jelly with a wobble shine',
    'Rainbow arcs in every bubble',
    'Dark smoked glass, silver rim',
  ];

  /// Styles free players may use.
  static const freeCount = 4;
  static bool isPro(int index) => index >= freeCount;
}

/// Launcher (shooter) styles. 0-3 = FREE, 4+ = PRO.
class LauncherStyles {
  static const names = [
    'Wooden Tap',
    'Brass Cannon',
    'Copper Pipe',
    'Bamboo Tube',
    'Ivory & Brass',
    'Chrome Works',
  ];
  static const descriptions = [
    'Oak barrel tap with brass bands',
    'Polished brass cannon barrel',
    'Hammered copper pipe',
    'Lacquered bamboo tube',
    'Ivory collar, brass body',
    'Mirror-chrome industrial works',
  ];

  /// Styles free players may use.
  static const freeCount = 4;
  static bool isPro(int index) => index >= freeCount;
}
