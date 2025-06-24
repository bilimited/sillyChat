import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/pages/chat/search_page.dart';
import 'package:flutter_example/chat-app/pages/chat_options/chat_options_manager.dart';
import 'package:flutter_example/chat-app/pages/vault_manager.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/webdav_util.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
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
  final ChatController _chatController = Get.find();

  final webDav = WebDavUtil();

  int desktop_destination_left = 0;
  int desktop_destination_right = 0;
  int desktop_chatId = 0;
  MessageModel? desktop_initialPosition;

  late List<Widget> _desktop_pages;

  CharacterModel get me => _characterController.me;

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

    setState(() {
      desktop_destination_left = 0;
      desktop_destination_right = 0;
    });
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
    final urlController =
        TextEditingController(text: SettingController.webdav_url);
    final usernameController =
        TextEditingController(text: SettingController.webdav_username);
    final passwordController =
        TextEditingController(text: SettingController.webdav_password);

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
    _desktop_pages = [
      ChatPage(onSelectChat: (chat) {
        setState(() {
          desktop_initialPosition = null;
          desktop_chatId = chat.id;
        });
      }),
      ContactsPage(),
      ChatOptionsManagerPage(),
      Obx(() => SearchPage(
          chats: _chatController.chats.value,
          onMessageTap: (msg, chat) {
            setState(() {
              desktop_initialPosition = msg;
              desktop_chatId = chat.id;
            });
          }))
    ];
    webDav.init();
  }

  Future<void> _showBackupDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
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

  Widget _buildDesktop(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const LEFT_WIDTH = 350.0;
    return Scaffold(
      backgroundColor: colors.surface,
      body: Row(
        children: [
          Column(
            children: [
              Expanded(
                child:
                    // NavigationRail as the left-side AppBar
                    NavigationRail(
                        selectedIndex: desktop_destination_left,
                        backgroundColor: colors.surfaceContainerHighest,
                        labelType: NavigationRailLabelType.all,
                        leading: Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: CircleAvatar(
                            backgroundImage: Image.file(File(me.avatar)).image,
                            radius: 24,
                          ),
                        ),
                        destinations: [
                          NavigationRailDestination(
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('聊天'),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.person),
                            label: const Text('角色'),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.settings_applications),
                            label: const Text('对话配置'),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.search),
                            label: const Text('搜索'),
                          ),
                        ],
                        onDestinationSelected: (index) {
                          setState(() {
                            desktop_destination_left = index;
                          });
                        },
                        trailing: null),
              ),
              Container(
                width: 80, // 暂时和rail严丝合缝
                color: colors.surfaceContainerHighest,
                child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      children: [
                        PopupMenuButton<int>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            // 根据 value 执行不同操作
                            if (value == 0) {
                              _settingController.toggleDarkMode();
                            } else if (value == 1) {
                              _showBackupDialog();
                            } else if (value == 2) {
                              customNavigate(VaultManagerPage());
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 0,
                              child: Row(
                                children: [
                                  _settingController.isDarkMode.value
                                      ? Icon(Icons.nightlight)
                                      : Icon(Icons.sunny),
                                  SizedBox(width: 8),
                                  Text('切换主题'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 1,
                              child: Row(
                                children: const [
                                  Icon(Icons.cloud, size: 20),
                                  SizedBox(width: 8),
                                  Text('云端同步'),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 2,
                              child: Row(
                                children: const [
                                  Icon(Icons.switch_camera, size: 20),
                                  SizedBox(width: 8),
                                  Text('切换仓库'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text('SillyChat',
                            style:
                                TextStyle(color: colors.outline, fontSize: 12)),
                        Text(
                          SillyChatApp.getVersion(),
                          style: TextStyle(color: colors.outline, fontSize: 12),
                        ),
                      ],
                    )),
              ),
            ],
          ),

          // Main chat area
          Expanded(
            child: Container(
              child: Stack(
                children: [
                  // 左侧固定宽度容器
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                        width: LEFT_WIDTH,
                        color: colors.surfaceContainer, // 可自定义颜色
                        child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder:
                                (Widget child, Animation<double> animation) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(-0.0, -0.2),
                                  end: Offset.zero,
                                ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutCubic,
                                )),
                                child: FadeTransition(
                                  opacity: CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeIn,
                                  ),
                                  child: child,
                                ),
                              );
                            },
                            child: IndexedStack(
                              key: ValueKey(desktop_destination_left),
                              index: desktop_destination_left,
                              children: _desktop_pages,
                            ))),
                  ),
                  // 主内容区（右侧），留出左侧容器宽度
                  Padding(
                      padding: const EdgeInsets.only(left: LEFT_WIDTH),
                      child: Obx(() => ChatDetailPage(
                            key: ValueKey(
                                '${desktop_chatId}_${desktop_initialPosition?.id ?? 0}'),
                            chatId: _chatController.chats.isEmpty
                                ? -1
                                : desktop_chatId,
                            initialPosition: desktop_initialPosition,
                          ))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
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
                  icon: Icon(Icons.search),
                  onPressed: () {
                    Get.to(() => SearchPage(
                          chats: Get.find<ChatController>().chats,
                          onMessageTap: (message, chat) {
                            Get.back();
                            Get.to(() => ChatDetailPage(
                                  chatId: chat.id,
                                  initialPosition: message,
                                ));
                          },
                        ));
                  },
                ),
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

  @override
  Widget build(BuildContext context) {
    if ((Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return _buildDesktop(context);
    } else {
      return _buildMobile(context);
    }
  }
}
