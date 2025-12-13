import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/pages/character/edit_character_page.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/utils/image_utils.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:get/get.dart';
import '../../../chat-app/models/character_model.dart';
import '../../../chat-app/providers/character_controller.dart';

class CharacterExecuter extends StatelessWidget {
  final Function(int) onToggleMember;

  const CharacterExecuter({
    Key? key,
    required this.onToggleMember,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 最近选择过的角色
    final List<CharacterModel> recentCharacter = VaultSettingController.of()
        .historyModel
        .value
        .characterHistory
        .map((id) => CharacterController.of.getCharacterById(id))
        .where((c) => c != null)
        .cast<CharacterModel>()
        .toList();

    // 全部分组角色
    final Map<String, List<CharacterModel>> allGroupedCharacters =
        CharacterController.of.groupedCharacters;

    final double avatarDiameter = 46;
    Widget buildItem(CharacterModel c) {
      return InkWell(
        onTap: () => onToggleMember(c.id),
        child: SizedBox(
          width: 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: avatarDiameter,
                height: avatarDiameter,
                child: ClipOval(
                    child: AvatarImage.avatar(
                        c.avatar, (avatarDiameter / 2).toInt())),
              ),
              const SizedBox(height: 6),
              Text(
                c.roleName ?? c.remark ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildSection(String title, List<CharacterModel> items) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: items.map(buildItem).toList(),
            ),
          ],
        ),
      );
    }

    final List<Widget> sections = [];
    if (recentCharacter.isNotEmpty) {
      sections.add(buildSection('最近', recentCharacter));
      sections.add(const Divider());
    }

    allGroupedCharacters.forEach((group, list) {
      sections.add(buildSection(group, list));
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections,
      ),
    );
  }
}
