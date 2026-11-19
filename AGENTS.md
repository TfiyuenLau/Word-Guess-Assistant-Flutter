# Word Guess Assistant (Flutter) — Project Rules

## 1. Core Gameplay & UI Invariants
- **Full-screen IM room**: Keep `RoomScreen` as a full-screen mobile IM chat UI. Do NOT add a permanent top player-grid container; show roster on demand (`PlayerRosterSheet`) via the AppBar player-count button, keep `Icons.arrow_back` on the top-left, and place the Host-only floating `FloatingActionButton` at bottom-right above the bottom bar without covering messages, avatars, or action buttons.
- **Click avatar to mark**: Tapping another player's SVG `AvatarWidget` in chat (or roster) opens `PlayerMarkDialog` for local-only role guessing (`好人`/`卧底`/`天使`/`白板`). Render local marks next to the player's name and clear `playerMarks` on game settlement, reset, and `leaveRoom()`.
- **Dead (`OUT`) & spectator gating**: Render eliminated players with `OUT` avatar badge/pill and disable chat input and game actions for eliminated and spectator players.
- **Chat message rules**:
  - ALWAYS pass `player.id` (never `player.name`) as `senderId` in `GameMessage.chat`.
  - Non-host clients send chat to host without locally double-appending.
  - Round 1 `description`: bots speak automatically on start; repeat speeches by the same `senderId` update that player's Round-1 bubble in place (`is_speech: true, speech_round: 1`).
  - Voting, Night, BlankGuess, Settlement, and Round 2+ `description` lock text input for everyone until reset to `preparing`. Entering Round 2+ `description` replays all Round-1 speeches (including self) at the bottom of chat.
- **Voting & night secrecy**:
  - Never broadcast public vote-progress spam (`1/4` etc.) or who voted for whom; show a private self-only notice (`你已投票给 ...`) and lock to 1 vote per round.
  - Night actions are locked to 1 per player per night with neutral acknowledgment (`已记录夜间行动。`); reveal casualties/平安夜 objectively only at dawn without exposing assassination vs. self-elimination cause.
  - Good/Spy identities show blind-box (`盲盒词语`) until `settlement`. Show `PhaseNoticeDialog` on phase transitions.

## 2. Flutter Technical Guardrails
- **Socket & stream lifecycle**:
  - In `GameController.joinRoom()` / `createRoom()`, initialize room state and attach `_listenTransport()` BEFORE `await _transport!.joinRoom(...)` / `hostRoom(...)` so initial loopback `syncState` frames are never dropped.
  - In `LanTransport` (`lib/network/lan/lan_transport_io.dart`), queue TCP frames with `socket.add(frame)` — NEVER `await socket.flush()` per message (concurrent flushes throw `StateError: StreamSink is bound to a stream`).
  - Always reset `selfPlayer` alive/role/word/hint/mark and `currentRound` on `leaveRoom()` and guard async state updates with `if (!mounted)`.
- **Widget safety**: Never place `GridView(shrinkWrap: true)` inside `AlertDialog.content` (throws `RenderShrinkWrappingViewport` intrinsic-dimensions error); use `Column` + `Row` instead. Use SVG `AvatarWidget` consistently across screens and dialogs.

## 3. Git Workflow
- Create local `git commit` checkpoints when verified, and **NEVER run `git push`** unless explicitly instructed by the user.
