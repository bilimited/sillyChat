import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/pages/chat_options/edit_chat_option.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/PackageValue.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/option_input.dart';
import 'package:get/get.dart';

class SummarySettingsPage extends StatefulWidget {
  const SummarySettingsPage({super.key});

  @override
  State<SummarySettingsPage> createState() => _SummarySettingsPageState();
}

class _SummarySettingsPageState extends State<SummarySettingsPage> {
  late final VaultSettingController controller;
  late final TextEditingController depthController;

  @override
  void initState() {
    super.initState();
    controller = Get.find<VaultSettingController>();
    final settings = controller.summarySetting.value;
    depthController = TextEditingController(
      text: settings.defaultDepth?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    // 保存 controller 内容
    final depthValue = int.tryParse(depthController.text) ?? 0;
    final settings =
        controller.summarySetting.value.copyWith(defaultDepth: depthValue);
    controller.summarySetting.value = settings;
    controller.saveSettings();
    depthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = controller.summarySetting;
    final loreBookController = Get.find<LoreBookController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('摘要设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              '聊天内总结',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          ListTile(
            title: const Text('使用的预设'),
            subtitle: const Text('总结时使用的对话预设'),
            trailing: Icon(Icons.arrow_right),
            onTap: () {
              customNavigate(
                  EditChatOptionPage(
                    option: settings.value.summaryOption,
                    onSave: (newOption) {
                      settings.value =
                          settings.value.copyWith(option: newOption);
                      controller.saveSettings();
                    },
                  ),
                  context: context);
            },
          ),
          const Divider(height: 32),
          // TODO:不想写辣
          //
          // Padding(
          //   padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          //   child: Text(
          //     '总结并插入世界书',
          //     style: Theme.of(context).textTheme.titleMedium,
          //   ),
          // ),
          // ListTile(
          //   title: const Text('使用的预设'),
          //   subtitle: const Text('总结并插入世界书时使用的对话预设'),
          //   trailing: Icon(Icons.arrow_right),
          //   onTap: () {
          //     customNavigate(
          //         EditChatOptionPage(
          //           option: settings.value.lorebookSummaryOption,
          //           onSave: (newOption) {
          //             settings.value = settings.value
          //                 .copyWith(lorebookSummaryOption: newOption);
          //             controller.saveSettings();
          //           },
          //         ),
          //         context: context);
          //   },
          // ),
          // SizedBox(
          //   height: 24,
          // ),

          // // 新增：LoreBook选择下拉框
          // DropdownButtonFormField<int>(
          //   initialValue: settings.value.loreBookToInsert,
          //   decoration: const InputDecoration(
          //     labelText: '选择要插入的世界书',
          //     prefixIcon: Icon(Icons.book),
          //   ),
          //   items: loreBookController.lorebooks
          //       .map((lorebook) => DropdownMenuItem<int>(
          //             value: lorebook.id,
          //             child: Text(lorebook.name ?? '未命名'),
          //           ))
          //       .toList(),
          //   onChanged: (id) {
          //     settings.value = settings.value
          //         .copyWith(loreBookToInsert: PackageValue(id));
          //     controller.saveSettings();
          //   },
          // ),

          // const SizedBox(height: 24),
          // CustomOptionInputWidget(
          //   initialValue: settings.value.defaultPosition,
          //   labelText: '插入位置',
          //   options: [
          //     {'display': '角色定义前', 'value': 'before_char'},
          //     {'display': '角色定义后', 'value': 'after_char'},
          //     {'display': '对话示例前', 'value': 'before_em'},
          //     {'display': '对话示例后', 'value': 'after_em'},
          //     {'display': '@D 👤', 'value': '@Duser'},
          //     {'display': '@D 🤖', 'value': '@Dassistant'},
          //     {'display': '@D ⚙', 'value': '@Dsystem'},
          //   ],
          //   onChanged: (value) {
          //     settings.value =
          //         settings.value.copyWith(defaultPosition: value);
          //     controller.saveSettings();
          //   },
          // ),
          // const SizedBox(height: 24),

          // if (settings.value.defaultPosition.startsWith('@D'))
          //   TextField(
          //     controller: depthController,
          //     keyboardType: TextInputType.number,
          //     decoration: const InputDecoration(
          //       labelText: '深度',
          //       prefixIcon: Icon(Icons.layers),
          //     ),
          //     onChanged: (value) {
          //       final depthValue = int.tryParse(value) ?? 0;
          //       settings.value =
          //           settings.value.copyWith(defaultDepth: depthValue);
          //     },
          //   ),
        ],
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
