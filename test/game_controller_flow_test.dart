import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_guess_assistant_flutter/controllers/game_controller.dart';
import 'package:word_guess_assistant_flutter/models/game_models.dart';
import 'package:word_guess_assistant_flutter/models/word_bank.dart';

Future<int> _pickFreePort() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  await server.close();
  return port;
}

Future<void> _waitUntil(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 4),
  String Function()? debug,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate()) {
    if (DateTime.now().isAfter(deadline)) {
      final info = debug != null ? ' (${debug()})' : '';
      throw TimeoutException('Condition not met within $timeout$info');
    }
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    WordBank.loadFromJsonString(File('assets/word_bank.json').readAsStringSync());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GameController Host & Client Flow Verification', () {
    test('Host + Client loopback: senderId, no duplicate client chat, Round-1 in-place update, Round-2+ replay & locks, private voting, marks clear', () async {
      final port = await _pickFreePort();

      SharedPreferences.setMockInitialValues({'wga_player_id': 'host_p1'});
      final host = GameController();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      SharedPreferences.setMockInitialValues({'wga_player_id': 'client_p2'});
      final client = GameController();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      try {
        await host.updateProfile(name: '房主甲', avatar: 'characters/detective.svg');
        await client.updateProfile(name: '玩家乙', avatar: 'animals/fox.svg');

        await host.createRoom(mode: 'lan', customRoomId: '7777', port: port);
        expect(host.state.isInRoom, isTrue);
        expect(host.state.isHost, isTrue);
        expect(host.state.canSendChat, isTrue);

        await client.joinRoom(mode: 'lan', roomId: '7777', host: '127.0.0.1', port: port);
        await _waitUntil(
          () => host.state.players.length == 2 && client.state.players.length == 2,
          debug: () =>
              'hostIds=${host.state.players.map((p) => p.id).toList()} '
              'clientIds=${client.state.players.map((p) => p.id).toList()} '
              'hostSelf=${host.state.selfPlayer.id} clientSelf=${client.state.selfPlayer.id} '
              'hostErr=${host.state.errorMessage} clientErr=${client.state.errorMessage}',
        );

        // 1. Client chat must use player.id and NOT double-append locally
        await client.sendChatMessage('准备好了');
        await _waitUntil(() => client.state.chatMessages
            .any((m) => m.payload['text'] == '准备好了'));
        await Future<void>.delayed(const Duration(milliseconds: 80));

        final clientPrepMsgs = client.state.chatMessages
            .where((m) => m.payload['text'] == '准备好了')
            .toList();
        expect(clientPrepMsgs.length, 1, reason: '客户端发言不得本地重复追加');
        expect(clientPrepMsgs.first.payload['sender_id'], client.state.selfPlayer.id);
        expect(clientPrepMsgs.first.payload['sender_id'], isNot(client.state.selfPlayer.name));

        // 2. Fill bots to 6 and verify unique IDs & names
        host.addMockBots(1);
        host.fillBotsToCount(6);
        await _waitUntil(() =>
            host.state.players.length == 6 && client.state.players.length == 6);
        expect(host.state.players.map((p) => p.id).toSet().length, 6);
        expect(host.state.players.map((p) => p.name).toSet().length, 6);

        // Mark a player locally before game starts; startGame must clear marks
        final botId = host.state.players.firstWhere((p) => p.isBot).id;
        host.markPlayer(botId, GameRoles.spy);
        expect(host.state.playerMarks[botId], GameRoles.spy);

        // 3. Start game -> Round 1 description, bots speak automatically, PhaseNotice triggers
        await host.startGame();
        await _waitUntil(() =>
            client.state.currentPhase == GamePhase.description &&
            client.state.currentRound == 1 &&
            client.state.myIdentity != null);

        expect(host.state.playerMarks, isEmpty, reason: '开局时应清空本地标记');
        expect(host.state.phaseNoticeSeq, greaterThan(0));
        expect(client.state.phaseNoticeSeq, greaterThan(0));

        // Wait for all 4 bots to have spoken in Round 1
        final botIds = host.state.players.where((p) => p.isBot).map((p) => p.id).toSet();
        await _waitUntil(() {
          final spoken = client.state.chatMessages
              .where((m) => m.payload['is_speech'] == true)
              .map((m) => m.payload['sender_id']?.toString())
              .toSet();
          return botIds.every(spoken.contains);
        });

        // 4. Round-1 in-place speech update for both host and client
        await host.sendChatMessage('房主首轮初稿');
        await host.sendChatMessage('房主首轮修改稿');
        await client.sendChatMessage('玩家乙初稿');
        await _waitUntil(() => client.state.chatMessages
            .any((m) => m.payload['text'] == '玩家乙初稿'));
        await client.sendChatMessage('玩家乙修改稿');
        await _waitUntil(() =>
            host.state.chatMessages.any((m) => m.payload['text'] == '玩家乙修改稿') &&
            client.state.chatMessages.any((m) => m.payload['text'] == '玩家乙修改稿'));

        final hostSelfSpeeches = host.state.chatMessages
            .where((m) =>
                m.payload['is_system'] != true &&
                m.payload['sender_id'] == host.state.selfPlayer.id &&
                m.payload['is_speech'] == true)
            .toList();
        expect(hostSelfSpeeches.length, 1, reason: '首轮重复发言应原地更新而非追加');
        expect(hostSelfSpeeches.first.payload['text'], '房主首轮修改稿');

        final clientSelfSpeeches = client.state.chatMessages
            .where((m) =>
                m.payload['is_system'] != true &&
                m.payload['sender_id'] == client.state.selfPlayer.id &&
                m.payload['is_speech'] == true)
            .toList();
        expect(clientSelfSpeeches.length, 1, reason: '客户端首轮重复发言应原地更新');
        expect(clientSelfSpeeches.first.payload['text'], '玩家乙修改稿');

        // Mark a player during game
        host.markPlayer(client.state.selfPlayer.id, GameRoles.good);
        expect(host.state.playerMarks[client.state.selfPlayer.id], GameRoles.good);

        // 5. Advance to Voting -> input locked, single-vote lock, private self-only notice, no vote-progress spam
        final prevHostSeq = host.state.phaseNoticeSeq;
        await host.advancePhase();
        await _waitUntil(() => client.state.currentPhase == GamePhase.voting);

        expect(host.state.phaseNoticeSeq, greaterThan(prevHostSeq));
        expect(host.state.canSendChat, isFalse);
        expect(client.state.canSendChat, isFalse);

        // Verify sendChatMessage is ignored when locked
        final msgCountBeforeLocked = host.state.chatMessages.length;
        await host.sendChatMessage('投票阶段不允许发言');
        expect(host.state.chatMessages.length, msgCountBeforeLocked);

        // Host votes for a bot -> private self-only notice, no broadcast to client
        final targetBot = host.state.players.firstWhere((p) => p.isBot && p.isAlive);
        await host.submitVote(targetBot.id);
        expect(host.state.hasVotedThisRound, isTrue);
        expect(host.state.canVote, isFalse);
        expect(
          host.state.chatMessages.any((m) =>
              m.payload['is_system'] == true &&
              m.payload['text'] == '你已投票给 ${targetBot.name}'),
          isTrue,
        );

        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(
          client.state.chatMessages.any((m) =>
              (m.payload['text']?.toString() ?? '').contains('投票进度') ||
              (m.payload['text']?.toString() ?? '').contains('你已投票给')),
          isFalse,
          reason: '不得广播投票进度垃圾消息或泄露他人投票私信',
        );

        // Advance past voting (either nightAction, blankGuess, or settlement)
        if (host.state.currentPhase == GamePhase.voting) {
          await host.advancePhase();
        }
        if (host.state.currentPhase == GamePhase.blankGuess) {
          await host.advancePhase();
        }

        // If we reached nightAction, verify night lock & transition to Round 2 replay
        if (host.state.currentPhase == GamePhase.nightAction) {
          await _waitUntil(() => client.state.currentPhase == GamePhase.nightAction);
          expect(host.state.canSendChat, isFalse);

          if (host.state.canNightAct) {
            final aliveTarget = host.state.players
                .firstWhere((p) => p.isAlive && p.id != host.state.selfPlayer.id);
            await host.submitNightAction(aliveTarget.id);
            expect(host.state.hasNightActedThisRound, isTrue);
            expect(host.state.canNightAct, isFalse);
            expect(
              host.state.chatMessages.any((m) =>
                  m.payload['is_system'] == true &&
                  m.payload['text'] == '已记录夜间行动。'),
              isTrue,
            );
          }

          await host.advancePhase();
          await _waitUntil(() =>
              client.state.currentPhase == host.state.currentPhase &&
              client.state.currentRound == host.state.currentRound);

          if (host.state.currentPhase == GamePhase.description &&
              host.state.currentRound >= 2) {
            expect(host.state.canSendChat, isFalse, reason: '第 2 轮起禁止发言输入');
            expect(client.state.canSendChat, isFalse);

            // Past Round-1 speeches (including self!) must be replayed at the bottom of chat
            final hostTail = host.state.chatMessages
                .skip(host.state.chatMessages.length - 6)
                .toList();
            expect(
              hostTail.any((m) => m.payload['text'] == '房主首轮修改稿'),
              isTrue,
              reason: '房主第 2 轮底部应回放包含自己在内的首轮发言',
            );
            expect(
              hostTail.any((m) => m.payload['text'] == '玩家乙修改稿'),
              isTrue,
              reason: '房主第 2 轮底部应回放其他玩家的首轮发言',
            );

            final clientTail = client.state.chatMessages
                .skip(client.state.chatMessages.length - 6)
                .toList();
            expect(
              clientTail.any((m) => m.payload['text'] == '玩家乙修改稿'),
              isTrue,
              reason: '客户端第 2 轮底部应回放包含自己在内的首轮发言',
            );
          }
        }

        // 6. Reset game clears marks, locks, identity
        host.markPlayer(botId, GameRoles.angel);
        host.resetGame();
        await _waitUntil(() =>
            host.state.currentPhase == GamePhase.preparing &&
            client.state.currentPhase == GamePhase.preparing);
        expect(host.state.playerMarks, isEmpty);
        expect(client.state.playerMarks, isEmpty);
        expect(host.state.currentRound, 1);
        expect(host.state.canSendChat, isTrue);

        // 7. Leave room resets all state cleanly
        host.markPlayer(botId, GameRoles.blank);
        await host.leaveRoom();
        expect(host.state.isInRoom, isFalse);
        expect(host.state.isHost, isFalse);
        expect(host.state.currentRound, 1);
        expect(host.state.currentPhase, GamePhase.preparing);
        expect(host.state.playerMarks, isEmpty);
        expect(host.state.hasVotedThisRound, isFalse);
        expect(host.state.hasNightActedThisRound, isFalse);
        expect(host.state.phaseNoticeSeq, 0);
        expect(host.state.selfPlayer.isAlive, isTrue);
        expect(host.state.selfPlayer.role, isNull);
      } finally {
        await client.leaveRoom();
        await host.leaveRoom();
        client.dispose();
        host.dispose();
      }
    });

    test('Mid-game spectator leaveRoom resets selfPlayer role & isAlive for next room', () async {
      final port = await _pickFreePort();
      SharedPreferences.setMockInitialValues({'wga_player_id': 'host_spec_1'});
      final host = GameController();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      SharedPreferences.setMockInitialValues({'wga_player_id': 'late_joiner_2'});
      final lateJoiner = GameController();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      try {
        await host.createRoom(mode: 'lan', customRoomId: '8888', port: port);
        host.fillBotsToCount(4);
        await host.startGame();

        // Join mid-game -> automatically becomes spectator with isAlive == false
        await lateJoiner.joinRoom(mode: 'lan', roomId: '8888', host: '127.0.0.1', port: port);
        await _waitUntil(() => lateJoiner.state.isSpectator);
        expect(lateJoiner.state.selfPlayer.isAlive, isFalse);
        expect(lateJoiner.state.canSendChat, isFalse);
        expect(lateJoiner.state.canVote, isFalse);
        expect(lateJoiner.state.canNightAct, isFalse);

        // Leave room -> must reset selfPlayer role and isAlive so next room works
        await lateJoiner.leaveRoom();
        expect(lateJoiner.state.isSpectator, isFalse,
            reason: 'leaveRoom() 必须清除 selfPlayer 的观战者身份');
        expect(lateJoiner.state.selfPlayer.isAlive, isTrue,
            reason: 'leaveRoom() 必须恢复 selfPlayer.isAlive 为 true');
        expect(lateJoiner.state.canSendChat, isTrue);
      } finally {
        await lateJoiner.leaveRoom();
        await host.leaveRoom();
        lateJoiner.dispose();
        host.dispose();
      }
    });
  });
}
