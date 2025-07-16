import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
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

  // 新增：用于排序的关系列表
  late List<MapEntry<int, Relation>> _relationList;

  @override
  void initState() {
    super.initState();
    _relations = Map.from(widget.relations);
    _relationList = _relations.entries.toList();
  }

  void _addRelation() async {
    final characters = _characterController.characters
        .where((c) => !_relations.containsKey(c.id))
        .toList();

    if (characters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可添加的角色')),
      );
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
        _relations[result.id] = Relation(targetId: result.id);
        _relationList = _relations.entries.toList();
        widget.onChanged(_relations);
      });
    }
  }

  void _removeRelation(int id) {
    setState(() {
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
      // 重新生成 _relations 保持顺序
      _relations = {for (var e in _relationList) e.key: e.value};
      widget.onChanged(_relations);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 用 ReorderableListView 替换原来的 Column
        SizedBox(
          height: 56.0 * _relationList.length + 80, // 估算高度，防止溢出
          child: ReorderableListView(
            clipBehavior: Clip.antiAliasWithSaveLayer,
            shrinkWrap: true,
            physics: const ScrollPhysics(),
            onReorder: _onReorder,
            children: [
              for (final entry in _relationList)
                Padding(
                  key: ValueKey(entry.key),
                  padding: const EdgeInsets.only(bottom: 16),
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
                                  backgroundImage: _characterController.getCharacterById(entry.key).avatar.isNotEmpty
                                      ? FileImage(File(_characterController.getCharacterById(entry.key).avatar))
                                      : null,
                                  child: _characterController.getCharacterById(entry.key).avatar.isEmpty
                                      ? Text(_characterController.getCharacterById(entry.key).roleName[0])
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Text(_characterController.getCharacterById(entry.key).roleName),
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
                            TextFormField(
                              initialValue: entry.value.brief ?? '',
                              decoration: const InputDecoration(
                                hintText: '关系描述（可选）',
                              ),
                              style: TextStyle(fontSize: 13),
                              maxLines: null,
                              minLines: 2,
                              onChanged: (value) {
                                entry.value.brief = value;
                                widget.onChanged(_relations);
                              },
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
          ),
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
