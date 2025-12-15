import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/log_detail_page.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/utils/entitys/RequestOptions.dart';
import 'package:flutter_example/chat-app/utils/json_util.dart';
import 'package:get/get.dart';

class ErrorHandler {
  static const ERR_CODES = {
    "100": "继续 (Continue)",
    "101": "切换协议 (Switching Protocols)",
    "200": "成功 (OK)",
    "201": "已创建 (Created)",
    "202": "已接受 (Accepted)",
    "204": "无内容 (No Content)",
    "301": "永久移动 (Moved Permanently)",
    "302": "临时移动 (Found)",
    "304": "未修改 (Not Modified)",
    "400": "错误请求 (Bad Request)",
    "401": "未授权 (Unauthorized)",
    "403": "禁止 (Forbidden)",
    "404": "未找到 (Not Found)",
    "405": "方法禁用 (Method Not Allowed)",
    "408": "请求超时 (Request Timeout)",
    "409": "冲突 (Conflict)",
    "410": "已失效 (Gone)",
    "429": "请求过多 (Too Many Requests)",
    "500": "服务器内部错误 (Internal Server Error)",
    "501": "未实现 (Not Implemented)",
    "502": "错误网关 (Bad Gateway)",
    "503": "服务不可用 (Service Unavailable)",
    "504": "网关超时 (Gateway Timeout)"
  };

  static void handleDioExpection(
      DioException e, Function(dynamic)? handleDetail,
      {LLMRequestOptions? requestOptions}) {
    String message = "";
    String longMessage = "";
    LogEntry? entry;
    String? dataJson;

    if (e.response == null) {
      message = "服务器没有返回任何结果!";
    } else {
      int? code = e.response!.statusCode;
      String? detail = handleDetail != null
          ? handleDetail(e.response!.data).toString()
          : tryHandleLLMError(e.response!.data);
      message = """错误码：${code ?? "未知"} - ${ERR_CODES[code.toString()] ?? "未知"}
详细信息：${detail ?? "无"}
""";
      try {
        dataJson = JsonUtil.encode(e.response!.data);
      } catch (e) {
        // 放弃了...
      }

      longMessage = """
# 错误详情

**HOST**:${e.requestOptions.uri.host}

**状态码**:${e.response?.statusCode ?? '未知'}

**提取的信息**：${message}

---

### 原始Data字段
```
${dataJson ?? '无'}
```
""";
      if (requestOptions != null) {
        final option = requestOptions.copyWith(messages: []);
        longMessage += """

---

### 请求详情

**模型名称**：${requestOptions.api?.modelName ?? '未知'}

**消息数量**: ${requestOptions.messages.length}

**请求数据（消息内容已隐藏）**
```
${JsonUtil.formatMap(option.toJson())}
```

""";
      }

      entry = LogController.log(longMessage, LogLevel.error,
          title: "请求错误", type: LogType.text);
    }

    Get.dialog(
      AlertDialog(
        title: const Text("请求错误"),
        content: SingleChildScrollView(
          child: SelectableText(
            message,
            style: const TextStyle(color: Colors.red),
          ),
        ),
        actions: [
          if (entry != null)
            TextButton(
              onPressed: () {
                Get.to(() => LogDetailPage(logEntry: entry!));
              },
              child: const Text("打开日志"),
            ),
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("关闭"),
          ),
        ],
      ),
      barrierDismissible: true,
    );

    //LogController.log(message, LogLevel.error);
  }

  static String tryHandleLLMError(dynamic data) {
    try {
      if (data is Map) {
        // gemini style
        if (data["error"] != null) {
          return data["error"]?["message"];
        }
        if(data["message"] != null){
          return data["message"];
        }
      } else {
        return "无法获取错误信息，请关闭流式传输后重试..";
      }
    } catch (e) {}
    return "无法获取错误信息，请打开日志界面并将错误报告发给作者..";
  }
}
