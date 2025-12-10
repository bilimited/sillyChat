import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
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

  static void handleExpection(DioException e, Function(dynamic)? handleDetail) {
    String message = "";

    if (e.response == null) {
      message = "服务器没有返回任何结果!";
    } else {
      int? code = e.response!.statusCode;
      String? detail = handleDetail != null
          ? handleDetail(e.response!.data).toString()
          : null;
      message = """错误码：${code ?? "未知"} - ${ERR_CODES[code.toString()] ?? "未知"}
详细信息：${detail ?? "无"}
""";
      try {
        LogController.log(json.encode(e.response!.data), LogLevel.error,
            title: "请求错误", type: LogType.json);
      } catch (e) {
        // 放弃了...
      }
    }

    Get.snackbar("请求错误", message, colorText: Colors.red);
    LogController.log(message, LogLevel.error);
  }
}
