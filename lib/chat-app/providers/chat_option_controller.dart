import 'dart:convert';
import 'dart:io';
import 'package:flutter_example/chat-app/utils/RequestOptions.dart';
import 'package:get/get.dart';
import '../models/chat_option_model.dart';
import 'setting_controller.dart';

class ChatOptionController extends GetxController {
  final RxList<ChatOptionModel> chatOptions = <ChatOptionModel>[].obs;
  final String fileName = 'chat_options.json';

  ChatOptionModel get defaultOption => chatOptions.isEmpty
      ? ChatOptionModel.empty()
      : chatOptions[0];

  @override
  void onInit() {
    super.onInit();
    loadChatOptions();
  }

  // 从本地加载聊天选项数据
  Future<void> loadChatOptions() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$fileName');

      if (await file.exists()) {
        final String contents = await file.readAsString();
        final List<dynamic> jsonList = json.decode(contents);
        chatOptions.value =
            jsonList.map((json) => ChatOptionModel.fromJson(json)).toList();
      }
    } catch (e) {
      print('加载聊天选项数据失败: $e');
    }
  }

  // 保存聊天选项数据到本地
  Future<void> saveChatOptions() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$fileName');

      final String jsonString =
          json.encode(chatOptions.map((option) => option.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (e) {
      print('保存聊天选项数据失败: $e');
    }
  }

  // 添加新聊天选项
  Future<void> addChatOption(ChatOptionModel chatOption) async {
    chatOptions.add(chatOption);
    await saveChatOptions();
  }

  // 更新聊天选项
  Future<void> updateChatOption(ChatOptionModel chatOption, int? index) async {
    if (index == null) {
      index = chatOptions.indexWhere((option) => option.id == chatOption.id);
    }
    if (index >= 0 && index < chatOptions.length) {
      chatOptions[index] = chatOption;
      await saveChatOptions();
    }
  }

  // 删除聊天选项
  Future<void> deleteChatOption(int index) async {
    if (index >= 0 && index < chatOptions.length) {
      chatOptions.removeAt(index);
      await saveChatOptions();
    }
  }

  // 获取特定索引的聊天选项
  ChatOptionModel? getChatOptionByIndex(int index) {
    if (index >= 0 && index < chatOptions.length) {
      return chatOptions[index];
    }
    return null;
  }

  ChatOptionModel? getChatOptionById(int id) {
    return chatOptions.firstWhereOrNull((option) => option.id == id);
  }

  // 重新排序聊天选项
  void reorderChatOptions(int oldIndex, int newIndex) {
    final option = chatOptions.removeAt(oldIndex);
    chatOptions.insert(newIndex, option);
    update();
    saveChatOptions();
  }
}
