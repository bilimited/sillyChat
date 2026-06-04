import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/memory_model.dart';
import 'package:flutter_example/chat-app/pages/common/memory_entry_edit_page.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';

/// 可复用的记忆编辑器组件。
///
/// 展示记忆条目列表，支持添加/编辑/启用切换/删除。
/// [memory] 和 [onChanged] 由父组件管理状态。
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
  void _emit(MemoryModel updated) => widget.onChanged(updated);

  void _onAdd() async {
    final result = await customNavigate<bool>(
      MemoryEntryEditPage(memory: widget.memory),
      context: context,
    );
    if (result == true && context.mounted) {
      _emit(widget.memory); 
    }
  }

  void _onEdit(MemoryEntryModel entry) async {
    final result = await customNavigate<bool>(
      MemoryEntryEditPage(entry: entry, memory: widget.memory),
      context: context,
    );
    if (result == true && context.mounted) {
      _emit(widget.memory);
    }
  }

  void _onToggle(MemoryEntryModel entry, bool value) {
    final index =
        widget.memory.entries.indexWhere((e) => e.id == entry.id);
    if (index == -1) return;
    widget.memory.entries[index] = entry.copyWith(isActive: value);
    _emit(widget.memory);
  }

  void _onDelete(MemoryEntryModel entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('将永久删除此记忆条目，是否继续？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('确认')),
        ],
      ),
    );
    if (confirmed == true) {
      widget.memory.entries.removeWhere((e) => e.id == entry.id);
      _emit(widget.memory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.memory.entries;

    if (entries.isEmpty) {
      return Column(
        children: [
          const Expanded(
            child: Center(
              child: Text('暂无记忆条目', style: TextStyle(color: Colors.grey)),
            ),
          ),
          _buildAddButton(),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  onTap: () => _onEdit(entry),
                  title: Text(
                    entry.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      decoration:
                          entry.isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    entry.createdAt.toString().substring(0, 16),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: entry.isActive,
                        onChanged: (v) => _onToggle(entry, v),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: Colors.redAccent),
                        onPressed: () => _onDelete(entry),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _buildAddButton(),
      ],
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _onAdd,
          icon: const Icon(Icons.add),
          label: const Text('新增记忆'),
        ),
      ),
    );
  }
}
