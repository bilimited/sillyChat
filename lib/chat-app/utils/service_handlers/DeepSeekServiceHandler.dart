import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:dio/dio.dart';

import 'package:flutter_example/chat-app/utils/service_handlers/OpenAIServiceHandler.dart';
import 'package:http/http.dart';

class Deepseekservicehandler extends Openaiservicehandler {
  const Deepseekservicehandler()
      : super(
            baseUrl: 'https://api.deepseek.com',
            name: 'deepseek',
            defaultModelList: const [
              'deepseek-chat',
              'deepseek-reasoner',
              'DeepSeek-V3-0324',
              'DeepSeek-R1-0528',
              'DeepSeek-V3',
              'DeepSeek-R1'
            ]);

  @override
  bool get canFetchBalance => true;

  @override
  Future<String> fetchBalance(String apiKey) async {
    final url = 'https://api.deepseek.com/user/balance';

    final Dio _dio = Dio();

    try {
      // 设置请求头，通常使用 Bearer Token 形式
      final response = await _dio.get(
        url,
        options: dio.Options(
          headers: {
            'Authorization': 'Bearer $apiKey', // 根据实际 API 要求调整
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // 解析 balance_infos 数组
        final balanceInfos = data['balance_infos'] as List;
        final markdownLines = <String>[];

        for (final info in balanceInfos) {
          final currency = info['currency'] as String;
          final totalBalance = info['total_balance'] as String;
          final grantedBalance = info['granted_balance'] as String;
          final toppedUpBalance = info['topped_up_balance'] as String;

          markdownLines.add('### 🪙 $currency');
          markdownLines.add('- **总可用余额**: `$totalBalance`');
          markdownLines.add('- **赠金余额**: `$grantedBalance`');
          markdownLines.add('- **充值余额**: `$toppedUpBalance`');
          markdownLines.add('');
        }

        // 可选：添加是否可用状态
        final isAvailable = data['is_available'] as bool;
        markdownLines.add('---');
        markdownLines.add('> 💡 账户当前是否可用: ${isAvailable ? "✅ 是" : "❌ 否"}');

        return markdownLines.join('\n');
      } else {
        return '❌ 请求失败，状态码: ${response.statusCode}';
      }
    } on DioException catch (e) {
      return '❌ 网络错误: ${e.message}';
    } catch (e) {
      return '❌ 未知错误: $e';
    }
  }
}
