import 'package:dio/dio.dart' show Dio, Options, DioException;
import 'package:flutter_example/chat-app/utils/service_handlers/OpenAIServiceHandler.dart';

class Kimiservicehandler extends Openaiservicehandler {
  const Kimiservicehandler()
      : super(
            baseUrl: 'https://api.moonshot.cn/v1',
            name: 'kimi',
            defaultModelList: const []);

  @override
  bool get canFetchBalance => true;

  @override
  Future<String> fetchBalance(String apiKey) async {
    final url = 'https://api.moonshot.cn/v1/users/me/balance';
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
          return '❌ 接口返回失败: ${data['scode'] ?? '未知错误'}';
        }

        final balanceData = data['data'] as Map<String, dynamic>?;

        if (balanceData == null) {
          return '❌ 数据解析失败: 未找到 data 字段';
        }

        // 提取余额数据
        final availableBalance = balanceData['available_balance'] as num? ?? 0;
        final voucherBalance = balanceData['voucher_balance'] as num? ?? 0;
        final cashBalance = balanceData['cash_balance'] as num? ?? 0;

        // 构建 Markdown
        final markdown = '''
### 🌙 Kimi (Moonshot AI) 账户余额


- **总可用余额**: `$availableBalance`
- **赠券余额**: `$voucherBalance`
- **现金余额**: `$cashBalance`

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
