import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/stack_avatar.dart';
import 'package:get/get.dart';
import '../../models/chat_model.dart';
import '../../pages/chat/chat_detail_page.dart';

// ignore: must_be_immutable
class ChatListItem extends StatelessWidget {
  int chatId;

  CharacterController _characterController = Get.find();
  ChatController _chatController = Get.find();
  final void Function(ChatModel chat)? onSelectChat;

  ChatModel get chat => _chatController.getChatById(chatId);
  ChatListItem({Key? key, required this.chatId, this.onSelectChat})
      : super(key: key);

  String _getModeText(ChatMode? mode) {
    switch (mode) {
      case ChatMode.auto:
        return '单聊';
      case ChatMode.group:
        return '群聊';
      case ChatMode.manual:
        return '手动';
      default:
        return '单聊';
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 根据聊天模式决定显示的头像
    List<String> avatars = [];
    if (chat.mode == ChatMode.group) {
      if (chat.messages.isNotEmpty) {
        avatars = chat.getAllAvatars(_characterController);
      }
    } else {
      // 非群聊模式下只显示助手角色的头像
      final assistant = chat.assistant;
      avatars.add(assistant.avatar);
    }
    if (avatars.isEmpty) {
      avatars.add(chat.avatar);
    }

    return InkWell(
      onTap: () {
        if (onSelectChat != null) {
          onSelectChat!(chat);
        } else {
          customNavigate(
              ChatDetailPage(
                chatId: chat.id,
              ),
              context: context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            chat.mode == ChatMode.group
                ? StackAvatar(
                    avatarUrls: chat.getAllAvatars(_characterController))
                : CircleAvatar(
                    radius: 24,
                    backgroundImage: FileImage(File(chat.assistant.avatar)),
                  ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 如果有标签则显示标签，否则显示最近消息
                  chat.tags.isNotEmpty
                      ? Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: chat.tags
                              .map((tag) => Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceVariant,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: TextStyle(
                                        color: theme.colorScheme.outline,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        )
                      // 最近信息
                      : Text(
                          chat.lastMessage
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _formatTime(chat.time),
                  style: TextStyle(
                    color: theme.colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${chat.messages.length}条',
                        style: TextStyle(
                          color: theme.colorScheme.outline,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getModeText(chat.mode),
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
      ),
    );
  }
}
