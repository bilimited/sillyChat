import 'dart:convert';
import 'dart:io';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:get/get.dart';
import '../models/character_model.dart';

class CharacterController extends GetxController {
  final RxList<CharacterModel> characters = <CharacterModel>[].obs;
  final String fileName = 'characters.json';

  CharacterModel? characterCilpBoard = null;

  final VaultSettingController _vaultSettingController = Get.find();

  // 系统内建角色
  static final defaultCharacter = CharacterModel(
      id: -1,
      remark: "内置角色",
      roleName: 'AI助手',
      avatar: "",
      category: "",
      messageStyle: MessageStyle.common);

  int? get myId => _vaultSettingController.myId.value;
  set myId(val) {
    _vaultSettingController.myId.value = val;
  }

  @override
  void onInit() {
    super.onInit();
    loadCharacters();
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
}
