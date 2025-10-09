import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import '../../models/character_model.dart';

class CharacterWheel extends StatelessWidget {
  final List<CharacterModel> characters;
  final double radius;
  final Function(CharacterModel) onCharacterSelected;

  CharacterWheel({
    Key? key,
    required List<CharacterModel> characters,
    this.radius = 160,
    required this.onCharacterSelected,
  })  : characters = [
          ...characters,
        ],
        super(key: key);

  Widget _buildAvatar(CharacterModel character) {
    if (character.messageStyle == MessageStyle.narration) {
      return Icon(Icons.chat);
    } else {
      return AvatarImage(fileName: character.avatar);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        children: [
          // 背景圆
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 10.0,
                sigmaY: 10.0,
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withOpacity(0.5),
                ),
              ),
            ),
          ),
          // 角色头像
          ...List.generate(characters.length, (index) {
            final angle = 2 * pi * index / characters.length;
            final x = radius + radius * 0.7 * cos(angle);
            final y = radius + radius * 0.7 * sin(angle);

            return Positioned(
              left: x - 25,
              top: y - 35, // 向上调整位置以适应文字空间
              child: GestureDetector(
                onTap: () => onCharacterSelected(characters[index]),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(child: _buildAvatar(characters[index])),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      characters[index].roleName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
