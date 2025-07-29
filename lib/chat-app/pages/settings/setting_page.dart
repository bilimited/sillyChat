import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/log_page.dart';
import 'package:flutter_example/chat-app/pages/other/api_manager.dart';
import 'package:flutter_example/chat-app/pages/settings/appearance_page.dart';
import 'package:flutter_example/chat-app/pages/settings/prompt_setting_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/main.dart';
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
  final CharacterController _characterController = Get.find();
  final SettingController _settingController = Get.find();
  final VaultSettingController _vaultSettingController = Get.find();
  final webDav = WebDavUtil();

  UniqueKey _pageKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
            const Text('上传将覆盖云端数据，是否继续？'),
            const Text('应用数据将上传至WebDAV云服务。\n数据未加密，请确保您的WebDAV服务安全可靠。',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
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
      Get.back();
      return;
    }

    // 关闭下拉框
    Get.back();
    _characterController.packageAvatarFiles();
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
    final data = await webDav.downloadAllProps();
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
              Navigator.pop(context);
              await webDav.downloadAllData(context);

              SillyChatApp.restart();
              await Get.find<CharacterController>().unpackAvatarFiles();
              Get.snackbar('导入完成', '数据已导入');
            },
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      key: _pageKey, // Apply the key here
      padding: const EdgeInsets.all(16.0),
      children: [
        // Theme Toggle
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Obx(
              () => Icon(
                _settingController.isDarkMode.value
                    ? Icons.nightlight_round
                    : Icons.wb_sunny_rounded,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
            title: Text(
              '切换主题',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              _settingController.isDarkMode.value ? '切换到明亮主题' : '切换到暗黑主题',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: Obx(
              () => Switch(
                value: _settingController.isDarkMode.value,
                onChanged: (newValue) {
                  setState(() {
                    _pageKey =
                        UniqueKey(); // Update page key to force theme redraw
                  });
                  _settingController.toggleDarkMode();
                },
                activeColor: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
        ),

        // WebDAV Configuration
        Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
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
        ),

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
            onTap: (){
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '常规设置'),
            Tab(text: 'API管理'),
            Tab(text: '外观设置'),
            Tab(text: '提示词设置'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralTab(),
          ApiManagerPage(),
          AppearanceSettingsPage(),
          PromptSettingsPage(),
        ],
      ),
    );
  }
}
