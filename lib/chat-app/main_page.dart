import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/chat_options/chat_options_manager.dart';
import 'package:flutter_example/chat-app/pages/vault_manager.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/webdav_util.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'pages/chat/chat_page.dart';
import 'pages/character/contacts_page.dart'; // 添加这一行

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;
  final VaultSettingController _vaultSettingController = Get.find();
  final SettingController _settingController = Get.find();
  final CharacterController _characterController = Get.find();

  final webDav = WebDavUtil();

  void _showCharacterSelectDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择角色'),
          content: SizedBox(
            width: double.maxFinite,
            child: Obx(
              () => ListView.builder(
                shrinkWrap: true,
                itemCount: _characterController.characters.length,
                itemBuilder: (context, index) {
                  final character = _characterController.characters[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: Image.file(File(character.avatar)).image,
                    ),
                    title: Text(character.name),
                    onTap: () {
                      _characterController.myId = character.id;
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void refleshAll() {
    SillyChatApp.restart();
    // _characterController.loadCharacters();
    // _promptController.loadPrompts();
    // _chatController.chats.value = [];
    // _chatController.loadChats();
    // _vaultSettingController.loadSettings();
    // _chatOptionController.loadChatOptions();
  }

  void _uploadAll() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认上传'),
        content: const Text('上传将覆盖云端数据，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    await webDav.init();

    if (result != true) {
      Get.back();
      return;
    }

    // 关闭下拉框
    Get.back();
    _characterController.packageAvatarFiles();

    final lastSyncTimeOnFail = _vaultSettingController.lastSyncTime.value;
    _vaultSettingController.lastSyncTime.value = DateTime.now();
    await _vaultSettingController.saveSettings();

    webDav.backupAllData(context, onSuccess: (count) {
      Get.back();
      Get.snackbar("保存成功", "上传了${count}个文件");
    }, onFail: (e) async {
      Get.back();
      Get.snackbar('备份数据失败', '$e');
      // 若上传失败则同步时间不变
      _vaultSettingController.lastSyncTime.value = lastSyncTimeOnFail;
      await _vaultSettingController.saveSettings();
    });

    //Get.back();
  }

  String getSizeString(int byteSize) {
    if (byteSize < 1024) {
      return '$byteSize B';
    } else if (byteSize < 1024 * 1024) {
      return '${(byteSize / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(byteSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  Future<void> _downloadAll() async {
    await webDav.init();
    final data = await webDav.downloadAllProps();
    Get.back();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('云端数据'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final file = data[index];
              return ListTile(
                title: Text(file.name ?? "unknown"),
                subtitle: Text(
                    '${getSizeString(file.size ?? 0)} - 修改时间: ${file.mTime}'),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await webDav.downloadAllData(context);
              refleshAll();
              await _characterController.unpackAvatarFiles();
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  void setupWebDav() {
    final urlController = TextEditingController(text: SettingController.webdav_url);
    final usernameController = TextEditingController(text: SettingController.webdav_username);
    final passwordController = TextEditingController(text: SettingController.webdav_password);

    Get.dialog(
      AlertDialog(
        title: const Text('WebDAV 配置'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'WebDAV URL',
                hintText: '请输入 WebDAV 服务器地址',
              ),
            ),
            TextFormField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: '用户名',
                hintText: '请输入用户名',
              ),
            ),
            TextFormField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: '密码',
                hintText: '请输入密码',
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              SettingController.webdav_url = urlController.text;
              SettingController.webdav_username = usernameController.text;
              SettingController.webdav_password = passwordController.text;
              _settingController.saveGlobalSettings();
              webDav.init();
              Get.back();
              Get.snackbar('成功', 'WebDAV 配置已更新');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    webDav.init();
  }

  Future<void> _showBackupDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置webdav'),
              onTap: setupWebDav,
            ),
            ListTile(
              leading: const Icon(Icons.cloud_download),
              title: const Text('从云端导入'),
              onTap: _downloadAll,
            ),
            ListTile(
              leading: const Icon(Icons.cloud_upload),
              title: const Text('上传到云端'),
              onTap: _uploadAll,
            ),
            // ListTile(
            //   leading: const Icon(Icons.back_hand),
            //   title: const Text('版本迁移'),
            //   onTap: () {
            //     MigrationStart();
            //   },
            // ),
          ],
        );
      },
    );
  }


  final List<Widget> _pages = [
    ChatPage(),
    const ContactsPage(), // 更新这一行
    ChatOptionsManagerPage(), // 更新这一行
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    //final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: _currentIndex < 2
          ? AppBar(
              title: Obx(
                () => Row(
                  children: [
                    GestureDetector(
                      onTap: _showCharacterSelectDialog,
                      child: CircleAvatar(
                          radius: 20,
                          backgroundImage:
                              Image.file(File(_characterController.me.avatar))
                                  .image),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          SettingController.currectValutName.isEmpty
                              ? "根目录"
                              : SettingController.currectValutName,
                          style: textTheme.titleLarge,
                        ),
                        Text(
                          "上次同步时间:${_vaultSettingController.lastSyncTimeString}",
                          style: textTheme.titleSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.switch_camera),
                  onPressed: () {
                    Get.to(() => VaultManagerPage());
                  },
                ),
                Obx(
                  () => IconButton(
                    icon: _settingController.isDarkMode.value
                        ? Icon(Icons.nightlight)
                        : Icon(Icons.sunny),
                    onPressed: () {
                      _settingController.toggleDarkMode();
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: _showBackupDialog,
                ),
              ],
            )
          : null,
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat),
            label: '聊天',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: '通讯录',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_applications_outlined),
            selectedIcon: Icon(Icons.settings_applications),
            label: '聊天配置',
          ),
        ],
      ),
    );
  }
}
