import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/chat_options/edit_chat_option.dart';
import 'package:flutter_example/chat-app/pages/other/prompt_manager.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STConfigImporter.dart';
import 'package:flutter_example/chat-app/widgets/filePickerWindow.dart';
import 'package:flutter_example/chat-app/widgets/inner_app_bar.dart';
import 'package:get/get.dart';
import '../../providers/chat_option_controller.dart';
import '../../models/chat_option_model.dart';

class ChatOptionsManagerPage extends StatelessWidget {
  final ChatOptionController _controller = Get.find<ChatOptionController>();
// 顶级菜单的key，用于控制侧边栏
  final GlobalKey<ScaffoldState>? scaffoldKey;
  ChatOptionsManagerPage({Key? key, this.scaffoldKey}) : super(key: key);

  void onDelete(BuildContext context, int index) {
    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除确认'), // 对话框标题
          content: const Text('你确定要删除这个聊天预设吗？'), // 对话框内容
          actions: <Widget>[
            TextButton(
              child: const Text('取消'), // 取消按钮
              onPressed: () {
                Get.back();
              },
            ),
            TextButton(
              child: const Text('删除'), // 删除按钮
              onPressed: () {
                Get.back();
                _controller.deleteChatOption(index);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionCard(
      ChatOptionModel option, int index, BuildContext context) {
    final name = option.name;
    final isdefaultApi = option.requestOptions.apiId == -1;
    final apiName = option.requestOptions.api?.displayName;
    final promptCount = option.prompts.length;
    final regexCount = option.regex.length;
    final temperature = option.requestOptions.temperature;
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: () {
          customNavigate(
              EditChatOptionPage(
                option: option,
              ),
              context: context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: -4.0,
                      children: [
                        if (apiName != null && apiName.isNotEmpty)
                          _buildInfoChip(isdefaultApi ? '使用默认' : '$apiName',
                              colors.primary,
                              icon: Icons.api),
                        if (promptCount > 0)
                          _buildInfoChip('$promptCount 提示词 ', colors.secondary),
                        if (regexCount > 0)
                          _buildInfoChip('$regexCount 正则', colors.tertiary),
                        if (temperature != null)
                          _buildInfoChip('温度 $temperature',
                              const Color.fromARGB(255, 216, 74, 63)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  onDelete(context, index);
                },
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, Color color, {IconData? icon}) {
    return Chip(
      avatar: icon != null
          ? Icon(
              icon,
              color: color,
            )
          : null,
      visualDensity: VisualDensity(vertical: -2),
      label: Text(
        label,
      ),
      backgroundColor: color.withOpacity(0.12),
      labelStyle: TextStyle(color: color, fontSize: 12),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 0.0),
      // shape: const StadiumBorder(),
    );
  }

  Widget _buildBuiltinOptionCard(
      IconData icon,
      String name,
      BuildContext context,
      ChatOptionModel option,
      void Function(ChatOptionModel) onSave) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: () {
          customNavigate(
              EditChatOptionPage(
                option: option,
                onSave: (option) {
                  onSave(option);
                  _controller.saveChatOptions();
                },
              ),
              context: context);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Icon(
                icon,
                color: colors.primary,
              ),
              const SizedBox(
                width: 12,
              ),
              Text(
                name,
                style: Theme.of(context).textTheme.titleSmall,
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
      backgroundColor: Colors.transparent,
      appBar: InnerAppBar(
        title: const Text('对话预设'),
        actions: [
          IconButton(
              onPressed: () {
                customNavigate(PromptManagerPage(), context: context);
              },
              icon: Icon(Icons.article)),
          IconButton(
              onPressed: () {
                FileImporter(
                    introduction: '导入SillyTavern预设。',
                    paramList: [],
                    allowedExtensions: ['json'],
                    onImport: (fileName, content, params, path) {
                      STConfigImporter.fromJson(json.decode(content), fileName);
                    }).pickAndProcessFile(context);
              },
              icon: Icon(Icons.download))
        ],
      ),
      body: Obx(
        () => Padding(
          padding: const EdgeInsets.all(8.0),
          child: ReorderableListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: _controller.chatOptions.length,
            onReorder: _controller.reorderChatOptions,
            itemBuilder: (context, index) {
              return KeyedSubtree(
                key: ValueKey(_controller.chatOptions[index].id),
                child: _buildOptionCard(
                    _controller.chatOptions[index], index, context),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ChatOptionController.of()
              .addChatOption(ChatOptionModel.roleplay(name: '空白预设'));
          //customNavigate(EditChatOptionPage(), context: context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
