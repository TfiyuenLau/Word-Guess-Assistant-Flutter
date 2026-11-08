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

  final _categories = ['特工角色', '萌系动物', '赛博朋克'];

  @override
  void initState() {
    super.initState();
    _selectedAvatar = widget.currentAvatar;
    _tabController = TabController(length: _categories.length, vsync: this);
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
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 顶部标题与当前选中形象预览
              Row(
                children: [
                  AvatarWidget(
                    avatar: _selectedAvatar,
                    size: 52,
                    showBorder: true,
                    borderColor: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '选择特工机密形象',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '点击下方形象进行切换',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 分类 Tab
              TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                tabs: _categories.map((c) => Tab(text: c)).toList(),
              ),
              const SizedBox(height: 12),

              // 头像网格内容
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _categories.map((cat) {
                    final items = kBuiltinAvatars
                        .where((item) => item.category == cat)
                        .toList();

                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.9,
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
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.4)
                                  : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    AvatarWidget(
                                      avatar: item.assetPath,
                                      size: 56,
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        right: -4,
                                        bottom: -4,
                                        child: CircleAvatar(
                                          radius: 10,
                                          backgroundColor:
                                              theme.colorScheme.primary,
                                          child: const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
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

              const SizedBox(height: 8),

              // 底部确认按钮
              FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('确认使用此形象'),
                onPressed: () {
                  widget.onAvatarSelected(_selectedAvatar);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
