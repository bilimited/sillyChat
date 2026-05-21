import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/chat_options/edit_chat_option.dart';
import 'package:flutter_example/chat-app/pages/other/prompt_manager.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/common/app_option_card.dart';
import 'package:flutter_example/chat-app/widgets/common/info_chip.dart';
import 'package:flutter_example/chat-app/widgets/inner_app_bar.dart';
import 'package:get/get.dart';
import '../../providers/chat_option_controller.dart';
import '../../models/chat_option_model.dart';

class ChatOptionsManagerPage extends StatelessWidget {
  final ChatOptionController _controller = Get.find<ChatOptionController>();

  ChatOptionsManagerPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            InnerAppBar(
              title: const Text('对话预设'),
              actions: [
                IconButton(
                  icon: Icon(Icons.article, color: colorScheme.onSurface),
                  onPressed: () {
                    customNavigate(PromptManagerPage(), context: context);
                  },
                  tooltip: '提示词管理',
                ),
              ],
            ),
          ];
        },
        body: Obx(
          () => ReorderableListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80,left: 8,right: 8),
            itemCount: _controller.chatOptions.length,
            onReorder: _controller.reorderChatOptions,
            itemBuilder: (context, index) {
              return _buildOptionCard(
                  _controller.chatOptions[index], index, context);
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ChatOptionController.of()
              .addChatOption(ChatOptionModel.roleplay(name: '空白预设'));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildOptionCard(
      ChatOptionModel option, int index, BuildContext context) {
    final name = option.name;
    final isDefaultApi = option.requestOptions.apiId == -1;
    final apiName = option.requestOptions.api?.displayName;
    final promptCount = option.prompts.length;
    final regexCount = option.regex.length;
    final temperature = option.requestOptions.temperature;
    final colorScheme = Theme.of(context).colorScheme;

    return KeyedSubtree(
      key: ValueKey(option.id),
      child: AppOptionCard<String>(
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.tune,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: name,
        subTitle: Builder(builder: (context) {
          final chips = <Widget>[];
          if (apiName != null && apiName.isNotEmpty) {
            chips.add(InfoChip(
              label: isDefaultApi ? '使用默认' : apiName,
              color: colorScheme.primary,
              icon: Icons.api,
            ));
          }
          if (promptCount > 0) {
            if (chips.isNotEmpty) chips.add(const SizedBox(width: 6));
            chips.add(InfoChip(
              label: '$promptCount 提示词',
              color: colorScheme.secondary,
            ));
          }
          if (regexCount > 0) {
            if (chips.isNotEmpty) chips.add(const SizedBox(width: 6));
            chips.add(InfoChip(
              label: '$regexCount 正则',
              color: colorScheme.tertiary,
            ));
          }
          if (temperature != null) {
            if (chips.isNotEmpty) chips.add(const SizedBox(width: 6));
            chips.add(InfoChip(
              label: '温度 $temperature',
              color: Color.fromARGB(255, 216, 74, 63),
            ));
          }
          if (chips.isEmpty) return const SizedBox.shrink();
          return Wrap(children: chips);
        }),
        options: [
          AppCardOptionItem<String>(
            value: 'edit',
            child: const Row(
              children: [
                Icon(Icons.edit),
                SizedBox(width: 12),
                Text('编辑'),
              ],
            ),
          ),
          AppCardOptionItem<String>(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: colorScheme.error),
                const SizedBox(width: 12),
                Text(
                  '删除',
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'edit') {
            customNavigate(
                EditChatOptionPage(option: option), context: context);
          } else if (value == 'delete') {
            _onDelete(context, index);
          }
        },
        onTap: () {
          customNavigate(
              EditChatOptionPage(option: option), context: context);
        },
      ),
    );
  }

  void _onDelete(BuildContext context, int index) {
    showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除确认'),
          content: const Text('你确定要删除这个聊天预设吗？'),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Get.back();
              },
            ),
            TextButton(
              child: const Text('删除'),
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
}
