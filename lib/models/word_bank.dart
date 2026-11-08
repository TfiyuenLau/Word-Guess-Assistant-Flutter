import 'dart:math';

/// 预设双词题库条目
class PresetWordPair {
  final String wordA;
  final String wordB;
  final String hint;
  final String similarity; // "极为接近" 或 "较为接近" / "高度相似"
  final String category;

  const PresetWordPair({
    required this.wordA,
    required this.wordB,
    required this.hint,
    required this.similarity,
    required this.category,
  });
}

class WordBank {
  static const List<PresetWordPair> builtinPairs = [
    PresetWordPair(
      wordA: '玫瑰',
      wordB: '月季',
      hint: '多刺木本观赏花卉，常作为爱情与热烈情感的象征',
      similarity: '极为接近',
      category: '自然植物',
    ),
    PresetWordPair(
      wordA: '汉堡',
      wordB: '肉夹馍',
      hint: '外层为烘烤面食、中层夹香浓熟肉与调味的经典主食',
      similarity: '较为接近',
      category: '美食饮品',
    ),
    PresetWordPair(
      wordA: '单反相机',
      wordB: '微单相机',
      hint: '拥有可更换专业镜头组件的高画质便携数码摄影设备',
      similarity: '极为接近',
      category: '科技数码',
    ),
    PresetWordPair(
      wordA: '微信',
      wordB: 'QQ',
      hint: '腾讯公司旗下拥有海量用户的国民级即时通讯与社交软件',
      similarity: '极为接近',
      category: '科技数码',
    ),
    PresetWordPair(
      wordA: '台风',
      wordB: '龙卷风',
      hint: '伴随高速气旋旋转并伴有极强破坏力的大气涡旋恶劣天气',
      similarity: '较为接近',
      category: '自然植物',
    ),
    PresetWordPair(
      wordA: '自行车',
      wordB: '电动车',
      hint: '日常街头常见、依靠两个轮子维持平衡的个人代步骑行工具',
      similarity: '较为接近',
      category: '交通出行',
    ),
    PresetWordPair(
      wordA: '牛奶',
      wordB: '豆浆',
      hint: '富含丰富蛋白质、常在清晨早餐搭配享用的营养乳白色饮品',
      similarity: '较为接近',
      category: '美食饮品',
    ),
    PresetWordPair(
      wordA: '雪碧',
      wordB: '可乐',
      hint: '口感清爽、充满二氧化碳气泡的经典瓶装碳酸甜味软饮料',
      similarity: '较为接近',
      category: '美食饮品',
    ),
    PresetWordPair(
      wordA: '眉毛',
      wordB: '睫毛',
      hint: '生长在人体眼眶周边、起到遮挡汗水灰尘与装饰面部作用的毛发',
      similarity: '极为接近',
      category: '日常生活',
    ),
    PresetWordPair(
      wordA: '眉毛',
      wordB: '胡须',
      hint: '面部长出的毛发，体现人的面容特征',
      similarity: '极为接近',
      category: '日常生活',
    ),
    PresetWordPair(
      wordA: '橙子',
      wordB: '橘子',
      hint: '外皮为鲜艳橙黄色、富含维C且酸甜多汁的柑橘属水果',
      similarity: '极为接近',
      category: '美食饮品',
    ),
    PresetWordPair(
      wordA: '羽毛球',
      wordB: '网球',
      hint: '通过挥动球拍隔着中央球网将球来回击打的双人或四人竞技运动',
      similarity: '较为接近',
      category: '文体艺术',
    ),
    PresetWordPair(
      wordA: '小提琴',
      wordB: '中提琴',
      hint: '依靠马尾琴弓在四根琴弦上摩擦振动发声的木质西洋弦乐器',
      similarity: '极为接近',
      category: '文体艺术',
    ),
    PresetWordPair(
      wordA: '状元',
      wordB: '榜眼',
      hint: '古代科举及第名次，殿试名列前茅者',
      similarity: '极为接近',
      category: '文化历史',
    ),
    PresetWordPair(
      wordA: '面包',
      wordB: '蛋糕',
      hint: '日常烘焙面食甜点，香甜松软',
      similarity: '极为接近',
      category: '美食饮品',
    ),
    PresetWordPair(
      wordA: '西瓜',
      wordB: '哈密瓜',
      hint: '夏季常见多汁甘甜瓜果，清凉解渴',
      similarity: '极为接近',
      category: '美食饮品',
    ),
    PresetWordPair(
      wordA: '蝴蝶',
      wordB: '蜜蜂',
      hint: '花丛中穿梭采蜜授粉的常见飞行动物',
      similarity: '极为接近',
      category: '自然植物',
    ),
    PresetWordPair(
      wordA: '雨伞',
      wordB: '雨衣',
      hint: '雨天出门必备的防雨遮水用具',
      similarity: '极为接近',
      category: '日常生活',
    ),
    PresetWordPair(
      wordA: '警察',
      wordB: '保安',
      hint: '维护公共治安与安全秩序的工作人员',
      similarity: '极为接近',
      category: '日常生活',
    ),
    PresetWordPair(
      wordA: '钢笔',
      wordB: '圆珠笔',
      hint: '日常学生与办公常用的纸质墨水书写工具',
      similarity: '极为接近',
      category: '文化历史',
    ),
    PresetWordPair(
      wordA: '魔术师',
      wordB: '特异功能',
      hint: '展示不可思议的障眼手法或神秘超自然现象',
      similarity: '较为接近',
      category: '文体艺术',
    ),
    PresetWordPair(
      wordA: '牛肉干',
      wordB: '猪肉脯',
      hint: '便携耐嚼、咸香诱人的常见肉类休闲零食',
      similarity: '极为接近',
      category: '美食饮品',
    ),
    PresetWordPair(
      wordA: '洗发水',
      wordB: '沐浴露',
      hint: '个人洗漱卫浴必备的清洁起泡洗护液体',
      similarity: '较为接近',
      category: '日常生活',
    ),
    PresetWordPair(
      wordA: '高铁',
      wordB: '动车',
      hint: '依靠电气轨道高速运行的现代旅客列车',
      similarity: '极为接近',
      category: '交通出行',
    ),
    PresetWordPair(
      wordA: '咖啡',
      wordB: '奶茶',
      hint: '现代都市年轻人日常提神解渴的流行杯装饮品',
      similarity: '较为接近',
      category: '美食饮品',
    ),
    PresetWordPair(
      wordA: '毛巾',
      wordB: '浴巾',
      hint: '擦拭身体与面部多余水分的棉质纺织布品',
      similarity: '极为接近',
      category: '日常生活',
    ),
    PresetWordPair(
      wordA: '苹果',
      wordB: '梨子',
      hint: '常见多汁甘甜的水果，脆爽可口',
      similarity: '极为接近',
      category: '美食饮品',
    ),
  ];

  static List<String> get categories => [
    '全部主题',
    '美食饮品',
    '自然植物',
    '科技数码',
    '日常生活',
    '交通出行',
    '文化历史',
    '文体艺术',
  ];

  static List<String> get similarities => [
    '极为接近',
    '较为接近',
  ];

  /// 根据主题和相似度智能抽取词组
  static PresetWordPair generateWords({String? theme, String? similarity}) {
    final random = Random();
    final trimmedTheme = theme?.trim() ?? '';
    final trimmedSim = similarity?.trim() ?? '';

    // 1. 尝试匹配主题 + 相似度
    var candidates = builtinPairs.where((p) {
      final simMatch = trimmedSim.isEmpty || p.similarity == trimmedSim;
      final themeMatch = trimmedTheme.isEmpty ||
          trimmedTheme == '全部主题' ||
          p.category.contains(trimmedTheme) ||
          p.hint.contains(trimmedTheme);
      return simMatch && themeMatch;
    }).toList();

    if (candidates.isNotEmpty) {
      return candidates[random.nextInt(candidates.length)];
    }

    // 2. 退化匹配相似度
    if (trimmedSim.isNotEmpty) {
      candidates = builtinPairs.where((p) => p.similarity == trimmedSim).toList();
      if (candidates.isNotEmpty) {
        return candidates[random.nextInt(candidates.length)];
      }
    }

    // 3. 兜底全局随机
    return builtinPairs[random.nextInt(builtinPairs.length)];
  }
}
