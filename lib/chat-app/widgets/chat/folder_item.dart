import 'dart:io';

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
class FolderItem extends StatelessWidget {
  Directory entity;
  bool isSelected;

  VoidCallback onTap;
  VoidCallback onLongPress;

  Widget? avatar; // 替换头像

  FolderItem(
      {Key? key,
      required this.entity,
      required this.isSelected,
      required this.onTap,
      required this.onLongPress,})
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
    final fname = p.basename(entity.path);
    final fileCount = entity.listSync().length;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(

            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    // 设置圆角：12 左右看起来是“微圆的方形”，0 则是纯直角正方形
                    borderRadius: BorderRadius.circular(12), 
                  ),
                  child: Icon(
                    Icons.folder,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),

                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          fname,
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
                      
                        Text(
                          '$fileCount 个文件',
                          style: TextStyle(
                            color: theme.colorScheme.outline,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, color: theme.colorScheme.secondary)
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatTime(entity.statSync().changed.toString()),
                        style: TextStyle(
                          color: theme.colorScheme.outline,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                          
              
              ],
            ),
          )
    );
  }
}
