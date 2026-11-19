import 'package:flutter/material.dart';
import '../widgets/avatar_widget.dart';

class AvatarPickerDialog extends StatefulWidget {
  final String currentAvatar;
  final ValueChanged<String> onAvatarSelected;

  const AvatarPickerDialog({
    super.key,
    required this.currentAvatar,
    required this.onAvatarSelected,
  });

  @override
  State<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _selectedAvatar;

  static const _tabs = [
    (label: '角色', category: '特工角色'),
    (label: '动物', category: '萌系动物'),
    (label: '赛博', category: '赛博朋克'),
  ];

  @override
  void initState() {
    super.initState();
    _selectedAvatar = widget.currentAvatar;
    final currentPath = normalizeAvatarPath(widget.currentAvatar);
    final matchIndex = _tabs.indexWhere((t) => kBuiltinAvatars
        .any((a) => a.category == t.category && a.assetPath == currentPath));
    _tabController = TabController(
      length: _tabs.length,
      initialIndex: matchIndex >= 0 ? matchIndex : 0,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 480),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  AvatarWidget(
                    avatar: _selectedAvatar,
                    size: 40,
                    showBorder: true,
                    borderColor: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '选择头像',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _tabs.map((tab) {
                    final items = kBuiltinAvatars
                        .where((item) => item.category == tab.category)
                        .toList();

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.78,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isSelected =
                            normalizeAvatarPath(_selectedAvatar) ==
                                item.assetPath;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedAvatar = item.id;
                            });
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.4)
                                  : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AvatarWidget(
                                      avatar: item.assetPath,
                                      size: 48,
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        right: -2,
                                        bottom: -2,
                                        child: CircleAvatar(
                                          radius: 9,
                                          backgroundColor:
                                              theme.colorScheme.primary,
                                          child: const Icon(
                                            Icons.check,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                onPressed: () {
                  widget.onAvatarSelected(_selectedAvatar);
                  Navigator.of(context).pop();
                },
                child: const Text('确定'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
