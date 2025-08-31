// ChatFileTile.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:path/path.dart' as p;

/// 一个用于显示文件或文件夹条目的可重用组件。
///
/// 这个组件被设计为在 [TreeView] 中使用，用于渲染每个节点。
/// 它包含了点击和长按的手势处理。
class ChatFileTile extends StatelessWidget {
  /// TreeView 中的节点，包含了文件系统实体 [FileSystemEntity] 的数据。
  final TreeNode<FileSystemEntity> node;

  /// 当前条目是否被选中。
  final bool isSelected;

  /// 当用户点击这个条目时调用的回调函数。
  final VoidCallback onTap;

  /// 当用户长按这个条目时调用的回调函数。
  final void Function(LongPressEndDetails details) onLongPressEnd;

  const ChatFileTile({
    super.key,
    required this.node,
    required this.isSelected,
    required this.onTap,
    required this.onLongPressEnd,
  });

  /// 构建文件或文件夹的 UI 表示。
  Widget _buildFileTile(BuildContext context, FileSystemEntity entity) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? colors.outlineVariant
                    : Colors.transparent, // 边框颜色
                width: 2.0, // 边框宽度
              ),
              borderRadius: BorderRadius.circular(10.0), // 圆角半径
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(p.basenameWithoutExtension(entity.path)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final entity = node.data!;
    final tile = _buildFileTile(context, entity);

    // 使用 GestureDetector 来处理用户的点击和长按手势。
    return GestureDetector(
      onTap: onTap,
      onLongPressEnd: onLongPressEnd,
      child: tile,
    );
  }
}
