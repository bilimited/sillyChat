import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/events.dart';
import 'package:flutter_example/chat-app/models/chat_metadata_model.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/widgets/chat/chat_list_item.dart';
import 'package:flutter_example/chat-app/widgets/inner_app_bar.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

/// 简化版聊天文件查看页面
/// 1. 只展示指定目录下的 .chat 文件，不显示文件夹
/// 2. 支持多选，多选后只能删除选中文件
/// 3. 移除了复制、剪切、粘贴、重命名、创建文件夹、搜索、设置等文件夹操作
class SimpleChatFilesPage extends StatefulWidget {
  final String directoryPath; // 要查看的目录路径

  const SimpleChatFilesPage({
    super.key,
    required this.directoryPath,
  });

  @override
  State<SimpleChatFilesPage> createState() => _SimpleChatFilesPageState();
}

class _SimpleChatFilesPageState extends State<SimpleChatFilesPage> {
  late Directory _directory;
  List<File> _chatFiles = [];
  bool _isMultiSelectMode = false;
  final List<File> _selectedFiles = [];

  @override
  void initState() {
    super.initState();
    _directory = Directory(widget.directoryPath);
    _loadFiles();
  }

  /// 加载目录下的 .chat 文件（按修改时间降序）
  Future<void> _loadFiles() async {
    final List<File> files = [];
    try {
      if (!_directory.existsSync()) {
        _directory.createSync(recursive: true);
      }
      final allEntities = await _directory.list().toList();

      // 收集文件及其修改时间
      List<Map<String, dynamic>> fileStats = [];
      for (final entity in allEntities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.chat')) {
          try {
            final stat = await entity.stat();
            fileStats.add({'file': entity, 'modified': stat.modified});
          } catch (_) {
            // 忽略无法获取状态的文件
          }
        }
      }

      // 按修改时间降序排序（最新的在前）
      fileStats.sort((a, b) =>
          (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));
      files.addAll(fileStats.map((e) => e['file'] as File));
    } catch (e) {
      if (mounted) {
        SillyChatApp.snackbarErr(context, '加载聊天文件失败: $e');
      }
    }

    if (mounted) {
      setState(() {
        _chatFiles = files;
      });
    }
  }

  /// 格式化时间为中文简要表达
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
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

  /// 打开聊天
  void _openChat(String path) {
    // 如果从侧边栏打开，关闭侧边栏
    if (!SillyChatApp.isDesktop()) {
      Get.back();
    }
    ChatController.of.openChat(path);
  }

  /// 删除选中的文件（带确认对话框）
  void _deleteSelectedFiles() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除?'),
        content: Text('您确定要删除这 ${_selectedFiles.length} 个项目吗?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              for (final file in _selectedFiles) {
                try {
                  await file.delete();
                  ChatController.of.fileDeleteEvent.value =
                      FileDeletedEvent(path.canonicalize(file.path));
                } catch (e) {
                  if (mounted) {
                    SillyChatApp.snackbarErr(context, '删除失败: $e');
                  }
                }
              }
              setState(() {
                _isMultiSelectMode = false;
                _selectedFiles.clear();
              });
              _loadFiles();
              if (mounted) Navigator.of(context).pop();
            },
            child: const Text('删除'),
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
        if (_isMultiSelectMode) {
          setState(() {
            _isMultiSelectMode = false;
            _selectedFiles.clear();
          });
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: _buildAppBar(theme),
        body: _buildFileList(theme),
      ),
    );
  }

  /// 构建 AppBar（多选模式与非多选模式）
  PreferredSizeWidget _buildAppBar(ThemeData theme) {
    if (_isMultiSelectMode) {
      return AppBar(
        title: Text(
          '${_selectedFiles.length} 已选择',
          style: theme.textTheme.titleSmall,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            setState(() {
              _isMultiSelectMode = false;
              _selectedFiles.clear();
            });
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteSelectedFiles,
          ),
        ],
      );
    } else {
      return AppBar(
        title: Text(
          '查看历史话题',
          //path.basename(_directory.path),
          style: theme.textTheme.titleMedium,
        ),
      );
    }
  }

  /// 构建文件列表
  Widget _buildFileList(ThemeData theme) {
    if (_chatFiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 8),
            Text(
              '无聊天文件',
              style: TextStyle(color: theme.colorScheme.outline),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _chatFiles.length,
      itemBuilder: (context, index) {
        final file = _chatFiles[index];
        final isSelected = _selectedFiles.contains(file);

        return ChatListItem(
          path: file.path,
          isSelected: isSelected,
          onTap: () {
            if (_isMultiSelectMode) {
              setState(() {
                if (isSelected) {
                  _selectedFiles.remove(file);
                  if (_selectedFiles.isEmpty) {
                    _isMultiSelectMode = false;
                  }
                } else {
                  _selectedFiles.add(file);
                }
              });
            } else {
              _openChat(file.path);
            }
          },
          onLongPress: () {
            if (!_isMultiSelectMode) {
              setState(() {
                _isMultiSelectMode = true;
                _selectedFiles.add(file);
              });
            }
          },
        );
      },
    );
  }
}
