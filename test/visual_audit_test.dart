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
import 'package:word_guess_assistant_flutter/ui/modals/identity_card_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/player_mark_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/modals/settlement_dialog.dart';
import 'package:word_guess_assistant_flutter/ui/screens/home_screen.dart';
import 'package:word_guess_assistant_flutter/ui/screens/room_screen.dart';

String get _auditDir =>
    Platform.environment['VISUAL_AUDIT_DIR'] ?? 'assets/screenshots';

bool get _saveScreenshots =>
    Platform.environment['GENERATE_VISUAL_AUDIT'] == '1';

Future<void> _loadAuditFonts() async {
  final cjkCandidates = <String>[
    if ((Platform.environment['VISUAL_AUDIT_CJK_FONT'] ?? '').isNotEmpty)
      Platform.environment['VISUAL_AUDIT_CJK_FONT']!,
    '/mnt/c/Windows/Fonts/Deng.ttf',
    '/mnt/c/Windows/Fonts/simhei.ttf',
    '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
    '/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc',
    '/System/Library/Fonts/PingFang.ttc',
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

  final iconCandidates = <String>[
    if ((Platform.environment['VISUAL_AUDIT_ICON_FONT'] ?? '').isNotEmpty)
      Platform.environment['VISUAL_AUDIT_ICON_FONT']!,
    if ((Platform.environment['FLUTTER_ROOT'] ?? '').isNotEmpty)
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ];

  void addAncestorCandidates(Directory start) {
    var dir = start;
    for (var i = 0; i < 8; i++) {
      iconCandidates.add(
        '${dir.path}/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      iconCandidates.add(
        '${dir.path}/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      iconCandidates.add(
        '${dir.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
  }

  addAncestorCandidates(File(Platform.resolvedExecutable).parent);
  final pathEnv = Platform.environment['PATH'] ?? '';
  for (final entry in pathEnv.split(Platform.pathSeparator)) {
    if (entry.isEmpty) continue;
    final flutterBin = File('$entry/flutter');
    if (flutterBin.existsSync()) {
      try {
        addAncestorCandidates(
          File(flutterBin.resolveSymbolicLinksSync()).parent,
        );
      } catch (_) {
        addAncestorCandidates(Directory(entry));
      }
    }
  }

  for (final path in iconCandidates) {
    final iconFile = File(path);
    if (iconFile.existsSync()) {
      final bytes = await iconFile.readAsBytes();
      final loader = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      break;
    }
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
  String filename, {
  double pixelRatio = 1.5,
}) async {
  if (!_saveScreenshots) return;
  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
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

  testWidgets(
      'Visual layout screenshots across mobile (390x844) and desktop (1100x760) in Light default + Dark sanity',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1.0;

    final boundaryKey = GlobalKey();

    Widget wrap(
      Widget child, {
      AppThemeType theme = AppThemeType.light,
      List<Override> overrides = const [],
    }) {
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

    Widget overlayOnRoom(Widget dialog, RoomState room) {
      final ctrl = _StaticRoomController(room);
      return wrap(
        Stack(
          children: [
            const IgnorePointer(child: RoomScreen()),
            const ModalBarrier(dismissible: false, color: Colors.black54),
            Center(child: dialog),
          ],
        ),
        overrides: [gameControllerProvider.overrideWith((_) => ctrl)],
      );
    }

    final prevDisableShadows = debugDisableShadows;
    if (_saveScreenshots) {
      debugDisableShadows = false;
    }
    try {
      // 1. HomeScreen Mobile Light (390x844)
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpWidget(wrap(const HomeScreen()));
      await tester.pumpAndSettle();
      await _capture(tester, boundaryKey, 'home_mobile.png');

      // 2. IdentityCardDialog overlaid on RoomScreen Mobile Light (390x844)
      await tester.pumpWidget(
        overlayOnRoom(
          const IdentityCardDialog(
            identity: IdentityAssignment(
              role: GameRoles.agent,
              word: '拿铁咖啡',
              hint: '',
            ),
          ),
          _makeRoom(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('点击查看'));
      await tester.pumpAndSettle();
      await _capture(tester, boundaryKey, 'identity_card_mobile.png');

      // 3. RoomScreen Mobile Light (390x844)
      final roomMobileCtrl = _StaticRoomController(_makeRoom());
      await tester.pumpWidget(wrap(
        const RoomScreen(),
        overrides: [gameControllerProvider.overrideWith((_) => roomMobileCtrl)],
      ));
      await tester.pumpAndSettle();
      await _capture(tester, boundaryKey, 'room_chat_mobile.png');

      // 4. PlayerMarkDialog overlaid on RoomScreen Mobile Light (390x844)
      await tester.pumpWidget(
        overlayOnRoom(
          PlayerMarkDialog(
            player: const Player(
              id: 'p_2',
              name: 'AI · Alpha',
              avatar: 'animals/fox.svg',
            ),
            currentMark: GameRoles.spy,
            onMarkSelected: (_) {},
          ),
          _makeRoom(),
        ),
      );
      await tester.pumpAndSettle();
      await _capture(tester, boundaryKey, 'player_mark_mobile.png');

      // 5. RoomScreen Voting Mobile Light (390x844)
      final voteCtrl =
          _StaticRoomController(_makeRoom(phase: GamePhase.voting));
      await tester.pumpWidget(wrap(
        const RoomScreen(),
        overrides: [gameControllerProvider.overrideWith((_) => voteCtrl)],
      ));
      await tester.pumpAndSettle();
      await _capture(tester, boundaryKey, 'room_voting_mobile.png');

      // 6. SettlementDialog overlaid on RoomScreen Mobile Light (390x844)
      await tester.pumpWidget(
        overlayOnRoom(
          SettlementDialog(
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
          _makeRoom(phase: GamePhase.settlement),
        ),
      );
      await tester.pumpAndSettle();
      await _capture(tester, boundaryKey, 'settlement_mobile.png');

      // 7. HomeScreen Desktop Light (1100x760)
      tester.view.physicalSize = const Size(1100, 760);
      await tester.pumpWidget(wrap(const HomeScreen()));
      await tester.pumpAndSettle();
      await _capture(tester, boundaryKey, 'home_desktop.png');

      // 8. RoomScreen Desktop Light (1100x760)
      final roomDesktopCtrl = _StaticRoomController(_makeRoom());
      await tester.pumpWidget(wrap(
        const RoomScreen(),
        overrides: [gameControllerProvider.overrideWith((_) => roomDesktopCtrl)],
      ));
      await tester.pumpAndSettle();
      await _capture(tester, boundaryKey, 'room_desktop_light.png');

      // 9. Dark Theme Desktop Sanity Check (1100x760)
      final roomDarkCtrl = _StaticRoomController(_makeRoom());
      await tester.pumpWidget(wrap(
        const RoomScreen(),
        theme: AppThemeType.night,
        overrides: [gameControllerProvider.overrideWith((_) => roomDarkCtrl)],
      ));
      await tester.pumpAndSettle();
      await _capture(tester, boundaryKey, 'room_desktop_dark.png');
    } finally {
      debugDisableShadows = prevDisableShadows;
    }
  });
}
