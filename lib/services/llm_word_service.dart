import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../controllers/settings_controller.dart';
import '../models/word_bank.dart';
import 'llm_http_client.dart';

/// 基于 OpenAI Chat Completions Tool Calling 的实时双词生成服务
/// （不依赖 dart:io，全面兼容 Web / 桌面 / 移动端）
class LlmWordService {
  final http.Client _client;
  final bool _ownsClient;
  final Duration timeout;

  LlmWordService({
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }

  Future<PresetWordPair> generateWordPair({
    required LlmSettings settings,
    String? topic,
    String? similarity,
  }) async {
    final trimmedUrl = settings.apiUrl.trim();
    final trimmedKey = settings.apiKey.trim();
    final trimmedModel = settings.model.trim();

    if (trimmedUrl.isEmpty) {
      throw StateError('请先在首页「设置」中配置 API 地址');
    }
    if (trimmedKey.isEmpty) {
      throw StateError('请先在首页「设置」中配置 API Key');
    }
    if (trimmedModel.isEmpty) {
      throw StateError('请先在首页「设置」中配置模型名称');
    }

    final endpoint = settings.resolvedEndpoint;
    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw ArgumentError('API 地址格式无效: $endpoint');
    }

    final rawTopic = topic?.trim() ?? '';
    final effectiveTopic = (rawTopic.isEmpty ||
            rawTopic == WordBank.randomCategory ||
            rawTopic == '全部主题')
        ? '随机常见生活主题'
        : rawTopic;

    final rawSim = similarity?.trim() ?? '';
    final effectiveSimilarity =
        (rawSim.isEmpty || rawSim == WordBank.randomSimilarity)
            ? '极为接近'
            : rawSim;

    final requestBody = <String, dynamic>{
      'model': trimmedModel,
      'temperature': 0.8,
      'messages': [
        {
          'role': 'system',
          'content':
              '你是「猜词助手（谁是卧底）」游戏的权威出题官。请严格通过调用 submit_word_pair 工具提交一组高质量中文双词与白板提示。'
                  '要求：1) good_word 与 spy_word 必须属于同一语境但含义有清晰边界，绝不能相同或互相包含；'
                  '2) blank_hint 为 10~25 字的宽泛共性特征，绝不能直接出现 good_word 或 spy_word 的字眼。',
        },
        {
          'role': 'user',
          'content':
              '请围绕主题「$effectiveTopic」，按词义相似度「$effectiveSimilarity」生成一组适合聚会游玩的双词与白板提示，并调用 submit_word_pair 提交。',
        },
      ],
      'tools': [
        {
          'type': 'function',
          'function': {
            'name': 'submit_word_pair',
            'description': '提交一组「猜词助手」好人词、卧底词与白板提示词',
            'parameters': {
              'type': 'object',
              'properties': {
                'good_word': {
                  'type': 'string',
                  'description': '好人（平民）词汇，简洁中文词语（2~6字）',
                },
                'spy_word': {
                  'type': 'string',
                  'description': '卧底词汇，与好人词同属一类且不相同',
                },
                'blank_hint': {
                  'type': 'string',
                  'description': '给白板玩家的共性特征提示，不得包含好人词或卧底词本身',
                },
              },
              'required': ['good_word', 'spy_word', 'blank_hint'],
            },
          },
        },
      ],
      'tool_choice': {
        'type': 'function',
        'function': {'name': 'submit_word_pair'},
      },
    };

    final headers = <String, String>{
      'Authorization': 'Bearer $trimmedKey',
      'Content-Type': 'application/json; charset=UTF-8',
    };
    final encodedBody = jsonEncode(requestBody);

    final response = await _postWithTransportFallback(
      primaryUri: uri,
      headers: headers,
      body: encodedBody,
    );

    final bodyText = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode != 200) {
      final apiErr = _extractApiErrorMessage(bodyText);
      final suffix = apiErr != null ? ': $apiErr' : '';
      throw Exception('AIGC 接口返回异常 (HTTP ${response.statusCode})$suffix');
    }

    final decoded = jsonDecode(bodyText);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('AIGC 响应 JSON 格式无效');
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const FormatException('AIGC 响应缺少 choices 字段');
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map) {
      throw const FormatException('AIGC 响应 choice 结构无效');
    }
    final message = firstChoice['message'];
    if (message is! Map) {
      throw const FormatException('AIGC 响应缺少 message 字段');
    }

    final args = _extractToolArguments(message);
    final goodWord = (args['good_word'] ?? '').toString().trim();
    final spyWord = (args['spy_word'] ?? '').toString().trim();
    var blankHint = (args['blank_hint'] ?? '').toString().trim();

    if (goodWord.isEmpty || spyWord.isEmpty) {
      throw const FormatException('AIGC 生成的词汇为空，请重试');
    }
    if (goodWord == spyWord) {
      throw const FormatException('AIGC 生成的好人词与卧底词重复，请重试');
    }
    if (blankHint.isEmpty) {
      blankHint = '与「$effectiveTopic」相关的常见事物';
    }

    return PresetWordPair(
      wordA: goodWord,
      wordB: spyWord,
      hint: blankHint,
      similarity: effectiveSimilarity,
      category: effectiveTopic,
    );
  }

  Future<http.Response> _postWithTransportFallback({
    required Uri primaryUri,
    required Map<String, String> headers,
    required String body,
  }) async {
    final candidates = _buildTransportCandidates(primaryUri);
    Object? lastError;

    for (var i = 0; i < candidates.length; i++) {
      final candidate = candidates[i];
      http.Client? ephemeralDirectClient;
      final http.Client activeClient;

      if (candidate.direct) {
        ephemeralDirectClient = createDirectHttpClient();
        if (ephemeralDirectClient == null) continue;
        activeClient = ephemeralDirectClient;
      } else {
        activeClient = _client;
      }

      try {
        return await activeClient
            .post(candidate.uri, headers: headers, body: body)
            .timeout(timeout);
      } catch (e) {
        final isTransportErr =
            e is TimeoutException || isTransportConnectionError(e);
        if (!isTransportErr) {
          rethrow;
        }
        lastError = e;
      } finally {
        ephemeralDirectClient?.close();
      }
    }

    if (lastError is TimeoutException) {
      throw Exception('AIGC 请求超时（>${timeout.inSeconds}秒），请检查网络或代理设置');
    }
    throw Exception(
      '连接 AIGC 接口失败，请检查网络、系统代理或 API 地址（ChatAnywhere 代理环境可尝试 https://api.chatanywhere.org）: $lastError',
    );
  }

  List<({Uri uri, bool direct})> _buildTransportCandidates(Uri primaryUri) {
    final candidates = <({Uri uri, bool direct})>[
      (uri: primaryUri, direct: false),
    ];

    if (primaryUri.host == 'api.chatanywhere.tech') {
      candidates.add(
        (uri: primaryUri.replace(host: 'api.chatanywhere.org'), direct: false),
      );
      if (_ownsClient) {
        candidates.add((uri: primaryUri, direct: true));
      }
    } else if (primaryUri.host == 'api.chatanywhere.org') {
      final techUri = primaryUri.replace(host: 'api.chatanywhere.tech');
      if (_ownsClient) {
        candidates.add((uri: techUri, direct: true));
      }
      candidates.add((uri: techUri, direct: false));
    } else if (_ownsClient) {
      candidates.add((uri: primaryUri, direct: true));
    }

    return candidates;
  }

  String? _extractApiErrorMessage(String bodyText) {
    try {
      final decoded = jsonDecode(bodyText);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map && err['message'] != null) {
          final msg = err['message'].toString().trim();
          if (msg.isNotEmpty) return msg;
        }
        if (decoded['message'] != null) {
          final msg = decoded['message'].toString().trim();
          if (msg.isNotEmpty) return msg;
        }
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> _extractToolArguments(Map message) {
    final toolCalls = message['tool_calls'];
    if (toolCalls is List && toolCalls.isNotEmpty) {
      final firstCall = toolCalls.first;
      if (firstCall is Map) {
        final fn = firstCall['function'];
        if (fn is Map) {
          final rawArgs = fn['arguments'];
          if (rawArgs is Map) {
            return Map<String, dynamic>.from(rawArgs);
          }
          if (rawArgs is String && rawArgs.trim().isNotEmpty) {
            return _decodeJsonObject(rawArgs);
          }
        }
      }
    }

    final content = message['content']?.toString() ?? '';
    if (content.trim().isNotEmpty) {
      return _decodeJsonObject(content);
    }

    throw const FormatException('AIGC 响应未包含工具调用参数或有效 JSON 内容');
  }

  Map<String, dynamic> _decodeJsonObject(String raw) {
    var cleaned = raw.trim();
    // 兼容部分中转接口返回 ```json ... ``` 代码块
    final fenceRegex = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$');
    final match = fenceRegex.firstMatch(cleaned);
    if (match != null) {
      cleaned = match.group(1)?.trim() ?? cleaned;
    }

    try {
      final parsed = jsonDecode(cleaned);
      if (parsed is Map) {
        return Map<String, dynamic>.from(parsed);
      }
    } catch (_) {
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end > start) {
        final slice = cleaned.substring(start, end + 1);
        final parsed = jsonDecode(slice);
        if (parsed is Map) {
          return Map<String, dynamic>.from(parsed);
        }
      }
    }

    throw const FormatException('无法解析 AIGC 返回的词组 JSON');
  }
}
