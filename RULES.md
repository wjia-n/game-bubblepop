# Bubble Pop — Rules

_Soda Shop edition. The authoritative source of truth for gameplay. If the
implementation conflicts with this document, fix the implementation._

## 1. Objective

Aim and fire bubbles from the launcher to clear the board. In **Levels**
mode, clear all 30 levels to become the Pop Master. In **Endless** mode,
score as many points as possible before the bubbles cross the red line.

## 2. Setup

- The board is a honeycomb grid of offset rows (9 cells on even rows,
  8 on odd rows), pre-filled with 3–7 rows of candy bubbles.
- The launcher sits at the bottom center, loaded with one bubble; the
  next bubble is shown on deck beside it.
- Levels mode starts at Level 1; Endless starts with 4 rows.

## 3. Turn order

- Single-player, turnless action game: aim → fire → the ball flies →
  snaps → pops/drops settle → aim again.
- Exactly one ball may be in flight at a time. Firing while a ball is in
  flight, while pops are settling, while paused, or after game over is
  ignored (invalid feedback, no state change).

## 4. Legal moves

- Drag anywhere to aim (upward cone only); release to fire.
- Tap the loaded bubble to swap it with the on-deck bubble (aiming only).
- Fire only when the engine is in the `aiming` phase.

## 5. Illegal moves

- Firing during `flying`, `settling`, `levelClear`, `over`, or while paused.
- Swapping during any phase other than `aiming`.
- Aiming below the horizontal (clamped to the upward cone).

## 6. Captures

- There are no captures; this section is not applicable (kept for template
  parity). Pops are matches, not captures.

## 7. Special rules

- **Match pop:** a fired bubble that connects 3 or more same-color bubbles
  (flood fill through touching neighbors) pops the whole group.
- **Droppers:** any bubble no longer connected to the top row falls and is
  collected for points.
- **Ceiling drops:** every N shots (Easy 7, Normal 6, Hard 5; Endless scales
  down from 7 to 4 as score grows) the ceiling drops — all bubbles shift
  down one row and a fresh row appears at the top.
- **Combos:** consecutive shots that pop (without a miss or a non-popping
  shot in between) multiply pop points: `10 × group × combo`.
- **Miss:** a ball that falls back past the launcher is wasted — the shot
  counts, the combo resets, no pop.

## 8. Scoring

- Pop: `10 × bubbles popped × current combo multiplier`.
- Dropper: `15` points per fallen bubble.
- Level clear bonus: `100 × level` (Levels mode); `100` per rack (Endless).
- Win bonus: none beyond the final level-clear bonus.

## 9. Winning conditions

- Levels mode: clear all 30 levels → Pop Master victory screen.
- Endless mode: there is no win; the run ends when the death line is
  crossed — the score is the result.

## 10. Draw conditions

- Not applicable (single-player). No draws.

## 11. AI strategy

- No AI opponents. Difficulty tiers scale the challenge instead:
  - **Easy:** slower shots, max 4 colors, ceiling drops every 7 shots.
  - **Normal:** classic pace, max 5 colors, ceiling drops every 6 shots.
  - **Hard (PRO):** faster shots, 6 colors, ceiling drops every 5 shots.
- The on-deck bubble prefers colors still present on the board, so the
  player is never handed an unmatchable color while matches exist.

## 12. Edge cases

- A ball that can find no attachable cell consumes the shot (never hangs).
- A ball that vanishes mid-flight (watchdog): phase returns to `aiming`.
- Ceiling drop pushing a bubble past the bottom of the board = instant
  loss (it crossed the death line).
- Clearing the last bubble of the final level = win, even if the death
  line would also be crossed that shot (clear is checked first).
- Pause freezes the phase timer and ball physics; resume re-arms the
  current phase. App backgrounding auto-pauses.
- Restart resets score, level, combo, grid, and timers deterministically.

## 13. Test cases

1. Fire a ball that completes a 3-group → group pops, score increases,
   combo becomes 1.
2. Pop on two consecutive shots → second pop scores with combo ×2.
3. A shot that pops nothing → combo resets to 0.
4. Fire at an isolated bubble pair of another color → no pop, ball sticks.
5. Pop the last anchor of a cluster → whole cluster drops, drop points
   awarded.
6. Every Nth shot → ceiling drops, new row appears at top, banner shows.
7. Bubble crosses the red death line → game over (loss), phase `over`.
8. Clear the board on level < 30 → level-clear bonus, next level builds.
9. Clear the board on level 30 → victory, phase `over`, `won == true`.
10. Endless: clear the board → fresh rack, run continues.
11. Fire during flight/settle → ignored, no second ball.
12. Swap during aiming → current/next exchange; swap during flight ignored.
13. Pause mid-flight → ball freezes; resume → continues.
14. Profile name round-trips through one JSON string in exact form.
15. Watchdog: engine with a killed timer in `settling` recovers to `aiming`.
