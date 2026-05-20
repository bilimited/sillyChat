import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/story_model.dart';
import 'package:flutter_example/chat-app/pages/character/edit_character_page.dart';
import 'package:flutter_example/chat-app/pages/story/story_form_page.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/common/avatar_image.dart';

class NewChatScreen extends StatelessWidget {
  final ChatModel chat;

  const NewChatScreen({
    Key? key,
    required this.chat,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 32, top: 128, left: 30, right: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (chat.bindCharacter != null) ...[
            _buildCharacterSection(context, chat.bindCharacter!),
          ] else if (chat.bindStory != null) ...[
            _buildStorySection(context, chat.bindStory!),
          ] else
            Text("如果你看到这个,一定是出了什么bug。"),
        ],
      ), 
    );
  }

  Widget _buildCharacterSection(BuildContext context, CharacterModel character) {
    final presetName = character.bindOption?.name ??
        ChatOptionController.of().defaultOption.name;
    final loreCount = character.lorebookIds.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          child: AvatarImage.round(character.avatar, 44),
          onTap: (){
            customNavigate(EditCharacterPage(characterId: character.id,), context: context);
          },
        ),
        const SizedBox(height: 16),
        Text(character.roleName, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            _MetaText(icon: Icons.settings_outlined, label: presetName),
            if (loreCount > 0)
              _MetaText(icon: Icons.book_outlined, label: '$loreCount 本世界书'),
          ],
        ),
      ],
    );
  }

  Widget _buildStorySection(BuildContext context, StoryModel story) {
    final colorScheme = Theme.of(context).colorScheme;
    final presetName =
        story.chatOption?.name ?? ChatOptionController.of().defaultOption.name;
    final loreCount = story.lorebookIds.length;
    final charCount = story.characterIds.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            customNavigate(StoryFormPage(initialStory: story,), context: context);
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(Icons.groups, size: 22, color: colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 16),
        Text(story.name, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            _MetaText(icon: Icons.settings_outlined, label: presetName),
            _MetaText(icon: Icons.person_outline, label: '$charCount 位角色'),
            if (loreCount > 0)
              _MetaText(icon: Icons.book_outlined, label: '$loreCount 本世界书'),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '点击右下角'),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.group_outlined, size: 16, color: colorScheme.outline),
                  ),
                ),
                const TextSpan(text: '让AI角色发送一条消息\n'),
                const TextSpan(text: '或者直接输入消息并发送'),
              ],
            ),
            style: TextStyle(fontSize: 14, color: colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaText({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colorScheme.outline),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: colorScheme.outline),
        ),
      ],
    );
  }
}
