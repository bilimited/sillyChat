import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/character/edit_character_page.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:get/get.dart';
import '../../../chat-app/models/character_model.dart';
import '../../../chat-app/providers/character_controller.dart';

class MemberSelector extends StatelessWidget {
  final List<int> selectedMembers;
  final Function(int) onToggleMember;

  const MemberSelector({
    Key? key,
    required this.selectedMembers,
    required this.onToggleMember,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final CharacterController characterController = Get.find();

    return Obx(() {
      final allCharacters = characterController.characters;
      Map<String, List<CharacterModel>> groupedCharacters = {};

      for (var character in allCharacters) {
        if (!groupedCharacters.containsKey(character.category)) {
          groupedCharacters[character.category] = [];
        }
        groupedCharacters[character.category]!.add(character);
      }

      return ListView.builder(
        itemCount: groupedCharacters.length,
        itemBuilder: (context, index) {
          String category = groupedCharacters.keys.elementAt(index);
          List<CharacterModel> characters = groupedCharacters[category]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  category,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ...characters.map((character) {
                final isMember = selectedMembers.contains(character.id);
                return Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              Image.file(File(character.avatar)).image,
                        ),
                        title: Text(character.roleName),
                        trailing: isMember
                            ? Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () => onToggleMember(character.id),
                      ),
                    ),
                    IconButton(
                        onPressed: () {
                          customNavigate(
                              EditCharacterPage(
                                characterId: character.id,
                              ),
                              context: context);
                        },
                        icon: Icon(Icons.more_horiz)),
                  ],
                );
              }).toList(),
            ],
          );
        },
      );
    });
  }
}
