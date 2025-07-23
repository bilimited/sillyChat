import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/settings/chat_displaysetting_model.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/fontManager.dart';
import 'package:flutter_example/chat-app/widgets/theme_selector.dart';
import 'package:get/get.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key});

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  late TextEditingController _globalFontController;
  late FocusNode _globalFontFocusNode;

  @override
  void initState() {
    super.initState();
    final controller = Get.find<VaultSettingController>();
    _globalFontController = TextEditingController(
        text: controller.displaySettingModel.value.GlobalFont);
    _globalFontFocusNode = FocusNode();

    _globalFontFocusNode.addListener(() {
      if (!_globalFontFocusNode.hasFocus) {
        // If the focus node has lost focus
        controller.saveSettings();
        controller.updateTheme(fontName: _globalFontController.text);
      }
    });
  }

  @override
  void dispose() {
    _globalFontController.dispose();
    _globalFontFocusNode.removeListener(() {}); // Remove the listener
    _globalFontFocusNode.dispose();
    super.dispose();
  }

  // 辅助函数：翻译 AvatarStyle 枚举值为中文
  String _translateAvatarStyle(AvatarStyle style) {
    switch (style) {
      case AvatarStyle.circle:
        return '圆形';
      case AvatarStyle.rounded:
        return '圆角';
      case AvatarStyle.hidden:
        return "隐藏";
      default:
        // 如果没有匹配的翻译，则返回原始值
        return style.toString().split('.').last;
    }
  }

  // 辅助函数：翻译 MessageBubbleStyle 枚举值为中文
  String _translateMessageBubbleStyle(MessageBubbleStyle style) {
    switch (style) {
      case MessageBubbleStyle.bubble:
        return '气泡';
      case MessageBubbleStyle.compact:
        return '紧凑';

      default:
        // 如果没有匹配的翻译，则返回原始值
        return style.toString().split('.').last;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Find the already-initialized VaultSettingController
    final VaultSettingController controller =
        Get.find<VaultSettingController>();

    return Obx(
      () {
        // Obx widget ensures the UI rebuilds whenever the observable
        // displaySettingModel changes.
        final setting = controller.displaySettingModel.value;

        // Update the text controller if the setting changes from elsewhere
        // This is important if `setting.GlobalFont` can be changed from another part of the app
        if (_globalFontController.text != setting.GlobalFont &&
            !_globalFontFocusNode.hasFocus) {
          _globalFontController.text = setting.GlobalFont ?? '';
        }

        return Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: <Widget>[
              // Dropdown for AvatarStyle
              ListTile(
                title: const Text('头像风格'),
                trailing: SegmentedButton(
                  segments: AvatarStyle.values.map((AvatarStyle style) {
                    return ButtonSegment<AvatarStyle>(
                      value: style,
                      label: Text(_translateAvatarStyle(style)),
                      // You can also add icons here if desired:
                      // icon: Icon(Icons.star),
                    );
                  }).toList(),
                  selected: <AvatarStyle>{setting.avatarStyle},

                  onSelectionChanged: (Set<AvatarStyle> newSelection) {
                    if (newSelection.isNotEmpty) {
                      final selectedStyle = newSelection.first;
                      setting.avatarStyle = selectedStyle;
                      controller.displaySettingModel.refresh();
                      controller.saveSettings();
                    }
                  },
                  // Ensure only one option can be selected at a time, like a radio button group
                  multiSelectionEnabled: false,
                ),
              ),

              // 改为ListTile+SegmentedButton样式
              ListTile(
                title: const Text('消息气泡风格'), // 'Message Bubble Style'
                trailing: SegmentedButton<MessageBubbleStyle>(
                  segments:
                      MessageBubbleStyle.values.map((MessageBubbleStyle style) {
                    return ButtonSegment<MessageBubbleStyle>(
                      value: style,
                      label: Text(_translateMessageBubbleStyle(style)),
                    );
                  }).toList(),
                  selected: <MessageBubbleStyle>{setting.messageBubbleStyle},
                  onSelectionChanged: (Set<MessageBubbleStyle> newSelection) {
                    if (newSelection.isNotEmpty) {
                      final selectedStyle = newSelection.first;
                      setting.messageBubbleStyle = selectedStyle;
                      controller.displaySettingModel.refresh();
                      controller.saveSettings();
                    }
                  },
                  // Ensure only one option can be selected at a time, like a radio button group
                  multiSelectionEnabled: false,
                ),
              ),
              const Divider(),
              Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(
                        decoration: const InputDecoration(
                          labelText: '全局字体', // 'Global Font'
                          hintText: '请输入全局字体名称',
                        ),
                        controller: _globalFontController,
                        focusNode: _globalFontFocusNode,
                        onChanged: (value) {
                          // Update the model immediately for responsiveness
                          setting.GlobalFont = value;
                          controller.displaySettingModel.refresh();
                          // Saving happens on focus loss, not here.
                        },
                        // Removed onEditingComplete as save is handled by FocusNode listener
                      ),
                      SizedBox(
                        height: 10,
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          FontManager.loadFont(
                              context: context,
                              onFontLoaded: (fontFamily, fontPath) {
                                controller.updateTheme(fontName: fontFamily);
                                _globalFontController.text = fontFamily;
                                setting.GlobalFont = fontFamily;
                                setting.CustomFontPath = fontPath;
                                controller.displaySettingModel.refresh();
                                controller.saveSettings();
                              });
                        },
                        label: Text('加载字体'),
                      )
                    ],
                  )),

              const Divider(),
              // Switches for boolean values
              SwitchListTile(
                title: const Text('显示用户名称'), // 'Display User Name'
                value: setting.displayUserName,
                onChanged: (bool value) {
                  setting.displayUserName = value;
                  controller.displaySettingModel.refresh();
                  controller.saveSettings();
                },
              ),
              SwitchListTile(
                title: const Text('显示助手名称'), // 'Display Assistant Name'
                value: setting.displayAssistantName,
                onChanged: (bool value) {
                  setting.displayAssistantName = value;
                  controller.displaySettingModel.refresh();
                  controller.saveSettings();
                },
              ),
              SwitchListTile(
                title: const Text('显示消息日期'), // 'Display Message Date'
                value: setting.displayMessageDate,
                onChanged: (bool value) {
                  setting.displayMessageDate = value;
                  controller.displaySettingModel.refresh();
                  controller.saveSettings();
                },
              ),
              SwitchListTile(
                title: const Text('显示消息序号'), // 'Display Message Index'
                value: setting.displayMessageIndex,
                onChanged: (bool value) {
                  setting.displayMessageIndex = value;
                  controller.displaySettingModel.refresh();
                  controller.saveSettings();
                },
              ),
              const Divider(),

              // Slider for ContentFontScale
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '聊天字体缩放: ${setting.ContentFontScale.toStringAsFixed(2)}', // 'Content Font Scale:'
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: setting.ContentFontScale,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    label: setting.ContentFontScale.toStringAsFixed(2),
                    onChanged: (double value) {
                      setting.ContentFontScale = value;
                      controller.displaySettingModel.refresh();
                    },
                    onChangeEnd: (double value) {
                      // Save settings only when the user finishes sliding
                      // to avoid excessive writes to the file.
                      controller.saveSettings();
                    },
                  ),
                  Text(
                    '聊天头像尺寸: ${setting.AvatarSize.toStringAsFixed(2)}', // 'Avatar Size:'
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: setting.AvatarSize,
                    min: 10,
                    max: 100,
                    divisions: 90,
                    label: setting.AvatarSize.toStringAsFixed(2),
                    onChanged: (double value) {
                      setting.AvatarSize = value;
                      controller.displaySettingModel.refresh();
                    },
                    onChangeEnd: (double value) {
                      controller.saveSettings();
                    },
                  ),
                ],
              ),

              // 新增：头像圆角滑块
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '头像圆角: ${setting.AvatarBorderRadius.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: setting.AvatarBorderRadius,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    label: setting.AvatarBorderRadius.toStringAsFixed(1),
                    onChanged: (double value) {
                      setting.AvatarBorderRadius = value;
                      controller.displaySettingModel.refresh();
                    },
                    onChangeEnd: (double value) {
                      controller.saveSettings();
                    },
                  ),
                ],
              ),
              // 新增：消息气泡圆角滑块
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '消息气泡圆角: ${setting.MessageBubbleBorderRadius.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Slider(
                    value: setting.MessageBubbleBorderRadius,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    label: setting.MessageBubbleBorderRadius.toStringAsFixed(1),
                    onChanged: (double value) {
                      setting.MessageBubbleBorderRadius = value;
                      controller.displaySettingModel.refresh();
                    },
                    onChangeEnd: (double value) {
                      controller.saveSettings();
                    },
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(
                height: 16,
              ),
              ThemeSelector(
                  initialValue: controller.displaySettingModel.value.schemeName,
                  onThemeSelected: (theme) {
                    setting.schemeName = theme;
                    controller.displaySettingModel.refresh();
                    controller.saveSettings();
                    controller.updateTheme(themename: theme);
                  }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
