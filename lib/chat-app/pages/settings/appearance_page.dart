import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/settings/chat_displaysetting_model.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/fontManager.dart';
import 'package:flutter_example/chat-app/widgets/chat/example_chat.dart';
import 'package:flutter_example/chat-app/widgets/settings/settings_color_tile.dart';
import 'package:flutter_example/chat-app/widgets/settings/settings_segmented_tile.dart';
import 'package:flutter_example/chat-app/widgets/settings/settings_slider_tile.dart';
import 'package:flutter_example/chat-app/widgets/settings/settings_switch_tile.dart';
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
        controller.saveSettings();
        controller.updateThemeStardard(fontName: _globalFontController.text);
      }
    });
  }

  @override
  void dispose() {
    _globalFontController.dispose();
    _globalFontFocusNode.removeListener(() {});
    _globalFontFocusNode.dispose();
    super.dispose();
  }

  String _translateAvatarStyle(AvatarStyle style) {
    switch (style) {
      case AvatarStyle.circle:
        return '圆形';
      case AvatarStyle.rounded:
        return '圆角';
      case AvatarStyle.hidden:
        return '隐藏';
    }
  }

  String _translateMessageBubbleStyle(MessageBubbleStyle style) {
    switch (style) {
      case MessageBubbleStyle.bubble:
        return '气泡';
      case MessageBubbleStyle.compact:
        return '紧凑';
    }
  }

  @override
  Widget build(BuildContext context) {
    final VaultSettingController controller =
        Get.find<VaultSettingController>();

    return Obx(() {
      final setting = controller.displaySettingModel.value;

      // 外部可能重置了字体，同步到 TextEditingController
      if (_globalFontController.text != setting.GlobalFont &&
          !_globalFontFocusNode.hasFocus) {
        _globalFontController.text = setting.GlobalFont ?? '';
      }

      return Scaffold(
        appBar: AppBar(
          title: const Text('聊天界面设置'),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: <Widget>[
            SettingsColorTile(
              title: '主题颜色',
              value: setting.themeColor,
              onChanged: (color) {
                setting.themeColor = color;
                controller.displaySettingModel.refresh();
                controller.saveSettings();
                controller.updateThemeStardard(color: color);
              },
            ),

            SettingsSegmentedTile<AvatarStyle>(
              title: '头像风格',
              values: AvatarStyle.values,
              labelFor: _translateAvatarStyle,
              selected: <AvatarStyle>{setting.avatarStyle},
              onSelectionChanged: (Set<AvatarStyle> newSelection) {
                if (newSelection.isNotEmpty) {
                  setting.avatarStyle = newSelection.first;
                  controller.displaySettingModel.refresh();
                  controller.saveSettings();
                }
              },
            ),

            SettingsSegmentedTile<MessageBubbleStyle>(
              title: '消息气泡风格',
              values: MessageBubbleStyle.values,
              labelFor: _translateMessageBubbleStyle,
              selected: <MessageBubbleStyle>{setting.messageBubbleStyle},
              onSelectionChanged: (Set<MessageBubbleStyle> newSelection) {
                if (newSelection.isNotEmpty) {
                  setting.messageBubbleStyle = newSelection.first;
                  controller.displaySettingModel.refresh();
                  controller.saveSettings();
                }
              },
            ),

            const Divider(),

            // --- 字体设置（自定义布局，不强行塞入通用组件）---
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextField(
                    enabled: setting.CustomFontPath == null,
                    decoration: const InputDecoration(
                      labelText: '全局字体',
                      hintText: '请输入全局字体名称',
                    ),
                    controller: _globalFontController,
                    focusNode: _globalFontFocusNode,
                    onChanged: (value) {
                      setting.GlobalFont = value;
                      controller.displaySettingModel.refresh();
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          FontManager.loadFont(
                              context: context,
                              onFontLoaded: (fontFamily, fontPath) {
                                controller
                                    .updateThemeStardard(fontName: fontFamily);
                                _globalFontController.text = fontFamily;
                                setting.GlobalFont = fontFamily;
                                setting.CustomFontPath = fontPath;
                                controller.displaySettingModel.refresh();
                                controller.saveSettings();
                              });
                        },
                        label: const Text('加载字体'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          _globalFontController.text = '';
                          controller.updateThemeStardard(fontName: '');
                          setting.GlobalFont = null;
                          setting.CustomFontPath = null;
                          controller.displaySettingModel.refresh();
                          controller.saveSettings();
                        },
                        label: const Text('重置字体'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Divider(),

            SettingsSwitchTile(
              title: '显示用户名称',
              value: setting.displayUserName,
              onChanged: (bool value) {
                setting.displayUserName = value;
                controller.displaySettingModel.refresh();
                controller.saveSettings();
              },
            ),
            SettingsSwitchTile(
              title: '显示助手名称',
              value: setting.displayAssistantName,
              onChanged: (bool value) {
                setting.displayAssistantName = value;
                controller.displaySettingModel.refresh();
                controller.saveSettings();
              },
            ),
            SettingsSwitchTile(
              title: '显示消息日期',
              value: setting.displayMessageDate,
              onChanged: (bool value) {
                setting.displayMessageDate = value;
                controller.displaySettingModel.refresh();
                controller.saveSettings();
              },
            ),
            SettingsSwitchTile(
              title: '显示消息序号',
              value: setting.displayMessageIndex,
              onChanged: (bool value) {
                setting.displayMessageIndex = value;
                controller.displaySettingModel.refresh();
                controller.saveSettings();
              },
            ),

            const Divider(),

            SettingsSliderTile(
              label:
                  '聊天字体缩放: ${setting.ContentFontScale.toStringAsFixed(2)}',
              value: setting.ContentFontScale,
              min: 0.5,
              max: 2.0,
              divisions: 30,
              onChanged: (double value) {
                setting.ContentFontScale = value;
                controller.displaySettingModel.refresh();
              },
              onSave: () => controller.saveSettings(),
            ),
            SettingsSliderTile(
              label: '聊天头像尺寸: ${setting.AvatarSize.toStringAsFixed(2)}',
              value: setting.AvatarSize,
              min: 10,
              max: 100,
              divisions: 90,
              onChanged: (double value) {
                setting.AvatarSize = value;
                controller.displaySettingModel.refresh();
              },
              onSave: () => controller.saveSettings(),
            ),
            SettingsSliderTile(
              label:
                  '头像圆角: ${setting.AvatarBorderRadius.toStringAsFixed(1)}',
              value: setting.AvatarBorderRadius,
              min: 0,
              max: 50,
              divisions: 50,
              fractionDigits: 1,
              onChanged: (double value) {
                setting.AvatarBorderRadius = value;
                controller.displaySettingModel.refresh();
              },
              onSave: () => controller.saveSettings(),
            ),
            SettingsSliderTile(
              label:
                  '消息气泡圆角: ${setting.MessageBubbleBorderRadius.toStringAsFixed(1)}',
              value: setting.MessageBubbleBorderRadius,
              min: 0,
              max: 50,
              divisions: 50,
              fractionDigits: 1,
              onChanged: (double value) {
                setting.MessageBubbleBorderRadius = value;
                controller.displaySettingModel.refresh();
              },
              onSave: () => controller.saveSettings(),
            ),

            const Divider(),
            const SizedBox(height: 16),

            SettingsSliderTile(
              label:
                  '背景图片不透明度: ${setting.BackgroundImageOpacity.toStringAsFixed(2)}',
              value: setting.BackgroundImageOpacity,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: (double value) {
                setting.BackgroundImageOpacity = value;
                controller.displaySettingModel.refresh();
              },
              onSave: () => controller.saveSettings(),
            ),
            SettingsSliderTile(
              label:
                  '背景图片模糊: ${setting.BackgroundImageBlur.toStringAsFixed(1)}',
              value: setting.BackgroundImageBlur,
              min: 0,
              max: 20,
              divisions: 40,
              fractionDigits: 1,
              onChanged: (double value) {
                setting.BackgroundImageBlur = value;
                controller.displaySettingModel.refresh();
              },
              onSave: () => controller.saveSettings(),
            ),

            const Divider(),
            const SizedBox(height: 16),

            Text('预览', style: TextStyle(fontSize: 17)),
            ExampleChat(),
          ],
        ),
      );
    });
  }
}
