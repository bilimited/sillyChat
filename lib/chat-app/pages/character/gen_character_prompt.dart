import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/AIHandler.dart';
import 'package:get/get.dart';
import '../../models/character_model.dart';
import '../../models/prompt_model.dart';
import '../../providers/prompt_controller.dart';
import '../../widgets/prompt/request_options_editor.dart';
import '../../utils/RequestOptions.dart';

class GenCharacterPromptPage extends StatefulWidget {
  final CharacterModel character;

  const GenCharacterPromptPage({Key? key, required this.character})
      : super(key: key);

  @override
  State<GenCharacterPromptPage> createState() => _GenCharacterPromptPageState();
}

/**
 * 该界面未完成
 * 问题：prompt生成器的初始message构建
 */
class _GenCharacterPromptPageState extends State<GenCharacterPromptPage> {
  final PromptController _promptController = Get.find();
  final VaultSettingController _settingController = Get.find();
  final TextEditingController _archiveController = TextEditingController();
  final TextEditingController _requestController = TextEditingController();
  final aiHandler = Aihandler();
  PromptModel? selectedPrompt;
  bool showOptions = false;
  late LLMRequestOptions requestOptions;
  bool isGenerating = false; // 添加生成状态标记

  @override
  void initState() {
    super.initState();
    _archiveController.text = widget.character.archive;
    requestOptions = LLMRequestOptions(
        messages: [],
        apiId: _settingController.apis.length > 0
            ? _settingController.apis[0].id
            : 0);

    selectedPrompt = _promptController.getPromptByNameAndRole("人设生成", 'user');
  }

  void _startGenerate() async {
    if (aiHandler.isBusy) return;

    setState(() => isGenerating = true);

    var promptContent = selectedPrompt?.BuildCharacterSystemPrompt(
            selectedPrompt!.content, widget.character) ??
        '**用户没有选择Prompt!请提示“请选择Propmt”。**';

    promptContent =
        promptContent.replaceAll("<request>", _requestController.text);
    requestOptions.messages.addAll([
      {'role': 'user', 'content': promptContent},
    ]);

    bool isFirstTokenGenerated = false;
    try {
      await for (String token in aiHandler.requestTokenStream(requestOptions)) {
        if (!isFirstTokenGenerated) {
          _archiveController.text = ''; // 确保只有请求成功后清空内容
          isFirstTokenGenerated = true;
        }
        _archiveController.text += token;
      }
    } finally {
      setState(() => isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('生成角色描述'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 可折叠的请求参数编辑器
            ExpansionTile(
              title: const Text('请求参数设置'),
              initiallyExpanded: showOptions,
              onExpansionChanged: (expanded) {
                setState(() => showOptions = expanded);
              },
              children: [
                Column(
                  children: [
                    const SizedBox(height: 16),
                    // Prompt选择器
                    DropdownButtonFormField<PromptModel>(
                      value: selectedPrompt,
                      decoration: const InputDecoration(
                        labelText: '选择提示词模板',
                        border: OutlineInputBorder(),
                      ),
                      items: _promptController.prompts
                          .where((p) => p.category == PromptCategory.character)
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(p.name),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedPrompt = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    RequestOptionsEditor(
                      options: requestOptions,
                      onChanged: (options) {
                        setState(() => requestOptions = options);
                      },
                    ),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _requestController,
              maxLines: null,
              minLines: 3,
              decoration: const InputDecoration(
                labelText: '生成请求',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: aiHandler.isBusy ? null : _startGenerate,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(isGenerating ? "正在生成" : "开始生成"),
                    if (isGenerating) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    ],
                  ],
                )),
            const SizedBox(height: 16),
            // 文本编辑区域
            TextField(
              controller: _archiveController,
              maxLines: null,
              minLines: 10,
              decoration: const InputDecoration(
                labelText: '结果',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 返回编辑后的文本
          Get.back(result: _archiveController.text);
        },
        child: const Icon(Icons.save),
      ),
    );
  }

  @override
  void dispose() {
    _archiveController.dispose();
    aiHandler.interrupt();
    super.dispose();
  }
}
