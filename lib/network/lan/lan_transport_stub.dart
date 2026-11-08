import 'dart:async';
import '../../models/game_models.dart';
import '../../models/protocol_messages.dart';
import '../game_transport.dart';

/// Web 平台下的局域网传输存根类（不支持 dart:io，平滑降级）
class LanTransport implements GameTransport {
  final String selfId;

  LanTransport({required this.selfId});

  @override
  bool get isHost => false;

  @override
  bool get isConnected => false;

  @override
  Stream<GameMessage> get onMessage => const Stream.empty();

  @override
  Stream<String> get onPeerJoined => const Stream.empty();

  @override
  Stream<String> get onPeerLeft => const Stream.empty();

  @override
  Future<void> hostRoom(String roomId, {int? port}) async {
    throw UnsupportedError('Web 平台不支持原生 TCP/UDP 局域网开房，请使用 P2P 联机模式');
  }

  @override
  Future<void> joinRoom(
    String roomId, {
    String? host,
    int? port,
    required String playerId,
    required String playerName,
    required String avatar,
  }) async {
    throw UnsupportedError('Web 平台不支持原生 TCP/UDP 局域网联机，请使用 P2P 联机模式');
  }

  @override
  Future<void> sendToHost(GameMessage message) async {}

  @override
  Future<void> sendToPeer(String peerId, GameMessage message) async {}

  @override
  Future<void> broadcast(GameMessage message) async {}

  @override
  Future<void> disconnect() async {}
}

/// Web 平台下的局域网探针存根类
class LanDiscovery {
  bool get isScanning => false;
  Stream<List<DiscoveredRoom>> get onRoomsDiscovered => const Stream.empty();

  Future<void> startAdvertising({
    required String roomId,
    required String hostName,
    required String hostAvatar,
    required int port,
    required int Function() playerCountGetter,
    required int Function() phaseGetter,
  }) async {}

  void stopAdvertising() {}

  Future<void> startDiscovery() async {}

  void stopDiscovery() {}

  void dispose() {}
}
