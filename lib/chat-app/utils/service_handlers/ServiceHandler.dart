import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/entitys/llmMessage.dart';

abstract class Servicehandler {
  final String baseUrl;
  final String name;
  final List<String> defaultModelList;

  const Servicehandler({
    required this.baseUrl,
    required this.name,
    required this.defaultModelList,
  });

  // TODO:模型自定义API选项

  // 获取模型列表
  Future<List<String>> fetchModelList();

  // 测试连通性
  Future<bool> testConnectivity();

  // 发送API请求，同时包含了结果处理
  Stream<String> request(
      Aihandler aihandler, LLMRequestOptions options, ApiModel api);

  // 将中间消息格式转换为服务商专用数据格式
  dynamic parseMessage(LLMMessage message);

  Map<String, dynamic> getRequestBody(LLMRequestOptions options);

  // 消息预处理（在合并消息之前执行）
  List<LLMMessage> processMessage(List<LLMMessage> messages) {
    return messages;
  }
}
