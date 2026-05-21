import 'dart:convert';
import 'dart:io';
import 'package:flutter_example/chat-app/providers/base_controller.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import '../models/category_config.dart';
import '../models/story_model.dart';
import 'character_controller.dart';
import 'chat_controller.dart';
import 'setting_controller.dart';

class StoryController extends BaseController {
  final RxList<StoryModel> stories = <StoryModel>[].obs;
  final String fileName = 'stories.json';

  final String categoryConfigFileName = 'story_categories.json';
  final RxList<CategoryConfig> categoryConfigs = <CategoryConfig>[].obs;

  StoryModel? get defaultStory => stories.isEmpty ? null : stories[0];

  @override
  void onInit() async {
    super.onInit();
    await loadStories();
    await loadCategoryConfigs();
    await _migrateExtraFolders();
    markReady();
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

  // 加载分组配置
  Future<void> loadCategoryConfigs() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$categoryConfigFileName');
      if (await file.exists()) {
        final String contents = await file.readAsString();
        final List<dynamic> jsonList = json.decode(contents);
        categoryConfigs.value = jsonList
            .map((json) => CategoryConfig.fromJson(json))
            .toList();
      }
    } catch (e) {
      print('加载故事分组配置失败: $e');
    }
  }

  // 保存分组配置
  Future<void> saveCategoryConfigs() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$categoryConfigFileName');
      final String jsonString = json.encode(
        categoryConfigs.map((c) => c.toJson()).toList(),
      );
      await file.writeAsString(jsonString);
    } catch (e) {
      print('保存故事分组配置失败: $e');
    }
  }

  // 添加分组
  Future<void> addCategory(String name) async {
    if (categoryConfigs.any((c) => c.name == name)) return;
    final order = categoryConfigs.isEmpty
        ? 0
        : categoryConfigs.map((c) => c.order).reduce((a, b) => a > b ? a : b) + 1;
    categoryConfigs.add(CategoryConfig(name: name, order: order));
    await saveCategoryConfigs();
  }

  // 重命名分组，级联更新故事
  Future<void> renameCategory(String oldName, String newName) async {
    if (oldName == newName) return;
    final index = categoryConfigs.indexWhere((c) => c.name == oldName);
    if (index >= 0) {
      categoryConfigs[index].name = newName;
    }
    for (int i = 0; i < stories.length; i++) {
      if (stories[i].category == oldName) {
        stories[i].category = newName;
      }
    }
    await saveCategoryConfigs();
    await saveStories();
  }

  // 删除分组，将下属故事的 category 清空
  Future<void> deleteCategory(String name) async {
    categoryConfigs.removeWhere((c) => c.name == name);
    for (int i = 0; i < stories.length; i++) {
      if (stories[i].category == name) {
        stories[i].category = '';
      }
    }
    await saveCategoryConfigs();
    await saveStories();
  }

  // 重新排序分组
  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    final item = categoryConfigs.removeAt(oldIndex);
    categoryConfigs.insert(newIndex, item);
    for (int i = 0; i < categoryConfigs.length; i++) {
      categoryConfigs[i].order = i;
    }
    await saveCategoryConfigs();
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
    await Get.find<CharacterController>().deleteCharactersByStoryId(id);
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

  Future<void> _migrateExtraFolders() async {
    try {
      final vaultPath = await Get.find<SettingController>().getVaultPath();
      final chatsDir = Directory(p.join(vaultPath, 'chats'));

      if (!chatsDir.existsSync()) return;

      final entries = chatsDir.listSync();
      const knownDirs = {'roles', 'stories'};

      final extraDirs = entries
          .whereType<Directory>()
          .where((d) => !knownDirs.contains(p.basename(d.path)))
          .toList();

      final looseFiles = entries.whereType<File>().toList();

      if (extraDirs.isEmpty && looseFiles.isEmpty) return;

      await ChatController.of.ready;

      for (final extraDir in extraDirs) {
        await _migrateDirectory(extraDir, vaultPath); 
      }

      if (looseFiles.isNotEmpty) {
        await _createStoryFromFiles('未分类', looseFiles, vaultPath);
      }
    } catch (e) {
      print('数据迁移失败: $e');
    }
  }

  Future<void> _migrateDirectory(Directory dir, String vaultPath) async {
    final entries = dir.listSync();
    final subDirs = entries.whereType<Directory>().toList();
    final files = entries.whereType<File>().toList();

    for (final subDir in subDirs) {
      await _migrateDirectory(subDir, vaultPath);
    }

    if (files.isEmpty) {
      if (dir.existsSync()) {
        try {
          dir.deleteSync();
        } catch (_) {} 
      }
      return;
    }

    await _createStoryFromFiles(p.basename(dir.path), files, vaultPath);

    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> _createStoryFromFiles(
      String name, List<File> files, String vaultPath) async {
    final story = StoryModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      remark: '',
      story_prompt: '',
      category: '从旧版本导入'
    );
    stories.add(story);

    final targetDirPath = p.join(vaultPath, 'chats', 'stories', story.id);
    final targetDir = Directory(targetDirPath);
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }

    final chatController = ChatController.of;

    for (final file in files) {
      final oldPath = p.canonicalize(file.path);
      final fileName = p.basename(file.path);
      var newPath = p.canonicalize(p.join(targetDirPath, fileName));

      int counter = 2;
      while (File(newPath).existsSync()) {
        final baseName = p.basenameWithoutExtension(fileName);
        final extension = p.extension(fileName);
        newPath = p.canonicalize(
            p.join(targetDirPath, '$baseName($counter)$extension'));
        counter++;
      }

      await file.rename(newPath);

      final meta = chatController.chatIndex[oldPath];
      if (meta != null) {
        chatController.chatIndex.remove(oldPath);
        chatController.chatIndex[newPath] = meta.copyWith(path: newPath);
      }

      for (int i = 0; i < chatController.recentChats.length; i++) {
        if (p.equals(p.canonicalize(chatController.recentChats[i].path), oldPath)) {
          chatController.recentChats[i] =
              chatController.recentChats[i].copyWith(path: newPath);
        }
      }
    }

    await saveStories();
    await chatController.saveChatIndex();
    await chatController.saveRecentChats();
  }

  static StoryController of() {
    return Get.find<StoryController>();
  }
}
