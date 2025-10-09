import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/widgets/character/memory_editor.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  // 初始化中文日期格式
  initializeDateFormatting('zh_CN', null).then((_) => runApp(MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '记忆编辑器',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: MemoryScreen(),
    );
  }
}

class MemoryScreen extends StatefulWidget {
  @override
  _MemoryScreenState createState() => _MemoryScreenState();
}

class _MemoryScreenState extends State<MemoryScreen> {
  // GlobalKey 用于从外部访问 MemoryEditorState 的方法
  final GlobalKey<MemoryEditorState> _editorKey =
      GlobalKey<MemoryEditorState>();

  // 示例记忆数据
  final List<CharacterMemory> _memories = [
    CharacterMemory(time: DateTime.now(), content: '今天天气很好。'),
    CharacterMemory(
        time: DateTime.now().subtract(Duration(days: 1)),
        content: '昨天学习了 Flutter。'),
    CharacterMemory(
        time: DateTime.now().subtract(Duration(days: 2)),
        content: '前天和朋友一起去吃饭了。'),
    CharacterMemory(
        time: DateTime.now().subtract(Duration(days: 35)),
        content: '上个月去旅游了，很开心。'),
    CharacterMemory(
        time: DateTime.now().subtract(Duration(days: 40)),
        content: '上个月的项目顺利完成了。'),
    CharacterMemory(
        time: DateTime.now().subtract(Duration(days: 70)),
        content: '两个月前开始学习新的技能。'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('记忆编辑器'),
      ),
      body: MemoryEditor(
        key: _editorKey, // 将 key 传递给编辑器
        memories: _memories,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 通过 key 调用 MemoryEditorState 中的 addMemory 方法
          _editorKey.currentState?.addMemory();
        },
        child: Icon(Icons.add),
        tooltip: '添加记忆',
      ),
    );
  }
}
