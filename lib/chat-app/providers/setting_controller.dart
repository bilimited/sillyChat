import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

// 全局配置
class SettingController extends GetxController {
  static String currectValutName = '';
  var isDarkMode = false.obs;
  var colorTheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple).obs;
  static final String globalSettingsFileName = 'global_settings.json';

  static String webdav_url='';
  static String webdav_password='';
  static String webdav_username='';

  @override
  void onInit() async {
    super.onInit();
    await loadGlobalSettings();
  }

  Future<String> getVaultPath() async {
    if (currectValutName.isEmpty) {
      return '${(await getApplicationDocumentsDirectory()).path}/SillyChat';
    }
    return '${(await getApplicationDocumentsDirectory()).path}/SillyChat/${currectValutName}';
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

  // 添加设置当前保管库名称的方法
  void setCurrentVaultName(String name) {
    currectValutName = name;
    saveGlobalSettings();
  }
}
