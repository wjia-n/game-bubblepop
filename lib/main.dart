import 'package:flutter/material.dart';
import 'package:wajiha_game_core/wajiha_game_core.dart';
import 'game_screen.dart';

void main() => runApp(const BubblePopApp());

class BubblePopApp extends StatelessWidget {
  const BubblePopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GameShell(
      variant: ShellVariant.neonArcade,
      title: 'Bubble Pop',
      tagline: 'Aim true, match three, and pop your way to fizzy glory!',
      emoji: '🫧',
      slug: 'bubblepop',
      howToPlay:
          '• Drag to aim, release to fire your bubble.\n• Match 3 or more bubbles of the same color to pop them.\n• Bubbles left hanging with nothing above will drop!\n• Every 6 shots the ceiling drops — don\'t let bubbles cross the line!\n• Clear all 15 levels to become the Pop Master.',
      playerOptions: const [1],
      supportsBots: false,
      gameBuilder: (ctx, players, cb) => BubblePopScreen(players: players, callbacks: cb),
    );
  }
}
