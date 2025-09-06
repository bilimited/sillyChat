import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/prompt_model.dart';
import '../../providers/prompt_controller.dart';

class EditPromptPage extends StatefulWidget {
  final PromptModel? prompt;
  final bool editTempPrompt;

  const EditPromptPage({
    Key? key,
    this.prompt,
    this.editTempPrompt = false,
  }) : super(key: key);

  @override
  _EditPromptPageState createState() => _EditPromptPageState();
}

class _EditPromptPageState extends State<EditPromptPage> {
  final _formKey = GlobalKey<FormState>();
  final _promptController = Get.find<PromptController>();

  late String _name = '';
  late String _content = '';
  late String _role = 'user';
  int _depth = 4;
  int _priority = 100;
  bool _isInChat = false;

  @override
  void initState() {
    super.initState();
    if (widget.prompt != null) {
      _name = widget.prompt!.name;
      _content = widget.prompt!.content;
      _role = widget.prompt!.role;
      _depth = widget.prompt!.depth;
      _priority = widget.prompt!.priority;
      _isInChat = widget.prompt!.isInChat;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    final prompt = PromptModel(
        id: widget.prompt?.id ?? DateTime.now().millisecondsSinceEpoch,
        name: _name,
        content: _content,
        role: _role,
        createDate: widget.prompt?.createDate,
        updateDate: DateTime.now(),
        isInChat: _isInChat,
        depth: _depth,
        priority: _priority)
      ..isEnable = widget.prompt?.isEnable ?? true;

    if (widget.editTempPrompt) {
      Navigator.pop(context, prompt);
      return;
    }

    if (widget.prompt == null) {
      await _promptController.addPrompt(prompt);
    } else {
      await _promptController.updatePrompt(prompt);
    }

    Get.back();
  }

  Future<void> _duplicate() async {
    if (!_formKey.currentState!.validate()) return;

    _formKey.currentState!.save();

    final prompt = PromptModel(
      id: DateTime.now().millisecondsSinceEpoch,
      name: _name,
      content: _content,
      role: _role,
      isInChat: _isInChat,
      depth: _depth,
      priority: _priority,
    );

    await _promptController.addPrompt(prompt);
    if (widget.editTempPrompt) {
      Get.snackbar("保存成功", "当前Prompt已保存到提示词管理");
    } else {
      Get.snackbar("复制成功", "当前Prompt已复制");
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _save();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.prompt == null ? '新建提示词' : '编辑提示词'),
            actions: [
              if (widget.prompt != null)
                IconButton(
                  icon: Icon(Icons.copy),
                  onPressed: _duplicate,
                  tooltip: '复制提示词',
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    initialValue: _name,
                    decoration: InputDecoration(
                      labelText: '名称',
                    ),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return '请输入名称';
                      return null;
                    },
                    onSaved: (value) => _name = value!,
                  ),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _role,
                    decoration: InputDecoration(
                      labelText: '角色',
                    ),
                    items: [
                      'user',
                      'assistant',
                      'system',
                    ]
                        .map((role) => DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => _role = value!),
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Switch(
                        value: _isInChat,
                        onChanged: (value) {
                          setState(() {
                            _isInChat = value;
                          });
                        },
                      ),
                      Text('插入到聊天记录中'),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (_isInChat)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        children: [
                          TextFormField(
                            initialValue: _depth.toString(),
                            decoration: InputDecoration(
                              labelText: '深度(0代表最后一条消息之后，1代表最后一条消息之前)',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入深度';
                              }
                              final n = int.tryParse(value);
                              if (n == null) return '请输入有效的数字';

                              return null;
                            },
                            onSaved: (value) {
                              _depth = int.tryParse(value ?? '4') ?? 4;
                            },
                            onChanged: (value) {
                              setState(() {
                                _depth = int.tryParse(value) ?? 4;
                              });
                            },
                          ),
                          SizedBox(
                            height: 16,
                          ),
                          TextFormField(
                            initialValue: _priority.toString(),
                            decoration: InputDecoration(
                              labelText: '优先级',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return '请输入优先级';
                              }
                              final n = int.tryParse(value);
                              if (n == null) return '请输入有效的数字';

                              return null;
                            },
                            onSaved: (value) {
                              _priority = int.tryParse(value ?? '4') ?? 4;
                            },
                            onChanged: (value) {
                              setState(() {
                                _priority = int.tryParse(value) ?? 4;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 16),
                  TextFormField(
                    initialValue: _content,
                    decoration: InputDecoration(
                      labelText: '内容',
                    ),
                    maxLines: 18,
                    style: TextStyle(fontSize: 14),
                    validator: (value) {
                      if (value?.isEmpty ?? true) return '请输入内容';
                      return null;
                    },
                    onSaved: (value) => _content = value!,
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}
