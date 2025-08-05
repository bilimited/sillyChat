import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/character/edit_character_page.dart';
import 'package:flutter_example/chat-app/pages/character/personal_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STCharacterImporter.dart';
import 'package:get/get.dart';
import '../../models/character_model.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({Key? key}) : super(key: key);

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final Map<String, bool> _expandedState = {};
  bool _isSortingMode = false; // 控制排序模式
  final characterController = Get.find<CharacterController>();

  // 新增：搜索控制器和响应式字符串
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchText = ''.obs;

  @override
  void initState() {
    super.initState();
    // 监听搜索框文本变化
    _searchController.addListener(() {
      _searchText.value = _searchController.text;
    });
  }

  @override
  void dispose() {
    _searchController.dispose(); // 释放控制器
    super.dispose();
  }

  Future<void> _importCharCard() async {
    // 使用file_picker选择PNG文件
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png'],
      dialogTitle: '选择角色卡PNG文件',
    );
    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final bytes = await file.readAsBytes();

    // 查找PNG的chara字段（tEXt chunk）
    // PNG文件格式: https://www.w3.org/TR/PNG/#5Chunk-layout
    // tEXt chunk格式: [length][tEXt][type][keyword][\0][text][CRC]
    // 这里只做简单查找，不做完整校验
    int offset = 8; // 跳过PNG头
    String? charaBase64;
    while (offset < bytes.length) {
      if (offset + 8 > bytes.length) break;
      final length = bytes.buffer.asByteData().getUint32(offset);
      final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
      if (type == 'tEXt') {
        final chunkData = bytes.sublist(offset + 8, offset + 8 + length);
        final nulIndex = chunkData.indexOf(0);
        if (nulIndex != -1) {
          final keyword = utf8.decode(chunkData.sublist(0, nulIndex));
          if (keyword == 'chara') {
            charaBase64 = utf8.decode(chunkData.sublist(nulIndex + 1));
            break;
          }
        }
      }
      offset += 8 + length + 4; // 8: length+type, length: data, 4: CRC
    }

    if (charaBase64 == null) {
      Get.snackbar('导入失败', '未找到chara字段');
      return;
    }

    try {
      final decoded = utf8.decode(base64.decode(charaBase64));

      try {
        final char = await STCharacterImporter.fromJson(
            json.decode(decoded), file.path, file.path);
        if (char != null) {
          characterController.addCharacter(char);
          Get.snackbar('导入成功', '角色卡已导入');
        }

         
      } catch (e) {
        Get.snackbar('导入失败', '$e');
      }

     
    } catch (e) {
      Get.snackbar('解码失败', '$e');
    }
  }

  // 处理搜索过滤后的分组
  Map<String, List<CharacterModel>> get _filteredAndGroupedContacts {
    // 如果搜索框为空，返回所有分组
    if (_searchText.value.isEmpty) {
      return characterController.characters
          .fold(<String, List<CharacterModel>>{}, (map, contact) {
        if (!map.containsKey(contact.category)) {
          map[contact.category] = [];
        }
        map[contact.category]!.add(contact);
        return map;
      });
    } else {
      // 如果有搜索文本，过滤后再分组
      final filteredContacts = characterController.characters
          .where((contact) =>
              contact.roleName
                  .toLowerCase()
                  .contains(_searchText.value.toLowerCase()) ||
              contact.category
                  .toLowerCase()
                  .contains(_searchText.value.toLowerCase()) ||
              (contact.brief?.toLowerCase() ?? '')
                  .contains(_searchText.value.toLowerCase()))
          .toList();

      return filteredContacts.fold(<String, List<CharacterModel>>{},
          (map, contact) {
        // 即使搜索，也保持分组逻辑，但只显示包含搜索词的组
        if (!map.containsKey(contact.category)) {
          map[contact.category] = [];
        }
        map[contact.category]!.add(contact);
        return map;
      });
    }
  }

  // 分组模式的视图 (根据搜索结果调整)
  Iterable<Column> _groupedContactsWidget(BuildContext context) {
    final theme = Theme.of(context);
    final groupedContacts = _filteredAndGroupedContacts;

    // 如果搜索结果为空，显示提示
    if (groupedContacts.isEmpty && _searchText.value.isNotEmpty) {
      return [
        Column(
          children: [
            const SizedBox(height: 50),
            Icon(Icons.search_off, size: 60, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text('未找到匹配的角色',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ];
    }

    return groupedContacts.entries.map((entry) {
      // 确保每个组在 _expandedState 中有状态，默认展开
      _expandedState.putIfAbsent(entry.key, () => true);
      return Column(
        children: [
          // 分组标题 (搜索时可能总是展开)
          ListTile(
            title: Text(
              "${entry.key} (${entry.value.length})",
              style: TextStyle(
                color: theme.colorScheme.outline,
                fontSize: 14,
              ),
            ),
            trailing: _searchText.value.isEmpty // 搜索时隐藏展开图标
                ? AnimatedRotation(
                    turns: _expandedState[entry.key]! ? 0.5 : 0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.fastOutSlowIn,
                    child: const Icon(Icons.expand_more),
                  )
                : null,
            onTap: _searchText.value.isEmpty // 搜索时禁用标题点击
                ? () {
                    setState(() {
                      _expandedState[entry.key] = !_expandedState[entry.key]!;
                    });
                  }
                : null,
          ),
          // 分组内容
          if (_searchText.value.isNotEmpty || _expandedState[entry.key]!)
            ClipRect(
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: Column(
                  children: entry.value
                      .map((contact) => _contractWidget(context, contact))
                      .toList(),
                ),
              ),
            ),
        ],
      );
    });
  }

  // 排序模式的视图 (根据搜索结果调整)
  Widget _reorderableListWidget(BuildContext context) {
    List<CharacterModel> itemsToDisplay;
    if (_searchText.value.isEmpty) {
      itemsToDisplay = characterController.characters;
    } else {
      itemsToDisplay = characterController.characters
          .where((contact) =>
              contact.roleName
                  .toLowerCase()
                  .contains(_searchText.value.toLowerCase()) ||
              contact.category
                  .toLowerCase()
                  .contains(_searchText.value.toLowerCase()) ||
              (contact.brief?.toLowerCase() ?? '')
                  .contains(_searchText.value.toLowerCase()))
          .toList();
    }

    // 如果搜索结果为空且处于排序模式
    if (itemsToDisplay.isEmpty && _searchText.value.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off,
                size: 60, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('未找到匹配的角色',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      );
    }

    return ReorderableListView.builder(
      itemCount: itemsToDisplay.length,
      itemBuilder: (context, index) {
        final contact = itemsToDisplay[index];
        return Container(
          key: ValueKey(contact.id),
          child: _contractWidget(context, contact),
        );
      },
      onReorder: (int oldIndex, int newIndex) {
        // 注意：搜索模式下的排序可能需要更复杂的逻辑来映射回原始列表
        // 这里简化处理：只在未搜索时允许排序原始列表
        if (_searchText.value.isNotEmpty) {
          // 如果在搜索结果中排序，只更新 itemsToDisplay 的顺序（不会影响原始数据）
          // 或者禁用搜索时的排序
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先清除搜索以对所有角色进行排序')),
          );
          return;
        }

        setState(() {
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          final character = characterController.characters.removeAt(oldIndex);
          characterController.characters.insert(newIndex, character);
        });
      },
    );
  }

  ListTile _contractWidget(BuildContext context, CharacterModel contact) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundImage: Image.file(File(contact.avatar)).image,
            radius: 29,
          ),
        ],
      ),
      trailing: _isSortingMode
          ? const Icon(Icons.drag_handle) // 排序模式下显示拖拽图标
          : IconButton(
              onPressed: () {
                customNavigate(PersonalPage(character: contact),
                    context: context);
              },
              icon: Icon(Icons.chevron_right)),
      title: Text(contact.roleName),
      subtitle: contact.brief != null
          ? Text(
              contact.brief!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
              maxLines: 2,
            )
          : null,
      onTap: () {
        // 排序模式下禁用点击事件
        if (_isSortingMode) return;
        customNavigate(EditCharacterPage(characterId: contact.id),
            context: context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // 使用 AppBar
      appBar: AppBar(
        // AppBar 标题区域放置搜索框
        title: Container(
          height: 40, // 设置一个合适的高度
          decoration: BoxDecoration(
            color: theme.colorScheme.surface, // 背景色匹配原来的设计
            borderRadius: BorderRadius.circular(20.0), // 圆角
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索角色',
              hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              prefixIcon: Icon(
                Icons.search,
                color: theme.colorScheme.onSurfaceVariant,
                size: 20, // 调整图标大小
              ),
              prefixIconConstraints: const BoxConstraints(
                minHeight: 32, minWidth: 32, // 调整图标约束
              ),
              // 移除默认边框和填充，使用 Container 的装饰
              // border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              // 可选：添加清除按钮
              suffixIcon: _searchText.value.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          size: 20, color: theme.colorScheme.onSurfaceVariant),
                      onPressed: () {
                        _searchController.clear();
                        _searchText.value = '';
                      },
                    )
                  : null,
            ),
            style: TextStyle(color: theme.colorScheme.onSurface),
            cursorColor: theme.colorScheme.primary,
          ),
        ),
        // AppBar 操作区域放置按钮
        actions: [
          // 新增角色按钮
          PopupMenuButton<int>(
            icon: Icon(Icons.add, color: theme.colorScheme.onSurface),
            tooltip: '新增角色', // 添加提示

            onSelected: (value) {
              if (value == 0) {
                // 创建空角色
                customNavigate(const EditCharacterPage(), context: context);
              } else if (value == 1) {
                _importCharCard();
              } else if (value == 2 &&
                  characterController.characterCilpBoard != null) {
                characterController
                    .addCharacter(characterController.characterCilpBoard!);
                characterController.characterCilpBoard = null;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 0,
                child: Row(
                  children: [
                    const Icon(Icons.person_add, size: 20),
                    const SizedBox(width: 8),
                    const Text('创建空角色'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    const Icon(Icons.file_upload, size: 20),
                    const SizedBox(width: 8),
                    const Text('从ST导入角色卡'),
                  ],
                ),
              ),
              if (characterController.characterCilpBoard != null)
                PopupMenuItem(
                  value: 2,
                  child: Row(
                    children: [
                      const Icon(Icons.paste, size: 20),
                      const SizedBox(width: 8),
                      const Text('从剪切板粘贴角色'),
                    ],
                  ),
                ),
            ],
          ),
          // 排序模式切换按钮
          IconButton(
            icon: Icon(_isSortingMode ? Icons.check : Icons.sort,
                color: theme.colorScheme.onSurface),
            onPressed: () {
              setState(() {
                _isSortingMode = !_isSortingMode;
              });
            },
            tooltip: _isSortingMode ? '完成排序' : '进入排序', // 添加提示
          ),
          const SizedBox(width: 8), // 右边距
        ],
        // 可以根据需要调整 AppBar 的背景色等
        backgroundColor: theme.appBarTheme.backgroundColor ??
            theme.colorScheme.surface, // 使用主题色或默认surface色
        elevation: theme.appBarTheme.elevation ?? 0, // 控制阴影
      ),
      body: Obx(() {
        // 根据是否为排序模式来决定显示哪个视图
        if (_isSortingMode) {
          return _reorderableListWidget(context);
        } else {
          return ListView(
            children: [
              ..._groupedContactsWidget(context),
            ],
          );
        }
      }),
      // 移除原来的 floatingActionButton
      // floatingActionButton: ...
    );
  }
}
