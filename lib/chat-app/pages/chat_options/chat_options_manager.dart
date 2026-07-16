import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/chat_options/edit_chat_option.dart';
import 'package:flutter_example/chat-app/pages/other/prompt_manager.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STConfigExporter.dart';
import 'package:flutter_example/chat-app/widgets/common/app_option_card.dart';
import 'package:flutter_example/chat-app/widgets/common/info_chip.dart';
import 'package:flutter_example/chat-app/widgets/inner_app_bar.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import '../../providers/chat_option_controller.dart';
import '../../models/chat_option_model.dart';
import '../../utils/tool_registry.dart';

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
            padding:
                const EdgeInsets.only(top: 8, bottom: 80, left: 8, right: 8),
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
    final isDefault = index == 0;
    final name = option.name;
    final isDefaultApi = option.requestOptions.apiId == -1;
    final apiName = option.requestOptions.api?.displayName;
    final promptCount = option.prompts.length;
    final regexCount = option.regex.length;
    final agentEnabled = option.agentConfig?.enabled ?? false;
    final toolWhitelist = option.agentConfig?.toolWhitelist;
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
          if (isDefault) {
            chips.add(InfoChip(
              label: '默认预设',
              color: Colors.orange,
              icon: Icons.star,
            ));
          }
          if (apiName != null && apiName.isNotEmpty) {
            if (chips.isNotEmpty) chips.add(const SizedBox(width: 6));
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
          if (chips.isNotEmpty) chips.add(const SizedBox(width: 6));
          if (agentEnabled) {
            final toolCount = toolWhitelist?.length ??
                ToolRegistry.instance.definitions.length;
            chips.add(InfoChip(
              label: '$toolCount 个工具',
              color: Colors.teal,
              icon: Icons.build,
            ));
          } else {
            chips.add(InfoChip(
              label: 'Agent 未启用',
              color: Colors.grey,
              icon: Icons.build_outlined,
            ));
          }
          if (chips.isEmpty) return const SizedBox.shrink();
          return Wrap(children: chips);
        }),
        options: [
          if (!isDefault)
            AppCardOptionItem<String>(
              value: 'set_default',
              child: const Row(
                children: [
                  Icon(Icons.push_pin),
                  SizedBox(width: 12),
                  Text('设为默认预设'),
                ],
              ),
            ),
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
            value: 'export_st',
            child: const Row(
              children: [
                Icon(Icons.file_upload_outlined),
                SizedBox(width: 12),
                Text('导出 ST'),
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
          if (value == 'set_default') {
            _onSetDefault(index);
          } else if (value == 'edit') {
            customNavigate(EditChatOptionPage(option: option),
                context: context);
          } else if (value == 'export_st') {
            _onExportST(option, context);
          } else if (value == 'delete') {
            _onDelete(context, index);
          }
        },
        onTap: () {
          customNavigate(EditChatOptionPage(option: option), context: context);
        },
      ),
    );
  }

  void _onSetDefault(int index) {
    final option = _controller.chatOptions.removeAt(index);
    _controller.chatOptions.insert(0, option);
    _controller.update();
    _controller.saveChatOptions();
  }

  Future<void> _onExportST(ChatOptionModel option, BuildContext context) async {
    try {
      final jsonStr = STConfigExporter.export(option);
      final safeName = option.name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
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
