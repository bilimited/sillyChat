import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/widgets/expandable_text_field.dart';
import 'package:flutter_example/main.dart';

// KeyValueEditor 组件
class KeyValueEditor extends StatefulWidget {
  // 初始的 Map 数据
  final Map<String, String> initialMap;
  // 当 Map 数据发生变化时的回调
  final ValueChanged<Map<String, String>> onChanged;

  const KeyValueEditor({
    super.key,
    required this.initialMap,
    required this.onChanged,
  });

  @override
  State<KeyValueEditor> createState() => _KeyValueEditorState();
}

class _KeyValueEditorState extends State<KeyValueEditor> {
  // 存储键值对数据
  late Map<String, String> _data;
  // 为每个值的 TextFormField 管理一个控制器
  final Map<String, TextEditingController> _valueControllers = {};

  @override
  void initState() {
    super.initState();
    // 初始化数据，深拷贝一份以避免直接修改外部传入的 map
    _data = Map<String, String>.from(widget.initialMap);
    // 为每个值创建一个 TextEditingController
    _data.forEach((key, value) {
      _createValueController(key, value);
    });
  }

  // 为指定的键创建并监听一个 TextEditingController
  void _createValueController(String key, String value) {
    final controller = TextEditingController(text: value);
    _valueControllers[key] = controller;
    controller.addListener(() {
      // 当 TextFormField 的内容变化时，更新 _data 中的值并通知父组件
      if (_data[key] != controller.text) {
        _data[key] = controller.text;
        widget.onChanged(Map.from(_data));
      }
    });
  }

  // 在组件销毁时，释放所有控制器以避免内存泄漏
  @override
  void dispose() {
    for (var controller in _valueControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // 显示用于添加新键或编辑现有键的对话框
  void _showKeyDialog({String? oldKey}) {
    final keyController = TextEditingController(text: oldKey ?? '');
    final isEditing = oldKey != null;
    final title = isEditing ? '编辑变量' : '创建新变量';
    final confirmButtonText = isEditing ? '修改' : '创建';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: keyController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '变量名',
              hintText: '请输入一个变量名',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                final newKey = keyController.text.trim();
                if (newKey.isEmpty) return;

                // 校验键是否重复
                if ((!isEditing && _data.containsKey(newKey)) ||
                    (isEditing &&
                        newKey != oldKey &&
                        _data.containsKey(newKey))) {
                  SillyChatApp.snackbarErr(context, '错误：变量 "$newKey" 已存在！');

                  return;
                }

                // 根据是编辑还是创建，执行不同操作
                if (isEditing) {
                  _updateKey(oldKey, newKey);
                } else {
                  _addEntry(newKey);
                }
                Navigator.pop(context);
              },
              child: Text(confirmButtonText),
            ),
          ],
        );
      },
    );
  }

  // 添加一个新的键值对
  void _addEntry(String key) {
    setState(() {
      _data[key] = '';
      _createValueController(key, '');
    });
    widget.onChanged(Map.from(_data));
  }

  // 更新一个已存在的键
  void _updateKey(String oldKey, String newKey) {
    if (oldKey == newKey) return; // 如果键没有改变，则不执行任何操作

    setState(() {
      final value = _data[oldKey]!;
      _data.remove(oldKey);
      _data[newKey] = value;

      // 销毁旧的控制器，并为新键创建新的控制器
      _valueControllers[oldKey]?.dispose();
      _valueControllers.remove(oldKey);
      _createValueController(newKey, value);
    });
    widget.onChanged(Map.from(_data));
  }

  // 删除一个键值对
  void _removeEntry(String key) {
    setState(() {
      _data.remove(key);
      _valueControllers[key]?.dispose();
      _valueControllers.remove(key);
    });
    widget.onChanged(Map.from(_data));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keys = _data.keys.toList();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: keys.length,
            itemBuilder: (context, index) {
              final key = keys[index];
              final valueController = _valueControllers[key];

              return valueController == null
                  ? Text('ERROR:Value Controller不存在!')
                  : Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            // 用于显示和编辑键的按钮
                            TextButton.icon(
                              icon: Icon(Icons.vpn_key_outlined,
                                  color: colorScheme.secondary),
                              label: Text(
                                key,
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurface),
                              ),
                              onPressed: () => _showKeyDialog(oldKey: key),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // 用于编辑值的 TextFormField
                            Expanded(
                              child: ExpandableTextField(
                                minLines: 1,
                                controller: valueController,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 删除按钮
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  color: colorScheme.error),
                              onPressed: () => _removeEntry(key),
                            ),
                          ],
                        ),
                      ),
                    );
            },
          ),
        ),
        // 添加新键值对的按钮
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('添加变量'),
            onPressed: () => _showKeyDialog(),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ),
      ],
    );
  }
}

// // ------ 如何使用 KeyValueEditor 组件的示例 ------

// void main() {
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Key-Value Editor Demo',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//         useMaterial3: true,
//       ),
//       home: const EditorScreen(),
//     );
//   }
// }

// class EditorScreen extends StatefulWidget {
//   const EditorScreen({super.key});

//   @override
//   State<EditorScreen> createState() => _EditorScreenState();
// }

// class _EditorScreenState extends State<EditorScreen> {
//   // 在父组件中维护最终的 Map 状态
//   Map<String, String> _myMap = {
//     'api_key': 'abc-123-xyz',
//     'username': 'flutter_dev',
//     'endpoint': 'https://api.example.com/v1',
//   };

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Map<String, String> 编辑器'),
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: KeyValueEditor(
//           initialMap: _myMap,
//           onChanged: (newMap) {
//             // 当编辑器中的数据变化时，更新父组件的状态
//             setState(() {
//               _myMap = newMap;
//             });
//             // 你可以在这里看到实时更新的数据
//             debugPrint('Updated Map: $newMap');
//           },
//         ),
//       ),
//     );
//   }
// }
