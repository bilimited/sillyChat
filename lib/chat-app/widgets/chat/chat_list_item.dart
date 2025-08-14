import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import '../../pages/chat/chat_detail_page.dart';

// ignore: must_be_immutable
class ChatListItem extends StatelessWidget {
  String path;

  final void Function(String path)? onSelectChat;

  //ChatModel get chat => _chatController.getChatById(chatId);
  ChatMetaModel chat;

  ChatListItem(
      {Key? key, required this.path, required this.chat, this.onSelectChat})
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        if (onSelectChat != null) {
          onSelectChat!(path);
        } else {
          customNavigate(
              ChatDetailPage(
                sessionController: ChatSessionController(path),
              ),
              context: context);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: FileImage(File(chat.avatar)),
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
                  Text(
                    chat.lastMessage
                        .replaceAll(
                            RegExp(r'<think>.*?</think>', dotAll: true), '')
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
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${chat.messageCount}条',
                        style: TextStyle(
                          color: theme.colorScheme.outline,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    // const SizedBox(width: 4),
                    // Container(
                    //   padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    //   decoration: BoxDecoration(
                    //     color: theme.colorScheme.surfaceVariant,
                    //     borderRadius: BorderRadius.circular(4),
                    //   ),
                    //   child: Text(
                    //     _getModeText(chat.mode),
                    //     style: TextStyle(
                    //       color: theme.colorScheme.outline,
                    //       fontSize: 10,
                    //     ),
                    //   ),
                    // ),
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
