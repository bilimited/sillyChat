import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/chat_option_model.dart';
import '../providers/chat_option_controller.dart';
import '../utils/llmMessage.dart';
import '../utils/AIHandler.dart';

class ContentGenerator extends StatefulWidget {
  final List<LLMMessage> messages;
  const ContentGenerator({Key? key, required this.messages}) : super(key: key);

  @override
  State<ContentGenerator> createState() => _ContentGeneratorState();
}

class _ContentGeneratorState extends State<ContentGenerator> {
  late ChatOptionController chatOptionController;
  ChatOptionModel? selectedOption;
  final TextEditingController extraController = TextEditingController();
  final TextEditingController resultController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    chatOptionController = Get.find<ChatOptionController>();
    if (chatOptionController.chatOptions.isNotEmpty) {
      selectedOption = chatOptionController.chatOptions.first;
    }
  }

  Future<void> generateContent() async {
    if (selectedOption == null) return;
    setState(() => isLoading = true);

    // 构建消息列表，附加要求作为一条user消息
    List<LLMMessage> messages = List.from([
      ...selectedOption!.prompts.map((p) => LLMMessage.fromPromptModel(p)),
      ...widget.messages
    ]);
    if (extraController.text.trim().isNotEmpty) {
      messages.add(LLMMessage(
        content: extraController.text.trim(),
        role: 'user',
      ));
    }

    final handler = Aihandler();
    StringBuffer result = StringBuffer();
    await handler.request((token) {
      result.write(token);
      setState(() {
        resultController.text = result.toString();
      });
    }, selectedOption!.requestOptions.copyWith(messages: messages));

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('内容生成'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context, resultController.text);
            },
            child: const Text('提交', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ChatOption选择器
            Obx(() => DropdownButton<ChatOptionModel>(
                  isExpanded: true,
                  value: selectedOption,
                  items: chatOptionController.chatOptions
                      .map((opt) => DropdownMenuItem(
                            value: opt,
                            child: Text(opt.name),
                          ))
                      .toList(),
                  onChanged: (opt) {
                    setState(() {
                      selectedOption = opt;
                    });
                  },
                )),
            const SizedBox(height: 16),
            // 附加要求输入框
            TextField(
              controller: extraController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '附加要求',
              ),
            ),
            const SizedBox(height: 12),
            // 生成按钮
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome),
                label: const Text('生成'),
                onPressed: isLoading ? null : generateContent,
              ),
            ),
            const SizedBox(height: 16),
            // 生成结果编辑框
            Expanded(
              child: TextField(
                controller: resultController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: '生成结果',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
