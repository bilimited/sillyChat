import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// 全局配置
class SettingController extends GetxController {
  static String currectValutPath = '';
  var isDarkMode = false.obs;
  //var colorTheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple).obs;
  final List<String> vaultPaths = <String>[].obs;

  static final String globalSettingsFileName = 'global_settings.json';

  static String webdav_url = '';
  static String webdav_password = '';
  static String webdav_username = '';

  @override
  void onInit() async {
    super.onInit();
    await loadGlobalSettings();
  }

  Future<String> getVaultPath() async {
    if (currectValutPath.isEmpty) {
      return '${(await getApplicationDocumentsDirectory()).path}/SillyChat';
    }
    return currectValutPath;
  }

  Future<String> getChatPath() async {
    return '${await getVaultPath()}/chats';
  }

  @Deprecated('远程仓库路径不对')
  String getRemoteVaultPath() {
    if (currectValutPath.isEmpty) {
      return '/SillyChat';
    }
    return '/SillyChat/${currectValutPath}';
  }

  // Early loading
  static Future<void> loadVaultName() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$globalSettingsFileName');

      if (await file.exists()) {
        final String contents = await file.readAsString();
        final Map<String, dynamic> settings = json.decode(contents);
        currectValutPath = settings['currectVaultPath'] ?? '';
      }
    } catch (e) {
      print('加载全局设置失败: $e');
    }
  }

  // 加载全局设置
  Future<void> loadGlobalSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$globalSettingsFileName');

      if (await file.exists()) {
        final String contents = await file.readAsString();
        final Map<String, dynamic> settings = json.decode(contents);
        webdav_url = settings['webdav_url'] ?? '';
        webdav_username = settings['webdav_username'] ?? '';
        webdav_password = settings['webdav_password'] ?? '';
        isDarkMode.value = settings['isDarkMode'] ?? false;
        currectValutPath = settings['currectVaultPath'] ?? '';
        vaultPaths.assignAll(settings['vaultPaths'] ?? []);
      }
    } catch (e) {
      print('加载全局设置失败: $e');
    }
  }

  // 保存全局设置
  Future<void> saveGlobalSettings() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$globalSettingsFileName');

      final Map<String, dynamic> settings = {
        'isDarkMode': isDarkMode.value,
        'currectVaultPath': currectValutPath,
        'webdav_url': webdav_url,
        'webdav_username': webdav_username,
        'webdav_password': webdav_password,
        'vaultPaths': vaultPaths,
      };

      final String jsonString = json.encode(settings);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('保存全局设置失败: $e');
    }
  }

  // 修改toggleDarkMode方法
  void toggleDarkMode() {
    isDarkMode.value = !isDarkMode.value;
    saveGlobalSettings();
  }

  // 第一次启动：加载初始数据
  static Future<void> loadInitialData() async {
    getApplicationDocumentsDirectory().then((directory) async {
      final rootDir = Directory('${directory.path}/SillyChat');
      if (!(await rootDir.exists()) || (await rootDir.list().isEmpty)) {
        // 创建 {directory.path}/SillyChat 文件夹（如果不存在的话）
        if (!(await rootDir.exists())) {
          await rootDir.create(recursive: true);
        }
      } else {
        print('数据根目录已存在且不为空');
      }
    });
  }

  // 添加设置当前保管库名称的方法
  void setCurrentVaultName(String name) {
    currectValutPath = name;
    saveGlobalSettings();
  }

  static SettingController get of => Get.find<SettingController>();
}
