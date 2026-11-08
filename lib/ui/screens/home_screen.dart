import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/game_controller.dart';
import '../modals/rule_dialog.dart';
import 'room_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _nameController = TextEditingController();
  final _roomCodeController = TextEditingController();
  final _manualIpController = TextEditingController(text: '127.0.0.1');
  final _manualPortController = TextEditingController(text: '8888');

  String _selectedMode = 'p2p'; // "p2p" | "lan"

  final List<String> _avatarPool = [
    'agent_1',
    'agent_2',
    'agent_3',
    'agent_4',
    'agent_5',
  ];

  @override
  void initState() {
    super.initState();
    final self = ref.read(gameControllerProvider).selfPlayer;
    _nameController.text = self.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roomCodeController.dispose();
    _manualIpController.dispose();
    _manualPortController.dispose();
    super.dispose();
  }

  void _randomizeName() {
    final codenames = ['孤狼', '夜莺', '猎鹰', '幽灵', '暗影', '蝰蛇', '渡鸦', '青鸟'];
    final name = '特工 · ${codenames[Random().nextInt(codenames.length)]}_${100 + Random().nextInt(900)}';
    _nameController.text = name;
    final self = ref.read(gameControllerProvider).selfPlayer;
    ref.read(gameControllerProvider.notifier).updateProfile(
          name: name,
          avatar: self.avatar,
        );
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(gameControllerProvider);
    final theme = Theme.of(context);

    // 监听进入房间并跳转
    ref.listen(gameControllerProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
      if (next.isInRoom && !(prev?.isInRoom ?? false)) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RoomScreen()),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.fingerprint),
            SizedBox(width: 8),
            Text(
              '特工猜词助手',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '军规法则说明',
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const RuleDialog(),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 特工档案编辑卡片
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '特工代号与机密形象',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: theme.colorScheme.primaryContainer,
                              child: Text(
                                roomState.selfPlayer.name.isNotEmpty
                                    ? roomState.selfPlayer.name[0]
                                    : 'A',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                decoration: const InputDecoration(
                                  labelText: '特工代号',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (val) {
                                  ref.read(gameControllerProvider.notifier).updateProfile(
                                        name: val.trim(),
                                        avatar: roomState.selfPlayer.avatar,
                                      );
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.outlined(
                              tooltip: '随机生成代号',
                              icon: const Icon(Icons.casino),
                              onPressed: _randomizeName,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: _avatarPool.map((av) {
                            final isSel = roomState.selfPlayer.avatar == av;
                            return ChoiceChip(
                              avatar: const Icon(Icons.person, size: 16),
                              label: Text(av),
                              selected: isSel,
                              onSelected: (_) {
                                ref.read(gameControllerProvider.notifier).updateProfile(
                                      name: _nameController.text.trim(),
                                      avatar: av,
                                    );
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 联机模式切换
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'p2p',
                      icon: Icon(Icons.hub),
                      label: Text('WebRTC P2P (外网快速联机)'),
                    ),
                    ButtonSegment(
                      value: 'lan',
                      icon: Icon(Icons.wifi),
                      label: Text('局域网离线面对面 (TCP)'),
                    ),
                  ],
                  selected: {_selectedMode},
                  onSelectionChanged: (set) {
                    setState(() {
                      _selectedMode = set.first;
                    });
                    if (_selectedMode == 'lan') {
                      ref.read(gameControllerProvider.notifier).startLanDiscovery();
                    } else {
                      ref.read(gameControllerProvider.notifier).stopLanDiscovery();
                    }
                  },
                ),
                const SizedBox(height: 16),

                // 模式具体卡片
                if (_selectedMode == 'p2p') ...[
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.public, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'P2P 房间互联',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '通过 4 位房间号连接，无需公网 IP，跨网络零配置直连。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _roomCodeController,
                                  decoration: const InputDecoration(
                                    labelText: '4 位房间号',
                                    hintText: '如 8888',
                                    border: OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton.icon(
                                onPressed: roomState.isConnecting
                                    ? null
                                    : () {
                                        final code = _roomCodeController.text.trim();
                                        if (code.isEmpty) return;
                                        ref
                                            .read(gameControllerProvider.notifier)
                                            .joinRoom(mode: 'p2p', roomId: code);
                                      },
                                icon: const Icon(Icons.login),
                                label: const Text('加入房间'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: roomState.isConnecting
                                ? null
                                : () {
                                    ref.read(gameControllerProvider.notifier).createRoom(
                                          mode: 'p2p',
                                        );
                                  },
                            icon: const Icon(Icons.add_home),
                            label: const Text('一键创建专属 P2P 房间 (我是房主)'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.radar, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    '局域网雷达探针',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (roomState.isDiscovering)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '同一 Wi-Fi 或热点下自动搜索房间，完全断网亦可畅玩。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonalIcon(
                            onPressed: roomState.isConnecting
                                ? null
                                : () {
                                    ref.read(gameControllerProvider.notifier).createRoom(
                                          mode: 'lan',
                                          port: 8888,
                                        );
                                  },
                            icon: const Icon(Icons.wifi_tethering),
                            label: const Text('开启局域网房间并广播 (我是房主)'),
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            '已发现的局域网房间：',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (roomState.discoveredRooms.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(
                                child: Text(
                                  '正在雷达扫描中，暂未发现房间...',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: roomState.discoveredRooms.length,
                              itemBuilder: (context, index) {
                                final r = roomState.discoveredRooms[index];
                                return ListTile(
                                  leading: const Icon(Icons.meeting_room),
                                  title: Text('【${r.hostName}】的房间 (房号 ${r.roomId})'),
                                  subtitle: Text('${r.ip}:${r.port} · ${r.playerCount}人 · ${r.phaseTitle}'),
                                  trailing: FilledButton(
                                    onPressed: () {
                                      ref.read(gameControllerProvider.notifier).joinRoom(
                                            mode: 'lan',
                                            roomId: r.roomId,
                                            host: r.ip,
                                            port: r.port,
                                          );
                                    },
                                    child: const Text('加入'),
                                  ),
                                );
                              },
                            ),
                          const SizedBox(height: 8),
                          ExpansionTile(
                            title: const Text('手动直连 IP 与端口'),
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: _manualIpController,
                                      decoration: const InputDecoration(
                                        labelText: '房主 IP',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: _manualPortController,
                                      decoration: const InputDecoration(
                                        labelText: '端口',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    onPressed: () {
                                      final ip = _manualIpController.text.trim();
                                      final port = int.tryParse(_manualPortController.text.trim()) ?? 8888;
                                      ref.read(gameControllerProvider.notifier).joinRoom(
                                            mode: 'lan',
                                            roomId: 'manual',
                                            host: ip,
                                            port: port,
                                          );
                                    },
                                    child: const Text('直连'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                if (roomState.isConnecting) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '正在安全接入特工联络网...',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
