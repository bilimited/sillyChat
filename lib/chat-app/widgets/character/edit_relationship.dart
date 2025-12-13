import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/widgets/expandable_text_field.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import '../../models/character_model.dart';
import '../../providers/character_controller.dart';

class EditRelationship extends StatefulWidget {
  final Map<int, Relation> relations;
  final Function(Map<int, Relation>) onChanged;
  final CharacterModel? character;

  const EditRelationship({
    Key? key,
    required this.relations,
    required this.onChanged,
    this.character,
  }) : super(key: key);

  @override
  State<EditRelationship> createState() => _EditRelationshipState();
}

class _EditRelationshipState extends State<EditRelationship> {
  final _characterController = Get.find<CharacterController>();

  late Map<int, Relation> _relations;
  late List<MapEntry<int, Relation>> _relationList;

  // 新增：用于管理每个关系描述输入框的控制器
  // 使用角色的 ID 作为键，以便轻松查找。
  late Map<int, TextEditingController> _briefControllers;

  @override
  void initState() {
    super.initState();
    _relations = Map.from(widget.relations);
    _relationList = _relations.entries.toList();

    // 初始化控制器 Map
    _briefControllers = {};
    // 为每个已存在的关系创建一个 TextEditingController
    for (var entry in _relationList) {
      _createBriefController(entry.key, entry.value.brief);
    }
  }

  // 新增：封装创建和监听 Controller 的逻辑
  void _createBriefController(int characterId, String? initialText) {
    final controller = TextEditingController(text: initialText ?? '');
    controller.addListener(() {
      // 当控制器的文本改变时，更新数据模型...
      _relations[characterId]?.brief = controller.text;
      // ...并触发外部的回调函数
      widget.onChanged(_relations);
    });
    _briefControllers[characterId] = controller;
  }

  @override
  void dispose() {
    // 销毁所有控制器以防止内存泄漏
    for (var controller in _briefControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addRelation() async {
    final characters = _characterController.characters
        .where((c) => !_relations.containsKey(c.id))
        .toList();

    if (characters.isEmpty) {
      Get.snackbar('没有可添加的角色', '', messageText: SizedBox.shrink());
      return;
    }

    final result = await Get.to(() => CharacterSelector(excludeCharacters: [
          if (widget.character != null) widget.character!,
          ..._characterController.characters
              .where((c) => _relations.containsKey(c.id))
              .toList()
        ]));

    if (result != null) {
      setState(() {
        final newRelation = Relation(targetId: result.id);
        _relations[result.id] = newRelation;
        _relationList = _relations.entries.toList();

        // 为新的关系创建一个新的控制器
        _createBriefController(result.id, newRelation.brief);

        widget.onChanged(_relations);
      });
    }
  }

  void _removeRelation(int id) {
    setState(() {
      // 在移除关系之前，先销毁并移除对应的控制器
      _briefControllers[id]?.dispose();
      _briefControllers.remove(id);

      _relations.remove(id);
      _relationList = _relations.entries.toList();
      widget.onChanged(_relations);
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _relationList.removeAt(oldIndex);
      _relationList.insert(newIndex, item);
      _relations = {for (var e in _relationList) e.key: e.value};
      widget.onChanged(_relations);
    });
  }

  void _syncRelation(int id) {
    String? brief = _relations[id]?.brief;
    String? type = _relations[id]?.type;
    CharacterModel target =
        Get.find<CharacterController>().getCharacterById(id);
    if (brief != null &&
        target != CharacterController.defaultCharacter &&
        widget.character != null) {
      int curId = widget.character!.id;
      if (target.relations[curId] != null) {
        target.relations[curId]!.brief = brief;
      } else {
        target.relations[curId] = Relation(targetId: curId)
          ..brief = brief
          ..type = type;
      }

      Get.find<CharacterController>().updateCharacter(target);
      SillyChatApp.snackbar(context, '关系同步成功');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 56.0 * _relationList.length + 80,
          child: ShaderMask(
              shaderCallback: (Rect bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.06, 0.94, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.dstIn,
              child: ReorderableListView(
                clipBehavior: Clip.antiAliasWithSaveLayer,
                shrinkWrap: true,
                physics: const ScrollPhysics(),
                onReorder: _onReorder,
                children: [
                  for (final entry in _relationList)
                    Padding(
                      key: ValueKey(entry.key),
                      padding: const EdgeInsets.only(bottom: 16, top: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: _characterController
                                              .getCharacterById(entry.key)
                                              .avatar
                                              .isNotEmpty
                                          ? FileImage(File(_characterController
                                              .getCharacterById(entry.key)
                                              .avatar))
                                          : null,
                                      child: _characterController
                                              .getCharacterById(entry.key)
                                              .avatar
                                              .isEmpty
                                          ? Text(_characterController
                                              .getCharacterById(entry.key)
                                              .roleName[0])
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(_characterController
                                        .getCharacterById(entry.key)
                                        .roleName),
                                    const Text(' 是我的 '),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: entry.value.type ?? '',
                                        decoration: const InputDecoration(
                                          hintText: '关系',
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                        ),
                                        onChanged: (value) {
                                          entry.value.type = value;
                                          widget.onChanged(_relations);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ExpandableTextField(
                                  controller: _briefControllers[entry.key]!,
                                  decoration: const InputDecoration(
                                    hintText: '关系描述（可选）',
                                  ),
                                  style: TextStyle(fontSize: 13),
                                  maxLines: null,
                                  minLines: 2,
                                  extraActions: [
                                    buildIconTextButton(context,
                                        text: '同步关系',
                                        icon: Icons.sync_rounded,
                                        onPressed: () =>
                                            _syncRelation(entry.key))
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeRelation(entry.key),
                          ),
                        ],
                      ),
                    ),
                ],
              )),
        ),
        TextButton.icon(
          onPressed: _addRelation,
          icon: const Icon(Icons.add),
          label: const Text('添加关系'),
        ),
      ],
    );
  }
}
