import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AvatarItem {
  final String id;
  final String name;
  final String category;
  final String assetPath;

  const AvatarItem({
    required this.id,
    required this.name,
    required this.category,
    required this.assetPath,
  });
}

const List<AvatarItem> kBuiltinAvatars = [
  // 特工角色
  AvatarItem(
    id: 'characters/detective.svg',
    name: '名牌侦探',
    category: '特工角色',
    assetPath: 'assets/avatars/characters/detective.svg',
  ),
  AvatarItem(
    id: 'characters/ninja.svg',
    name: '暗影忍者',
    category: '特工角色',
    assetPath: 'assets/avatars/characters/ninja.svg',
  ),
  AvatarItem(
    id: 'characters/robot.svg',
    name: '仿生机兵',
    category: '特工角色',
    assetPath: 'assets/avatars/characters/robot.svg',
  ),
  AvatarItem(
    id: 'characters/hero.svg',
    name: '正义勇者',
    category: '特工角色',
    assetPath: 'assets/avatars/characters/hero.svg',
  ),
  AvatarItem(
    id: 'characters/wizard.svg',
    name: '奥术占卜',
    category: '特工角色',
    assetPath: 'assets/avatars/characters/wizard.svg',
  ),

  // 萌系动物
  AvatarItem(
    id: 'animals/fox.svg',
    name: '狡黠赤狐',
    category: '萌系动物',
    assetPath: 'assets/avatars/animals/fox.svg',
  ),
  AvatarItem(
    id: 'animals/cat.svg',
    name: '黑夜灵猫',
    category: '萌系动物',
    assetPath: 'assets/avatars/animals/cat.svg',
  ),
  AvatarItem(
    id: 'animals/bear.svg',
    name: '沉稳棕熊',
    category: '萌系动物',
    assetPath: 'assets/avatars/animals/bear.svg',
  ),
  AvatarItem(
    id: 'animals/rabbit.svg',
    name: '敏锐白兔',
    category: '萌系动物',
    assetPath: 'assets/avatars/animals/rabbit.svg',
  ),
  AvatarItem(
    id: 'animals/panda.svg',
    name: '国宝熊猫',
    category: '萌系动物',
    assetPath: 'assets/avatars/animals/panda.svg',
  ),

  // 赛博朋克
  AvatarItem(
    id: 'cyber/agent.svg',
    name: '矩阵特工',
    category: '赛博朋克',
    assetPath: 'assets/avatars/cyber/agent.svg',
  ),
  AvatarItem(
    id: 'cyber/cyborg.svg',
    name: '义体生化',
    category: '赛博朋克',
    assetPath: 'assets/avatars/cyber/cyborg.svg',
  ),
  AvatarItem(
    id: 'cyber/hacker.svg',
    name: '极客骇客',
    category: '赛博朋克',
    assetPath: 'assets/avatars/cyber/hacker.svg',
  ),
  AvatarItem(
    id: 'cyber/neon.svg',
    name: '霓虹暗流',
    category: '赛博朋克',
    assetPath: 'assets/avatars/cyber/neon.svg',
  ),
  AvatarItem(
    id: 'cyber/glitch.svg',
    name: '故障代码',
    category: '赛博朋克',
    assetPath: 'assets/avatars/cyber/glitch.svg',
  ),
];

String normalizeAvatarPath(String raw) {
  if (raw.isEmpty) {
    return kBuiltinAvatars.first.assetPath;
  }
  // 兼容旧格式 /avatar/characters/detective.svg
  var clean = raw.replaceAll(RegExp(r'^/+'), '');
  if (clean.startsWith('avatar/')) {
    clean = clean.replaceFirst('avatar/', '');
  }
  if (!clean.startsWith('assets/avatars/')) {
    clean = 'assets/avatars/$clean';
  }
  return clean;
}

const ColorFilter _kOutGrayscaleFilter = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0,      0,      0,      1, 0,
]);

class AvatarWidget extends StatelessWidget {
  final String avatar;
  final double size;
  final bool showBorder;
  final Color? borderColor;
  final bool isOut;

  const AvatarWidget({
    super.key,
    required this.avatar,
    this.size = 48,
    this.showBorder = false,
    this.borderColor,
    this.isOut = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final assetPath = normalizeAvatarPath(avatar);

    Widget avatarCircle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: borderColor ?? theme.colorScheme.primary,
                width: 2,
              )
            : null,
      ),
      child: ClipOval(
        child: SvgPicture.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => Container(
            color: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.fingerprint,
              size: size * 0.6,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );

    if (!isOut) {
      return avatarCircle;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: 0.45,
            child: ColorFiltered(
              colorFilter: _kOutGrayscaleFilter,
              child: avatarCircle,
            ),
          ),
          Positioned(
            bottom: -2,
            right: -3,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: size >= 36 ? 4 : 3,
                vertical: 1.5,
              ),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: theme.colorScheme.surface,
                  width: 1,
                ),
              ),
              child: Text(
                'OUT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size >= 36 ? 8 : 7,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
