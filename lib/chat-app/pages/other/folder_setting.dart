import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/folder_setting_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';
// 假设你的模型文件在这里导入
// import 'path_to_your_model/folder_setting_model.dart';

class FolderSettingPage extends StatefulWidget {
  final String path; // 文件夹所在路径（不包含配置文件名）

  const FolderSettingPage({Key? key, required this.path}) : super(key: key);

  @override
  State<FolderSettingPage> createState() => _FolderSettingPageState();
}

class _FolderSettingPageState extends State<FolderSettingPage> {
  // 1. 声明数据模型
  // late FolderSettingModel _settingModel;

  late final Rx<FolderSettingModel> _settingModel;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  // 2. 初始化方法
  Future<void> _initData() async {
    _settingModel = Rx(ChatController.of.getFolderSetting(widget.path)!);
  }

  // 3. 释放资源方法
  @override
  void dispose() {
    super.dispose();
  }

  // 4. 保存方法
  void _onSave() {
    ChatController.of.saveFolderSetting(_settingModel.value);
  }

  void _showChatOptionDialog() {
    final controller = Get.find<ChatOptionController>();
    final options = controller.chatOptions;

    Get.dialog(
      AlertDialog(
        title: const Text('选择聊天预设'),
        content: SizedBox(
          width: double.maxFinite,
          // 使用 ListView.builder 处理可能较长的列表
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              // 检查当前是否选中
              bool isSelected = _settingModel.value.chatOptionId == option.id;

              return ListTile(
                title: Text(
                  '${option.name}',
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: isSelected
                    ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                    : null,
                selected: isSelected,
                onTap: () {
                  // 1. 更新数据
                  setState(() {
                    _settingModel.value =
                        _settingModel.value.copyWith(chatOptionId: option.id);
                  });
                  Get.back();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        _onSave();
      },
      child: Scaffold(
        backgroundColor: colorScheme.surface, // 使用主题背景色
        appBar: AppBar(
          title: const Text('文件夹设置'),
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          actions: [
          ],
        ),
      
        // 内容区域
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Obx(() => Column(
                children: [
                  ListTile(
                    title: Text("使用的预设"),
                    subtitle: Text("该文件夹下的聊天会默认使用此预设"),
                    trailing:
                        Text(_settingModel.value.chatOptionModel?.name ?? "未选择"),
                    onTap: _showChatOptionDialog,
                  ),
                  ListTile(
                    title: Text("默认角色"),
                    subtitle: Text("该文件夹下新聊天会默认使用此角色"),
                    trailing: Text(
                        _settingModel.value.defaultAssistant?.roleName ?? "未选择"),
                    onTap: () async {
                      final CharacterModel? charactar = await customNavigate(
                          CharacterSelector(),
                          context: context);
                      _settingModel.value = _settingModel.value
                          .copyWith(defaultAssistantId: charactar?.id ?? null);
                    },
                  ),
                  ListTile(
                    title: Text("重置设置"),
                    subtitle: Text("重置所有设置"),
                    onTap: () async {
                      Get.defaultDialog(
                          title: "确认重置",
                          middleText: "您确定要重置所有设置吗？此操作将无法撤销。",
                          textConfirm: "确定重置",
                          textCancel: "取消",
                          onConfirm: () {
                            _settingModel.value = FolderSettingModel(
                                id: _settingModel.value.id,
                                path: _settingModel.value.path);
                            // 在这里执行重置逻辑
      
                            Get.back(); // 关闭弹窗
                          });
                    },
                  )
                ],
              )),
        ),
      
        // 悬浮保存按钮

      ),
    );
  }
}
