import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/widgets/common/expandable_text_field.dart';
import 'package:flutter_example/chat-app/widgets/common/option_input.dart';

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
  late TextEditingController activationDepthController; // 激活深度 (高级)
  late TextEditingController priorityController; // 顺序
  late TextEditingController positionIdController; // 插入位置深度
  late ActivationType activationType;
  late MatchingLogic logic;
  late bool isActive;
  late bool isFavorite;
  late String position;
  final _formKey = GlobalKey<FormState>();
  late List<FocusNode> _focusNodes;

  // 控制高级设置展开状态
  bool _isAdvancedExpanded = false;

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
    isFavorite = item?.isFavorite ?? false;
    activationType = item?.activationType ?? ActivationType.keywords;
    logic = item?.logic ?? MatchingLogic.or;
    isActive = item?.isActive ?? true;
    position = item?.position ?? 'before_char';

    // 焦点管理，用于失焦保存
    _focusNodes = List.generate(8, (_) => FocusNode());
    for (var node in _focusNodes) {
      node.addListener(() {
        if (!node.hasFocus) {
          save();
        }
      });
    }
  }

  @override
  void dispose() {
    // 页面退出时强制保存一次，确保数据同步
    //save();
    nameController.dispose();
    contentController.dispose();
    keywordsController.dispose();
    activationDepthController.dispose();
    priorityController.dispose();
    positionIdController.dispose();
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void save() {
    final item = (widget.item ??
            LorebookItemModel(
              id: DateTime.now().millisecondsSinceEpoch,
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
            position: position,
            positionId: int.tryParse(positionIdController.text) ?? 0,
            isFavorite: isFavorite);
    widget.onSave?.call(item);
  }

  @override
  Widget build(BuildContext context) {
    // 检查是否需要显示位置深度输入框
    final bool showPositionDepth = position.startsWith('@D');

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑条目'),
        // 移除了保存按钮，依赖自动保存
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // 第一行：名称
            TextField(
              controller: nameController,
              focusNode: _focusNodes[0],
              decoration: const InputDecoration(
                labelText: '条目名称',
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
            const SizedBox(height: 12),

            // 第二行：位置设置 (位置、顺序、深度)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: CustomOptionInputWidget(
                    initialValue: position,
                    labelText: '位置',
                    options: [
                      {'display': '角色前', 'value': 'before_char'},
                      {'display': '角色后', 'value': 'after_char'},
                      {'display': '示例前', 'value': 'before_em'},
                      {'display': '示例后', 'value': 'after_em'},
                      {'display': '@D 👤', 'value': '@Duser'},
                      {'display': '@D 🤖', 'value': '@Dassistant'},
                      {'display': '@D ⚙', 'value': '@Dsystem'},
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => position = value);
                        save();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: priorityController,
                    focusNode: _focusNodes[6],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '顺序',
                      prefixIcon: Icon(Icons.sort, size: 18),
                    ),
                  ),
                ),
                if (showPositionDepth) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: positionIdController,
                      focusNode: _focusNodes[7],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '深度',
                        prefixIcon: Icon(Icons.layers, size: 18),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // 第三行：内容 (占据主要空间)
            ExpandableTextField(
              controller: contentController,
              focusNode: _focusNodes[1],
              minLines: 10, // 增大高度
              maxLines: null,
              decoration: const InputDecoration(
                labelText: '内容',
                hintText: '输入世界书内容...',
                alignLabelWithHint: true,

                filled: true,
                // fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3), // 可选：轻微背景色
              ),
            ),
            const SizedBox(height: 12),

            // 第四行：高级设置 (折叠面板)
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text('高级设置', style: TextStyle(fontSize: 14)),
                leading: const Icon(Icons.settings),
                tilePadding: EdgeInsets.zero,
                initiallyExpanded: _isAdvancedExpanded,
                onExpansionChanged: (val) =>
                    setState(() => _isAdvancedExpanded = val),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
                    child: Column(
                      children: [
                        // 关键词
                        TextField(
                          controller: keywordsController,
                          focusNode: _focusNodes[2],
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: '关键词（逗号分隔）',
                            prefixIcon: Icon(Icons.vpn_key),
                            helperText: '主要用于关键词激活',
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 激活类型与逻辑
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<ActivationType>(
                                value: activationType,
                                focusNode: _focusNodes[3],
                                decoration: const InputDecoration(
                                  labelText: '激活条件',
                                ),
                                items: ActivationType.values.map((e) {
                                  return DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      _activationTypeLabel(e),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null)
                                    setState(() => activationType = v);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<MatchingLogic>(
                                value: logic,
                                focusNode: _focusNodes[4],
                                decoration: const InputDecoration(
                                  labelText: '匹配逻辑',
                                ),
                                items: MatchingLogic.values.map((e) {
                                  return DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      _logicLabel(e),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => logic = v);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 扫描深度 (区别于位置深度)
                        TextField(
                          controller: activationDepthController,
                          focusNode: _focusNodes[5],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '扫描深度 (上下文扫描范围)',
                            prefixIcon: Icon(Icons.radar),
                            helperText: '填0则使用全局设置',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
      return '总是';
    case ActivationType.keywords:
      return '关键词';
    // case ActivationType.rag:
    //   return 'RAG';
    case ActivationType.manual:
      return '手动';
  }
}

String _logicLabel(MatchingLogic logic) {
  switch (logic) {
    case MatchingLogic.and:
      return 'AND (全含)';
    case MatchingLogic.or:
      return 'OR (任一)';
    case MatchingLogic.regex:
      return '正则';
  }
}
