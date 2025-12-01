import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/api_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

// 全局配置
class SettingController extends GetxController {
  static String currectValutName = '';
  var isDarkMode = false.obs;
  var colorTheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple).obs;
  static final String globalSettingsFileName = 'global_settings.json';

  static String webdav_url = '';
  static String webdav_password = '';
  static String webdav_username = '';

  static RxMap<ServiceProvider, List<String>> cachedModelList =
      <ServiceProvider, List<String>>{}.obs;

  static String vaultPath = '';

  @override
  void onInit() async {
    super.onInit();
    await loadGlobalSettings();
    vaultPath = await getVaultPath();
  }

  Future<bool> isExternalStorageDirectoryExists() async {
    return Platform.isAndroid; //!SillyChatApp.isDesktop();
  }

  Future<String> getVaultPath() async {
    late Directory root;
    if (!await isExternalStorageDirectoryExists()) {
      root = await getApplicationDocumentsDirectory();
    } else {
      root = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    }

    if (currectValutName.isEmpty) {
      return '${root.path}/SillyChat';
    }
    return '${root.path}/SillyChat/${currectValutName}';
  }

  Future<String> getOldVaultPath() async {
    final root = await getApplicationDocumentsDirectory();

    if (currectValutName.isEmpty) {
      return '${root.path}/SillyChat';
    }
    return '${root.path}/SillyChat/${currectValutName}';
  }

  Future<String> getChatPath() async {
    return '${await getVaultPath()}/chats';
  }

  Future<Directory> getChatDirectory() async {
    return Directory('${await getVaultPath()}/chats');
  }

  Future<String> getImagePath() async {
    return '${await getVaultPath()}/.imgs';
  }

  String getImagePathSync() {
    return '${vaultPath}/.imgs';
  }

  String getChatPathSync() {
    return '${vaultPath}/chats';
  }

  Directory getChatDirectorySync() {
    return Directory('${vaultPath}/chats');
  }

  String getRemoteVaultPath() {
    if (currectValutName.isEmpty) {
      return '/SillyChat';
    }
    return '/SillyChat/${currectValutName}';
  }

  // Early loading
  static Future<void> loadVaultName() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$globalSettingsFileName');

      if (await file.exists()) {
        final String contents = await file.readAsString();
        final Map<String, dynamic> settings = json.decode(contents);
        currectValutName = settings['currectVaultName'] ?? '';
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
        currectValutName = settings['currectVaultName'] ?? '';

        cachedModelList.value = (jsonDecode(settings['cachedModelList'] ?? '')
                as Map<String, dynamic>)
            .map((key, value) => MapEntry(
                ServiceProvider.fromJson(key), List<String>.from(value)));

        vaultPath = await getVaultPath();
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
        'currectVaultName': currectValutName,
        'webdav_url': webdav_url,
        'webdav_username': webdav_username,
        'webdav_password': webdav_password,
        'cachedModelList': jsonEncode(
            cachedModelList.map((key, value) => MapEntry(key.toJson(), value)))
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
        print("init data...");
        // 创建 {directory.path}/SillyChat 文件夹（如果不存在的话）
        if (!(await rootDir.exists())) {
          await rootDir.create(recursive: true);
        }
        // 复制 assets/initData 下的所有文件到数据根目录
        final assetManifest = await DefaultAssetBundle.of(Get.context!)
            .loadString('AssetManifest.json');
        final Map<String, dynamic> manifestMap = json.decode(assetManifest);
        final initDataFiles = manifestMap.keys
            .where((String key) => key.startsWith('assets/initData/'))
            .toList();

        for (final assetPath in initDataFiles) {
          final data = await rootBundle.load(assetPath);
          final List<int> bytes = data.buffer.asUint8List();
          final fileName = assetPath.split('/').last;
          final file = File('${rootDir.path}/$fileName');
          await file.writeAsBytes(bytes, flush: true);
        }
        print('初始数据已复制到数据根目录');
        SillyChatApp.restart();
      } else {
        print('数据根目录已存在且不为空');
      }
    });
  }

  // 添加设置当前保管库名称的方法
  void setCurrentVaultName(String name) {
    currectValutName = name;
    saveGlobalSettings();
  }

  static SettingController get of => Get.find<SettingController>();
}
