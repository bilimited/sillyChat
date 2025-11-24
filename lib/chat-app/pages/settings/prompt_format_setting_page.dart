import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:get/get.dart';

class PromptFormatSettingsPage extends StatelessWidget {
  const PromptFormatSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 通过GetX查找已初始化的VaultSettingController实例
    final VaultSettingController controller =
        Get.find<VaultSettingController>();
    // 获取响应式的设置模型
    final settings = controller.promptSettingModel;

    return Scaffold(
      appBar: AppBar(
        title: Text('格式设置'),
      ),
      body: Obx(
        // 使用Obx包裹，以确保在模型对象本身被替换时UI能正确刷新
        () => ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            // 开关：是否格式化主内容
            SwitchListTile(
              title: const Text('格式化正文和世界书'),
              subtitle: const Text('是否替换世界书和正文中的{{user}}等。'),
              value: settings.value.isFormatMainContent,
              onChanged: (bool value) {
                // 使用Rx的update以确保Obx能感知到变化并刷新UI
                settings.update((s) {
                  if (s != null) s.isFormatMainContent = value;
                });
                // 立即保存设置
                controller.saveSettings();
              },
            ),
            const Divider(height: 32),

            //构建“连续输出提示词”的编辑区域
            _buildPromptSection(
              context: context,
              title: '连续输出提示词',
              description: '用于在AI输出未完整时，要求其继续输出的指令。',
              initialValue: settings.value.continuePrompt,
              onChanged: (value) {
                // 实时更新模型在内存中的值
                settings.value.continuePrompt = value;
              },
              onSave: () {
                // 结束编辑时保存设置
                controller.saveSettings();
              },
            ),
            const Divider(height: 32),

            // 构建“消息分隔符”的编辑区域
            _buildPromptSection(
              context: context,
              title: '消息分隔符',
              description: '在连续的助手消息之间，以此内容作为用户消息插入，以符合大语言模型的对话格式。',
              initialValue: settings.value.interAssistantUserSeparator,
              onChanged: (value) {
                settings.value.interAssistantUserSeparator = value;
              },
              onSave: () {
                controller.saveSettings();
              },
            ),
            const Divider(height: 32),

            // 构建“群聊消息格式化”的编辑区域
            _buildPromptSection(
              context: context,
              title: '群聊消息格式化',
              description:
                  '在群聊中，每条消息会以此格式套用。`<char>`会被替换为角色名，`<message>`会被替换为消息内容。',
              initialValue: settings.value.groupFormatter,
              onChanged: (value) {
                settings.value.groupFormatter = value;
              },
              onSave: () {
                controller.saveSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 一个私有的辅助方法，用于构建可复用的设置项UI，包含标题、描述和文本输入框。
  Widget _buildPromptSection({
    required BuildContext context,
    required String title,
    required String description,
    required String initialValue,
    required ValueChanged<String> onChanged,
    required VoidCallback onSave,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        // 功能描述
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        // 文本输入框
        TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          // 当点击输入框外部时，取消焦点并保存
          onTapOutside: (event) {
            FocusScope.of(context).unfocus(); // 收起键盘
            onSave();
          },
          // 当在键盘上点击“完成”或“提交”时保存
          onFieldSubmitted: (value) {
            onSave();
          },
          decoration: const InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          ),
          // 允许多行输入
          maxLines: null,
        ),
      ],
    );
  }
}
