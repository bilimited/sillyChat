import 'dart:convert';
import 'dart:io';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:get/get.dart';

class LoreBookController extends GetxController {
  final RxList<LorebookModel> lorebooks = <LorebookModel>[].obs;

  final Rx<LorebookItemModel?> lorebookItemClipboard =
      Rx<LorebookItemModel?>(null);

  // 全局激活的世界书
  final RxList<int> globalActivitedLoreBookIds = <int>[].obs;
  List<LorebookModel> get globalActivitedLoreBooks => globalActivitedLoreBookIds
      .map((i) => getLorebookById(i))
      .nonNulls
      .toList();

  final String fileName = 'lorebooks.json';

  @override
  void onInit() {
    super.onInit();
    loadLorebooks();
  }

  // 加载世界书和激活的世界书ID
  Future<void> loadLorebooks() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$fileName');
      if (await file.exists()) {
        final String contents = await file.readAsString();
        final Map<String, dynamic> jsonMap = json.decode(contents);
        final List<dynamic> lorebookList = jsonMap['lorebooks'] ?? [];
        final List<dynamic> activatedList =
            jsonMap['globalActivitedLoreBooks'] ?? [];
        lorebooks.value =
            lorebookList.map((json) => LorebookModel.fromJson(json)).toList();
        globalActivitedLoreBookIds.value = activatedList.cast<int>();
      }
    } catch (e) {
      print('加载世界书失败: $e');
    }
  }

  // 保存世界书和激活的世界书ID
  Future<void> saveLorebooks() async {
    try {
      final directory = await Get.find<SettingController>().getVaultPath();
      final file = File('${directory}/$fileName');
      final Map<String, dynamic> jsonMap = {
        'lorebooks': lorebooks.map((lorebook) => lorebook.toJson()).toList(),
        'globalActivitedLoreBooks': globalActivitedLoreBookIds.toList(),
      };
      final String jsonString = json.encode(jsonMap);
      await file.writeAsString(jsonString);
    } catch (e) {
      print('保存世界书失败: $e');
    }
  }

  // 添加世界书
  Future<void> addLorebook(LorebookModel lorebook) async {
    lorebooks.add(lorebook);
    await saveLorebooks();
  }

  // 更新世界书
  Future<void> updateLorebook(LorebookModel lorebook) async {
    final index = lorebooks.indexWhere((l) => l.id == lorebook.id);
    if (index != -1) {
      lorebooks[index] = lorebook;
      await saveLorebooks();
    }
  }

  // 删除世界书
  Future<void> deleteLorebook(int id) async {
    lorebooks.removeWhere((l) => l.id == id);
    await saveLorebooks();
  }

  // 根据ID获取世界书
  LorebookModel? getLorebookById(int id) {
    return lorebooks.firstWhereOrNull((l) => l.id == id);
  }

  void reorderLorebooks(int oldIndex, int newIndex) {
    final lorebook = lorebooks.removeAt(oldIndex);
    lorebooks.insert(newIndex, lorebook);
    update();
    saveLorebooks();
  }

  static LoreBookController get of => Get.find<LoreBookController>();
}
