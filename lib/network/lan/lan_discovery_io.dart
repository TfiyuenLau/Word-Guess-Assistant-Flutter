import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../../models/game_models.dart';

/// 局域网 UDP 探针与组播广播服务（原生平台）
class LanDiscovery {
  static const int discoveryPort = 38888;
  static const String protocolMagic = 'WGA-SSDP';
  static final InternetAddress multicastAddress =
      InternetAddress('239.255.42.99');

  RawDatagramSocket? _advertiserSocket;
  Timer? _advertiserTimer;

  RawDatagramSocket? _scannerSocket;
  Timer? _cleanupTimer;

  final Map<String, DiscoveredRoom> _discoveredRooms = {};
  final StreamController<List<DiscoveredRoom>> _roomsController =
      StreamController<List<DiscoveredRoom>>.broadcast();

  bool _isScanning = false;
  bool get isScanning => _isScanning;
  Stream<List<DiscoveredRoom>> get onRoomsDiscovered => _roomsController.stream;

  /// 房主端：开启定期 UDP 广播公告
  Future<void> startAdvertising({
    required String roomId,
    required String hostName,
    required String hostAvatar,
    required int port,
    required int Function() playerCountGetter,
    required int Function() phaseGetter,
  }) async {
    stopAdvertising();

    try {
      _advertiserSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
      );
      _advertiserSocket!.broadcastEnabled = true;

      _advertiserTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_advertiserSocket == null) return;
        final packet = {
          'protocol': protocolMagic,
          'action': 'ANNOUNCE',
          'room_id': roomId,
          'host_name': hostName,
          'host_avatar': hostAvatar,
          'port': port,
          'player_count': playerCountGetter(),
          'max_players': 12,
          'phase': phaseGetter(),
          'phase_title': GamePhaseExt.fromInt(phaseGetter()).label,
        };

        final data = utf8.encode(json.encode(packet));
        // 发送给局域网全网广播与组播地址
        try {
          _advertiserSocket?.send(
            data,
            InternetAddress('255.255.255.255'),
            discoveryPort,
          );
          _advertiserSocket?.send(
            data,
            multicastAddress,
            discoveryPort,
          );
        } catch (_) {}
      });
    } catch (_) {}
  }

  void stopAdvertising() {
    _advertiserTimer?.cancel();
    _advertiserTimer = null;
    _advertiserSocket?.close();
    _advertiserSocket = null;
  }

  /// 客户端：开启局域网房间雷达扫描
  Future<void> startDiscovery() async {
    if (_isScanning) return;
    _isScanning = true;
    _discoveredRooms.clear();

    try {
      _scannerSocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
      );
      _scannerSocket!.broadcastEnabled = true;

      try {
        _scannerSocket!.joinMulticast(multicastAddress);
      } catch (_) {}

      _scannerSocket!.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = _scannerSocket?.receive();
          if (datagram != null) {
            _handleDatagram(datagram);
          }
        }
      });

      // 定期剔除 6 秒未刷新的房间
      _cleanupTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        final now = DateTime.now();
        final expired = _discoveredRooms.keys.where((k) {
          return now.difference(_discoveredRooms[k]!.lastSeen).inSeconds > 6;
        }).toList();

        if (expired.isNotEmpty) {
          for (final k in expired) {
            _discoveredRooms.remove(k);
          }
          _roomsController.add(_discoveredRooms.values.toList());
        }
      });
    } catch (_) {}
  }

  void _handleDatagram(Datagram datagram) {
    try {
      final jsonStr = utf8.decode(datagram.data);
      final map = json.decode(jsonStr) as Map<String, dynamic>;
      if (map['protocol'] != protocolMagic) return;

      final ip = datagram.address.address;
      final room = DiscoveredRoom.fromMap(map, ip);
      _discoveredRooms['${room.ip}:${room.port}'] = room;

      _roomsController.add(_discoveredRooms.values.toList());
    } catch (_) {}
  }

  void stopDiscovery() {
    _isScanning = false;
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _scannerSocket?.close();
    _scannerSocket = null;
  }

  void dispose() {
    stopAdvertising();
    stopDiscovery();
    _roomsController.close();
  }
}
