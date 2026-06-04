import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/memory_model.dart';

/// 全屏记忆条目编辑页面。
///
/// 如果 [entry] 不为空则为编辑模式，否则为新建模式。
/// 调用 [MemoryModel.addEntry] / [MemoryModel.updateEntry] 静态方法
/// 来修改传入的 [MemoryModel]。
/// 返回 `true` 表示有更改，`false` 表示无更改。
class MemoryEntryEditPage extends StatefulWidget {
  /// 要编辑的条目。null 表示新建。
  final MemoryEntryModel? entry;

  /// 目标 MemoryModel，用于添加或更新条目。
  final MemoryModel memory;

  const MemoryEntryEditPage({
    super.key,
    this.entry,
    required this.memory,
  });

  @override
  State<MemoryEntryEditPage> createState() => _MemoryEntryEditPageState();
}

class _MemoryEntryEditPageState extends State<MemoryEntryEditPage> {
  late final TextEditingController _contentController;
  bool _isActive = true;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(
      text: widget.entry?.content ?? '',
    );
    _isActive = widget.entry?.isActive ?? true;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _save() {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    if (_isEditing) {
      final index = widget.memory.entries
          .indexWhere((e) => e.id == widget.entry!.id);
      if (index != -1) {
        widget.memory.entries[index] =
            widget.entry!.copyWith(content: content, isActive: _isActive);
      }
    } else {
      widget.memory.entries.add(MemoryEntryModel(
        id: DateTime.now().microsecondsSinceEpoch,
        content: content,
        isActive: _isActive,
      ));
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑记忆' : '新增记忆'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                autofocus: !_isEditing,
                decoration: InputDecoration(
                  hintText: '输入记忆内容...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
          ],
        ),
      ),
    );
  }
}
