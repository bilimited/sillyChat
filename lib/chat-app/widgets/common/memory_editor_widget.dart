import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/memory_model.dart';

/// 默认记忆编辑器 — 一个大文本编辑框，直接编辑短期/默认记忆。
///
/// [memory] 和 [onChanged] 由父组件管理状态。
/// 每次文本变化时会通过 [onChanged] 将更新后的 MemoryModel 回传。
class MemoryEditorWidget extends StatefulWidget {
  final MemoryModel memory;
  final ValueChanged<MemoryModel> onChanged;

  const MemoryEditorWidget({
    super.key,
    required this.memory,
    required this.onChanged,
  });

  @override
  State<MemoryEditorWidget> createState() => _MemoryEditorWidgetState();
}

class _MemoryEditorWidgetState extends State<MemoryEditorWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.memory.defaultMemory);
  }

  @override
  void didUpdateWidget(covariant MemoryEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 若外部传入新的 memory 对象（如数据刷新），同步文本
    if (oldWidget.memory.defaultMemory != widget.memory.defaultMemory &&
        _controller.text != widget.memory.defaultMemory) {
      _controller.text = widget.memory.defaultMemory;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    final updated = widget.memory.copyWith(defaultMemory: text);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _controller,
        onChanged: _onTextChanged,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        decoration: const InputDecoration(
          hintText: '在此输入默认记忆…\n\n'
              '默认记忆是一段会自动注入到 prompt 中的长文本，'
              '适合记录当前会话的关键上下文、角色状态或近期事件。',
          border: OutlineInputBorder(),
          contentPadding: EdgeInsets.all(12),
        ),
      ),
    );
  }
}
