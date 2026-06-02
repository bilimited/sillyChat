import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/widgets/settings/settings_switch_tile.dart';
import 'package:flutter_example/chat-app/widgets/settings/settings_text_tile.dart';
import 'package:get/get.dart';

class PromptFormatSettingsPage extends StatelessWidget {
  const PromptFormatSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final VaultSettingController controller =
        Get.find<VaultSettingController>();
    final settings = controller.promptSettingModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('格式设置'),
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            SettingsSwitchTile(
              title: '格式化正文和世界书',
              subtitle: '是否替换世界书和正文中的{{user}}等。',
              value: settings.value.isFormatMainContent,
              onChanged: (bool value) {
                settings.update((s) {
                  if (s != null) s.isFormatMainContent = value;
                });
                controller.saveSettings();
              },
            ),
            const Divider(height: 32),
            SettingsTextTile(
              title: '连续输出提示词',
              description: '用于在AI输出未完整时，要求其继续输出的指令。',
              initialValue: settings.value.continuePrompt,
              onChanged: (value) {
                settings.value.continuePrompt = value;
              },
              onSave: () => controller.saveSettings(),
            ),
            const Divider(height: 32),
            SettingsTextTile(
              title: '消息分隔符',
              description:
                  '在连续的助手消息之间，以此内容作为用户消息插入，以符合大语言模型的对话格式。',
              initialValue: settings.value.interAssistantUserSeparator,
              onChanged: (value) {
                settings.value.interAssistantUserSeparator = value;
              },
              onSave: () => controller.saveSettings(),
            ),
            const Divider(height: 32),
            SettingsTextTile(
              title: '群聊消息格式化',
              description:
                  '在群聊中，每条消息会以此格式套用。`<char>`会被替换为角色名，`<message>`会被替换为消息内容。',
              initialValue: settings.value.groupFormatter,
              onChanged: (value) {
                settings.value.groupFormatter = value;
              },
              onSave: () => controller.saveSettings(),
            ),
          ],
        ),
      ),
    );
  }
}
