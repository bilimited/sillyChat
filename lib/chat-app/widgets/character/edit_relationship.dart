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

  @override
  void initState() {
    super.initState();
    _relations = Map.from(widget.relations);
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
        widget.onChanged(_relations);
      });
    }
  }

  void _removeRelation(int id) {
    setState(() {
      _relations.remove(id);
      widget.onChanged(_relations);
    });
  }

  @override
  void dispose() {
    print("--- dispose");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._relations.entries.map((entry) {
          final targetChar = _characterController.getCharacterById(entry.key);
          final relation = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              key: Key(targetChar.id.toString()),
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
                            backgroundImage: targetChar.avatar.isNotEmpty
                                ? FileImage(File(targetChar.avatar))
                                : null,
                            child: targetChar.avatar.isEmpty
                                ? Text(targetChar.roleName[0])
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Text(targetChar.roleName),
                          const Text(' 是我的 '),
                          Expanded(
                            child: TextFormField(
                              initialValue: relation.type ?? '',
                              decoration: const InputDecoration(
                                hintText: '关系',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                              ),
                              onChanged: (value) {
                                relation.type = value;
                                widget.onChanged(_relations);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: relation.brief ?? '',
                        decoration: const InputDecoration(
                          hintText: '关系描述（可选）',
                          border: OutlineInputBorder(),
                        ),
                        style: TextStyle(fontSize: 13),
                        maxLines: null,
                        minLines: 2,
                        onChanged: (value) {
                          relation.brief = value;
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
          );
        }).toList(),
        TextButton.icon(
          onPressed: _addRelation,
          icon: const Icon(Icons.add),
          label: const Text('添加关系'),
        ),
      ],
    );
  }
}
