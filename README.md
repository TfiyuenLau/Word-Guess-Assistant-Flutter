# 特工猜词助手 (Word Guess Assistant) - Flutter 跨平台版

<p align="center">
  <img src="assets/avatars/characters/detective.svg" width="96" height="96" alt="Logo" />
</p>

<p align="center">
  <b>纯 Dart / Flutter 驱动的多人跨平台社交推理与心理博弈游戏</b><br>
  涵盖 <b>4~12 人动态博弈</b> · <b>WebRTC P2P 4位房间号秒连</b> · <b>纯离线局域网 TCP/UDP 雷达</b> · <b>白板绝杀逆袭</b> · <b>黑夜误动自爆</b>
</p>

---

## 一、项目简介与核心亮点

本项目是「谁是卧底·猜词助手」的 **100% 纯 Flutter / Dart 全栈重构版本**。告别原有 Rust 与 TypeScript 双语言、双引擎维护的割裂历史，实现单一代码库、单一权威博弈引擎同时驱动原生与 Web 全平台。

### ✨ 核心设计亮点

- **📱 移动端优先与自适应视口**：
  - 默认采用现代主流智能手机（Portrait）人机工程比例；
  - 桌面端（Linux / Windows）默认以精致移动手机窗体呈现；Web 端宽屏自适应居中暗黑沉浸式画幅；移动端全屏无缝适配。
- **🌐 双模极速互联 (双通道自选)**：
  - **WebRTC P2P 模式（外网跨网络秒连）**：基于公共 EMQX WSS MQTT 极简信令与国内主流 STUN（腾讯/B站/小米）穿透，仅凭 **4 位数字房间号** 即可在不同网络、不同城市之间点对点直连。同 Wi-Fi 下自动建立局域网直连，零服务器带宽成本。
  - **局域网离线面对面模式（TCP/UDP 离线开黑）**：基于 `dart:io` 原生套接字，支持无网环境（机舱、露营、聚会、地下室）下的完全离线对局。内置 **38888 端口 UDP 组播/广播雷达**，自动发现房间并支持一键直连。
- **🎭 15 款精品矢量 SVG 特工形象**：
  - 提取并内置 15 套高精度 SVG 矢量形象，划分为 **特工角色**、**萌系动物**、**赛博朋克** 三大阵营；
  - 玩家点击头像即可在精美分类弹窗中自由切换，并实时同步给房间全体特工。
- **🎨 6 套定制终端主题风格**：
  - 提供 **暗夜特工 (默认)**、**赛博霓虹**、**深海潜行**、**森林隐蔽**、**赤红警报**、**极简浅色** 6 种精心调校的 Material 3 配色，支持随时一键无感热切，且持久化保存。
- **🔒 单一可信源与信息安全脱敏**：
  - 彻底弃用 Protobuf 及其 `protoc` 编译繁琐流程，局域网与 P2P 统一使用 **「4 字节前缀 + UTF-8 JSON」** 强类型自解析协议；
  - 房主广播全量快照时对底牌词语、方向提示及他人真实身份执行实时脱敏擦除，彻底杜绝客户端抓包泄题与作弊作恶。
- **🤖 内置虚拟特工 (Mock Bots) 模拟器**：
  - 随时一键填充虚拟特工，自动模拟发言、白天公投、黑夜暗杀以及白板被投出后的逆袭猜词，支持单人随时走通完整博弈流转，并作为高覆盖率自动化测试基石。

---

## 二、军规法则与身份机制

为确保 4~12 人局的紧凑悬疑感与白板逆袭的独特性，游戏内严格锁定 **1 名天使** 与 **1 名白板**，卧底人数随对局人数动态平衡：

| 总人数 | 🕵️ 卧底 (Spy) | 👼 天使 (Angel) | 🎭 白板 (Blank) | 🛡️ 平民好人 (Good) | 博弈格局说明 |
| :---: | :---: | :---: | :---: | :---: | :--- |
| **4 人** | 1 | 1 | 1 | 1 | 迷你经典四人局 (1卧 : 2好 : 1白) |
| **5 人** | 1 | 1 | 1 | 2 | 标准五人进阶局 (1卧 : 3好 : 1白) |
| **6 人** | 2 | 1 | 1 | 2 | 六人双卧风云局 (2卧 : 3好 : 1白) |
| **7 人** | 2 | 1 | 1 | 3 | 七人双卧稳健局 (2卧 : 4好 : 1白) |
| **8 人** | 2 | 1 | 1 | 4 | 八人双卧大局 (2卧 : 5好 : 1白) |
| **9 人** | 3 | 1 | 1 | 4 | 九人三卧乱斗局 (3卧 : 5好 : 1白) |
| **10 人** | 3 | 1 | 1 | 5 | 十人三卧平衡局 (3卧 : 6好 : 1白) |
| **11 人** | 3 | 1 | 1 | 6 | 十一人大局博弈 (3卧 : 7好 : 1白) |
| **12 人** | 4 | 1 | 1 | 6 | 十二人四卧巅峰局 (4卧 : 7好 : 1白) |

### 核心玩法细节：
1. **身份盲盒**：对局启动发词时，好人与卧底的身份界面统一盲盒显示为 **「特工」**，仅能看到自身底牌词语，不知道自己是否为卧底；
2. **天使视界**：天使同时获知两方词语（顺序随机），需要在不暴露自身的前提下隐蔽引导平民；
3. **白板与绝地逆袭**：白板全程无词，仅能看到题目分类方向提示。若白板在**白天公投阶段被投出**，不立即阵亡，而是触发专属的 **「白板逆袭」特别阶段**；白板若能同时准确猜中好人词与卧底词（顺序不限），直接宣布**白板独赢！**
4. **黑夜行动与误动自爆**：进入黑夜后，卧底暗中选择刺杀目标；好人、天使、白板若在夜间违规操作提交暗杀指令，将触发 **「误动自爆反噬」**！天亮后系统仅客观通报出局特工名单，绝不透露出局死因。
5. **推理标记系统**：玩家在对局中可点击任意特工头像，打上属于自己的本地推理标签（好人/卧底/天使/白板），辅助梳理局势。

---

## 三、系统架构与模块设计

```text
lib/
├── main.dart                          # 应用入口，ProviderScope 注入与自适应视口适配
├── models/
│   ├── game_models.dart               # GamePhase, Player, IdentityAssignment, SettlementDetails
│   ├── protocol_messages.dart         # 统一 4 字节前缀 JSON 编解码协议与网络消息信封
│   └── word_bank.dart                 # 100+ 精品分类双词库 (涵盖科技、美食、自然、生活等)
├── core/
│   ├── game_engine.dart               # 权威纯 Dart 博弈引擎 (发词/公投/白板逆袭/刺杀/自爆/胜负裁决)
│   └── mock_bots.dart                 # 虚拟特工生成与发言/投票/暗杀/猜词行为模拟器
├── network/
│   ├── game_transport.dart            # 抽象双工传输接口 (Host / Client)
│   ├── lan/
│   │   ├── lan_transport.dart         # 条件导出入口 (自动隔离 Web 与原生平台的 dart:io)
│   │   ├── lan_transport_stub.dart    # Web 端安全降级空实现
│   │   ├── lan_transport_io.dart      # 原生 TCP 4 字节帧头编解码与高并发 Server/Client
│   │   └── lan_discovery_io.dart      # 原生 UDP 38888 组播/广播局域网房间雷达
│   └── p2p/
│       ├── mini_mqtt_client.dart      # 基于 WebSocket 的纯 Dart MQTT 3.1.1 客户端 (支持 SUBACK 确认)
│       ├── p2p_signaling.dart         # 4 位房间号信令服务与 ICE 候选暂存队列
│       └── webrtc_transport.dart      # 基于 flutter_webrtc 的星型拓扑 DataChannel 传输
├── controllers/
│   ├── game_controller.dart           # Riverpod 状态调度中枢 (连接/建房/断线重连/观战/发词)
│   └── theme_controller.dart          # 全局 6 套终端主题管理器与持久化
└── ui/
    ├── screens/
    │   ├── home_screen.dart           # 大厅页面 (形象更换/代号随机/P2P建房加房/局域网雷达)
    │   └── room_screen.dart           # 房间页面 (阶段横幅/特工网格/SVG头像气泡流/底部行动栏)
    ├── widgets/
    │   └── avatar_widget.dart         # 15 套 SVG 矢量头像渲染组件
    └── modals/
        ├── avatar_picker_dialog.dart  # 分类形象选择弹窗
        ├── theme_picker_dialog.dart   # 终端主题切换面板
        ├── host_console_dialog.dart   # 房主控制台 (选词筛选/开局/流转/机器人填充)
        ├── identity_card_dialog.dart  # 身份词卡查看
        ├── vote_dialog.dart           # 白天公投票选
        ├── night_action_dialog.dart   # 黑夜刺杀与自爆确认
        ├── blank_guess_dialog.dart    # 白板终局猜词逆袭
        ├── player_mark_dialog.dart    # 本地身份推理标记
        └── settlement_dialog.dart     # 终局战报全员底牌复盘
```

---

## 四、快速上手与多平台构建

### 1. 环境准备 (国内高速镜像)

在编译与安装依赖前，建议在终端中配置 Flutter 官方中国镜像：

```bash
export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
```

### 2. 获取依赖与代码分析

```bash
cd /home/project/word_guess_assistant_flutter
flutter pub get
flutter analyze # 验证代码规范，0 issues
```

### 3. 运行全套自动化测试

项目已内置针对博弈规则矩阵、网络粘包、脱敏安全、P2P 协议以及全流程机器人的自动化测试套件：

```bash
flutter test
```
*（当前包含 26 个深度测试用例，100% 全部通过）*

### 4. 多平台运行与发布构建

- **Linux 桌面端运行与编译**：
  ```bash
  # 运行 Debug 模式 (以默认 420x860 手机比例窗体启动)
  flutter run -d linux

  # 构建 Release 发布包
  flutter build linux --release
  # 产物位置: build/linux/x64/release/bundle/word_guess_assistant_flutter
  ```

- **Web 端运行与编译**：
  ```bash
  # 启动本地开发 Web 服务 (支持跨标签页与同网手机联调)
  flutter run -d web-server --web-port 8080

  # 构建 Release 纯静态部署包 (条件导入自动剥离 dart:io，专注 P2P)
  flutter build web --release
  # 产物位置: build/web/
  ```

- **Android 移动端编译**：
  ```bash
  flutter build apk --release
  # 产物位置: build/app/outputs/flutter-apk/app-release.apk
  ```

- **Windows 桌面端运行与编译**：
  ```bash
  flutter run -d windows
  flutter build windows --release
  ```

---

## 五、技术问题与常见排查 (FAQ)

### Q1: Linux 环境下编译报错找不到 `libwebrtc.so` 或 GTK 库？
**原因**：若用户系统安装了 Conda/Cuda-env，其自带的 `x86_64-conda-linux-gnu-ld` 可能会劫持系统默认链接器，导致无法检索 Ubuntu 系统库路径。  
**对策**：本项目的 [`linux/CMakeLists.txt`](linux/CMakeLists.txt) 已内置防御规则，自动添加 `-fuse-ld=/usr/bin/ld` 强制调用系统官方标准链接器，无需手动调整 `PATH` 即可一次编译通过。

### Q2: 局域网模式下找不到房间？
**原因**：部分公共商业 Wi-Fi（如商场、企业网）开启了 **AP 隔离 (Client Isolation)** 或屏蔽了局域网 UDP 组播/广播。  
**对策**：
1. 房主与玩家连接同一部手机开启的个人热点；
2. 或者在局域网卡片中展开「手动直连 IP:Port」，直接输入房主手机/电脑的局域网 IP 直连；
3. 或直接切换到 **WebRTC P2P 模式**，输入 4 位房间号即可秒级互通。

---

## 六、开源协议

本项目基于 MIT License 开源，欢迎提交 Issue 与 Pull Request 共同完善！
