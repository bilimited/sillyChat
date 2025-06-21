import 'package:get/get.dart';

enum LogLevel {
  info,
  warning,
  error,
}

class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime timestamp;

  LogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
  });
}

class LogController extends GetxController {
  static LogController get to => Get.find<LogController>();
  
  final RxList<LogEntry> _logs = <LogEntry>[].obs;
  final RxInt _unread = 0.obs;
  static const int _maxLogs = 30;

  List<LogEntry> get logs => _logs.toList();
  int get unread => _unread.value;
  
  void addLog(String message, LogLevel level) {
    _logs.insert(0, LogEntry(
      message: message,
      level: level,
      timestamp: DateTime.now(),
    ));
    
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }
    _unread.value ++;
  }

  void clearLogs() {
    _logs.clear();
  }

  void clearUnread(){
    _unread.value = 0;
  }

  List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  // 静态方法用于快速记录日志
  static void log(String message, [LogLevel level = LogLevel.info]) {
    LogController.to.addLog(message, level);
  }
}
