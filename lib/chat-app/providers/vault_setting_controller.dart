import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import '../models/api_model.dart';
import '../models/vault_settings.dart';

// 库配置
class VaultSettingController extends GetxController {
  final String vaultSettingFileName = 'settings.json';
  final RxList<ApiModel> apis = <ApiModel>[].obs;
  final Rx<DateTime?> lastSyncTime = Rx<DateTime?>(null);
  
  String get lastSyncTimeString{
    if (lastSyncTime.value == null) return "未同步";
    
    final now = DateTime.now();
    final difference = now.difference(lastSyncTime.value!);
    
    if (difference.inMinutes < 60) {
      return "${difference.inMinutes}分钟前";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}小时前";
    } else if (difference.inDays < 7) {
      return "${difference.inDays}天前";
    } else {
      return "${lastSyncTime.value!.year}-${lastSyncTime.value!.month.toString().padLeft(2, '0')}-${lastSyncTime.value!.day.toString().padLeft(2, '0')}";
    }
  }

  @override
  void onInit() async {
    super.onInit();
    await loadSettings();
  }

  // 从本地加载设置
  Future<void> loadSettings() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$vaultSettingFileName');

      if (await file.exists()) {
        final String contents = await file.readAsString();
        final Map<String, dynamic> jsonMap = json.decode(contents);
        final settings = VaultSettings.fromJson(jsonMap);
        
        apis.value = settings.apis;
        lastSyncTime.value = settings.lastSyncTime;
      }
    } catch (e) {
      print('加载设置失败: $e');
    }
  }

  // 保存设置到本地
  Future<void> saveSettings() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$vaultSettingFileName');

      final settings = VaultSettings(
        vaultName: SettingController.currectValutName,
        lastSyncTime: lastSyncTime.value,
        apis: apis,
      );

      final String jsonString = json.encode(settings.toJson());
      await file.writeAsString(jsonString);
    } catch (e) {
      print('保存设置失败: $e');
    }
  }

  // API管理方法
  Future<void> addApi(ApiModel api) async {
    apis.add(api);
    await saveSettings();
  }

  Future<void> updateApi(ApiModel api) async {
    final index = apis.indexWhere((a) => a.id == api.id);
    if (index != -1) {
      apis[index] = api;
      await saveSettings();
    }
  }

  Future<void> deleteApi({required int id}) async {
    apis.removeWhere((a) => a.id == id);
    await saveSettings();
  }

  ApiModel? getApiByUrlAndModel(String url, String modelName) {
    return apis.firstWhereOrNull(
        (a) => a.url == url && a.modelName == modelName);
  }

  ApiModel? getApiById(int id) {
    return apis.firstWhereOrNull((a) => a.id == id);
  }
}