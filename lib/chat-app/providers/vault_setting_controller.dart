import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/constants.dart';
import 'package:flutter_example/chat-app/models/history_model.dart';
import 'package:flutter_example/chat-app/models/regex_model.dart';
import 'package:flutter_example/chat-app/models/settings/misc_setting_model.dart';
import 'package:flutter_example/chat-app/models/settings/chat_displaysetting_model.dart';
import 'package:flutter_example/chat-app/models/settings/prompt_setting_model.dart';
import 'package:flutter_example/chat-app/providers/base_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/themes.dart';
import 'package:flutter_example/chat-app/utils/fontManager.dart';
import 'package:flutter_example/chat-app/utils/init_app.dart';
import 'package:flutter_example/chat-app/widgets/theme_selector.dart';
import 'package:get/get.dart';
import 'dart:convert';
import 'dart:io';
import '../models/api_model.dart';

// 库配置
class VaultSettingController extends BaseController {
  final String vaultSettingFileName = 'settings.json';

  final RxList<ApiModel> apis = <ApiModel>[].obs;
  final Rx<int?> defaultApiId = Rx(null); // 如果没有设置默认API，则会自动选取第一个。
  final Rx<String> defaultModelName = Rx("未设置API");

  ApiModel? get defaultApi {
    if (defaultApiId.value == null) {
      return null;
    }
    return getApiById(defaultApiId.value!);
  }

  final RxList<RegexModel> regexes = <RegexModel>[].obs;
  final Rx<DateTime?> lastSyncTime = Rx<DateTime?>(null);
  final RxInt myId = 0.obs;
  late Rx<ChatDisplaySettingModel> displaySettingModel =
      ChatDisplaySettingModel().obs;
  late Rx<MiscSettingModel> miscSetting = MiscSettingModel(
          autoTitle_enabled: false,
          autoTitle_level: 1,
          autotitleOption: MiscSettingModel.defaultAutoTitleOption,
          summaryOption: MiscSettingModel.defaultSummaryOption,
          simulateUserOption: MiscSettingModel.defaultSimulateUserOption,
          genMemOption: MiscSettingModel.defaultGenMemOption)
      .obs;

  final RxBool isShowOnBoardPage = false.obs;
  final RxBool isFirstOpen = false.obs; // 该项目是否第一次启动

  late Rx<PromptSettingModel> promptSettingModel = PromptSettingModel().obs;

  Rx<ThemeData> themeLight = ThemeData().obs;

  Rx<ThemeData> themeNight = ThemeData().obs;

  String get lastSyncTimeString {
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
    markReady();
  }



  // 从本地加载设置
  Future<void> loadSettings() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$vaultSettingFileName');

      if (await file.exists()) {
        final String contents = await file.readAsString();
        final Map<String, dynamic> jsonMap = json.decode(contents);

        apis.value = (jsonMap['apis'] as List<dynamic>? ?? [])
            .map((item) => ApiModel.fromJson(item))
            .toList()
            .cast<ApiModel>();

        lastSyncTime.value = jsonMap['lastSyncTime'] != null
            ? DateTime.tryParse(jsonMap['lastSyncTime'])
            : null;
        myId.value = jsonMap['myId'] ?? 0;
        displaySettingModel.value = jsonMap['displaySettingModel'] != null
            ? ChatDisplaySettingModel.fromJson(jsonMap['displaySettingModel'])
            : ChatDisplaySettingModel();

        promptSettingModel.value = jsonMap['promptSettingModel'] != null
            ? PromptSettingModel.fromJson(jsonMap['promptSettingModel'])
            : PromptSettingModel();

        regexes.value = jsonMap['regexes'] != null
            ? (jsonMap['regexes'] as List<dynamic>)
                .map((item) => RegexModel.fromJson(item))
                .toList()
                .cast<RegexModel>()
            : <RegexModel>[];

        defaultApiId.value = jsonMap['defaultApi'] ?? -1;
        defaultModelName.value = jsonMap['defaultModelName'] ?? '未设置API';

        if (jsonMap['autoTileSetting'] != null) {
          miscSetting.value =
              MiscSettingModel.fromJson(jsonMap['autoTileSetting']);
        }
      } else {
        // 文件不存在：证明初次启动
        isShowOnBoardPage.value = true;
        isFirstOpen.value = true;
        debugPrint("检测到初次启动");
        displaySettingModel.value = ChatDisplaySettingModel();
      }

      if (displaySettingModel.value.CustomFontPath != null &&
          displaySettingModel.value.CustomFontPath!.isNotEmpty) {
        await FontManager.initCustomFont(
            displaySettingModel.value.GlobalFont ?? "",
            displaySettingModel.value.CustomFontPath ?? "");
      }

      updateThemeStardard(
          color: displaySettingModel.value.themeColor,
          fontName: displaySettingModel.value.GlobalFont);
    } catch (e) {
      print('加载设置失败: $e');
      displaySettingModel.value = ChatDisplaySettingModel();
    }
  }

  // 保存设置到本地
  Future<void> saveSettings() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$vaultSettingFileName');

      final Map<String, dynamic> jsonMap = {
        'vaultName': SettingController.currectValutName,
        'lastSyncTime': lastSyncTime.value?.toIso8601String(),
        'apis': apis.map((api) => api.toJson()).toList(),
        'defaultApi': defaultApiId.value,
        'regexes': regexes.map((reg) => reg.toJson()).toList(),
        'myId': myId.value,
        'displaySettingModel': displaySettingModel.toJson(),
        'promptSettingModel': promptSettingModel.toJson(),
        'autoTileSetting': miscSetting.toJson(),
        'defaultModelName': defaultModelName.value,
      };

      final String jsonString = json.encode(jsonMap);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('保存设置失败: $e');
    }
  }

  void updateTheme({String? fontName, String? themename}) {
    FlexScheme theme =
        schemeMap[themename ?? displaySettingModel.value.schemeName] ??
            Constants.DEFAULT_THEME;
    FlexScheme.sakura; // 默认使用sakura主题，如果未找到则使用sakura
    themeLight.value = SillyChatThemeBuilder.buildLight(
        theme, fontName ?? displaySettingModel.value.GlobalFont);
    themeNight.value = SillyChatThemeBuilder.buildNight(
        theme, fontName ?? displaySettingModel.value.GlobalFont);
  }

  void updateThemeStardard({String? fontName, Color? color}) {
    themeLight.value = SillyChatThemeBuilder.buildStandardLight(
        color ?? Colors.purpleAccent,
        fontName ?? displaySettingModel.value.GlobalFont);
    themeNight.value = SillyChatThemeBuilder.buildStandardNight(
        color ?? Colors.purpleAccent,
        fontName ?? displaySettingModel.value.GlobalFont);
  }

  // API管理方法
  Future<void> addApi(ApiModel api) async {
    if (apis.isEmpty) {
      defaultApiId.value = api.id;
    }
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
    if (id == defaultApiId.value && apis.isNotEmpty) {
      defaultApiId.value = apis.first.id;
    }
    await saveSettings();
  }

  @Deprecated('AI写的傻逼方法')
  ApiModel? getApiByUrlAndModel(String url, String modelName) {
    return apis
        .firstWhereOrNull((a) => a.url == url && a.modelName == modelName);
  }

  ApiModel? getApiById(int id) {
    return apis.firstWhereOrNull((a) => a.id == id);
  }

  static VaultSettingController of() {
    return Get.find<VaultSettingController>();
  }
}
