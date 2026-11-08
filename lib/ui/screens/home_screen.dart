import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/game_controller.dart';
import '../modals/avatar_picker_dialog.dart';
import '../modals/rule_dialog.dart';
import '../modals/theme_picker_dialog.dart';
import '../widgets/avatar_widget.dart';
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
    final codenames = ['孤狼', '夜莺', '猎鹰', '幽灵', '暗影', '蝰蛇', '渡鸦', '青鸟', '苍鹰', '极光'];
    final name = '特工 · ${codenames[Random().nextInt(codenames.length)]}_${100 + Random().nextInt(900)}';
    _nameController.text = name;
    final self = ref.read(gameControllerProvider).selfPlayer;
    ref.read(gameControllerProvider.notifier).updateProfile(
          name: name,
          avatar: self.avatar,
        );
  }

  void _openAvatarPicker() {
    final self = ref.read(gameControllerProvider).selfPlayer;
    showDialog(
      context: context,
      builder: (_) => AvatarPickerDialog(
        currentAvatar: self.avatar,
        onAvatarSelected: (newAvatar) {
          ref.read(gameControllerProvider.notifier).updateProfile(
                name: _nameController.text.trim(),
                avatar: newAvatar,
              );
        },
      ),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fingerprint, size: 26),
            SizedBox(width: 8),
            Text(
              '特工猜词助手',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '终端主题风格',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const ThemePickerDialog(),
              );
            },
          ),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 特工档案编辑卡片 (移动端紧凑布局)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '特工机密档案',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            icon: const Icon(Icons.style_outlined, size: 16),
                            label: const Text('更换形象', style: TextStyle(fontSize: 12)),
                            onPressed: _openAvatarPicker,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          // 可点击的大 SVG 头像
                          InkWell(
                            onTap: _openAvatarPicker,
                            borderRadius: BorderRadius.circular(32),
                            child: Stack(
                              children: [
                                AvatarWidget(
                                  avatar: roomState.selfPlayer.avatar,
                                  size: 64,
                                  showBorder: true,
                                  borderColor: theme.colorScheme.primary,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: theme.colorScheme.primary,
                                    child: const Icon(
                                      Icons.edit,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 特工代号编辑
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: '特工代号',
                                border: const OutlineInputBorder(),
                                isDense: true,
                                suffixIcon: IconButton(
                                  tooltip: '随机生成代号',
                                  icon: const Icon(Icons.casino, size: 20),
                                  onPressed: _randomizeName,
                                ),
                              ),
                              onChanged: (val) {
                                ref.read(gameControllerProvider.notifier).updateProfile(
                                      name: val.trim(),
                                      avatar: roomState.selfPlayer.avatar,
                                    );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 快捷头像选择列表 (横向滚动预览)
                      SizedBox(
                        height: 48,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: kBuiltinAvatars.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final av = kBuiltinAvatars[index];
                            final isSel = normalizeAvatarPath(roomState.selfPlayer.avatar) == av.assetPath;

                            return InkWell(
                              onTap: () {
                                ref.read(gameControllerProvider.notifier).updateProfile(
                                      name: _nameController.text.trim(),
                                      avatar: av.id,
                                    );
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSel ? theme.colorScheme.primary : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                padding: const EdgeInsets.all(2),
                                child: AvatarWidget(
                                  avatar: av.assetPath,
                                  size: 40,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // 联机模式切换 (适配移动端尺寸)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'p2p',
                    icon: Icon(Icons.hub_outlined, size: 18),
                    label: Text('WebRTC P2P'),
                  ),
                  ButtonSegment(
                    value: 'lan',
                    icon: Icon(Icons.wifi, size: 18),
                    label: Text('局域网直连'),
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

              const SizedBox(height: 14),

              // P2P 模式卡片
              if (_selectedMode == 'p2p') ...[
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.public, color: theme.colorScheme.onPrimaryContainer, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '4 位房间号快速入局',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '免公网 IP，跨网络秒级打洞直连；同 Wi-Fi 自动走内网极速通道。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 4 位房间号输入框
                        TextField(
                          controller: _roomCodeController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),
                          decoration: InputDecoration(
                            hintText: '如 8888',
                            hintStyle: TextStyle(
                              fontSize: 16,
                              letterSpacing: 2,
                              color: theme.colorScheme.outline,
                            ),
                            labelText: '输入 4 位房间号',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        ),
                        const SizedBox(height: 12),

                        // 加入房间按钮
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
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
                          label: const Text('加入房间', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),

                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('或', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 创建房间按钮
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: roomState.isConnecting
                              ? null
                              : () {
                                  ref.read(gameControllerProvider.notifier).createRoom(
                                        mode: 'p2p',
                                      );
                                },
                          icon: const Icon(Icons.add_home),
                          label: const Text('创建全新 P2P 房间 (我是房主)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // 局域网模式卡片
                Card(
                  elevation: 2,
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
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.radar, color: theme.colorScheme.onSecondaryContainer, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '局域网雷达探测',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (roomState.isDiscovering)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '同一 Wi-Fi 或热点下自动搜索房间，完全断网亦可面对面开黑。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),

                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                          ),
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
                        const SizedBox(height: 6),

                        Text(
                          '雷达发现的房间：',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),

                        if (roomState.discoveredRooms.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: roomState.discoveredRooms.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final r = roomState.discoveredRooms[index];
                              return ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: AvatarWidget(
                                  avatar: r.hostAvatar,
                                  size: 36,
                                ),
                                title: Text(
                                  '【${r.hostName}】(房号 ${r.roomId})',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text('${r.ip}:${r.port} · ${r.playerCount}人 · ${r.phaseTitle}'),
                                trailing: FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
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

                        // 手动直连折叠面板
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('手动直连 IP:Port', style: TextStyle(fontSize: 13)),
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
                            const SizedBox(height: 10),
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
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    '正在建立端到端加密握手...',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
