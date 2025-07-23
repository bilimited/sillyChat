// log_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/log_detail_page.dart';
import 'package:flutter_example/chat-app/providers/log_controller.dart';
import 'package:get/get.dart';

class LogPage extends StatelessWidget {
  const LogPage({Key? key}) : super(key: key);

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.blueGrey[700]!;
      case LogLevel.warning:
        return Colors.orange[700]!;
      case LogLevel.error:
        return Colors.red[700]!;
    }
  }

  String _getLogLevelText(LogLevel level) {
    return level.toString().split('.').last.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '应用日志',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5, // 稍微有点阴影
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all, color: Colors.grey),
            tooltip: '清空日志',
            onPressed: () {
              LogController.to.clearLogs();
            },
          ),
          Obx(() => IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none, color: Colors.grey),
                if (LogController.to.unread > 0)
                  Positioned(
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 12,
                        minHeight: 12,
                      ),
                      child: Text(
                        '${LogController.to.unread}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: '未读日志',
            onPressed: () {
              // 点击未读图标时清除未读计数
              LogController.to.clearUnread();
            },
          )),
        ],
      ),
      body: Obx(() {
        final logs = LogController.to.logs;
        if (logs.isEmpty) {
          return Center(
            child: Text(
              '暂无日志记录',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          );
        }
        return ListView.separated(
          itemCount: logs.length,
          separatorBuilder: (context, index) => Divider(
            height: 1,
            color: Colors.grey[200],
            indent: 16,
            endIndent: 16,
          ), // 分隔线
          itemBuilder: (context, index) {
            final log = logs[index];
            final Color logColor = _getLogColor(log.level);

            // 如果有标题，则导航到详情页
            if (log.title != null && log.title!.isNotEmpty) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 0.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Get.to(() => LogDetailPage(logEntry: log));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.title!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: logColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_getLogLevelText(log.level)} - ${log.timestamp.toString().substring(0, 19)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else {
              // 没有标题，直接显示日志内容
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.message,
                      style: TextStyle(
                        color: logColor,
                        fontSize: 14,
                      ),
                      maxLines: 2, // 限制行数，避免过长
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_getLogLevelText(log.level)} - ${log.timestamp.toString().substring(0, 19)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }
          },
        );
      }),
    );
  }
}