import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/other/api_manager.dart';
import 'package:flutter_example/chat-app/pages/settings/appearance_page.dart';
import 'package:flutter_example/chat-app/pages/settings/prompt_setting_page.dart';
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

    if (result != true) return;

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
      children: [
        ListTile(
          leading: Obx(() => Icon(_settingController.isDarkMode.value
              ? Icons.nightlight
              : Icons.sunny)),
          title: const Text('切换主题'),
          onTap: () {
            setState(() {
              _pageKey = UniqueKey(); // 更新页面键以强制重建
            });
            _settingController.toggleDarkMode();
          },
        ),
        Divider(),
        ListTile(
          leading: const Icon(Icons.settings),
          title: const Text('WebDAV 配置'),
          onTap: _setupWebDav,
        ),
        Divider(),
        ListTile(
          leading: const Icon(Icons.cloud_upload),
          title: const Text('上传数据到云端'),
          onTap: _uploadAll,
        ),
        Divider(),
        ListTile(
          leading: const Icon(Icons.cloud_download),
          title: const Text('从云端导入数据'),
          onTap: _downloadAll,
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
