import 'dart:async';
import '../models/protocol_messages.dart';

/// 统一网络传输接口（抹平 WebRTC P2P 与 局域网 TCP/UDP 的协议差异）
abstract class GameTransport {
  /// 房主开辟房间
  Future<void> hostRoom(String roomId, {int? port});

  /// 客户端连接指定房间
  Future<void> joinRoom(
    String roomId, {
    String? host,
    int? port,
    required String playerId,
    required String playerName,
    required String avatar,
  });

  /// 客户端向房主单播消息
  Future<void> sendToHost(GameMessage message);

  /// 房主向指定玩家单播消息
  Future<void> sendToPeer(String peerId, GameMessage message);

  /// 房主向全员广播消息
  Future<void> broadcast(GameMessage message);

  /// 接收到的网络消息流
  Stream<GameMessage> get onMessage;

  /// 玩家连入事件流 (返回 peerId)
  Stream<String> get onPeerJoined;

  /// 玩家断开事件流 (返回 peerId)
  Stream<String> get onPeerLeft;

  /// 断开连接并释放全部网络资源
  Future<void> disconnect();

  /// 当前是否为房主
  bool get isHost;

  /// 当前是否已连接就绪
  bool get isConnected;
}
