import 'dart:convert';
import 'dart:io';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:get/get.dart';
import '../models/prompt_model.dart';

class PromptController extends GetxController {
  final RxList<PromptModel> prompts = <PromptModel>[].obs;
  final String fileName = 'prompts.json';
  final Rx<PromptSort> _sortMethod = PromptSort.timeDesc.obs;

  PromptSort get sortMethod => _sortMethod.value;
  set sortMethod(PromptSort value) => _sortMethod.value = value;

  @override
  void onInit() {
    super.onInit();
    loadPrompts();
  }



  // 从本地加载提示词数据
  Future<void> loadPrompts() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$fileName');

      if (await file.exists()) {
        final String contents = await file.readAsString();
        final List<dynamic> jsonList = json.decode(contents);
        print(contents);
        prompts.value =
            jsonList.map((json) => PromptModel.fromJson(json)).toList();
      }
    } catch (e) {
      print('加载提示词数据失败: $e');
    }
  }

  // 保存提示词数据到本地
  Future<void> savePrompts() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$fileName');

      final String jsonString = json.encode(
        prompts.where((prompt) => !prompt.isDefault).map((prompt) => prompt.toJson()).toList(),
      );
      await file.writeAsString(jsonString);
    } catch (e) {
      print('保存提示词数据失败: $e');
    }
  }

  // 添加新提示词
  Future<void> addPrompt(PromptModel prompt) async {
    prompts.add(prompt);
    await savePrompts();
  }

  // 更新提示词
  Future<void> updatePrompt(PromptModel prompt) async {
    final index = prompts.indexWhere((p) => p.id == prompt.id);
    if (index != -1) {
      prompts[index] = prompt;
      await savePrompts();
    }
  }

  // 删除提示词
  Future<void> deletePrompt(int id) async {
    prompts.removeWhere((p) => p.id == id);
    await savePrompts();
  }

  // 获取特定类别的提示词
  List<PromptModel> getPromptsByCategory(PromptCategory category) {
    return _sortPrompts(prompts.where((p) => p.category == category).toList());
  }

  // 获取自定义类别的提示词
  List<PromptModel> getPromptsByCustomCategory(String customCategory) {
    return prompts
        .where((p) =>
            p.category == PromptCategory.custom &&
            p.customCategory == customCategory)
        .toList();
  }

  // 根据名称和角色获取提示词
  PromptModel? getPromptByNameAndRole(String name, String role) {
    return prompts.firstWhereOrNull((p) => p.name == name && p.role == role);
  }

  // 根据ID获取提示词
  PromptModel? getPromptById(int id) {
    return prompts.firstWhereOrNull((p) => p.id == id);
  }

  void reorderPrompts(int oldIndex, int newIndex) {
    final prompt = prompts.removeAt(oldIndex);
    prompts.insert(newIndex, prompt);
    update();
    // 可选：保存新的排序到持久化存储
    savePrompts();
  }

  List<PromptModel> _sortPrompts(List<PromptModel> prompts) {
    switch (_sortMethod.value) {
      case PromptSort.timeAsc:
        return prompts..sort((a, b) => a.updateDate.compareTo(b.updateDate));
      case PromptSort.timeDesc:
        return prompts..sort((a, b) => b.updateDate.compareTo(a.updateDate));
      case PromptSort.name:
        return prompts..sort((a, b) => a.name.compareTo(b.name));
    }
  }
}

enum PromptSort {
  timeAsc,
  timeDesc,
  name,
}
