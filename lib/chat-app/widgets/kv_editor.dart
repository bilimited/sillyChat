import 'package:flutter/material.dart';

// 定义一个回调函数类型，用于在Map更新时通知父组件
typedef OnUpdateMap = void Function(Map<String, String> map);

class KVEditor extends StatefulWidget {
  // 初始的Map数据
  final Map<String, String> initialMap;
  // Map更新时的回调函数
  final OnUpdateMap onUpdate;

  const KVEditor({
    super.key,
    required this.initialMap,
    required this.onUpdate,
  });

  @override
  State<KVEditor> createState() => _KVEditorState();
}

class _KVEditorState extends State<KVEditor> {
  // 使用List来存储键值对，方便增删和排序
  late List<MapEntry<String, String>> _entries;
  // 用于追踪每个TextField的控制器
  final Map<int, TextEditingController> _keyControllers = {};
  final Map<int, TextEditingController> _valueControllers = {};
  // 用于生成唯一的key，确保小部件在重建时状态正确
  int _nextId = 0;

  @override
  void initState() {
    super.initState();
    // 初始化时，将传入的Map转换为List<MapEntry>
    _entries = widget.initialMap.entries.toList();
    // 为已有的条目创建文本控制器
    for (int i = 0; i < _entries.length; i++) {
      _addControllersForIndex(i);
    }
  }

  // 为指定索引的条目创建并关联TextEditingController
  void _addControllersForIndex(int index) {
    final entry = _entries[index];
    _keyControllers[index] = TextEditingController(text: entry.key);
    _valueControllers[index] = TextEditingController(text: entry.value);

    // 监听文本变化，实时更新内部状态并触发回调
    _keyControllers[index]!.addListener(() {
      _updateEntry(index);
    });
    _valueControllers[index]!.addListener(() {
      _updateEntry(index);
    });
  }

  // 更新指定索引的键值对
  void _updateEntry(int index) {
    final newKey = _keyControllers[index]!.text;
    final newValue = _valueControllers[index]!.text;
    if (index < _entries.length) {
      setState(() {
        _entries[index] = MapEntry(newKey, newValue);
      });
      _notifyParent();
    }
  }

  // 通知父组件Map已更新
  void _notifyParent() {
    // 将内部的List<MapEntry>转换回Map<String, String>
    final updatedMap = {for (var entry in _entries) entry.key: entry.value};
    widget.onUpdate(updatedMap);
  }

  // 添加一个新的空键值对
  void _addNewEntry() {
    setState(() {
      const newEntry = MapEntry('', '');
      _entries.add(newEntry);
      _addControllersForIndex(_entries.length - 1);
    });
    _notifyParent();
  }

  // 删除一个键值对
  void _removeEntry(int index) {
    final removedEntry = _entries.removeAt(index);
    // 清理相关的控制器
    _keyControllers.remove(index)?.dispose();
    _valueControllers.remove(index)?.dispose();

    // 重新构建控制器映射以匹配新的索引
    final newKeyControllers = <int, TextEditingController>{};
    final newValueControllers = <int, TextEditingController>{};
    for (int i = 0; i < _entries.length; i++) {
        if(i >= index) {
            newKeyControllers[i] = _keyControllers[i+1]!;
            newValueControllers[i] = _valueControllers[i+1]!;
        } else {
            newKeyControllers[i] = _keyControllers[i]!;
            newValueControllers[i] = _valueControllers[i]!;
        }
    }

    setState(() {
        _keyControllers.clear();
        _valueControllers.clear();
        _keyControllers.addAll(newKeyControllers);
        _valueControllers.addAll(newValueControllers);
    });


    _notifyParent();

    // 显示一个SnackBar，提供撤销操作
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('键值对已删除'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () {
            setState(() {
              _entries.insert(index, removedEntry);
              _addControllersForIndex(index);
               // 插入后也需要更新控制器映射
              final tempKeyControllers = Map.of(_keyControllers);
              final tempValueControllers = Map.of(_valueControllers);

              for(int i = index + 1; i <= _entries.length -1; i++){
                _keyControllers[i] = tempKeyControllers[i-1]!;
                _valueControllers[i] = tempValueControllers[i-1]!;
              }

            });
            _notifyParent();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    // 销毁所有控制器以释放资源
    _keyControllers.values.forEach((controller) => controller.dispose());
    _valueControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 头部标题
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Text('键', style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text('值', style: Theme.of(context).textTheme.titleSmall),
              ),
              const SizedBox(width: 48), // 为删除图标留出空间
            ],
          ),
        ),
        const Divider(height: 1),
        // 键值对列表
        Expanded(
          child: ListView.builder(
            itemCount: _entries.length,
            itemBuilder: (context, index) {
              final entryId = _nextId++; // 为Dismissible生成唯一key
              return Dismissible(
                key: ValueKey('entry_${entryId}_${_entries[index].key}'),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  _removeEntry(index);
                },
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.delete_sweep, color: Colors.white),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    children: [
                      // Key 输入框
                      Expanded(
                        child: TextField(
                          controller: _keyControllers[index],
                          decoration: const InputDecoration(
                            hintText: 'Key',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Value 输入框
                      Expanded(
                        child: TextField(
                          controller: _valueControllers[index],
                          decoration: const InputDecoration(
                            hintText: 'Value',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        // 添加按钮
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextButton.icon(
            onPressed: _addNewEntry,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('添加一项'),
          ),
        ),
      ],
    );
  }
}