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
    const names = ['孤狼', '夜莺', '猎鹰', '幽灵', '暗影', '渡鸦', '青鸟', '极光', '微风', '星辰'];
    final name = '${names[Random().nextInt(names.length)]}_${100 + Random().nextInt(900)}';
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

  void _joinP2p() {
    final code = _roomCodeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入房间号')),
      );
      return;
    }
    ref.read(gameControllerProvider.notifier).joinRoom(
          mode: 'p2p',
          roomId: code,
        );
  }

  void _joinLan() {
    final ip = _manualIpController.text.trim();
    final port = int.tryParse(_manualPortController.text.trim()) ?? 8888;
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 IP 地址')),
      );
      return;
    }
    ref.read(gameControllerProvider.notifier).joinRoom(
          mode: 'lan',
          roomId: 'manual',
          host: ip,
          port: port,
        );
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(gameControllerProvider);
    final theme = Theme.of(context);

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
        title: const Text(
          '猜词助手',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        actions: [
          IconButton(
            tooltip: '主题',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const ThemePickerDialog(),
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
              // 个人资料卡（头像 + 昵称）
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: _openAvatarPicker,
                        borderRadius: BorderRadius.circular(32),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AvatarWidget(
                              avatar: roomState.selfPlayer.avatar,
                              size: 60,
                              showBorder: true,
                              borderColor: theme.colorScheme.primary,
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
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
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: '昵称',
                            isDense: true,
                            suffixIcon: IconButton(
                              tooltip: '随机昵称',
                              icon: const Icon(Icons.casino_outlined, size: 20),
                              onPressed: _randomizeName,
                            ),
                          ),
                          onChanged: (val) {
                            ref
                                .read(gameControllerProvider.notifier)
                                .updateProfile(
                                  name: val.trim(),
                                  avatar: roomState.selfPlayer.avatar,
                                );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 全宽矩形「游戏规则」按钮
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const RuleDialog(),
                  );
                },
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: const Text(
                  '游戏规则',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),

              const SizedBox(height: 14),

              // 联机模式切换
              Row(
                children: [
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'p2p',
                          icon: Icon(Icons.tag, size: 18),
                          label: Text('房间号'),
                        ),
                        ButtonSegment(
                          value: 'lan',
                          icon: Icon(Icons.wifi, size: 18),
                          label: Text('局域网'),
                        ),
                      ],
                      selected: {_selectedMode},
                      onSelectionChanged: (set) {
                        setState(() {
                          _selectedMode = set.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    triggerMode: TooltipTriggerMode.tap,
                    message: '房间号支持跨网连接；局域网通过同 Wi-Fi 的 IP 与端口直连',
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.info_outline,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              if (_selectedMode == 'p2p')
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _roomCodeController,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 6,
                          ),
                          decoration: InputDecoration(
                            labelText: '房间号',
                            hintText: '输入 4 位房间号',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              letterSpacing: 1,
                              fontWeight: FontWeight.normal,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          buildCounter: (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) =>
                              null,
                          onSubmitted: (_) {
                            if (!roomState.isConnecting) _joinP2p();
                          },
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: roomState.isConnecting ? null : _joinP2p,
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text(
                            '加入房间',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: roomState.isConnecting
                              ? null
                              : () {
                                  ref
                                      .read(gameControllerProvider.notifier)
                                      .createRoom(mode: 'p2p');
                                },
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text(
                            '创建房间',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _manualIpController,
                                decoration: const InputDecoration(
                                  labelText: 'IP 地址',
                                  hintText: '192.168.1.x',
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _manualPortController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '端口',
                                  hintText: '8888',
                                  isDense: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: roomState.isConnecting ? null : _joinLan,
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text(
                            '加入房间',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: roomState.isConnecting
                              ? null
                              : () {
                                  final port = int.tryParse(
                                          _manualPortController.text.trim()) ??
                                      8888;
                                  ref
                                      .read(gameControllerProvider.notifier)
                                      .createRoom(
                                        mode: 'lan',
                                        port: port,
                                      );
                                },
                          icon: const Icon(Icons.wifi_tethering, size: 18),
                          label: const Text(
                            '创建局域网房间',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (roomState.isConnecting) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
