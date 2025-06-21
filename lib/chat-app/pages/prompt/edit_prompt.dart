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
  late PromptCategory _category = PromptCategory.general;
  String? _customCategory;

  @override
  void initState() {
    super.initState();
    if (widget.prompt != null) {
      _name = widget.prompt!.name;
      _content = widget.prompt!.content;
      _role = widget.prompt!.role;
      _category = widget.prompt!.category;
      _customCategory = widget.prompt!.customCategory;
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
      category: _category,
      customCategory: _customCategory,
      createDate: widget.prompt?.createDate,
      updateDate: DateTime.now(),
    );

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
      category: _category,
      customCategory: _customCategory,
    );

    await _promptController.addPrompt(prompt);
    if(widget.editTempPrompt){
      Get.snackbar("保存成功", "当前Prompt已保存到提示词管理");
    }else{
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
      floatingActionButton: FloatingActionButton(onPressed: _save,child: 
        Icon(Icons.save)
      ,),
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
              if (!widget.editTempPrompt) ...[
                SizedBox(height: 16),
                DropdownButtonFormField<PromptCategory>(
                  value: _category,
                  decoration: InputDecoration(
                    labelText: '类别',
                    border: OutlineInputBorder(),
                  ),
                  items: PromptCategory.values
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(category.toString().split('.').last),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() {
                    _category = value!;
                    if (_category != PromptCategory.custom) {
                      _customCategory = null;
                    }
                  }),
                ),
                if (_category == PromptCategory.custom) ...[
                  SizedBox(height: 16),
                  TextFormField(
                    initialValue: _customCategory,
                    decoration: InputDecoration(
                      labelText: '自定义类别',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_category == PromptCategory.custom && 
                          (value?.isEmpty ?? true)) {
                        return '请输入自定义类别';
                      }
                      return null;
                    },
                    onSaved: (value) => _customCategory = value,
                  ),
                ],
              ],
              SizedBox(height: 16),
              TextFormField(
                initialValue: _content,
                decoration: InputDecoration(
                  labelText: '内容',
                  border: OutlineInputBorder(),
                ),
                maxLines: 18,
                style: TextStyle(
                  fontSize: 14  
                ),
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
