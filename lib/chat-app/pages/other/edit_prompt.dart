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
  late int? _priority = null;

  @override
  void initState() {
    super.initState();
    if (widget.prompt != null) {
      _name = widget.prompt!.name;
      _content = widget.prompt!.content;
      _role = widget.prompt!.role;
      _priority = widget.prompt!.priority;
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
    )..priority = _priority;

    if (widget.editTempPrompt) {
      Get.back(result: prompt);
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
    )..priority = _priority;

    await _promptController.addPrompt(prompt);
    if (widget.editTempPrompt) {
      Get.snackbar("保存成功", "当前Prompt已保存到提示词管理");
    } else {
      Get.snackbar("复制成功", "当前Prompt已复制");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      floatingActionButton: FloatingActionButton(
        onPressed: _save,
        child: Icon(Icons.save),
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
                  border: OutlineInputBorder(),
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
                  border: OutlineInputBorder(),
                ),
                items: ['user', 'assistant', 'system']
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
                    value: _priority != null,
                    onChanged: (value) {
                      setState(() {
                        if (value) {
                          _priority = 99999;
                        } else {
                          _priority = null;
                        }
                      });
                    },
                  ),
                  Text('设置优先级'),
                ],
              ),
              SizedBox(height: 16),
              if (_priority != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: TextFormField(
                    initialValue: _priority?.toString(),
                    decoration: InputDecoration(
                      labelText: '优先级(0代表最后一条消息之后，1代表最后一条消息之前，99999代表消息列表开头)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (_priority != null) {
                        if (value == null || value.isEmpty) {
                          return '请输入优先级';
                        }
                        final n = int.tryParse(value);
                        if (n == null) return '请输入有效的数字';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      if (_priority != null) {
                        _priority = int.tryParse(value ?? '99999');
                      }
                    },
                    onChanged: (value) {
                      setState(() {
                        _priority = int.tryParse(value);
                      });
                    },
                  ),
                ),
              SizedBox(height: 16),
              TextFormField(
                initialValue: _content,
                decoration: InputDecoration(
                  labelText: '内容',
                  border: OutlineInputBorder(),
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
    );
  }
}
