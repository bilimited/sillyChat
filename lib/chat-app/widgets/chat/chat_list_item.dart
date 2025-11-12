import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_page.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/utils/image_utils.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_example/chat-app/widgets/stack_avatar.dart';
import 'package:get/get.dart';

import 'package:path/path.dart' as p;

// ignore: must_be_immutable
class ChatListItem extends StatelessWidget {
  String path;

  bool isSelected;
  VoidCallback onTap;
  VoidCallback onLongPress;

  ChatListItem(
      {Key? key,
      required this.path,
      required this.isSelected,
      required this.onTap,
      required this.onLongPress})
      : super(key: key);

  String _formatTime(String time) {
    final dateTime = DateTime.parse(time);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }

  ChatMetaModel? get chat => ChatController.of.getIndex(path);

  bool get isQuickChat => chat?.assistant.isDefaultAssistant ?? true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (chat == null) {
      ChatController.of.buildIndex(path);
    } else {
      print('缓存命中');
    }
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Obx(() => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (chat != null)
                  chat!.mode == ChatMode.group
                      ? StackAvatar(avatarUrls: chat!.getAllAvatars())
                      : isQuickChat
                          ? SizedBox.shrink()
                          : AvatarImage.round(chat!.assistant.avatar, 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          chat?.name ?? p.basenameWithoutExtension(path),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // 如果有标签则显示标签，否则显示最近消息
                      if (chat != null)
                        Text(
                          chat!.lastMessage
                              .replaceAll(
                                  RegExp(r'<think>.*?</think>', dotAll: true),
                                  '')
                              .replaceAll('\n', ''),
                          style: TextStyle(
                            color: theme.colorScheme.outline,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: theme.colorScheme.secondary)
                else if (chat != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatTime(chat!.time),
                        style: TextStyle(
                          color: theme.colorScheme.outline,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${chat!.messageCount}条',
                              style: TextStyle(
                                color: theme.colorScheme.outline,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          )),
    );
  }
}
