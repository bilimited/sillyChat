import 'package:dio/dio.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';
import 'package:flutter_example/chat-app/utils/service_handlers/OpenAIServiceHandler.dart';

class Siliconflowservicehandler extends Openaiservicehandler {
  const Siliconflowservicehandler()
      : super(
            baseUrl: 'https://api.siliconflow.cn/v1',
            name: "SiliconFlow",
            defaultModelList: const [

    ]
  );

  @override
  parseMessage(LLMMessage message) async {
    if (message.fileDirs.isNotEmpty) {
      // 先单独计算所有 image_url（压缩并 base64 编码），然后再构建返回内容
      final List<dynamic> imageContents = [];
      for (final path in message.fileDirs) {
        imageContents.add({
          "type": "image_url",
          "image_url": {"url": await parseImage(path)}
        });
      }

      return {
        "role": message.role,
        "content": [
          {
            "type": "text",
            "text": message.content,
          },
          ...imageContents,
        ],
      };
    }
    return {
      "role": message.role,
      "content": message.content,
    };
  }

  @override
  bool get canFetchBalance => true;

  @override
  Future<String> fetchBalance(String apiKey) async {
    final url = 'https://api.siliconflow.cn/v1/user/info';
    final dio = Dio();

    try {
      final response = await dio.get(
        url,
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey', // 使用 Bearer Token 认证
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;

        // 检查响应状态
        final status = data['status'] as bool?;
        if (status != true) {
          return '❌ 接口返回失败: ${data['code'] ?? '未知错误'} - ${data['message'] ?? '无消息'}';
        }

        final userData = data['data'] as Map<String, dynamic>?;

        if (userData == null) {
          return '❌ 数据解析失败: 未找到 data 字段';
        }

        // 提取余额数据
        final balance = userData['balance'] as String? ?? "0.00";
        final chargeBalance = userData['chargeBalance'] as String? ?? "0.00";
        final totalBalance = userData['totalBalance'] as String? ?? "0.00";

        // 构建 Markdown
        final markdown = '''
### 🤖 硅基流动 (SiliconFlow) 账户余额


- **当前余额**: `$balance`
- **充值余额**: `$chargeBalance`
- **总余额**: `$totalBalance`

---
✅ 状态: 成功
''';

        return markdown;
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
