import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '脚本编辑',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const ScriptEditorPage(),
    );
  }
}

class ScriptEditorPage extends StatefulWidget {
  const ScriptEditorPage({Key? key}) : super(key: key);

  @override
  State<ScriptEditorPage> createState() => _ScriptEditorPageState();
}

// 定义调用时机的枚举
enum TriggerTime {
  manual,
  onSend,
  onReceive,
}

class _ScriptEditorPageState extends State<ScriptEditorPage> {
  TriggerTime? _triggerTime = TriggerTime.manual;
  bool _isAsync = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('脚本编辑'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              '脚本内容',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const TextField(
              maxLines: 8, // 设置输入框的行数
              decoration: InputDecoration(
                hintText: '在此输入您的脚本...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '调用时机',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            // 使用 Column 垂直排列单选按钮. [14, 16]
            Column(
              children: <Widget>[
                // RadioListTile 是一个包含标题和单选按钮的列表项. [3]
                RadioListTile<TriggerTime>(
                  title: const Text('手动调用'),
                  value: TriggerTime.manual,
                  groupValue: _triggerTime,
                  onChanged: (TriggerTime? value) {
                    setState(() {
                      _triggerTime = value;
                    });
                  },
                ),
                RadioListTile<TriggerTime>(
                  title: const Text('发送消息时'),
                  value: TriggerTime.onSend,
                  groupValue: _triggerTime,
                  onChanged: (TriggerTime? value) {
                    setState(() {
                      _triggerTime = value;
                    });
                  },
                ),
                RadioListTile<TriggerTime>(
                  title: const Text('接受消息后'),
                  value: TriggerTime.onReceive,
                  groupValue: _triggerTime,
                  onChanged: (TriggerTime? value) {
                    setState(() {
                      _triggerTime = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 使用 Row 水平排列文本和开关. [14]
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  '异步执行',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                // Switch 是一个开/关切换按钮. [1, 2]
                Switch(
                  value: _isAsync,
                  onChanged: (bool value) {
                    setState(() {
                      _isAsync = value;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
