// log_controller.dart
import 'package:get/get.dart';

enum LogLevel {
  info,
  warning,
  error,
}

enum LogType {
  text,
  json // 假设未来可能需要展示JSON类型
}

class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime timestamp;
  final LogType type; // 新增：日志类型
  final String? title; // 新增：日志标题

  LogEntry(
      {required this.message,
      required this.level,
      required this.timestamp,
      this.type = LogType.text, // 默认为文本类型
      this.title // 标题可以为空
      });
}

class LogController extends GetxController {
  static LogController get to => Get.find<LogController>();

  final RxList<LogEntry> _logs = <LogEntry>[].obs;
  final RxInt _unread = 0.obs;
  static const int _maxLogs = 30;

  List<LogEntry> get logs => _logs.toList();
  int get unread => _unread.value;

  // 修改addLog方法，支持type和title
  LogEntry addLog(String message, LogLevel level,
      {LogType type = LogType.text, String? title}) {
    final entry = LogEntry(
      message: message,
      level: level,
      timestamp: DateTime.now(),
      type: type,
      title: title,
    );
    _logs.insert(0, entry);

    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }
    _unread.value++;

    return entry;
  }

  void clearLogs() {
    _logs.clear();
  }

  void clearUnread() {
    _unread.value = 0;
  }

  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  // 静态方法用于快速记录日志，支持title
  static LogEntry log(String message, LogLevel level,
      {LogType type = LogType.text, String? title}) {
    return LogController.to.addLog(message, level, title: title, type: type);
  }
}
