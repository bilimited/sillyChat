import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/log_controller.dart';

class LogPage extends StatelessWidget {
  const LogPage({Key? key}) : super(key: key);

  Color _getLogColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.black87;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
    }
  }

  String _getLogLevelText(LogLevel level) {
    return level.toString().split('.').last.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              LogController.to.clearLogs();
            },
          ),
        ],
      ),
      body: Obx(() {
        final logs = LogController.to.logs;
        return ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return ListTile(
              title: Text(
                log.message,
                style: TextStyle(
                  color: _getLogColor(log.level),
                ),
              ),
              subtitle: Text(
                '${_getLogLevelText(log.level)} - ${log.timestamp.toString().substring(0, 19)}',
                style: TextStyle(
                  fontSize: 12,
                  color: _getLogColor(log.level).withOpacity(0.7),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
