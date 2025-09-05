import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/utils/image_utils.dart';

class StackAvatar extends StatelessWidget {
  final List<String> avatarUrls;
  final int maxDisplayCount;
  final double avatarSize;
  final double spacing;

  const StackAvatar({
    Key? key,
    required this.avatarUrls,
    this.maxDisplayCount = 3,
    this.avatarSize = 45,
    this.spacing = 17,
  }) : super(key: key);

  double _calculateSpacing() {
    int len = avatarUrls.length;
    if (len == 2) {
      return spacing * 2;
    }
    return spacing;
  }

  @override
  Widget build(BuildContext context) {
    final displayCount = avatarUrls.length > maxDisplayCount
        ? maxDisplayCount
        : avatarUrls.length;
    final hasMore = avatarUrls.length > maxDisplayCount;
    final dynamicSpacing = _calculateSpacing();

    return SizedBox(
      width: avatarSize + ((spacing + 10) * (maxDisplayCount - 1)),
      height: avatarSize + 4,
      child: Stack(
        children: [
          ...List.generate(displayCount, (index) {
            return Positioned(
              left: index * dynamicSpacing,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: avatarSize / 2,
                  backgroundImage: ImageUtils.getProvider(avatarUrls[index]),
                ),
              ),
            );
          }),
          if (hasMore)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary, //Colors.green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+${avatarUrls.length - maxDisplayCount}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
