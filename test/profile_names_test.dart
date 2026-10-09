import 'package:flutter_test/flutter_test.dart';
import 'package:bubblepop/services/settings_service.dart';

/// Regression tests for order-safe profile persistence.
///
/// Player profiles are stored as ONE JSON array string under the
/// `bubblepop_player_names_json` key. Android's SharedPreferences backs
/// StringLists with an UNORDERED StringSet, so any ordered data stored via
/// setStringList comes back scrambled after an app restart — hence the
/// array-string format. These tests cover the encode/decode round-trip plus
/// the legacy key migration, without needing platform channels.
void main() {
  test('profile survives an encode/decode round-trip exactly', () {
    const name = 'Wajiha';
    final decoded = FizzSettings.decodeProfile(
      FizzSettings.encodeProfile([name]),
    );
    expect(decoded['name'], name);
  });

  test('encoded profile is a single JSON array string, never a list', () {
    final raw = FizzSettings.encodeProfile(['Wajiha']);
    expect(raw.startsWith('['), isTrue);
    expect(raw.contains('Wajiha'), isTrue);
  });

  test('multiple names keep their order through the JSON array', () {
    final decoded = FizzSettings.decodeProfile(
      FizzSettings.encodeProfile(['Zara', 'Ali', 'Bob']),
    );
    expect(decoded['name'], 'Zara');
  });

  test('decode falls back to the default name on missing or corrupt data',
      () {
    expect(FizzSettings.decodeProfile(null)['name'],
        FizzSettings.defaultName);
    expect(FizzSettings.decodeProfile('definitely not json')['name'],
        FizzSettings.defaultName);
    expect(FizzSettings.decodeProfile('[]')['name'],
        FizzSettings.defaultName);
    expect(FizzSettings.decodeProfile('{"name":"Wajiha"}')['name'],
        FizzSettings.defaultName);
  });

  test('blank names fall back to the default name', () {
    expect(FizzSettings.decodeProfile('[""]')['name'],
        FizzSettings.defaultName);
    expect(FizzSettings.decodeProfile('["   "]')['name'],
        FizzSettings.defaultName);
  });

  test('legacy single-name key migrates into the JSON profile', () {
    final decoded = FizzSettings.decodeProfile(null, legacyName: 'Zara');
    expect(decoded['name'], 'Zara');
  });

  test('legacy name list migrates the first slot only', () {
    final decoded =
        FizzSettings.decodeProfile(null, legacyNames: ['Ali', 'Bob']);
    expect(decoded['name'], 'Ali');
  });

  test('legacy map-format JSON migrates into the array profile', () {
    final decoded = FizzSettings.decodeProfile(
      null,
      legacyMap: '{"name":"Wajiha"}',
    );
    expect(decoded['name'], 'Wajiha');
  });

  test('array key wins over legacy keys when both exist', () {
    final decoded = FizzSettings.decodeProfile(
      '["New"]',
      legacyMap: '{"name":"Old"}',
      legacyName: 'Older',
    );
    expect(decoded['name'], 'New');
  });
}
