import 'package:flutter_example/chat-app/utils/entitys/tool_call.dart';

/// 工具执行器签名：接收已解析的 JSON 参数，返回结果字符串
typedef ToolExecutor = Future<String> Function(Map<String, dynamic> args);

/// 全局工具注册表（单例）
///
/// 使用方式：
/// ```dart
/// ToolRegistry.instance.register(
///   name: 'get_weather',
///   description: '获取指定城市的天气信息',
///   parameters: {
///     'type': 'object',
///     'properties': {
///       'city': {'type': 'string', 'description': '城市名称'},
///     },
///     'required': ['city'],
///   },
///   executor: (args) async {
///     final city = args['city'] as String;
///     return '${city}今天晴，气温 25°C';
///   },
/// );
/// ```
class ToolRegistry {
  static final ToolRegistry instance = ToolRegistry._();

  ToolRegistry._();

  final Map<String, _ToolEntry> _tools = {};

  /// 注册一个工具
  void register({
    required String name,
    required String description,
    required Map<String, dynamic> parameters,
    required ToolExecutor executor,
  }) {
    _tools[name] = _ToolEntry(
      definition: ToolDefinition(
        function: FunctionDefinition(
          name: name,
          description: description,
          parameters: parameters,
        ),
      ),
      executor: executor,
    );
  }

  /// 注销一个工具
  void unregister(String name) {
    _tools.remove(name);
  }

  /// 获取工具执行器
  ToolExecutor? getExecutor(String name) => _tools[name]?.executor;

  /// 获取所有已注册的工具定义（发送给 API）
  List<ToolDefinition> get definitions =>
      _tools.values.map((e) => e.definition).toList();

  /// 是否有已注册的工具
  bool get hasTools => _tools.isNotEmpty;

  /// 清空所有注册的工具
  void clear() => _tools.clear();
}

class _ToolEntry {
  final ToolDefinition definition;
  final ToolExecutor executor;

  _ToolEntry({required this.definition, required this.executor});
}
