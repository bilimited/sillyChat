import 'dart:convert';
import 'dart:io';
import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/providers/base_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:get/get.dart';

class LoreBookController extends BaseController {
  final RxList<LorebookModel> lorebooks = <LorebookModel>[].obs;

  final Rx<LorebookItemModel?> lorebookItemClipboard =
      Rx<LorebookItemModel?>(null);

  // 全局激活的世界书
  final RxList<int> globalActivitedLoreBookIds = <int>[].obs;
  List<LorebookModel> get globalActivitedLoreBooks => globalActivitedLoreBookIds
      .map((i) => getLorebookById(i))
      .nonNulls
      .toList();

  static const String lorebookDirName = 'lorebooks';
  static const String globalActivationFileName = '_global_activation.json';

  // 旧格式文件名，用于迁移检测
  static const String oldFileName = 'lorebooks.json';

  @override
  void onInit() async {
    super.onInit();
    await loadLorebooks();
    markReady();
  }

  /// 获取 lorebooks 目录路径
  Future<Directory> _getLorebookDir() async {
    final vaultPath = await Get.find<SettingController>().getVaultPath();
    return Directory('$vaultPath/$lorebookDirName');
  }

  /// 获取激活配置文件
  Future<File> _getActivationFile() async {
    final dir = await _getLorebookDir();
    return File('${dir.path}/$globalActivationFileName');
  }

  /// 获取单个 lorebook 文件
  Future<File> _getLorebookFile(int id) async {
    final dir = await _getLorebookDir();
    return File('${dir.path}/$id.json');
  }

  /// 加载激活 ID 配置文件
  Future<void> _loadActivationIds() async {
    final file = await _getActivationFile();
    if (await file.exists()) {
      try {
        final contents = await file.readAsString();
        final jsonMap = json.decode(contents);
        final list = jsonMap['globalActivitedLoreBookIds'] as List<dynamic>?;
        globalActivitedLoreBookIds.value = list?.cast<int>() ?? [];
      } catch (e) {
        print('加载世界书激活配置失败: $e');
        globalActivitedLoreBookIds.value = [];
      }
    }
  }

  /// 保存激活 ID 配置文件
  Future<void> _saveActivationIds() async {
    final file = await _getActivationFile();
    final jsonMap = {
      'globalActivitedLoreBookIds': globalActivitedLoreBookIds.toList(),
    };
    await file.writeAsString(json.encode(jsonMap));
  }

  /// 从旧的 lorebooks.json 迁移到新的独立文件格式
  Future<void> _migrateFromOldFormat(String vaultPath) async {
    final oldFile = File('$vaultPath/$oldFileName');
    if (!await oldFile.exists()) return;

    try {
      final contents = await oldFile.readAsString();
      final jsonMap = json.decode(contents);
      final List<dynamic> lorebookList = jsonMap['lorebooks'] ?? [];
      final List<dynamic> activatedList =
          jsonMap['globalActivitedLoreBooks'] ?? [];

      // 确保目录存在
      final dir = await _getLorebookDir();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 逐个写出 lorebook 文件
      for (final lbJson in lorebookList) {
        final lorebook = LorebookModel.fromJson(lbJson);
        final lbFile = await _getLorebookFile(lorebook.id);
        await lbFile.writeAsString(json.encode(lorebook.toJson()));
      }

      // 写出激活配置
      globalActivitedLoreBookIds.value = activatedList.cast<int>();
      await _saveActivationIds();

      // 迁移成功后删除旧文件
      await oldFile.delete();
      print('世界书数据已从 lorebooks.json 迁移到 lorebooks/ 目录');
    } catch (e) {
      print('迁移世界书数据失败: $e');
      // 迁移失败时不清除旧文件，下次启动会重试
    }
  }

  /// 加载世界书和激活的世界书ID
  Future<void> loadLorebooks() async {
    try {
      final vaultPath = await Get.find<SettingController>().getVaultPath();

      // 检查是否需要从旧格式迁移
      final oldFile = File('$vaultPath/$oldFileName');
      if (await oldFile.exists()) {
        await _migrateFromOldFormat(vaultPath);
      }

      // 从新格式加载
      final dir = await _getLorebookDir();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      await _loadActivationIds();

      final List<LorebookModel> loadedList = [];
      final entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.json')) {
          final filename = entity.uri.pathSegments.last;
          // 跳过激活配置文件
          if (filename == globalActivationFileName) continue;

          try {
            final contents = await entity.readAsString();
            final jsonMap = json.decode(contents);
            loadedList.add(LorebookModel.fromJson(jsonMap));
          } catch (e) {
            print('加载世界书文件失败 (${entity.path}): $e');
            // 跳过损坏的文件，继续加载其他文件
          }
        }
      }

      lorebooks.value = loadedList;
    } catch (e) {
      print('加载世界书失败: $e');
    }
  }

  /// 保存全部世界书和激活ID到独立文件
  Future<void> saveLorebooks() async {
    try {
      lorebooks.refresh();

      final dir = await _getLorebookDir();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 收集当前有效的 lorebook ID
      final validIds = lorebooks.map((lb) => lb.id).toSet();

      // 清理不再存在的 lorebook 文件
      final entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.json')) {
          final filename = entity.uri.pathSegments.last;
          if (filename == globalActivationFileName) continue;

          // 从文件名提取 ID
          final fileId = int.tryParse(filename.replaceAll('.json', ''));
          if (fileId != null && !validIds.contains(fileId)) {
            try {
              await entity.delete();
            } catch (e) {
              print('删除过期世界书文件失败 (${entity.path}): $e');
            }
          }
        }
      }

      // 写出每个 lorebook
      for (final lorebook in lorebooks) {
        final file = await _getLorebookFile(lorebook.id);
        await file.writeAsString(json.encode(lorebook.toJson()));
      }

      // 写出激活配置
      await _saveActivationIds();
    } catch (e) {
      print('保存世界书失败: $e');
    }
  }

  /// 保存单个 lorebook 到文件
  Future<void> _saveLorebook(LorebookModel lorebook) async {
    try {
      final dir = await _getLorebookDir();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = await _getLorebookFile(lorebook.id);
      await file.writeAsString(json.encode(lorebook.toJson()));
    } catch (e) {
      print('保存世界书文件失败 (${lorebook.id}): $e');
    }
  }

  /// 删除单个 lorebook 文件
  Future<void> _deleteLorebookFile(int id) async {
    try {
      final file = await _getLorebookFile(id);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('删除世界书文件失败 ($id): $e');
    }
  }

  // 添加世界书
  Future<void> addLorebook(LorebookModel lorebook) async {
    lorebooks.add(lorebook);
    await _saveLorebook(lorebook);
  }

  // 更新世界书
  Future<void> updateLorebook(LorebookModel lorebook) async {
    final index = lorebooks.indexWhere((l) => l.id == lorebook.id);
    if (index != -1) {
      lorebooks[index] = lorebook;
      await _saveLorebook(lorebook);
    }
  }

  // 删除世界书
  Future<void> deleteLorebook(int id) async {
    lorebooks.removeWhere((l) => l.id == id);
    // 同时从全局激活列表中移除
    globalActivitedLoreBookIds.remove(id);
    await _deleteLorebookFile(id);
    await _saveActivationIds();
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

  /// 保存全局激活状态（供外部直接修改 globalActivitedLoreBookIds 后调用）
  Future<void> saveActivationState() async {
    await _saveActivationIds();
  }

  static LoreBookController get of => Get.find<LoreBookController>();
}
