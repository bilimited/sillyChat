// log_detail_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:get/get.dart';
import 'package:flutter_json_view/flutter_json_view.dart'; // 引入JSON视图库

class LogDetailPage extends StatelessWidget {
  final LogEntry logEntry;

  const LogDetailPage({Key? key, required this.logEntry}) : super(key: key);

  // 辅助函数，根据日志级别获取颜色
  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.blueGrey;
      case LogLevel.warning:
        return Colors.orange[700]!;
      case LogLevel.error:
        return Colors.red[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color logColor = _getLogColor(logEntry.level);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(logEntry.title ?? '日志详情', style: TextStyle(color: logColor)),
        backgroundColor: Colors.grey[50], // 轻微背景色
        elevation: 0, // 无阴影
        iconTheme: IconThemeData(color: logColor), // 返回按钮颜色
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日志级别和时间戳
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: logColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    logEntry.level.toString().split('.').last.toUpperCase(),
                    style: TextStyle(
                      color: logColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  logEntry.timestamp.toString().substring(0, 19),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // 日志内容
            Text(
              '日志内容:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            // 根据日志类型显示内容
            _buildLogContent(logEntry,context),
          ],
        ),
      ),
    );
  }

  Widget _buildLogContent(LogEntry logEntry,BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (logEntry.type == LogType.json) {
      try {
        // 尝试解析JSON字符串
        final jsonDecoded = json.decode(logEntry.message);
        return JsonView.map(
          jsonDecoded,
          theme: JsonViewTheme(
            // 从colors获取主题
            backgroundColor: colors.surface,
            keyStyle: TextStyle(color: colors.primary),
            stringStyle: TextStyle(color: colors.onSurface),
            intStyle: TextStyle(color: colors.tertiary),
            boolStyle: TextStyle(color: colors.error),
            closeIcon: Icon(Icons.arrow_drop_up,color: colors.primary,size: 18,),
            openIcon: Icon(Icons.arrow_drop_down,color: colors.primary,size: 18,),
          ),
        );
      } catch (e) {
        // 如果解析失败，显示为普通文本
        return Text(
          logEntry.message,
          style: TextStyle(fontSize: 16, color: Colors.black87),
        );
      }
    } else {
      return Text(
        logEntry.message,
        style: TextStyle(fontSize: 16, color: Colors.black87),
      );
    }
  }
}