import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/agent_config_model.dart';
import 'package:flutter_example/chat-app/models/regex_model.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STConfigExporter.dart';
import 'package:flutter_example/chat-app/widgets/other/agent_config_editor.dart';
import 'package:flutter_example/chat-app/widgets/other/prompt_editor.dart';
import 'package:flutter_example/chat-app/widgets/other/regex_list_editor.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import '../../models/chat_option_model.dart';
import '../../models/prompt_model.dart';
import '../../providers/chat_option_controller.dart';
import '../../utils/entitys/RequestOptions.dart';
import '../../widgets/other/request_options_editor.dart';

class EditChatOptionPage extends StatefulWidget {
  final ChatOptionModel? option;
  final void Function(ChatOptionModel newOption)? onSave;

  const EditChatOptionPage({Key? key, this.option, this.onSave})
      : super(key: key);

  @override
  State<EditChatOptionPage> createState() => _EditChatOptionPageState();
}

class _EditChatOptionPageState extends State<EditChatOptionPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final ChatOptionController _controller = Get.find();

  late LLMRequestOptions _requestOptions;
  late List<PromptModel> _prompts;
  late List<RegexModel> _regexs;
  AgentConfig? _agentConfig;
  bool isEditing = false;

  @override
  void initState() {
    super.initState();
    isEditing = widget.option != null;
    final defaultOption = ChatOptionModel.roleplay();

    _nameController.text = widget.option?.name ?? '';
    _requestOptions =
        widget.option?.requestOptions ?? defaultOption.requestOptions;
    _prompts = widget.option?.prompts ?? defaultOption.prompts;
    _regexs = widget.option?.regex ?? [];
    _agentConfig = widget.option?.agentConfig;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleExportST() async {
    try {
      final option = ChatOptionModel(
        id: isEditing
            ? widget.option!.id
            : DateTime.now().millisecondsSinceEpoch,
        name: _nameController.text,
        requestOptions: _requestOptions,
        prompts: _prompts,
        regex: _regexs,
        agentConfig: _agentConfig,
      );

      final jsonStr = STConfigExporter.export(option);
      final safeName = _nameController.text.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final defaultFileName = '$safeName.json';

      final selectedDir = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择保存位置',
      );

      if (selectedDir == null) return;

      final destFile = File(p.join(selectedDir, defaultFileName));
      await destFile.writeAsString(jsonStr);
      Get.snackbar('导出成功', '已保存至 ${destFile.path}');
    } catch (e) {
      Get.snackbar('导出失败', '$e');
    }
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
      agentConfig: _agentConfig,
    );

    if (widget.onSave != null) {
      widget.onSave!(chatOption);
      Navigator.of(context).pop();
    } else {
      if (isEditing) {
        final index = _controller.chatOptions.indexOf(widget.option!);
        _controller.updateChatOption(chatOption, index);
      } else {
        _controller.addChatOption(chatOption);
      }

      Navigator.of(context).pop();
    }
  }

  void _handleCopy() {
    final chatOption = ChatOptionModel(
      id: DateTime.now()
          .millisecondsSinceEpoch, // Use a unique ID for new options
      name: "${_nameController.text}的副本",
      requestOptions: _requestOptions.copyWith(),
      prompts: _prompts.map((ele) => ele.copy()).toList(),
      regex: [],
      agentConfig: _agentConfig?.copyWith(),
    );
    _controller.addChatOption(chatOption);
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;

          _handleSave();
        },
        child: DefaultTabController(
          length: 4, // Number of tabs
          child: Scaffold(
            appBar: AppBar(
              title: Text(isEditing ? '编辑预设' : '新建预设'),
              actions: [
                IconButton(
                  onPressed: _handleExportST,
                  icon: const Icon(Icons.file_upload_outlined),
                  tooltip: '导出为 SillyTavern 预设',
                ),
                IconButton(
                    onPressed: _handleCopy, icon: const Icon(Icons.copy)),
              ],
            ),
            // floatingActionButton: FloatingActionButton.extended(
            //   onPressed: _handleSave,
            //   icon: const Icon(Icons.save),
            //   label: const Text("保存更改"),
            // ),
            body: Padding(
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
                    ),
                    const SizedBox(height: 16),
                    // TabBar for switching between modules
                    const TabBar(
                      tabs: [
                        Tab(text: '提示词'),
                        Tab(text: '请求参数'),
                        Tab(text: '正则'),
                        Tab(text: 'Agent'),
                      ],
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicatorWeight: 3,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Content for "提示词列表"
                          PromptEditor(
                            prompts: _prompts,
                            onPromptsChanged: (prompts) {
                              _prompts = prompts;
                            },
                          ),

                          // Content for "请求参数"
                          SingleChildScrollView(
                            child: RequestOptionsEditor(
                              options: _requestOptions,
                              onChanged: (options) {
                                setState(() {
                                  _requestOptions = options;
                                });
                              },
                            ),
                          ),
                          // Content for "正则表达式"
                          RegexListEditor(
                            regexList: _regexs,
                            onChanged: (regex) {
                              setState(() {
                                _regexs = regex;
                              });
                            },
                          ),
                          // Content for "Agent 配置"
                          AgentConfigEditor(
                            config: _agentConfig,
                            onChanged: (config) {
                              setState(() {
                                _agentConfig = config;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}
