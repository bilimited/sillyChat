import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/widgets/expandable_text_field.dart';
import 'package:intl/intl.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';

// 记忆编辑器组件
class MemoryEditor extends StatefulWidget {
  final List<CharacterMemory> memories;

  const MemoryEditor({Key? key, required this.memories}) : super(key: key);

  @override
  MemoryEditorState createState() => MemoryEditorState();
}

class MemoryEditorState extends State<MemoryEditor> {
  late List<TextEditingController> _controllers;
  late Map<String, List<CharacterMemory>> _groupedMemories;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _groupMemories();
  }

  // 当外部传入的 memories 列表发生变化时，重新初始化控制器
  @override
  void didUpdateWidget(covariant MemoryEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.memories != oldWidget.memories) {
      _disposeControllers();
      _initializeControllers();
      _groupMemories();
    }
  }

  void _initializeControllers() {
    _controllers = widget.memories
        .map((memory) => TextEditingController(text: memory.content))
        .toList();

    for (int i = 0; i < _controllers.length; i++) {
      final index = i;
      _controllers[index].addListener(() {
        if (index < widget.memories.length) {
          widget.memories[index].content = _controllers[index].text;
        }
      });
    }
  }

  void _disposeControllers() {
    for (var controller in _controllers) {
      controller.dispose();
    }
  }

  // 根据时间对记忆进行分组
  void _groupMemories() {
    _groupedMemories = {};
    final now = DateTime.now();

    // 先对记忆进行排序，确保显示顺序正确
    widget.memories.sort((a, b) => b.time.compareTo(a.time));

    for (var memory in widget.memories) {
      String groupKey;
      if (now.difference(memory.time).inDays <= 30) {
        // 一个月内的记忆，按天分组
        groupKey = DateFormat('yyyy-MM-dd').format(memory.time);
      } else {
        // 更早的记忆，按月分组
        groupKey = DateFormat('yyyy-MM').format(memory.time);
      }

      if (_groupedMemories[groupKey] == null) {
        _groupedMemories[groupKey] = [];
      }
      _groupedMemories[groupKey]!.add(memory);
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  // 添加一条新记忆
  void addMemory() {
    final newMemory = CharacterMemory(time: DateTime.now(), content: '');
    final newController = TextEditingController(text: '');

    newController.addListener(() {
      newMemory.content = newController.text;
    });

    setState(() {
      widget.memories.insert(0, newMemory);
      _controllers.insert(0, newController);
      _groupMemories();
    });
  }

  // 删除一条记忆
  void _deleteMemory(CharacterMemory memoryToDelete) {
    final index = widget.memories.indexOf(memoryToDelete);
    if (index != -1) {
      setState(() {
        // 先释放控制器，再从列表中移除
        _controllers[index].dispose();
        _controllers.removeAt(index);
        widget.memories.removeAt(index);
        _groupMemories();
      });
    }
  }

  // 日期选择器
  Future<void> _selectDate(BuildContext context, CharacterMemory memory) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: memory.time,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != memory.time) {
      setState(() {
        memory.time = picked;
        _groupMemories(); // 日期更改后重新分组和排序
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedKeys = _groupedMemories.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    // if (sortedKeys.isEmpty) {
    //   return Center(
    //     child: Text(
    //       '还没有任何记忆\n点击右下角按钮添加一条吧',
    //       textAlign: TextAlign.center,
    //       style: TextStyle(fontSize: 18, color: Colors.grey),
    //     ),
    //   );
    // }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          addMemory();
        },
        child: Icon(Icons.add),
        tooltip: '添加记忆',
      ),
      body: sortedKeys.isEmpty
          ? Center(
              child: Text(
                '记忆系统施工中\n敬请期待',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: sortedKeys.length,
              itemBuilder: (context, index) {
                final key = sortedKeys[index];
                final memoriesInGroup = _groupedMemories[key]!;
                final now = DateTime.now();

                String headerText;
                try {
                  final date = DateTime.parse(key);
                  if (now.difference(date).inDays <= 30) {
                    if (date.year == now.year &&
                        date.month == now.month &&
                        date.day == now.day) {
                      headerText = '今天';
                    } else if (date.year == now.year &&
                        date.month == now.month &&
                        date.day == now.day - 1) {
                      headerText = '昨天';
                    } else {
                      headerText =
                          DateFormat('M月d日 EEEE', 'zh_CN').format(date);
                    }
                  } else {
                    headerText = DateFormat('yyyy年M月', 'zh_CN').format(date);
                  }
                } catch (e) {
                  try {
                    final date = DateTime.parse('${key}-01');
                    headerText = DateFormat('yyyy年M月', 'zh_CN').format(date);
                  } catch (e) {
                    headerText = key;
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
                      child: Text(
                        headerText,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    ...memoriesInGroup.map((memory) {
                      final memoryIndex = widget.memories.indexOf(memory);
                      if (memoryIndex == -1) {
                        return const SizedBox.shrink(); // 如果记忆已被删除，则不显示
                      }
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 4.0),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  InkWell(
                                    onTap: () => _selectDate(context, memory),
                                    child: Row(
                                      children: [
                                        Icon(Icons.calendar_today, size: 16.0),
                                        SizedBox(width: 8.0),
                                        Text(
                                          DateFormat('yyyy-MM-dd HH:mm')
                                              .format(memory.time),
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline,
                                        color: Colors.grey[600]),
                                    onPressed: () => _deleteMemory(memory),
                                  ),
                                ],
                              ),
                              SizedBox(height: 8.0),
                              ExpandableTextField(
                                controller: _controllers[memoryIndex],
                                maxLines: 1,
                                minLines: 1,
                                decoration: InputDecoration(
                                  hintText: '输入记忆内容...',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
    );
  }
}
