import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/events.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/widgets/chat/chat_list_item.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

/// 最近聊天页面
/// 1. 数据来源于 ChatController.of.recentChats（响应式）
/// 2. 复用 ChatListItem 组件
/// 3. 支持多选删除（同时删除磁盘文件并发出 fileDeleteEvent）
class RecentChatPage extends StatefulWidget {
  const RecentChatPage({super.key});

  @override
  State<RecentChatPage> createState() => _RecentChatPageState();
}

class _RecentChatPageState extends State<RecentChatPage> {
  bool _isMultiSelectMode = false;
  final Set<String> _selectedPaths = <String>{};

  void _openChat(String path) {
    if (!SillyChatApp.isDesktop()) {
      // 移动端打开聊天前关闭抽屉
      final scaffoldState = Scaffold.maybeOf(context);
      if (scaffoldState?.isDrawerOpen ?? false) {
        Navigator.of(context).pop();
      }
    }
    ChatController.of.openChat(path);
  }

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedPaths.clear();
    });
  }

  void _toggleSelect(String path) {
    setState(() {
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
        if (_selectedPaths.isEmpty) {
          _isMultiSelectMode = false;
        }
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  void _deleteSelected() {
    if (_selectedPaths.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除?'),
        content: Text('您确定要删除这 ${_selectedPaths.length} 个聊天吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              for (final path in _selectedPaths.toList()) {
                try {
                  final file = File(path);
                  if (await file.exists()) {
                    await file.delete();
                  }
                  ChatController.of.fileDeleteEvent.value =
                      FileDeletedEvent(p.canonicalize(path));
                } catch (e) {
                  if (mounted) {
                    SillyChatApp.snackbarErr(context, '删除失败: $e');
                  }
                }
              }
              _exitMultiSelect();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _clearAll() {
    if (ChatController.of.recentChats.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空最近聊天?'),
        content: const Text('该操作只会清除最近聊天列表，不会删除聊天文件本身。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              ChatController.of.recentChats.clear();
              await ChatController.of.saveRecentChats();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_isMultiSelectMode,
      onPopInvokedWithResult: (didPop, result) {
        if (_isMultiSelectMode) _exitMultiSelect();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: _buildAppBar(theme),
        body: _buildList(theme),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    if (_isMultiSelectMode) {
      return AppBar(
        title: Text(
          '${_selectedPaths.length} 已选择',
          style: theme.textTheme.titleSmall,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _exitMultiSelect,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSelected,
          ),
        ],
      );
    }
    return AppBar(
      title: Text('最近聊天', style: theme.textTheme.titleMedium),
      actions: [
        IconButton(
          tooltip: '清空最近聊天',
          icon: const Icon(Icons.clear_all),
          onPressed: _clearAll,
        ),
      ],
    );
  }

  Widget _buildList(ThemeData theme) {
    return Obx(() {
      final List<ChatMetaModel> items = ChatController.of.recentChats.toList();
      if (items.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 64, color: theme.colorScheme.outline),
              const SizedBox(height: 8),
              Text(
                '暂无最近聊天',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ],
          ),
        );
      }

      return ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) {
          final meta = items[index];
          final path = meta.path;
          final isSelected = _selectedPaths.contains(path);
          return ChatListItem(
            key: ValueKey(path),
            path: path,
            isSelected: isSelected,
            onTap: () {
              if (_isMultiSelectMode) {
                _toggleSelect(path);
              } else {
                _openChat(path);
                Get.back();
              }
            },
            onLongPress: () {
              if (!_isMultiSelectMode) {
                setState(() {
                  _isMultiSelectMode = true;
                  _selectedPaths.add(path);
                });
              }
            },
          );
        },
      );
    });
  }
}
