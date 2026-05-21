import 'dart:convert';
import 'dart:io';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:get/get.dart';
import '../models/category_config.dart';
import '../models/character_model.dart';

class CharacterController extends GetxController {
  final RxList<CharacterModel> characters = <CharacterModel>[].obs;
  final String fileName = 'characters.json';

  final String categoryConfigFileName = 'contact_categories.json';
  final RxList<CategoryConfig> categoryConfigs = <CategoryConfig>[].obs;

  Rx<CharacterModel?> characterCilpBoard = Rx(null);

  final VaultSettingController _vaultSettingController = Get.find();

  // 按category字段分组（排除临时角色）
  Map<String, List<CharacterModel>> get groupedCharacters {
    final Map<String, List<CharacterModel>> grouped = {};
    for (var character in characters.where((c) => c.bindStoryId == null)) {
      if (!grouped.containsKey(character.category)) {
        grouped[character.category] = [];
      }
      grouped[character.category]!.add(character);
    }
    return grouped;
  }

  // 系统内建角色
  static final defaultCharacter = CharacterModel(
      id: -1,
      remark: "内置角色",
      roleName: 'AI助手',
      avatar: "",
      category: "",
      messageStyle: MessageStyle.common);

  static const SUMMARY_CHARACTER_ID = -2;
  static final summaryCharacter = CharacterModel(
      id: SUMMARY_CHARACTER_ID,
      remark: '总结姬',
      roleName: '总结姬',
      avatar: '',
      category: '',
      messageStyle: MessageStyle.summary);

  int? get myId => _vaultSettingController.myId.value;
  set myId(val) {
    _vaultSettingController.myId.value = val;
  }

  @override
  void onInit() {
    super.onInit();
    loadCharacters();
    loadCategoryConfigs();
  }

  // 从本地加载角色数据
  Future<void> loadCharacters() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$fileName');

      if (await file.exists()) {
        final String contents = await file.readAsString();

        final List<dynamic> jsonList = json.decode(contents);
        characters.value =
            jsonList.map((json) => CharacterModel.fromJson(json)).toList();

        if (!characters.any((char) => char.id == 0)) {
          characters.insert(
              0,
              CharacterModel(
                id: 0,
                roleName: '我',
                avatar: '',
                category: '',
                remark: '默认角色',
                messageStyle: MessageStyle.common,
              ));
        }
      }
    } catch (e) {
      print('加载角色数据失败: $e');
      Get.snackbar("ERROT", "Load Char Failed");
    }
  }

  // 保存角色数据到本地
  Future<void> saveCharacters() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$fileName');

      final String jsonString = json.encode(
        characters.map((char) => char.toJson()).toList(),
      );
      await file.writeAsString(jsonString);
    } catch (e) {
      print('保存角色数据失败: $e');
      Get.snackbar('角色数据保存失败', '$e');
      rethrow;
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
      print('加载联系人分组配置失败: $e');
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
      print('保存联系人分组配置失败: $e');
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

  // 重命名分组，级联更新角色
  Future<void> renameCategory(String oldName, String newName) async {
    if (oldName == newName) return;
    final index = categoryConfigs.indexWhere((c) => c.name == oldName);
    if (index >= 0) {
      categoryConfigs[index].name = newName;
    }
    for (int i = 0; i < characters.length; i++) {
      if (characters[i].category == oldName) {
        characters[i].category = newName;
      }
    }
    await saveCategoryConfigs();
    await saveCharacters();
  }

  // 删除分组，将下属角色的 category 清空
  Future<void> deleteCategory(String name) async {
    categoryConfigs.removeWhere((c) => c.name == name);
    for (int i = 0; i < characters.length; i++) {
      if (characters[i].category == name) {
        characters[i].category = '';
      }
    }
    await saveCategoryConfigs();
    await saveCharacters();
  }

  // 重新排序分组 TODO:有问题
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

  // 添加新角色
  Future<void> addCharacter(CharacterModel character) async {
    characters.add(character);
    await saveCharacters();
  }

  // 更新角色
  Future<void> updateCharacter(CharacterModel character) async {
    final index = characters.indexWhere((char) => char.id == character.id);
    if (index != -1) {
      characters[index] = character;
      await saveCharacters();
    }
  }

  // 删除角色
  Future<void> deleteCharacter(int id) async {
    characters.removeWhere((char) => char.id == id);
    await saveCharacters();
  }

  // 根据ID获取角色
  CharacterModel getCharacterById(int id) {
    if (id == SUMMARY_CHARACTER_ID) {
      return summaryCharacter;
    }

    return characters.firstWhereOrNull((char) => char.id == id) ??
        defaultCharacter;
  }

  // 根据类别筛选角色
  List<CharacterModel> getCharactersByCategory(String category) {
    return characters.where((char) => char.category == category).toList();
  }

  CharacterModel get me => getCharacterById(myId ?? 0);

  // 添加新方法
  Future<void> setRelation(int targetId, {String? type}) async {
    if (myId == null || myId == targetId) return;

    var relation = me.relations[targetId] ?? Relation(targetId: targetId);
    relation.type = type;
    me.relations[targetId] = relation;
    await saveCharacters();
  }

  Future<void> removeRelation(int targetId) async {
    if (myId == null) return;
    me.relations.remove(targetId);
    await saveCharacters();
  }

  // 获取所有角色的关系数据，并转换为一个类似list的json字符串
  List<Map<String, dynamic>> getAllRelationsJson() {
    final List<Map<String, dynamic>> relationList = [];
    final Set<String> seenPairs = {};

    for (var character in characters) {
      final List<Map<String, dynamic>> nextList = [];
      for (var rel in character.relations.values) {
        final pairKey = character.id < rel.targetId
            ? '${character.id}_${rel.targetId}'
            : '${rel.targetId}_${character.id}';

        // 只保留一条边（id小的发起的边）
        if (character.id < rel.targetId && !seenPairs.contains(pairKey)) {
          nextList.add({
            'outcome': rel.targetId.toString(),
            if (rel.type != null) 'type': rel.type,
            if (rel.brief != null) 'brief': rel.brief,
          });
          seenPairs.add(pairKey);
        }
      }
      relationList.add({
        'id': character.id.toString(),
        'next': nextList,
      });
    }
    return relationList;
  }

  static CharacterController get of => Get.find<CharacterController>();

  List<CharacterModel> getAllCharacters() {
    return characters.where((char) => char.bindStoryId == null).toList();
  }

  List<CharacterModel> getCharactersByStoryId(String storyId) {
    return characters.where((char) => char.bindStoryId == storyId).toList();
  }

  Future<void> deleteCharactersByStoryId(String storyId) async {
    characters.removeWhere((char) => char.bindStoryId == storyId);
    await saveCharacters();
  }
}
