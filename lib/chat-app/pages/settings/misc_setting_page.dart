import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/chat_options/edit_chat_option.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/settings/settings_nav_tile.dart';
import 'package:flutter_example/chat-app/widgets/settings/settings_number_tile.dart';
import 'package:flutter_example/chat-app/widgets/settings/settings_switch_tile.dart';
import 'package:get/get.dart';

class MiscSettingsPage extends StatelessWidget {
  const MiscSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final VaultSettingController controller =
        Get.find<VaultSettingController>();
    final settings = controller.miscSetting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('杂项设置'),
      ),
      body: Obx(
        () => ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                '自动标题设置',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SettingsSwitchTile(
              title: '启用自动生成标题',
              subtitle: '在合适的时机，自动为对话生成标题。',
              value: settings.value.autoTitle_enabled,
              onChanged: (bool value) {
                settings.value = settings.value.copyWith(enabled: value);
                controller.saveSettings();
              },
            ),
            SettingsNavTile(
              title: '使用的预设',
              subtitle: '生成标题时使用的对话预设',
              icon: Icons.tune,
              onTap: () {
                customNavigate(
                    EditChatOptionPage(
                      option: settings.value.autotitleOption,
                      onSave: (newOption) {
                        settings.value =
                            settings.value.copyWith(autotitleOption: newOption);
                        controller.saveSettings();
                      },
                    ),
                    context: context);
              },
            ),
            const Divider(height: 32),
            SettingsNumberTile(
              title: '生成标题的楼层',
              description: '在对话进行到第几层时，开始生成标题',
              initialValue: settings.value.autoTitle_level,
              onChanged: (value) {
                settings.value = settings.value.copyWith(level: value);
              },
              onSave: () => controller.saveSettings(),
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                '生成摘要设置',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SettingsNavTile(
              title: '摘要预设',
              subtitle: '生成摘要时使用的对话预设',
              icon: Icons.tune,
              onTap: () {
                customNavigate(
                    EditChatOptionPage(
                      option: settings.value.summaryOption,
                      onSave: (newOption) {
                        settings.value =
                            settings.value.copyWith(summaryOption: newOption);
                        controller.saveSettings();
                      },
                    ),
                    context: context);
              },
            ),
            SettingsNavTile(
              title: '生成记忆预设',
              subtitle: '生成记忆时使用的对话预设',
              icon: Icons.tune,
              onTap: () {
                customNavigate(
                    EditChatOptionPage(
                      option: settings.value.genMemOption,
                      onSave: (newOption) {
                        settings.value =
                            settings.value.copyWith(genMemOption: newOption);
                        controller.saveSettings();
                      },
                    ),
                    context: context);
              },
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                'AI帮答设置',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SettingsNavTile(
              title: '使用的预设',
              subtitle: '生成AI帮答时使用的对话预设',
              icon: Icons.tune,
              onTap: () {
                customNavigate(
                    EditChatOptionPage(
                      option: settings.value.simulateUserOption,
                      onSave: (newOption) {
                        settings.value = settings.value
                            .copyWith(simulateUserOption: newOption);
                        controller.saveSettings();
                      },
                    ),
                    context: context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
