import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_guess_assistant_flutter/controllers/settings_controller.dart';
import 'package:word_guess_assistant_flutter/models/word_bank.dart';
import 'package:word_guess_assistant_flutter/services/llm_word_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordBank JSON Loader & Schema Validation', () {
    test('生成词组前若未加载本地 JSON 词库应抛出 StateError', () {
      if (!WordBank.isLoaded) {
        expect(() => WordBank.generateWords(), throwsStateError);
      }
    });

    test('loadFromJsonString 解析 assets/word_bank.json 且字段与数量合法', () {
      final jsonStr = File('assets/word_bank.json').readAsStringSync();
      WordBank.loadFromJsonString(jsonStr);

      expect(WordBank.isLoaded, isTrue);
      expect(WordBank.entries.length, greaterThanOrEqualTo(50));
      expect(WordBank.categories.first, WordBank.randomCategory);
      expect(WordBank.categories, contains('食物'));
      expect(WordBank.categories, contains('家具'));

      for (final entry in WordBank.entries) {
        expect(entry.wordA.trim(), isNotEmpty);
        expect(entry.wordB.trim(), isNotEmpty);
        expect(entry.wordA, isNot(equals(entry.wordB)));
        expect(entry.hint.trim(), isNotEmpty);
        expect(entry.category.trim(), isNotEmpty);
        expect(
          entry.similarity == '极为接近' || entry.similarity == '较为接近',
          isTrue,
          reason: '无效相似度: ${entry.similarity}',
        );
      }
    });

    test('按分类与相似度筛选、通配符回退及 JSON 序列化均正常工作', () {
      final jsonStr = File('assets/word_bank.json').readAsStringSync();
      WordBank.loadFromJsonString(jsonStr);

      for (var i = 0; i < 15; i++) {
        final foodClose =
            WordBank.generateWords(theme: '食物', similarity: '极为接近');
        expect(foodClose.category, '食物');
        expect(foodClose.similarity, '极为接近');

        final furniture = WordBank.generateWords(theme: '家具');
        expect(furniture.category, '家具');
      }

      expect(WordBank.generateWords(theme: '').wordA, isNotEmpty);
      expect(WordBank.generateWords(theme: '随机').wordA, isNotEmpty);
      expect(WordBank.generateWords(theme: '全部主题').wordA, isNotEmpty);

      final sample = WordBank.entries.first;
      final roundTrip = PresetWordPair.fromJson(sample.toJson());
      expect(roundTrip.wordA, sample.wordA);
      expect(roundTrip.wordB, sample.wordB);
      expect(roundTrip.hint, sample.hint);
      expect(roundTrip.similarity, sample.similarity);
      expect(roundTrip.category, sample.category);
    });

    test('无效 JSON 或空词库条目应抛出 FormatException', () {
      expect(() => WordBank.loadFromJsonString('[]'), throwsFormatException);
      expect(
        () => WordBank.loadFromJsonString('{"version":1,"entries":[]}'),
        throwsFormatException,
      );
      expect(
        () => WordBank.loadFromJsonString(
          '{"version":1,"entries":[{"wordA":"咖啡","wordB":"咖啡","hint":"相同"}]}',
        ),
        throwsFormatException,
      );

      // 恢复真实词库，避免影响后续测试
      WordBank.loadFromJsonString(File('assets/word_bank.json').readAsStringSync());
    });
  });

  group('LlmSettings & SettingsController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('默认值与 URL 端点规范化规则正确', () {
      const defaults = LlmSettings();
      expect(
        defaults.apiUrl,
        'https://api.chatanywhere.tech/v1/chat/completions',
      );
      expect(defaults.apiKey, isEmpty);
      expect(defaults.model, 'deepseek-v4.1-flash-1017');
      expect(defaults.isConfigured, isFalse);
      expect(
        defaults.resolvedEndpoint,
        'https://api.chatanywhere.tech/v1/chat/completions',
      );

      expect(
        const LlmSettings(apiUrl: 'https://api.chatanywhere.tech')
            .resolvedEndpoint,
        'https://api.chatanywhere.tech/v1/chat/completions',
      );
      expect(
        const LlmSettings(apiUrl: 'https://api.chatanywhere.tech/')
            .resolvedEndpoint,
        'https://api.chatanywhere.tech/v1/chat/completions',
      );
      expect(
        const LlmSettings(apiUrl: 'https://api.chatanywhere.tech/v1')
            .resolvedEndpoint,
        'https://api.chatanywhere.tech/v1/chat/completions',
      );
      expect(
        const LlmSettings(apiUrl: 'https://api.chatanywhere.tech/v1/')
            .resolvedEndpoint,
        'https://api.chatanywhere.tech/v1/chat/completions',
      );
      expect(
        const LlmSettings(
          apiUrl: 'https://api.chatanywhere.tech/v1/chat/completions/',
        ).resolvedEndpoint,
        'https://api.chatanywhere.tech/v1/chat/completions',
      );
      expect(
        const LlmSettings(apiKey: 'sk-123').isConfigured,
        isTrue,
      );
    });

    test('SettingsController 支持 SharedPreferences 持久化、重载与恢复默认', () async {
      final controller = SettingsController();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      await controller.updateSettings(
        apiUrl: 'https://api.chatanywhere.tech',
        apiKey: 'sk-custom-key',
        model: 'gpt-4o-mini',
      );
      expect(controller.state.apiUrl, 'https://api.chatanywhere.tech');
      expect(controller.state.apiKey, 'sk-custom-key');
      expect(controller.state.model, 'gpt-4o-mini');
      expect(controller.state.isConfigured, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString(SettingsController.prefKeyApiUrl),
        'https://api.chatanywhere.tech',
      );
      expect(
        prefs.getString(SettingsController.prefKeyApiKey),
        'sk-custom-key',
      );
      expect(
        prefs.getString(SettingsController.prefKeyModel),
        'gpt-4o-mini',
      );

      // 新建实例应自动从 SharedPreferences 恢复
      final reloaded = SettingsController();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(reloaded.state.apiUrl, 'https://api.chatanywhere.tech');
      expect(reloaded.state.apiKey, 'sk-custom-key');
      expect(reloaded.state.model, 'gpt-4o-mini');

      // 恢复默认
      await reloaded.resetDefaults();
      expect(reloaded.state, const LlmSettings());
      expect(
        prefs.getString(SettingsController.prefKeyApiUrl),
        LlmSettings.defaultApiUrl,
      );
      expect(prefs.getString(SettingsController.prefKeyApiKey), '');
      expect(
        prefs.getString(SettingsController.prefKeyModel),
        LlmSettings.defaultModel,
      );
    });
  });

  group('LlmWordService Tool Calling & Error Handling', () {
    test('校验请求结构（URL、Header、Tool Calling、主题词）并解析中文 tool_calls 响应', () async {
      late http.Request capturedReq;
      late Map<String, dynamic> capturedBody;

      final mockClient = MockClient((request) async {
        capturedReq = request;
        capturedBody =
            jsonDecode(utf8.decode(request.bodyBytes)) as Map<String, dynamic>;

        final responsePayload = {
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'tool_calls': [
                  {
                    'id': 'call_001',
                    'type': 'function',
                    'function': {
                      'name': 'submit_word_pair',
                      'arguments': jsonEncode({
                        'good_word': '量子计算机',
                        'spy_word': '超级计算机',
                        'blank_hint': '拥有强大算力的前沿大型计算设备',
                      }),
                    },
                  },
                ],
              },
            },
          ],
        };
        return http.Response.bytes(
          utf8.encode(jsonEncode(responsePayload)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = LlmWordService(client: mockClient);
      const settings = LlmSettings(
        apiUrl: 'https://api.chatanywhere.tech',
        apiKey: 'sk-test-token',
        model: 'deepseek-v4.1-flash-1017',
      );

      final pair = await service.generateWordPair(
        settings: settings,
        topic: '前沿科技',
        similarity: '极为接近',
      );

      expect(
        capturedReq.url.toString(),
        'https://api.chatanywhere.tech/v1/chat/completions',
      );
      expect(capturedReq.headers['Authorization'], 'Bearer sk-test-token');
      expect(capturedBody['model'], 'deepseek-v4.1-flash-1017');

      final tools = capturedBody['tools'] as List;
      expect(tools.length, 1);
      expect(tools.first['function']['name'], 'submit_word_pair');
      expect(
        capturedBody['tool_choice']['function']['name'],
        'submit_word_pair',
      );

      final messages = capturedBody['messages'] as List;
      expect(messages[1]['content'].toString(), contains('前沿科技'));
      expect(messages[1]['content'].toString(), contains('极为接近'));

      expect(pair.wordA, '量子计算机');
      expect(pair.wordB, '超级计算机');
      expect(pair.hint, '拥有强大算力的前沿大型计算设备');
      expect(pair.category, '前沿科技');
      expect(pair.similarity, '极为接近');
    });

    test('支持解析 message.content 中的 Markdown JSON 代码块回退响应', () async {
      final mockClient = MockClient((_) async {
        final payload = {
          'choices': [
            {
              'message': {
                'role': 'assistant',
                'content':
                    '```json\n{"good_word":"拿铁","spy_word":"卡布奇诺","blank_hint":"意式浓缩搭配牛奶的常见咖啡"}\n```',
              },
            },
          ],
        };
        return http.Response.bytes(utf8.encode(jsonEncode(payload)), 200);
      });

      final service = LlmWordService(client: mockClient);
      final pair = await service.generateWordPair(
        settings: const LlmSettings(apiKey: 'sk-valid'),
        topic: '咖啡',
      );

      expect(pair.wordA, '拿铁');
      expect(pair.wordB, '卡布奇诺');
      expect(pair.hint, '意式浓缩搭配牛奶的常见咖啡');
    });

    test('空 API Key、HTTP 401/500 及重复/无效词组应抛出明确错误', () async {
      final serviceEmpty = LlmWordService(
        client: MockClient((_) async => http.Response('{}', 200)),
      );
      await expectLater(
        serviceEmpty.generateWordPair(settings: const LlmSettings()),
        throwsStateError,
      );

      final service401 = LlmWordService(
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode(jsonEncode({
              'error': {'message': 'Invalid API key'},
            })),
            401,
          ),
        ),
      );
      await expectLater(
        service401.generateWordPair(
          settings: const LlmSettings(apiKey: 'sk-bad'),
        ),
        throwsA(predicate((e) =>
            e.toString().contains('401') &&
            e.toString().contains('Invalid API key'))),
      );

      final service500 = LlmWordService(
        client: MockClient((_) async => http.Response('Internal Error', 500)),
      );
      await expectLater(
        service500.generateWordPair(
          settings: const LlmSettings(apiKey: 'sk-ok'),
        ),
        throwsA(predicate((e) => e.toString().contains('500'))),
      );

      final serviceSameWords = LlmWordService(
        client: MockClient((_) async {
          final payload = {
            'choices': [
              {
                'message': {
                  'tool_calls': [
                    {
                      'function': {
                        'name': 'submit_word_pair',
                        'arguments': jsonEncode({
                          'good_word': '火锅',
                          'spy_word': '火锅',
                          'blank_hint': '常见聚餐美食',
                        }),
                      },
                    },
                  ],
                },
              },
            ],
          };
          return http.Response.bytes(utf8.encode(jsonEncode(payload)), 200);
        }),
      );
      await expectLater(
        serviceSameWords.generateWordPair(
          settings: const LlmSettings(apiKey: 'sk-ok'),
        ),
        throwsFormatException,
      );
    });
  });
}
