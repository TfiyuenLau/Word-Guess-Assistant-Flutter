import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_guess_assistant_flutter/controllers/game_controller.dart';
import 'package:word_guess_assistant_flutter/controllers/theme_controller.dart';
import 'package:word_guess_assistant_flutter/models/game_models.dart';
import 'package:word_guess_assistant_flutter/models/protocol_messages.dart';
import 'package:word_guess_assistant_flutter/ui/modals/avatar_picker_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/host_console_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/identity_card_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/phase_notice_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/player_mark_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/player_roster_sheet.dart';
import 'package:word_guess_assistant_flutter/ui/modals/rule_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/settlement_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/vote_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/screens/home_screen.dart';
import 'package:word_guess_assistant_flutter/ui/screens/room_screen.dart';

const _auditDir =
    '/home/tfiyuen_lau/.gemini/antigravity/brain/c1aefd05-98a0-4d68-a3b2-fff9047d6b36/scratch/visual_audit';

bool get _saveScreenshots =>
    Platform.environment['GENERATE_VISUAL_AUDIT'] == '1';

Future<void> _loadAuditFonts() async {
  const cjkCandidates = [
    '/mnt/c/Windows/Fonts/Deng.ttf',
    '/mnt/c/Windows/Fonts/simhei.ttf',
  ];
  for (final path in cjkCandidates) {
    final file = File(path);
    if (file.existsSync()) {
      final bytes = await file.readAsBytes();
      final loader = FontLoader('AuditCJK')
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      break;
    }
  }

  const iconFontPath =
      '/home/tfiyuen_lau/snap/flutter/common/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  final iconFile = File(iconFontPath);
  if (iconFile.existsSync()) {
    final bytes = await iconFile.readAsBytes();
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }
}

ThemeData _auditTheme(AppThemeType type) {
  final base = ThemeNotifier().getThemeData(type);
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: 'AuditCJK'),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'AuditCJK'),
  );
}

class _StaticRoomController extends GameController {
  _StaticRoomController(RoomState initial) : super() {
    state = initial;
  }
}

RoomState _makeRoom({
  GamePhase phase = GamePhase.description,
  int round = 1,
  bool isHost = true,
  bool selfAlive = true,
  bool hasVoted = false,
}) {
  final self = Player(
    id: 'p_self',
    name: '林深',
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
    avatar: 'animals/panda.svg',
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
    hasVotedThisRound: hasVoted,
    myIdentity: const IdentityAssignment(
      role: GameRoles.agent,
      word: '拿铁咖啡',
      hint: '',
    ),
    players: [self, p2, p3, p4],
    playerMarks: const {
      'p_2': GameRoles.spy,
      'p_4': GameRoles.good,
    },
    chatMessages: [
      GameMessage.chat(
        senderId: 'SYSTEM',
        text: '游戏开始，第 1 轮描述开始，请存活玩家描述自己的词语。',
        isSystem: true,
      ),
      GameMessage(
        type: GameMessageType.chat,
        payload: {
          'sender_id': 'p_2',
          'text': '早晨很多人都会买一杯，味道带一点苦香。',
          'is_system': false,
          'is_speech': true,
          'speech_round': 1,
        },
      ),
      GameMessage(
        type: GameMessageType.chat,
        payload: {
          'sender_id': 'p_3',
          'text': '通常装在纸杯或陶瓷杯里，热饮冰饮都很常见。',
          'is_system': false,
          'is_speech': true,
          'speech_round': 1,
        },
      ),
      GameMessage(
        type: GameMessageType.chat,
        payload: {
          'sender_id': 'p_self',
          'text': '奶香和烘焙香气结合，下午办公提神常用。',
          'is_system': false,
          'is_speech': true,
          'speech_round': 1,
        },
      ),
      GameMessage(
        type: GameMessageType.chat,
        payload: {
          'sender_id': 'p_4',
          'text': '连锁门店里基本都能点到，还可以加糖或换燕麦奶。',
          'is_system': false,
          'is_speech': true,
          'speech_round': 1,
        },
      ),
    ],
  );
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String filename,
) async {
  if (!_saveScreenshots) return;
  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(_auditDir);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadAuditFonts();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Visual layout audit across HomeScreen, RoomScreen and modals at 390x844', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final boundaryKey = GlobalKey();

    Widget wrap(Widget child, {AppThemeType theme = AppThemeType.night, List<Override> overrides = const []}) {
      return ProviderScope(
        key: UniqueKey(),
        overrides: overrides,
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _auditTheme(theme),
            home: child,
          ),
        ),
      );
    }

    // 1. HomeScreen P2P (Dark)
    await tester.pumpWidget(wrap(const HomeScreen(), theme: AppThemeType.night));
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, '01_home_p2p_dark.png');

    // 2. HomeScreen LAN (Dark)
    await tester.tap(find.text('局域网'));
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, '02_home_lan_dark.png');

    // 3. HomeScreen P2P (Light)
    await tester.pumpWidget(wrap(const HomeScreen(), theme: AppThemeType.light));
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, '03_home_p2p_light.png');

    // 4. AvatarPickerDialog
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();
    expect(find.byType(AvatarPickerDialog), findsOneWidget);
    await _capture(tester, boundaryKey, '04_avatar_picker.png');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    // 5. RuleDialog
    await tester.tap(find.text('游戏规则'));
    await tester.pumpAndSettle();
    expect(find.byType(RuleDialog), findsOneWidget);
    await _capture(tester, boundaryKey, '05_rule_dialog.png');
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    // 6. RoomScreen Round 1 Host (Dark)
    final roomCtrl = _StaticRoomController(_makeRoom());
    await tester.pumpWidget(wrap(
      const RoomScreen(),
      theme: AppThemeType.night,
      overrides: [gameControllerProvider.overrideWith((_) => roomCtrl)],
    ));
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, '06_room_round1_host.png');

    // 7. RoomScreen Voting Bottom Bar
    final voteCtrl = _StaticRoomController(_makeRoom(phase: GamePhase.voting));
    await tester.pumpWidget(wrap(
      const RoomScreen(),
      theme: AppThemeType.night,
      overrides: [gameControllerProvider.overrideWith((_) => voteCtrl)],
    ));
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, '07_room_voting_bar.png');

    // 8. VoteDialog
    await tester.tap(find.text('投票'));
    await tester.pumpAndSettle();
    expect(find.byType(VoteDialog), findsOneWidget);
    await _capture(tester, boundaryKey, '08_vote_dialog.png');
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    // 9. RoomScreen Night Bottom Bar
    final nightCtrl = _StaticRoomController(_makeRoom(phase: GamePhase.nightAction));
    await tester.pumpWidget(wrap(
      const RoomScreen(),
      theme: AppThemeType.night,
      overrides: [gameControllerProvider.overrideWith((_) => nightCtrl)],
    ));
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, '09_room_night_bar.png');

    // 10. RoomScreen Round 2 Locked
    final r2Ctrl = _StaticRoomController(_makeRoom(phase: GamePhase.description, round: 2));
    await tester.pumpWidget(wrap(
      const RoomScreen(),
      theme: AppThemeType.night,
      overrides: [gameControllerProvider.overrideWith((_) => r2Ctrl)],
    ));
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, '10_room_round2_locked.png');

    // 11. PlayerRosterSheet
    await tester.tap(find.byIcon(Icons.group_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerRosterSheet), findsOneWidget);
    await _capture(tester, boundaryKey, '11_player_roster_sheet.png');
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // 12. IdentityCardDialog (revealed)
    await tester.tap(find.text('身份'));
    await tester.pumpAndSettle();
    expect(find.byType(IdentityCardDialog), findsOneWidget);
    await tester.tap(find.text('点击查看'));
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, '12_identity_card_dialog.png');
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    // 13. HostConsoleDialog (preparing)
    final prepCtrl = _StaticRoomController(_makeRoom(phase: GamePhase.preparing));
    await tester.pumpWidget(wrap(
      const RoomScreen(),
      theme: AppThemeType.night,
      overrides: [gameControllerProvider.overrideWith((_) => prepCtrl)],
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(HostConsoleDialog), findsOneWidget);
    await _capture(tester, boundaryKey, '13_host_console_dialog.png');
    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();

    // 14. PhaseNoticeDialog & SettlementDialog & PlayerMarkDialog standalone renders
    await tester.pumpWidget(wrap(
      const Scaffold(
        body: Center(
          child: PhaseNoticeDialog(
            title: '第 1 轮 · 投票',
            message: '第 1 轮描述结束，请存活玩家进行匿名投票。',
            phase: GamePhase.voting,
          ),
        ),
      ),
      theme: AppThemeType.night,
    ));
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, '14_phase_notice_dialog.png');

    await tester.pumpWidget(wrap(
      Scaffold(
        body: Center(
          child: SettlementDialog(
            details: const SettlementDetails(
              winnerCamp: GameRoles.good,
              goodWord: '拿铁咖啡',
              spyWord: '焦糖玛奇朵',
              hint: '常见咖啡饮品',
              playerReveals: [
                PlayerReveal(
                  id: 'p_self',
                  name: '林深',
                  avatar: 'characters/detective.svg',
                  role: GameRoles.good,
                  word: '拿铁咖啡',
                  hint: '',
                  isAlive: true,
                ),
                PlayerReveal(
                  id: 'p_2',
                  name: 'AI · Alpha',
                  avatar: 'animals/fox.svg',
                  role: GameRoles.spy,
                  word: '焦糖玛奇朵',
                  hint: '',
                  isAlive: false,
                ),
                PlayerReveal(
                  id: 'p_3',
                  name: 'AI · Bravo',
                  avatar: 'cyber/hacker.svg',
                  role: GameRoles.blank,
                  word: '【无词】',
                  hint: '常见咖啡饮品',
                  isAlive: false,
                ),
                PlayerReveal(
                  id: 'p_4',
                  name: 'AI · Charlie',
                  avatar: 'animals/panda.svg',
                  role: GameRoles.angel,
                  word: '拿铁咖啡 / 焦糖玛奇朵',
                  hint: '两词顺序随机',
                  isAlive: true,
                ),
              ],
            ),
            onDismiss: () {},
          ),
        ),
      ),
      theme: AppThemeType.night,
    ));
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, '15_settlement_dialog.png');

    // 16. PlayerMarkDialog
    await tester.pumpWidget(wrap(
      Scaffold(
        body: Center(
          child: PlayerMarkDialog(
            player: const Player(
              id: 'p_2',
              name: 'AI · Alpha',
              avatar: 'animals/fox.svg',
            ),
            currentMark: GameRoles.spy,
            onMarkSelected: (_) {},
          ),
        ),
      ),
      theme: AppThemeType.night,
    ));
    await tester.pumpAndSettle();
    await _capture(tester, boundaryKey, '16_player_mark_dialog.png');
  });
}
