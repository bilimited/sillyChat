import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/chat_options/chat_options_manager.dart';
import 'package:flutter_example/chat-app/pages/log_page.dart';
import 'package:flutter_example/chat-app/pages/regex/edit_global_regex.dart';
import 'package:flutter_example/chat-app/pages/settings/appearance_page.dart';
import 'package:flutter_example/chat-app/pages/settings/import_from_sillytavern_page.dart';
import 'package:flutter_example/chat-app/pages/settings/misc_setting_page.dart';
import 'package:flutter_example/chat-app/pages/settings/other_setting_page.dart';
import 'package:flutter_example/chat-app/pages/settings/prompt_format_setting_page.dart';
import 'package:flutter_example/chat-app/pages/vault_manager.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_example/chat-app/widgets/alert_card.dart';
import 'package:flutter_example/chat-app/widgets/inner_app_bar.dart';
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

  Widget _buildSettingsGroup({required List<Widget> children}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: children.asMap().entries.map((entry) {
          int idx = entry.key;
          Widget child = entry.value;
          // 自动在项之间添加分割线
          if (idx > 0) {
            return Column(
              children: [
                const Divider(height: 1, indent: 20, endIndent: 20),
                child,
              ],
            );
          }
          return child;
        }).toList(),
      ),
    );
  }

  /// 构建通用的设置行
  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Widget? leadingOverride,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: leadingOverride ??
          Icon(icon, color: Theme.of(context).colorScheme.secondary),
      onTap: onTap,
      title: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing:
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
    );
  }

  Widget _buildGeneralTab() {
    return ListView(
      key: _pageKey,
      padding: const EdgeInsets.all(16.0),
      children: [
        // 1. 账户与仓库
        _buildSettingsGroup(children: [
          Obx(() => _buildSettingTile(
                title: _characterController.me.roleName,
                subtitle: '切换主控角色',
                icon: Icons.person, // 这里的 icon 会被 leadingOverride 覆盖
                leadingOverride:
                    AvatarImage.round(_characterController.me.avatar, 20),
                onTap: _showCharacterSelectDialog,
              )),
          _buildSettingTile(
            title: '仓库管理',
            subtitle: '在不同仓库中独立管理应用数据',
            icon: Icons.cabin,
            onTap: () => customNavigate(VaultManagerPage(), context: context),
          ),
          _buildSettingTile(
            title: '预设管理',
            subtitle: '管理聊天预设',
            icon: Icons.dashboard,
            onTap: () =>
                customNavigate(ChatOptionsManagerPage(), context: context),
          ),
          _buildSettingTile(
            title: '从SillyTarvern导入',
            subtitle: '从酒馆导入角色卡、预设和世界书等数据',
            icon: Icons.wine_bar,
            onTap: () {
              customNavigate(ImportFromSillytavernPage(), context: context);
            },
            // onTap: () =>
            //     customNavigate(ChatOptionsManagerPage(), context: context),
          ),
        ]),

        // 2. 界面与格式
        _buildSettingsGroup(children: [
          _buildSettingTile(
            title: '聊天界面设置',
            subtitle: '编辑聊天界面的样式，包括气泡、头像、背景等',
            icon: Icons.color_lens,
            onTap: () =>
                customNavigate(AppearanceSettingsPage(), context: context),
          ),
          _buildSettingTile(
            title: '格式设置',
            subtitle: '编辑连续输出时的格式、群聊消息的格式等',
            icon: Icons.format_align_center,
            onTap: () =>
                customNavigate(PromptFormatSettingsPage(), context: context),
          ),
          _buildSettingTile(
            title: '杂项设置',
            subtitle: '编辑自动生成标题、生成摘要和AI帮答的相关设置',
            icon: Icons.miscellaneous_services,
            onTap: () => customNavigate(MiscSettingsPage(), context: context),
          ),
        ]),

        // 3. 增强功能
        _buildSettingsGroup(children: [
          _buildSettingTile(
            title: '全局正则',
            subtitle: '编辑全局正则表达式',
            icon: Icons.pattern,
            onTap: () =>
                customNavigate(EditGlobalRegexPage(), context: context),
          ),
        ]),

        // 4. 云端同步
        _buildSettingsGroup(children: [
          _buildSettingTile(
            title: 'WebDAV 配置',
            subtitle: '连接到你的WebDav网盘或服务器以同步数据。',
            icon: Icons.cloud_queue,
            onTap: _setupWebDav,
          ),
          _buildSettingTile(
            title: '上传到云端',
            subtitle: '将本地数据上传到WebDav云储存',
            icon: Icons.cloud_upload_outlined,
            onTap: _uploadAll,
          ),
          _buildSettingTile(
            title: '从云端导入',
            subtitle: '从云端下载数据，本地数据将会被覆盖。',
            icon: Icons.cloud_download_outlined,
            onTap: _downloadAll,
          ),
        ]),

        // 5. 系统
        _buildSettingsGroup(children: [
          _buildSettingTile(
            title: '查看日志',
            subtitle: '查看应用内运行日志（主要是API请求记录）',
            icon: Icons.clear_all,
            onTap: () => customNavigate(LogPage(), context: context),
          ),
          _buildSettingTile(
            title: '其他设置',
            subtitle: '乱七八糟的设置',
            icon: Icons.more_horiz,
            onTap: () => customNavigate(OtherSettingsPage(), context: context),
          ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 移除原有的 appBar: InnerAppBar(...)
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            InnerAppBar(
              title: const Text('设置'),
            ),
          ];
        },
        body: ShaderMask(
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white.withOpacity(0.0)],
              stops: [0.85, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          // 关键：内部 ListView 的 padding 需要调整，因为它不再直接顶着屏幕顶端
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true, // 移除顶部安全距离，交给 NestedScrollView 处理
            child: _buildGeneralTab(),
          ),
        ),
      ),
    );
  }
}
