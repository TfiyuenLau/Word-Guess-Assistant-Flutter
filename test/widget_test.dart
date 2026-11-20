import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_guess_assistant_flutter/controllers/game_controller.dart';
import 'package:word_guess_assistant_flutter/controllers/settings_controller.dart';
import 'package:word_guess_assistant_flutter/controllers/theme_controller.dart';
import 'package:word_guess_assistant_flutter/main.dart';
import 'package:word_guess_assistant_flutter/models/game_models.dart';
import 'package:word_guess_assistant_flutter/models/protocol_messages.dart';
import 'package:word_guess_assistant_flutter/models/word_bank.dart';
import 'package:word_guess_assistant_flutter/ui/modals/avatar_picker_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/blank_guess_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/host_console_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/identity_card_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/night_action_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/phase_notice_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/player_mark_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/player_roster_sheet.dart';
import 'package:word_guess_assistant_flutter/ui/modals/rule_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/settlement_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/settings_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/vote_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/screens/room_screen.dart';
import 'package:word_guess_assistant_flutter/ui/widgets/avatar_widget.dart';

class _TestGameController extends GameController {
  _TestGameController(RoomState initial) : super() {
    state = initial;
  }

  void setTestState(RoomState next) {
    state = next;
  }

  @override
  Future<void> sendChatMessage(String text) async {
    if (!state.canSendChat) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final isRound1Speech =
        state.currentPhase == GamePhase.description && state.currentRound == 1;

    final msg = GameMessage(
      type: GameMessageType.chat,
      payload: {
        'sender_id': state.selfPlayer.id,
        'text': trimmed,
        'is_system': false,
        if (isRound1Speech) 'is_speech': true,
        if (isRound1Speech) 'speech_round': 1,
      },
    );

    final updated = List<GameMessage>.from(state.chatMessages);
    if (isRound1Speech) {
      final idx = updated.indexWhere((m) =>
          m.payload['is_system'] != true &&
          m.payload['sender_id'] == state.selfPlayer.id &&
          m.payload['is_speech'] == true);
      if (idx != -1) {
        updated[idx] = msg;
      } else {
        updated.add(msg);
      }
    } else {
      updated.add(msg);
    }
    state = state.copyWith(chatMessages: updated);
  }

  @override
  Future<void> submitVote(String targetId) async {
    if (!state.canVote) return;
    final target = state.players.firstWhere((p) => p.id == targetId);
    final updated = List<GameMessage>.from(state.chatMessages)
      ..add(GameMessage.chat(
        senderId: 'SYSTEM',
        text: '你已投票给 ${target.name}',
        isSystem: true,
      ));
    state = state.copyWith(
      hasVotedThisRound: true,
      myVotedTargetId: targetId,
      chatMessages: updated,
    );
  }

  @override
  Future<void> submitNightAction(String targetId) async {
    if (!state.canNightAct) return;
    final updated = List<GameMessage>.from(state.chatMessages)
      ..add(GameMessage.chat(
        senderId: 'SYSTEM',
        text: '已记录夜间行动。',
        isSystem: true,
      ));
    state = state.copyWith(
      hasNightActedThisRound: true,
      chatMessages: updated,
    );
  }

  @override
  void resetGame() {
    state = state.copyWith(
      currentPhase: GamePhase.preparing,
      currentRound: 1,
      playerMarks: const {},
      hasVotedThisRound: false,
      clearMyVotedTarget: true,
      hasNightActedThisRound: false,
      clearSettlement: true,
      clearWinner: true,
      clearIdentity: true,
    );
  }
}

RoomState _sampleRoomState({
  bool isHost = true,
  GamePhase phase = GamePhase.description,
  int round = 1,
  bool selfAlive = true,
  bool hasVoted = false,
  bool hasNightActed = false,
  Map<String, String> marks = const {},
}) {
  final self = Player(
    id: 'p_self',
    name: '我方玩家',
    avatar: 'characters/detective.svg',
    isAlive: selfAlive,
  );
  const p2 = Player(
    id: 'p_2',
    name: 'AI · Alpha',
    avatar: 'animals/fox.svg',
    isAlive: true,
    isBot: true,
  );
  const p3 = Player(
    id: 'p_3',
    name: 'AI · Bravo',
    avatar: 'cyber/hacker.svg',
    isAlive: false,
    isBot: true,
  );
  const p4 = Player(
    id: 'p_4',
    name: 'AI · Charlie',
    avatar: 'animals/cat.svg',
    isAlive: true,
    isBot: true,
  );

  return RoomState(
    selfPlayer: self,
    roomId: '4521',
    isHost: isHost,
    isInRoom: true,
    currentPhase: phase,
    currentRound: round,
    myIdentity: const IdentityAssignment(
      role: GameRoles.agent,
      word: '咖啡',
      hint: '',
    ),
    players: [self, p2, p3, p4],
    playerMarks: marks,
    hasVotedThisRound: hasVoted,
    hasNightActedThisRound: hasNightActed,
    chatMessages: [
      GameMessage.chat(
        senderId: 'SYSTEM',
        text: '游戏开始，第 1 轮描述开始。',
        isSystem: true,
      ),
      GameMessage(
        type: GameMessageType.chat,
        payload: {
          'sender_id': 'p_2',
          'text': '这是一种常见的提神饮品。',
          'is_system': false,
          'is_speech': true,
          'speech_round': 1,
        },
      ),
      GameMessage(
        type: GameMessageType.chat,
        payload: {
          'sender_id': 'p_3',
          'text': '早晨经常能闻到它的香气。',
          'is_system': false,
          'is_speech': true,
          'speech_round': 1,
        },
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    WordBank.loadFromJsonString(File('assets/word_bank.json').readAsStringSync());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('HomeScreen Minimalist & Responsive Layout', () {
    testWidgets('Mobile portrait (390x844) defaults to Light theme and single-column layout', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: WordGuessAssistantApp()));
      await tester.pumpAndSettle();

      // Default theme is Light (#F8FAFC)
      final scaffoldCtx = tester.element(find.byType(Scaffold));
      final theme = Theme.of(scaffoldCtx);
      expect(theme.brightness, equals(Brightness.light));
      expect(theme.scaffoldBackgroundColor, equals(const Color(0xFFF8FAFC)));

      // Clean minimalist title & zero legacy dramatic labels
      expect(find.text('猜词助手'), findsOneWidget);
      expect(find.text('特工猜词助手'), findsNothing);
      expect(find.text('特工机密档案'), findsNothing);
      expect(find.text('WebRTC P2P'), findsNothing);

      // Avatar picker is dialog-only: only 1 AvatarWidget on HomeScreen
      expect(find.byType(AvatarWidget), findsOneWidget);

      // Single-column order: Profile -> 游戏规则 -> Mode Switch
      final profilePos = tester.getTopLeft(find.byType(AvatarWidget));
      final ruleButton = find.text('游戏规则');
      final modeSwitch = find.byType(SegmentedButton<String>);
      expect(ruleButton, findsOneWidget);
      expect(modeSwitch, findsOneWidget);
      expect(tester.getTopLeft(ruleButton).dy, greaterThan(profilePos.dy));
      expect(tester.getTopLeft(modeSwitch).dy, greaterThan(tester.getTopLeft(ruleButton).dy));

      // Tap 游戏规则 -> opens RuleDialog
      await tester.tap(ruleButton);
      await tester.pumpAndSettle();
      expect(find.byType(RuleDialog), findsOneWidget);
      expect(find.text('白板逆袭'), findsOneWidget);
      await tester.tap(find.text('知道了'));
      await tester.pumpAndSettle();

      // Tap AvatarWidget -> opens AvatarPickerDialog with 3 tabs
      await tester.tap(find.byType(AvatarWidget));
      await tester.pumpAndSettle();
      expect(find.byType(AvatarPickerDialog), findsOneWidget);
      expect(find.text('角色'), findsOneWidget);
      expect(find.text('动物'), findsOneWidget);
      expect(find.text('赛博'), findsOneWidget);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      // Tap settings gear button -> opens SettingsDialog with theme chips & LLM API defaults
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsDialog), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('主题'), findsOneWidget);
      expect(find.text('浅色'), findsOneWidget);
      expect(find.text('暗夜'), findsOneWidget);
      expect(find.text('AIGC 接口'), findsOneWidget);

      final urlField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'API 地址'),
      );
      final keyField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'API Key'),
      );
      final modelField = tester.widget<TextField>(
        find.widgetWithText(TextField, '模型名称'),
      );
      expect(urlField.controller?.text, LlmSettings.defaultApiUrl);
      expect(keyField.controller?.text, '');
      expect(modelField.controller?.text, LlmSettings.defaultModel);

      // Switch theme to 暗夜 live, then back to 浅色 and close
      await tester.tap(find.text('暗夜'));
      await tester.pumpAndSettle();
      expect(
        Theme.of(tester.element(find.byType(SettingsDialog))).brightness,
        Brightness.dark,
      );
      await tester.tap(find.text('浅色'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Switch to LAN mode -> IP 地址 + 端口 inputs
      await tester.tap(find.text('局域网'));
      await tester.pumpAndSettle();
      expect(find.text('IP 地址'), findsOneWidget);
      expect(find.text('端口'), findsOneWidget);
      expect(find.text('发现局域网房间'), findsNothing);
      expect(find.text('创建局域网房间'), findsOneWidget);
    });

    testWidgets('Wide desktop (1100x760) renders edge-to-edge two-column layout without 430px cage', (tester) async {
      tester.view.physicalSize = const Size(1100, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ProviderScope(child: WordGuessAssistantApp()));
      await tester.pumpAndSettle();

      // Scaffold & AppBar span the full 1100px window width (no 430x900 dark pillarbox)
      final scaffoldSize = tester.getSize(find.byType(Scaffold));
      expect(scaffoldSize.width, equals(1100));
      expect(scaffoldSize.height, equals(760));

      final appBarSize = tester.getSize(find.byType(AppBar));
      expect(appBarSize.width, equals(1100));

      // Two-column layout: Profile/Rule column on left, Mode switcher on right at same row
      final avatarRect = tester.getRect(find.byType(AvatarWidget));
      final modeRect = tester.getRect(find.byType(SegmentedButton<String>));
      expect(avatarRect.right, lessThan(modeRect.left));
      expect((avatarRect.top - modeRect.top).abs(), lessThan(40));

      // Switch to LAN mode cleanly on wide desktop
      await tester.tap(find.text('局域网'));
      await tester.pumpAndSettle();
      expect(find.text('IP 地址'), findsOneWidget);
      expect(find.text('端口'), findsOneWidget);
    });
  });

  group('RoomScreen Full-Screen IM Chat, Responsive Layout, Marking & Modals', () {
    testWidgets('Mobile portrait (390x844) Light theme full-screen IM chat, marking & Round-1 in-place update', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ctrl = _TestGameController(_sampleRoomState());
      final lightTheme = ThemeNotifier().getThemeData(AppThemeType.light);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [gameControllerProvider.overrideWith((_) => ctrl)],
          child: MaterialApp(theme: lightTheme, home: const RoomScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // No top player GridView container
      expect(find.byType(GridView), findsNothing);
      // Standard left back arrow
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      // Floating Host FAB
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsOneWidget);
      // OUT badge rendered for dead player p_3
      expect(find.text('OUT'), findsWidgets);

      // Tap another player's avatar (AI · Alpha) in chat -> opens PlayerMarkDialog
      final avatars = find.byType(AvatarWidget);
      await tester.tap(avatars.first);
      await tester.pumpAndSettle();
      expect(find.byType(PlayerMarkDialog), findsOneWidget);

      // Select 卧底 mark -> displays local mark badge in chat
      await tester.tap(find.text('卧底'));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerMarkDialog), findsNothing);
      expect(ctrl.state.playerMarks['p_2'], GameRoles.spy);
      expect(find.text('卧底'), findsOneWidget);

      // Round-1 in-place speech update
      await tester.enterText(find.byType(TextField), '我第一句描述');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(find.text('我第一句描述'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '我修改后的描述');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(find.text('我第一句描述'), findsNothing);
      expect(find.text('我修改后的描述'), findsOneWidget);

      // Open PlayerRosterSheet from AppBar player count
      await tester.tap(find.byIcon(Icons.group_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(PlayerRosterSheet), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // Open IdentityCardDialog
      await tester.tap(find.text('身份'));
      await tester.pumpAndSettle();
      expect(find.byType(IdentityCardDialog), findsOneWidget);
      expect(find.text('点击查看'), findsOneWidget);
      await tester.tap(find.text('点击查看'));
      await tester.pumpAndSettle();
      expect(find.text('咖啡'), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();

      // Open HostConsoleDialog via FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.byType(HostConsoleDialog), findsOneWidget);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
    });

    testWidgets('Wide desktop (1100x760) RoomScreen spans full width with centered 800px chat & aligned Host FAB', (tester) async {
      tester.view.physicalSize = const Size(1100, 760);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ctrl = _TestGameController(_sampleRoomState());
      final lightTheme = ThemeNotifier().getThemeData(AppThemeType.light);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [gameControllerProvider.overrideWith((_) => ctrl)],
          child: MaterialApp(theme: lightTheme, home: const RoomScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Full-width scaffold & AppBar
      expect(tester.getSize(find.byType(Scaffold)).width, equals(1100));
      expect(tester.getSize(find.byType(AppBar)).width, equals(1100));

      // Chat stream left padding centers 800px content: (1100 - 800) / 2 = 150
      final firstAvatarRect = tester.getRect(find.byType(AvatarWidget).first);
      expect(firstAvatarRect.left, closeTo(150.0, 2.0));

      // Host FAB sits cleanly near the right edge of the centered 800px column, above the bottom bar
      final fabRect = tester.getRect(find.byType(FloatingActionButton));
      final inputRect = tester.getRect(find.byType(TextField));
      expect(fabRect.right, closeTo(1100 - 166, 2.0));
      expect(fabRect.bottom, lessThan(inputRect.top));
    });

    testWidgets('PhaseNoticeDialog triggers, Voting lock + private notice, Round-2+ locked, dead player disabled, settlement clears marks', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ctrl = _TestGameController(_sampleRoomState(
        isHost: false,
        marks: {'p_2': GameRoles.spy},
      ));
      final lightTheme = ThemeNotifier().getThemeData(AppThemeType.light);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [gameControllerProvider.overrideWith((_) => ctrl)],
          child: MaterialApp(theme: lightTheme, home: const RoomScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Non-host should NOT see Host FAB
      expect(find.byType(FloatingActionButton), findsNothing);

      // Transition to Voting with phaseNoticeSeq bump -> PhaseNoticeDialog pops up
      ctrl.setTestState(ctrl.state.copyWith(
        currentPhase: GamePhase.voting,
        phaseNoticeSeq: 1,
        phaseNoticeTitle: '第 1 轮 · 投票',
        phaseNoticeBody: '第 1 轮描述结束，投票开始。',
      ));
      await tester.pumpAndSettle();

      expect(find.byType(PhaseNoticeDialog), findsOneWidget);
      expect(find.text('第 1 轮 · 投票'), findsOneWidget);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      // Input TextField must be disabled in voting; 投票 button shown
      expect(find.byType(TextField), findsNothing);
      expect(find.text('投票'), findsOneWidget);

      // Open VoteDialog (SVG AvatarWidget used, no letter CircleAvatar)
      await tester.tap(find.text('投票'));
      await tester.pumpAndSettle();
      expect(find.byType(VoteDialog), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);

      // Pick AI · Alpha and confirm -> private notice shown & button locks to 已投票
      await tester.tap(find.descendant(
        of: find.byType(VoteDialog),
        matching: find.text('AI · Alpha'),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();

      expect(find.text('你已投票给 AI · Alpha'), findsOneWidget);
      expect(find.text('已投票'), findsOneWidget);

      // Transition to Round-2 Description -> input locked, past speeches displayed
      ctrl.setTestState(ctrl.state.copyWith(
        currentPhase: GamePhase.description,
        currentRound: 2,
        phaseNoticeSeq: 2,
        phaseNoticeTitle: '第 2 轮 · 描述',
        phaseNoticeBody: '天亮了，昨夜是平安夜。进入第 2 轮。',
      ));
      await tester.pumpAndSettle();
      expect(find.byType(PhaseNoticeDialog), findsOneWidget);
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('第 2 轮讨论中'), findsOneWidget);
      expect(find.text('这是一种常见的提神饮品。'), findsOneWidget);

      // Eliminated player in Night phase -> 已出局, no action button
      ctrl.setTestState(ctrl.state.copyWith(
        currentPhase: GamePhase.nightAction,
        selfPlayer: ctrl.state.selfPlayer.copyWith(isAlive: false),
      ));
      await tester.pumpAndSettle();
      expect(find.text('夜间行动'), findsNothing);
      expect(find.text('已出局'), findsOneWidget);

      // Transition to Settlement -> SettlementDialog opens & marks cleared
      ctrl.setTestState(ctrl.state.copyWith(
        currentPhase: GamePhase.settlement,
        playerMarks: const {},
        settlementDetails: const SettlementDetails(
          winnerCamp: GameRoles.good,
          goodWord: '咖啡',
          spyWord: '奶茶',
          hint: '常见饮品',
          playerReveals: [
            PlayerReveal(
              id: 'p_self',
              name: '我方玩家',
              avatar: 'characters/detective.svg',
              role: GameRoles.good,
              word: '咖啡',
              hint: '',
              isAlive: true,
            ),
            PlayerReveal(
              id: 'p_2',
              name: 'AI · Alpha',
              avatar: 'animals/fox.svg',
              role: GameRoles.spy,
              word: '奶茶',
              hint: '',
              isAlive: false,
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(SettlementDialog), findsOneWidget);
      expect(find.text('好人获胜'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);
      expect(ctrl.state.playerMarks, isEmpty);
      await tester.tap(find.text('关闭'));
      await tester.pumpAndSettle();
    });

    testWidgets('NightActionDialog & BlankGuessDialog render cleanly with SVG avatars', (tester) async {
      final players = _sampleRoomState().players.where((p) => p.isAlive).toList();
      String? chosenNight;
      (String, String)? chosenBlank;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeNotifier().getThemeData(AppThemeType.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => NightActionDialog(
                        alivePlayers: players,
                        selfId: 'p_self',
                        onAction: (id) => chosenNight = id,
                      ),
                    ),
                    child: const Text('open_night'),
                  ),
                  ElevatedButton(
                    onPressed: () => showDialog(
                      context: context,
                      builder: (_) => BlankGuessDialog(
                        hint: '常见饮品',
                        onGuess: (a, b) => chosenBlank = (a, b),
                      ),
                    ),
                    child: const Text('open_blank'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open_night'));
      await tester.pumpAndSettle();
      expect(find.byType(NightActionDialog), findsOneWidget);
      expect(find.byType(AvatarWidget), findsWidgets);
      expect(find.byType(CircleAvatar), findsNothing);
      await tester.tap(find.text('AI · Alpha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认'));
      await tester.pumpAndSettle();
      expect(chosenNight, 'p_2');

      await tester.tap(find.text('open_blank'));
      await tester.pumpAndSettle();
      expect(find.byType(BlankGuessDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), '咖啡');
      await tester.enterText(find.byType(TextField).at(1), '奶茶');
      await tester.tap(find.text('提交'));
      await tester.pumpAndSettle();
      expect(chosenBlank, ('咖啡', '奶茶'));
    });

    testWidgets('HostConsoleDialog switches cleanly between 本地词库 (JSON categories) and AIGC (custom topic)', (tester) async {
      WordSourceMode? submittedMode;
      String? submittedTheme;
      String? submittedSimilarity;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeNotifier().getThemeData(AppThemeType.light),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showDialog(
                  context: context,
                  builder: (_) => HostConsoleDialog(
                    playerCount: 4,
                    currentPhase: GamePhase.preparing,
                    llmConfigured: false,
                    onOpenSettings: () {},
                    onStartGame: (mode, theme, similarity) async {
                      submittedMode = mode;
                      submittedTheme = theme;
                      submittedSimilarity = similarity;
                      if (theme == '触发错误') {
                        return '请先配置 API Key';
                      }
                      return null;
                    },
                    onAdvancePhase: () {},
                    onResetGame: () {},
                    onAddBots: (_) {},
                    onClearBots: () {},
                  ),
                ),
                child: const Text('open_host'),
              ),
            ),
          ),
        ),
      );

      // 1. Open dialog -> defaults to 本地词库 with JSON categories
      await tester.tap(find.text('open_host'));
      await tester.pumpAndSettle();
      expect(find.byType(HostConsoleDialog), findsOneWidget);
      expect(find.text('本地词库'), findsOneWidget);
      expect(find.text('AIGC'), findsOneWidget);

      // Open category dropdown and choose 食物 from assets/word_bank.json
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String>, '主题'));
      await tester.pumpAndSettle();
      expect(find.text('食物').last, findsOneWidget);
      expect(find.text('家具').last, findsOneWidget);
      await tester.tap(find.text('食物').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('开始游戏'));
      await tester.pumpAndSettle();
      expect(submittedMode, WordSourceMode.localJson);
      expect(submittedTheme, '食物');
      expect(submittedSimilarity, WordBank.randomSimilarity);
      expect(find.byType(HostConsoleDialog), findsNothing);

      // 2. Re-open dialog -> switch to AIGC, check warning + custom topic + inline error
      await tester.tap(find.text('open_host'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AIGC'));
      await tester.pumpAndSettle();

      expect(find.text('未配置 API Key'), findsOneWidget);
      expect(find.text('去设置'), findsOneWidget);
      expect(find.widgetWithText(TextField, '主题词'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '主题词'), '触发错误');
      await tester.tap(find.text('开始游戏'));
      await tester.pumpAndSettle();
      expect(find.byType(HostConsoleDialog), findsOneWidget);
      expect(find.text('请先配置 API Key'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, '主题词'), '太空探索');
      await tester.ensureVisible(find.text('开始游戏'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('开始游戏'));
      await tester.pumpAndSettle();
      expect(submittedMode, WordSourceMode.aigc);
      expect(submittedTheme, '太空探索');
      expect(find.byType(HostConsoleDialog), findsNothing);
    });
  });
}
