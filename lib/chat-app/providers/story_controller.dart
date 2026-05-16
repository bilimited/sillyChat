import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import '../models/story_model.dart';
import 'setting_controller.dart';

class StoryController extends GetxController {
  final RxList<StoryModel> stories = <StoryModel>[].obs;
  final String fileName = 'stories.json';

  StoryModel? get defaultStory => stories.isEmpty ? null : stories[0];

  @override
  void onInit() {
    super.onInit();
    loadStories();
  }

  // 从本地加载故事数据
  Future<void> loadStories() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$fileName');

      if (await file.exists()) {
        final String contents = await file.readAsString();
        final dynamic jsonData = json.decode(contents);

        // 兼容老数据格式（数组），新格式为对象包含 stories 字段
        List<dynamic> jsonList;
        if (jsonData is List) {
          jsonList = jsonData;
        } else if (jsonData is Map && jsonData['stories'] is List) {
          jsonList = jsonData['stories'];
        } else {
          jsonList = [];
        }

        stories.value =
            jsonList.map((json) => StoryModel.fromJson(json)).toList();
      }
    } catch (e) {
      Get.snackbar("加载故事数据失败", "$e");
      print('加载故事数据失败: $e');
    }
  }

  // 保存故事数据到本地
  Future<void> saveStories() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$fileName');

      final String jsonString = json.encode({
        'stories': stories.map((story) => story.toJson()).toList(),
      });
      await file.writeAsString(jsonString);
    } catch (e) {
      Get.snackbar("保存故事数据失败", "$e");
      print('保存故事数据失败: $e');
    }
  }

  // 添加新故事
  Future<void> addStory(StoryModel story) async {
    stories.add(story);
    await saveStories();
  }

  // 更新故事
  Future<void> updateStory(StoryModel story) async {
    final index = stories.indexWhere((s) => s.id == story.id);
    if (index >= 0) {
      stories[index] = story;
      await saveStories();
    }
  }

  // 删除故事
  Future<void> deleteStory(String id) async {
    stories.removeWhere((s) => s.id == id);
    await saveStories();
  }

  StoryModel? getStoryById(String id) {
    return stories.firstWhereOrNull((story) => story.id == id);
  }

  // 重新排序故事
  void reorderStories(int oldIndex, int newIndex) {
    final story = stories.removeAt(oldIndex);
    stories.insert(newIndex, story);
    update();
    saveStories();
  }

  static StoryController of() {
    return Get.find<StoryController>();
  }
}