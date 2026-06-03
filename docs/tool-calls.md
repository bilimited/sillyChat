# Agent 与工具调用 (Tool Call)

SillyChat 支持 OpenAI 兼容的 Tool Call 功能，允许 AI 模型在对话中调用外部工具（如获取天气、计算、搜索等），实现 Agent 式交互。

## 概述

Tool Call 允许 AI 模型在生成回复时"调用"预先注册的外部函数。模型会返回函数名和参数，由应用执行工具逻辑，再将结果返回给模型。模型可以基于工具结果继续推理或生成最终文本回复。

**典型流程**：

```
用户消息 → 模型推理 → 模型发起工具调用
                            ↓
                      应用执行工具
                            ↓
         模型接收结果 → 继续推理 → 文本回复（或再次调用工具）
```

## 支持的提供商

| 提供商 | Tool Call 支持 | 备注 |
|--------|:---:|------|
| OpenAI | ✅ | 完全支持 |
| DeepSeek | ✅ | 继承自 OpenAI handler |
| Kimi / Moonshot | ✅ | 继承自 OpenAI handler |
| SiliconFlow | ✅ | 继承自 OpenAI handler |
| Google / Gemini | ❌ | 当前仅返回文本（Google 的原生 function calling 格式不同，尚未适配） |
| 自定义 OpenAI 兼容 | ✅ | 继承自 OpenAI handler |

## 架构

### 关键文件

| 文件 | 职责 |
|------|------|
| `lib/chat-app/utils/entitys/tool_call.dart` | 数据模型：`ToolDefinition`、`ToolCall`、`FunctionDefinition`、`LLMResponseChunk` |
| `lib/chat-app/utils/tool_registry.dart` | 全局单例工具注册表，管理工具的注册/注销/执行 |
| `lib/chat-app/utils/service_handlers/OpenAIServiceHandler.dart` | 流式/非流式 Tool Call 的 SSE 解析和请求体构建 |
| `lib/chat-app/providers/chat_session_controller.dart` | Tool Call 执行循环（`_getResponse`）和工具执行（`_executeToolCall`） |

### 数据模型

#### ToolDefinition — 发送给 API 的工具描述

```json
{
  "type": "function",
  "function": {
    "name": "get_weather",
    "description": "获取指定城市的天气信息",
    "parameters": {
      "type": "object",
      "properties": {
        "city": {
          "type": "string",
          "description": "城市名称"
        }
      },
      "required": ["city"]
    }
  }
}
```

#### ToolCall — 模型返回的工具调用

```dart
class ToolCall {
  final String id;           // 工具调用唯一 ID
  final String type;         // "function"
  final String functionName; // 函数名
  final String arguments;    // JSON 字符串参数

  /// 解析 arguments 为 Map
  Map<String, dynamic> get parsedArguments;
}
```

#### LLMResponseChunk — 流式响应的统一块类型

替代原来的 `Stream<String>`，每个 chunk 可以是：

| 类型 | 判定方式 | 说明 |
|------|----------|------|
| 文本增量 | `chunk.isText` | 普通文本或思维链文本内容 |
| 工具调用 | `chunk.isToolCall` | 一个完整的工具调用（流式累积完成后） |
| 思考开始 | `chunk.isThinkingStart` | 思维链开始标记 |
| 思考结束 | `chunk.isThinkingEnd` | 思维链结束标记 |

消费者应将 `isThinkingStart` → `<think>`、`isThinkingEnd` → `</think>` 写回文本流，以保持与消息气泡 `<think></think>` 解析逻辑的兼容。

## ToolRegistry — 工具注册表

全局单例 `ToolRegistry.instance`，管理所有已注册的工具。

### 注册工具

```dart
import 'package:flutter_example/chat-app/utils/tool_registry.dart';

ToolRegistry.instance.register(
  name: 'get_weather',
  description: '获取指定城市的天气信息',
  parameters: {
    'type': 'object',
    'properties': {
      'city': {
        'type': 'string',
        'description': '城市名称',
      },
    },
    'required': ['city'],
  },
  executor: (args) async {
    final city = args['city'] as String;
    // 执行实际的天气查询逻辑...
    return '$city 今天晴，气温 25°C';
  },
);
```

### API

| 方法 | 说明 |
|------|------|
| `register(...)` | 注册一个工具（名称、描述、参数 JSON Schema、执行器） |
| `unregister(name)` | 注销指定工具 |
| `getExecutor(name)` | 获取指定工具的执行器 |
| `definitions` | 获取所有已注册工具的 `List<ToolDefinition>`（发送给 API） |
| `hasTools` | 是否有已注册的工具 |
| `clear()` | 清空所有注册的工具 |

### 注册位置

工具应在应用启动时注册。建议在 `SillyChatApp` 的初始化流程或专门的初始化模块中注册内置工具：

```dart
// 例如在 init_app.dart 或工具模块中
void registerBuiltInTools() {
  ToolRegistry.instance.register(
    name: 'calculate',
    description: '执行数学计算',
    parameters: {
      'type': 'object',
      'properties': {
        'expression': {
          'type': 'string',
          'description': '要计算的数学表达式',
        },
      },
      'required': ['expression'],
    },
    executor: (args) async {
      // 使用安全的表达式求值
      return '计算结果：42';
    },
  );
}
```

## Tool Call 执行循环

`ChatSessionController._getResponse()` 中实现了完整的工具调用循环：

```
┌────────────────────────────────────────────────────┐
│  1. Promptbuilder.buildMessages()                   │
│     ↓                                              │
│  2. while (iterations < 10) {                      │
│       options = copyWith(                           │
│         messages: currentMessages,                  │
│         tools: ToolRegistry.definitions  ← 自动注入 │
│       )                                            │
│       ↓                                            │
│       await stream response                         │
│         ├─ isThinkingStart → fullResponse += 思考标签 │
│         ├─ isText → fullResponse += 文本增量         │
│         ├─ isThinkingEnd → fullResponse += 思考标签   │
│         └─ isToolCall → 收集到 collectedToolCalls    │
│       ↓                                            │
│       if (no tool_calls) → break                   │
│       ↓                                            │
│       // 将工具调用消息追加到 API 消息列表（不持久化）  │
│       messages += assistant(toolCalls: [...])       │
│       ↓                                            │
│       for each tool call:                           │
│         result = ToolRegistry.execute(args)         │
│         messages += tool_result(result)             │
│     }                                              │
│  3. yield fullResponse → _handleAIResult()          │
└────────────────────────────────────────────────────┘
```

### 关键行为

| 特性 | 说明 |
|------|------|
| **自动注入** | 当 `ToolRegistry.instance.hasTools` 且请求未显式设置 `tools` 时，自动将注册的工具定义注入请求 |
| **最大迭代** | 最多 10 轮工具调用循环，防止无限循环 |
| **消息不持久化** | 工具调用和工具结果消息仅添加到 API 请求的瞬态消息列表中，**不会**保存到 `.chat` 文件 |
| **错误容错** | 未找到工具或执行异常时，返回错误字符串作为工具结果，让模型感知错误 |
| **跨迭代上下文** | 所有轮次共享同一个消息列表，模型可以看到之前所有工具调用和结果 |
| **状态显示** | 工具执行时，`GenerateState` 显示"正在执行: toolName..." |

### 空响应保护

如果所有工具调用完成后模型未返回文本回复（例如纯工具调用场景），则 yield 默认文本：
> （工具调用已完成，但模型未返回文本回复）

## Thinking / 思维链处理

在 Tool Call 架构中，思维链（reasoning）内容通过 `LLMResponseChunk` 的专用字段传输：

| ServiceHandler 发出 | 消费者应写入 |
|---------------------|-------------|
| `LLMResponseChunk(isThinkingStart: true)` | `<think>` |
| `LLMResponseChunk.thinking(content)` | 思维链文本（`isText=true`，直接写入） |
| `LLMResponseChunk(isThinkingEnd: true)` | `</think>` |

所有消费 `LLMResponseChunk` 流的位置都必须正确处理这三个状态，否则思维链内容将不被 `<think></think>` 包裹，导致消息气泡无法识别和折叠思维链区域。

当前已处理的消费端：
- `ChatSessionController._getResponse()` — 主要生成循环
- `ChatSessionController._getResponseInBackground()` — 后台生成（标题、摘要）
- `ChatSessionController.simulateUserMessage()` — 模拟用户消息
- `MessageOptimizationPage._performOptimization()` — 消息优化

## 为现有代码适配 Tool Call

如果要在新的流式消费位置正确处理 LLMResponseChunk，请遵循以下模式：

```dart
await for (final chunk in handler.requestTokenStream(options)) {
  if (chunk.isThinkingStart) {
    // 写入 <think> 标签
    buffer.write('<think>');
  } else if (chunk.isThinkingEnd) {
    // 写入 </think> 标签
    buffer.write('</think>');
  } else if (chunk.isText) {
    // 文本内容（包括思维链内容）
    buffer.write(chunk.content);
  } else if (chunk.isToolCall) {
    // 工具调用 — 根据需要处理或忽略
  }
}
```

> **注意**：`LLMResponseChunk.thinking(content)` 创建的 chunk 中 `isThinkingStart=false`，`isThinkingEnd=false`，但 `isText=true`。思维链内容通过 `isText` 分支处理，`<think>`/`</think>` 标签由 `isThinkingStart`/`isThinkingEnd` 分支添加。

## 限制与注意事项

1. **工具调用消息不持久化** — 工具调用和结果不会写入 `.chat` 文件。如果需要审计追踪，需要通过 `LogController` 日志查看
2. **仅 OpenAI 兼容 API** — Google Gemini 的原生 function calling 格式不同，当前不支持
3. **单线程执行** — 工具按顺序逐个执行，不并行
4. **执行器必须异步** — `ToolExecutor` 签名为 `Future<String> Function(Map<String, dynamic> args)`，所有执行器都是异步的
5. **参数上限** — API 的 tools 数组大小受模型上下文窗口限制，注册过多工具会占用上下文
6. **工具调用不计入聊天统计** — Token 计数暂不包含工具调用和结果的消耗
