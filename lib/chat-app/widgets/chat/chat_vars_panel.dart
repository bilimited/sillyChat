import 'package:flutter/material.dart';

class ChatVarsPanel extends StatelessWidget {
  final Map<String, String> chatVars;
  final void Function(String oldKey, String newKey, String value) onEdit;
  final ValueChanged<String> onDelete;

  const ChatVarsPanel({
    super.key,
    required this.chatVars,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final entries = chatVars.entries.toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          // color: colors.surfaceContainerHigh.withOpacity(0.92),
          // border: Border(
          //   bottom: BorderSide(color: colors.outlineVariant.withOpacity(0.3)),
          // ),
          ),
      child: entries.isEmpty
          ? _buildEmpty(context, colors)
          : Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...entries.map((e) => _VarChip(
                      entry: e,
                      onTap: () => _showEditDialog(context, e),
                    )),
                _AddButton(onPressed: () => _showAddDialog(context)),
              ],
            ),
    );
  }

  Widget _buildEmpty(BuildContext context, ColorScheme colors) {
    return Row(
      children: [
        Text('暂无变量', style: TextStyle(fontSize: 12, color: colors.outline)),
        const Spacer(),
        _AddButton(onPressed: () => _showAddDialog(context)),
      ],
    );
  }

  void _showEditDialog(BuildContext context, MapEntry<String, String> entry) {
    final keyCtrl = TextEditingController(text: entry.key);
    final valCtrl = TextEditingController(text: entry.value);
    final colors = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑变量'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(labelText: '变量名'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valCtrl,
              decoration: const InputDecoration(labelText: '变量值'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showDeleteConfirm(context, entry.key);
            },
            child: Text('删除', style: TextStyle(color: colors.error)),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final newKey = keyCtrl.text.trim();
              if (newKey.isEmpty) return;
              onEdit(entry.key, newKey, valCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final keyCtrl = TextEditingController();
    final valCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加变量'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: '变量名'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: valCtrl,
              decoration: const InputDecoration(labelText: '变量值'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              final key = keyCtrl.text.trim();
              if (key.isEmpty) return;
              onEdit('', key, valCtrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, String key) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除变量 "$key" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              onDelete(key);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _VarChip extends StatelessWidget {
  final MapEntry<String, String> entry;
  final VoidCallback onTap;

  const _VarChip({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 12, color: colors.onSurface),
            children: [
              TextSpan(
                text: entry.key,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: ': ${entry.value}',
                style: TextStyle(color: colors.onSecondaryContainer),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(Icons.add, size: 16, color: colors.primary),
      ),
    );
  }
}
