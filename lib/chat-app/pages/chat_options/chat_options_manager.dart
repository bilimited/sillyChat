import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/chat_options/edit_chat_option.dart';
import 'package:flutter_example/chat-app/pages/prompt/api_manager.dart';
import 'package:flutter_example/chat-app/pages/prompt/prompt_manager.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';
import '../../providers/chat_option_controller.dart';
import '../../models/chat_option_model.dart';

class ChatOptionsManagerPage extends StatelessWidget {
  final ChatOptionController _controller = Get.find<ChatOptionController>();

  ChatOptionsManagerPage({Key? key}) : super(key: key);

  Widget _buildOptionCard(ChatOptionModel option, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () {
          customNavigate(EditChatOptionPage(option: option,));
        },
        child: ListTile(
          title: Text(option.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('提示词数量: ${option.prompts.length}'),
              Text('温度: ${option.requestOptions.temperature}'),
              Text('历史长度: ${option.requestOptions.maxHistoryLength}'),
              Text('最大Token: ${option.requestOptions.maxTokens}'),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  _controller.deleteChatOption(index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('对话配置管理'),
        actions: [
          IconButton(
              onPressed: () {
                customNavigate(PromptManagerPage());
              },
              icon: Icon(Icons.article)),
          IconButton(
              onPressed: () {
                customNavigate(ApiManagerPage());
              },
              icon: Icon(Icons.api))
        ],
      ),
      body: Obx(
        () => ReorderableListView.builder(
          padding: const EdgeInsets.only(bottom: 80),
          itemCount: _controller.chatOptions.length,
          onReorder: _controller.reorderChatOptions,
          itemBuilder: (context, index) {
            return KeyedSubtree(
              key: ValueKey(_controller.chatOptions[index].id),
              child: _buildOptionCard(_controller.chatOptions[index], index),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          customNavigate(EditChatOptionPage());
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
