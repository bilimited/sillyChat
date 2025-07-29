import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/regex_model.dart';
import 'package:flutter_example/chat-app/widgets/prompt/prompt_editor.dart';
import 'package:flutter_example/chat-app/widgets/prompt/regex_list_editor.dart';
import 'package:get/get.dart';
import '../../models/chat_option_model.dart';
import '../../models/prompt_model.dart';
import '../../providers/chat_option_controller.dart';
import '../../utils/entitys/RequestOptions.dart';
import '../../widgets/prompt/request_options_editor.dart';

class EditChatOptionPage extends StatefulWidget {
  final ChatOptionModel? option;

  const EditChatOptionPage({Key? key, this.option}) : super(key: key);

  @override
  State<EditChatOptionPage> createState() => _EditChatOptionPageState();
}

class _EditChatOptionPageState extends State<EditChatOptionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  //final _msgTemplateController = TextEditingController();
  final ChatOptionController _controller = Get.find();

  late LLMRequestOptions _requestOptions;
  late List<PromptModel> _prompts;
  late List<RegexModel> _regexs;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    isEditing = widget.option != null;
    final defaultOption = ChatOptionModel.empty();

    _nameController.text = widget.option?.name ?? '';
    // _msgTemplateController.text = widget.option?.messageTemplate ?? '{{msg}}';
    _requestOptions = widget.option?.requestOptions ??
        defaultOption.requestOptions;
    _prompts = widget.option?.prompts ?? defaultOption.prompts;
    _regexs = widget.option?.regex ?? [];
    //_promptId = widget.option?.promptId ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    //_msgTemplateController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final chatOption = ChatOptionModel(
      id: isEditing
          ? widget.option!.id
          : DateTime.now()
              .millisecondsSinceEpoch, // Use a unique ID for new options
      name: _nameController.text,
      requestOptions: _requestOptions,
      prompts: _prompts,
      regex: _regexs,
    );

    if (isEditing) {
      final index = _controller.chatOptions.indexOf(widget.option!);
      _controller.updateChatOption(chatOption, index);
    } else {
      _controller.addChatOption(chatOption);
    }

    Get.back();
  }

  void _handleCopy() {
    final chatOption = ChatOptionModel(
      id: DateTime.now()
          .millisecondsSinceEpoch, // Use a unique ID for new options
      name: _nameController.text+"的副本",
      requestOptions: _requestOptions.copyWith(),
      prompts: _prompts.map((ele) => ele.copy()).toList(),
      regex: [],
    );
    _controller.addChatOption(chatOption);
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑预设' : '新建预设'),
        actions: [IconButton(onPressed: _handleCopy, icon: Icon(Icons.copy))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleSave,
        icon: Icon(Icons.save),
        label: Text("保存更改"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: '预设名称',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入预设名称';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const Text('提示词列表',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                PromptEditor(
                  prompts: _prompts,
                  onPromptsChanged: (prompts) {
                    _prompts = prompts;
                  },
                ),
                const SizedBox(height: 24),
                const Text('请求参数',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                RequestOptionsEditor(
                  options: _requestOptions,
                  onChanged: (options) {
                    setState(() {
                      _requestOptions = options;
                    });
                  },
                ),
                const SizedBox(height: 24),
                const Text('正则表达式',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                RegexListEditor(regexList: _regexs,onChanged: (regex){
                  setState(() {
                    _regexs = regex;
                  });
                },),
                const SizedBox(height: 64),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
