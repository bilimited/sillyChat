import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/log_page.dart';
import 'package:flutter_example/chat-app/pages/regex/edit_global_regex.dart';
import 'package:flutter_example/chat-app/pages/settings/appearance_page.dart';
import 'package:flutter_example/chat-app/pages/settings/misc_setting_page.dart';
import 'package:flutter_example/chat-app/pages/settings/prompt_format_setting_page.dart';
import 'package:flutter_example/chat-app/pages/vault_manager.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_example/chat-app/widgets/alert_card.dart';
import 'package:get/get.dart';
import '../../providers/setting_controller.dart';
import '../../providers/vault_setting_controller.dart';
import '../../utils/webdav_util.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({Key? key}) : super(key: key);

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CharacterController _characterController = CharacterController.of;
  final SettingController _settingController = Get.find();
  final VaultSettingController _vaultSettingController = Get.find();
  final webDav = WebDavUtil();

  UniqueKey _pageKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    webDav.init();
  }

  void _setupWebDav() {
    final urlController =
        TextEditingController(text: SettingController.webdav_url);
    final usernameController =
        TextEditingController(text: SettingController.webdav_username);
    final passwordController =
        TextEditingController(text: SettingController.webdav_password);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              SettingController.webdav_url = urlController.text;
              SettingController.webdav_username = usernameController.text;
              SettingController.webdav_password = passwordController.text;
              _settingController.saveGlobalSettings();
              webDav.init();
              Navigator.pop(context);
              Get.snackbar('成功', 'WebDAV 配置已更新');
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadAll() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认上传'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // const Text(),
            // SizedBox(height: 15,),
            ModernAlertCard(
              type: ModernAlertCardType.warning,
              title: '上传将覆盖云端数据，是否继续？',
              child: const Text(
                '应用数据将上传至WebDAV云服务。\n数据未加密，请确保您的WebDAV服务安全可靠。',
              ),
            )
          ],
        ),
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
      return;
    }

    // 关闭下拉框
    Get.back();
    _vaultSettingController.lastSyncTime.value = DateTime.now();
    await _vaultSettingController.saveSettings();

    webDav.backupAllData(context, onSuccess: (count) {
      Get.back();
      Get.snackbar("保存成功", "上传了${count}个文件");
    }, onFail: (e) async {
      Get.back();
      Get.snackbar('备份数据失败', '$e');
    });
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
    await webDav.downloadAllData(context);
  }

  void _showCharacterSelectDialog() async {
    CharacterModel? character = await customNavigate<CharacterModel>(
        CharacterSelector(),
        context: context);
    if (character != null) {
      _vaultSettingController.myId.value = character.id;
      await _vaultSettingController.saveSettings();
    }
  }

  Widget _buildGeneralTab() {
    return ListView(
      key: _pageKey, // Apply the key here
      padding: const EdgeInsets.all(16.0),
      children: [
        Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(children: [
              Obx(() => ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading:
                        AvatarImage.round(_characterController.me.avatar, 20),
                    onTap: () {
                      _showCharacterSelectDialog();
                    },
                    title: Text(
                      _characterController.me.roleName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '切换主控角色',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Icon(Icons.arrow_forward_ios,
                        size: 16, color: Colors.grey[400]),
                  )),
              const Divider(height: 1, indent: 20, endIndent: 20),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Icon(Icons.cabin,
                    color: Theme.of(context).colorScheme.secondary),
                onTap: () {
                  customNavigate(VaultManagerPage(), context: context);
                },
                title: Text(
                  '仓库管理',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '在不同仓库中独立管理应用数据',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]),
              ),
            ])),

        // Theme Toggle
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Icon(Icons.color_lens,
                    color: Theme.of(context).colorScheme.secondary),
                onTap: () {
                  customNavigate(AppearanceSettingsPage(), context: context);
                },
                title: Text(
                  '聊天界面设置',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '编辑聊天界面的样式，包括气泡、头像、背景等',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]),
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Icon(Icons.format_align_center,
                    color: Theme.of(context).colorScheme.secondary),
                onTap: () {
                  customNavigate(PromptFormatSettingsPage(), context: context);
                },
                title: Text(
                  '格式设置',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '编辑连续输出时的格式、群聊消息的格式等',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]),
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Icon(Icons.miscellaneous_services,
                    color: Theme.of(context).colorScheme.secondary),
                onTap: () {
                  customNavigate(MiscSettingsPage(), context: context);
                },
                title: Text(
                  '杂项设置',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '编辑自动生成标题、生成摘要和AI帮答的相关设置',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]),
              ),
            ],
          ),
        ),

        // WebDAV Configuration
        Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: Icon(Icons.pattern,
                      color: Theme.of(context).colorScheme.secondary),
                  title: Text(
                    '全局正则',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '编辑全局正则表达式',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  onTap: () {
                    customNavigate(EditGlobalRegexPage(), context: context);
                  },
                  trailing: Icon(Icons.arrow_forward_ios,
                      size: 16, color: Colors.grey[400]),
                ),
              ],
            )),

        // Cloud Data Management
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Icon(Icons.cloud_queue,
                    color: Theme.of(context).colorScheme.secondary),
                title: Text(
                  'WebDAV 配置',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '连接到你的WebDav网盘或服务器以同步数据。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: _setupWebDav,
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]),
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Icon(Icons.cloud_upload_outlined,
                    color: Theme.of(context).colorScheme.secondary),
                title: Text(
                  '上传到云端',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '将本地数据上传到WebDav云储存',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: _uploadAll,
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]),
              ),
              const Divider(height: 1, indent: 20, endIndent: 20),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: Icon(Icons.cloud_download_outlined,
                    color: Theme.of(context).colorScheme.secondary),
                title: Text(
                  '从云端导入',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '从云端下载数据，本地数据将会被覆盖。',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                onTap: _downloadAll,
                trailing: Icon(Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey[400]),
              ),
            ],
          ),
        ),

        Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Icon(Icons.clear_all,
                color: Theme.of(context).colorScheme.secondary),
            title: Text(
              '查看日志',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '查看应用内运行日志（主要是API请求记录）',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () {
              customNavigate(LogPage(), context: context);
            },
            trailing: Icon(Icons.arrow_forward_ios,
                size: 16, color: Colors.grey[400]),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _pageKey,
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: _buildGeneralTab(),
    );
  }
}
