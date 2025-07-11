import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';

class LoreBookItemEditorPage extends StatefulWidget {
  final LorebookItemModel? item;
  final void Function(LorebookItemModel item)? onSave;

  const LoreBookItemEditorPage({super.key, this.item, this.onSave});

  @override
  State<LoreBookItemEditorPage> createState() => _LoreBookItemEditorPageState();
}

class _LoreBookItemEditorPageState extends State<LoreBookItemEditorPage> {
  late TextEditingController nameController;
  late TextEditingController contentController;
  late TextEditingController keywordsController;
  late TextEditingController activationDepthController;
  late TextEditingController priorityController;
  late TextEditingController positionIdController;
  late ActivationType activationType;
  late MatchingLogic logic;
  late bool isActive;
  final _formKey = GlobalKey<FormState>();
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    nameController = TextEditingController(text: item?.name ?? '');
    contentController = TextEditingController(text: item?.content ?? '');
    keywordsController = TextEditingController(text: item?.keywords ?? '');
    activationDepthController =
        TextEditingController(text: (item?.activationDepth ?? 3).toString());
    priorityController =
        TextEditingController(text: (item?.priority ?? 0).toString());
    positionIdController =
        TextEditingController(text: (item?.positionId ?? 0).toString());
    activationType = item?.activationType ?? ActivationType.keywords;
    logic = item?.logic ?? MatchingLogic.or;
    isActive = item?.isActive ?? true;
    _focusNodes = List.generate(7, (_) => FocusNode());
    for (var node in _focusNodes) {
      node.addListener(() {
        if (!node.hasFocus) {
          save();
        }
      });
    }
  }

  void save() {
    final item = (widget.item ??
            LorebookItemModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: '',
              content: '',
            ))
        .copyWith(
      name: nameController.text.trim(),
      content: contentController.text,
      keywords: keywordsController.text,
      activationType: activationType,
      logic: logic,
      isActive: isActive,
      activationDepth: int.tryParse(activationDepthController.text) ?? 3,
      priority: int.tryParse(priorityController.text) ?? 0,
      positionId: int.tryParse(positionIdController.text) ?? 0,
    );
    widget.onSave?.call(item);
  }

  void saveAndBack() {
    save();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑世界书条目'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: '保存',
            onPressed: saveAndBack,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: nameController,
              focusNode: _focusNodes[0],
              decoration: const InputDecoration(
                labelText: '条目名称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              focusNode: _focusNodes[1],
              minLines: 4,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: '内容',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keywordsController,
              focusNode: _focusNodes[2],
              decoration: const InputDecoration(
                labelText: '关键词（逗号分隔）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<ActivationType>(
                    value: activationType,
                    focusNode: _focusNodes[3],
                    decoration: const InputDecoration(
                      labelText: '激活条件',
                      border: OutlineInputBorder(),
                    ),
                    items: ActivationType.values.map((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text(_activationTypeLabel(e)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => activationType = v);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<MatchingLogic>(
                    value: logic,
                    focusNode: _focusNodes[4],
                    decoration: const InputDecoration(
                      labelText: '匹配逻辑',
                      border: OutlineInputBorder(),
                    ),
                    items: MatchingLogic.values.map((e) {
                      return DropdownMenuItem(
                        value: e,
                        child: Text(_logicLabel(e)),
                      );
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => logic = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: activationDepthController,
                    focusNode: _focusNodes[5],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '激活深度(填0使用世界书设置)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.layers),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: priorityController,
                    focusNode: _focusNodes[6],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '优先级(仅超过token上限时有用)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.star),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: positionIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '插入位置ID',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.place),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: [
                    const Text('启用'),
                    Switch(
                      value: isActive,
                      onChanged: (v) {
                        setState(() => isActive = v);
                        save();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

 String _activationTypeLabel(ActivationType type) {
  switch (type) {
    case ActivationType.always:
      return '总是激活';
    case ActivationType.keywords:
      return '关键词激活';
    case ActivationType.rag:
      return 'RAG激活(未实现)';
    case ActivationType.manual:
      return '手动激活';
  }
}

String _logicLabel(MatchingLogic logic) {
  switch (logic) {
    case MatchingLogic.and:
      return 'AND(全部包含)';
    case MatchingLogic.or:
      return 'OR(任一包含)';
    case MatchingLogic.regex:
      return '正则';
  }
}
