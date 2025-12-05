import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/pages/chat_options/edit_chat_option.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';

class MiscSettingsPage extends StatelessWidget {
  const MiscSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 通过GetX查找已初始化的VaultSettingController实例
    final VaultSettingController controller =
        Get.find<VaultSettingController>();
    // 获取响应式的自动标题设置模型
    final settings = controller.miscSetting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('杂项设置'),
      ),
      body: Obx(
        // 使用Obx包裹，以确保在模型对象本身被替换时UI能正确刷新
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
            // 构建“启用自动生成标题”的开关
            SwitchListTile(
              title: const Text('启用自动生成标题'),
              subtitle: const Text('在合适的时机，自动为对话生成标题。'),
              value: settings.value.autoTitle_enabled,
              onChanged: (bool value) {
                // 使用copyWith创建一个新的模型实例来更新状态，这对于GetX的响应式更新更可靠
                settings.value = settings.value.copyWith(enabled: value);
                controller.saveSettings(); // 保存设置
              },
            ),
            ListTile(
              title: const Text('使用的预设'),
              subtitle: const Text('生成标题时使用的对话预设'),
              trailing: Icon(Icons.arrow_right),
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
            // 构建“生成标题的楼层”的编辑区域
            _buildNumberSection(
              context: context,
              title: '生成标题的楼层',
              description: '在对话进行到第几层时，开始生成标题',
              initialValue: settings.value.autoTitle_level,
              onChanged: (value) {
                // 实时更新模型在内存中的值
                settings.value = settings.value.copyWith(level: value);
              },
              onSave: () {
                // 结束编辑时保存设置
                controller.saveSettings();
              },
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
              child: Text(
                '生成摘要设置',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),

            ListTile(
              title: const Text('摘要预设'),
              subtitle: const Text('生成摘要时使用的对话预设'),
              trailing: Icon(Icons.arrow_right),
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
            ListTile(
              title: const Text('生成记忆预设'),
              subtitle: const Text('生成记忆时使用的对话预设'),
              trailing: Icon(Icons.arrow_right),
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

            ListTile(
              title: const Text('使用的预设'),
              subtitle: const Text('生成AI帮答时使用的对话预设'),
              trailing: Icon(Icons.arrow_right),
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

  /// 辅助方法，用于构建数字输入的设置项UI。
  Widget _buildNumberSection({
    required BuildContext context,
    required String title,
    required String description,
    required int initialValue,
    required ValueChanged<int> onChanged,
    required VoidCallback onSave,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TextFormField(
          initialValue: initialValue.toString(),
          keyboardType: TextInputType.number,
          // 只允许输入数字
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            // 将字符串转换为整数，如果解析失败则默认为0
            onChanged(int.tryParse(value) ?? 0);
          },
          onTapOutside: (event) {
            FocusScope.of(context).unfocus();
            onSave();
          },
          onFieldSubmitted: (value) {
            onSave();
          },
          decoration: const InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          ),
        ),
      ],
    );
  }
}
