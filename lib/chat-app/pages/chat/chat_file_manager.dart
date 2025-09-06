import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/pages/chat/new_group_chat.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/chat/chat_list_item.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

/// 文件列表项的操作类型
enum FileAction { copy, cut }

enum ConflictAction { ask, replace, keepBoth, skip }

/// 自定义文件列表项的构建器
typedef FileManagerItemBuilder = Widget Function(BuildContext context,
    FileSystemEntity entity, bool isSelected, VoidCallback onTap);

class FileManagerWidget extends StatefulWidget {
  final Directory directory; // 管理的文件夹根路径
  final List<String> fileExtensions; // 显示的文件类型

  const FileManagerWidget({
    super.key,
    required this.directory,
    this.fileExtensions = const ['.chat'],
  });

  @override
  State<FileManagerWidget> createState() => _FileManagerWidgetState();
}

class _FileManagerWidgetState extends State<FileManagerWidget> {
  // TODO:切换页面时不销毁当前目录状态
  late Directory _currentDirectory;
  List<FileSystemEntity> _files = [];
  bool _isMultiSelectMode = false;
  final List<FileSystemEntity> _selectedFiles = [];
  final List<FileSystemEntity> _clipboard = [];
  FileAction? _clipboardAction;

  @override
  void initState() {
    super.initState();

    _currentDirectory = widget.directory;
    _loadFiles();
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

  Future<void> _loadFiles() async {
    final List<FileSystemEntity> filteredEntities = [];
    try {
      if (!_currentDirectory.existsSync()) {
        _currentDirectory.createSync(recursive: true);
      }

      final List<FileSystemEntity> allEntities =
          await _currentDirectory.list().toList();

      // 创建一个列表来存储实体及其状态信息
      final List<Map<String, dynamic>> entitiesWithStats = [];
      for (final entity in allEntities) {
        // 过滤文件类型
        if (entity is Directory) {
          entitiesWithStats.add({'entity': entity, 'stat': null});
        } else if (entity is File) {
          if (widget.fileExtensions
              .any((ext) => entity.path.toLowerCase().endsWith(ext))) {
            try {
              final stat = await entity.stat();
              entitiesWithStats.add({'entity': entity, 'stat': stat});
            } catch (e) {
              // 如果无法获取状态，则忽略该文件
              print("无法获取文件状态: $e");
            }
          }
        }
      }

      // 排序逻辑
      entitiesWithStats.sort((a, b) {
        final entityA = a['entity'] as FileSystemEntity;
        final entityB = b['entity'] as FileSystemEntity;

        final isDirA = entityA is Directory;
        final isDirB = entityB is Directory;

        // 规则1: 文件夹始终置顶
        if (isDirA && !isDirB) return -1;
        if (!isDirA && isDirB) return 1;

        // 规则 2: 如果都是文件夹，按名称排序
        if (isDirA && isDirB) {
          return path
              .basename(entityA.path)
              .toLowerCase()
              .compareTo(path.basename(entityB.path).toLowerCase());
        }

        // 规则 3: 如果都是文件，按创建/修改日期降序排序 (最新的在前)
        final statA = a['stat'] as FileStat;
        final statB = b['stat'] as FileStat;
        return statB.changed.compareTo(statA.changed);
      });

      // 从排序后的列表中提取实体
      for (final item in entitiesWithStats) {
        filteredEntities.add(item['entity']);
      }
    } catch (e) {
      // 处理权限错误等
      Get.snackbar('无法访问目录', '$e');
    }

    if (mounted) {
      setState(() {
        _files = filteredEntities;
      });
    }
  }

  /// 默认的文件列表项显示样式
  Widget _defaultItemBuilder(BuildContext context, FileSystemEntity entity,
      bool isSelected, VoidCallback onTap) {
    final isDirectory = entity is Directory;
    int fileCount = -1;
    if (isDirectory) {
      fileCount = entity.listSync().length;
    }
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;

    return ListTile(
      leading: isDirectory
          ? Icon(
              Icons.folder,
              color: iconColor,
            )
          : null,
      title: Text(
        path.basename(entity.path).replaceAll('.chat', ''),
        style: TextStyle(color: textColor),
      ),
      subtitle: Text(
        '$fileCount 个文件',
        style: TextStyle(color: theme.colorScheme.outline, fontSize: 12),
      ),
      onTap: onTap,
      onLongPress: () {
        if (!_isMultiSelectMode) {
          setState(() {
            _isMultiSelectMode = true;
            _selectedFiles.add(entity);
          });
        }
      },
      trailing: isSelected
          ? Icon(Icons.check_circle, color: theme.colorScheme.secondary)
          : Text(
              _formatTime(entity.statSync().changed.toString()),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.outline),
            ),
    );
  }

  Widget _cachedItemBuilder(BuildContext context, FileSystemEntity entity,
      bool isSelected, VoidCallback onTap) {
    final isDirectory = entity is Directory;

    return isDirectory
        ? _defaultItemBuilder(context, entity, isSelected, onTap)
        : ChatListItem(
            path: entity.path,
            isSelected: isSelected,
            onTap: onTap,
            onLongPress: () {
              if (!_isMultiSelectMode) {
                setState(() {
                  _isMultiSelectMode = true;
                  _selectedFiles.add(entity);
                });
              }
            },
          );
  }

  /// 点击文件时触发的特定方法
  void _onFileTapped(File file) {
    if (file.path.endsWith('.chat')) {
      _openChat(file.path);
    }
  }

  void _openChat(String path) {
    if (SillyChatApp.isDesktop()) {
      ChatController.of.currentChat.value = ChatSessionController(path);
    } else {
      customNavigate(
          ChatDetailPage(
            sessionController: ChatSessionController(path),
          ),
          context: context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isMultiSelectMode) {
          setState(() {
            _isMultiSelectMode = false;
            _selectedFiles.clear();
          });
          return false;
        }
        if (_currentDirectory.path != widget.directory.path) {
          setState(() {
            _currentDirectory = _currentDirectory.parent;
            _loadFiles();
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildFileList(),
        floatingActionButton:
            _isMultiSelectMode ? null : _buildFloatingActionButton(),
      ),
    );
  }

  AppBar _buildAppBar() {
    final theme = Theme.of(context);
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
        actions: _buildAppBarActions(),
      );
    } else {
      return AppBar(
        leading: _currentDirectory.path != widget.directory.path
            ? IconButton(
                onPressed: () {
                  setState(() {
                    _currentDirectory = _currentDirectory.parent;
                    _loadFiles();
                  });
                },
                icon: Icon(Icons.arrow_back))
            : null,
        title: _buildPathTitle(),
      );
    }
  }

  Widget _buildPathTitle() {
    final theme = Theme.of(context);
    String displayPath;

    // 如果当前目录就是根目录，直接显示根目录的名称
    if (_currentDirectory.path == widget.directory.path) {
      displayPath = '全部聊天';
    } else {
      // 计算相对于根目录的路径
      final String relativePath =
          path.relative(_currentDirectory.path, from: widget.directory.path);

      // 路径截断逻辑
      const int maxPathLength = 35; // 定义一个合理的路径最大显示长度
      if (relativePath.length > maxPathLength) {
        final List<String> parts = path.split(relativePath);
        final List<String> displayParts = [];
        int currentLength = 0;

        // 从后往前添加路径部分，直到长度超出限制
        for (int i = parts.length - 1; i >= 0; i--) {
          final part = parts[i];
          if (currentLength + part.length > maxPathLength && i > 0) {
            displayParts.insert(0, '...');
            break;
          }
          displayParts.insert(0, part);
          currentLength += part.length + 1; // +1 是为了路径分隔符
        }
        displayPath = path.joinAll(displayParts);
      } else {
        displayPath = relativePath;
      }
    }

    return Text(
      displayPath,
      style: theme.textTheme.titleSmall, // 使用较小的字体尺寸
      overflow: TextOverflow.ellipsis, // 以防万一，再次处理溢出
    );
  }

  List<Widget> _buildAppBarActions() {
    List<Widget> actions = [];

    if (_selectedFiles.isNotEmpty) {
      actions.add(IconButton(
        icon: const Icon(Icons.copy),
        onPressed: _copyFiles,
      ));
      actions.add(IconButton(
        icon: const Icon(Icons.cut),
        onPressed: _cutFiles,
      ));
      actions.add(IconButton(
        icon: const Icon(Icons.delete),
        onPressed: _deleteFiles,
      ));
    }

    // 暂时取消直接重命名文件的方法
    // if (_selectedFiles.length == 1) {
    //   actions.add(IconButton(
    //     icon: const Icon(Icons.drive_file_rename_outline),
    //     onPressed: _renameFile,
    //   ));
    // }

    return actions;
  }

  Widget _buildFileList() {
    if (_files.isEmpty) {
      if (_currentDirectory == widget.directory) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('无数据'),
              SizedBox(
                height: 16,
              ),
              ElevatedButton(
                  onPressed: () async {
                    await ChatController.of.loadChats();
                    await ChatController.of.debug_moveAllChats();
                    _loadFiles();
                  },
                  child: Text('从旧版本迁移'))
            ],
          ),
        );
      }
      return const Center(child: Text('文件夹为空'));
    }
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final entity = _files[index];
        final isSelected = _selectedFiles.contains(entity);
        return _cachedItemBuilder(context, entity, isSelected, () {
          if (_isMultiSelectMode) {
            setState(() {
              if (isSelected) {
                _selectedFiles.remove(entity);
                if (_selectedFiles.isEmpty) {
                  _isMultiSelectMode = false;
                }
              } else {
                _selectedFiles.add(entity);
              }
            });
          } else {
            if (entity is Directory) {
              setState(() {
                _currentDirectory = entity;
                _loadFiles();
              });
            } else if (entity is File) {
              _onFileTapped(entity);
            }
          }
        });
      },
    );
  }

  Widget _buildFloatingActionButton() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_clipboard.isNotEmpty)
          FloatingActionButton(
            onPressed: _pasteFiles,
            child: const Icon(Icons.paste),
            heroTag: 'paste',
          ),
        const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: () => _showCreateDialog(),
          child: const Icon(Icons.add),
          heroTag: 'add',
        ),
      ],
    );
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('创建'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.create_new_folder),
                title: const Text('新建文件夹'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showCreateFolderDialog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.message),
                title: const Text('新建聊天'),
                onTap: () {
                  Navigator.of(context).pop();
                  _createChat(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('新建群聊'),
                onTap: () {
                  Navigator.of(context).pop();
                  _createGroupChat(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _createChat(BuildContext context) async {
    final char = await customNavigate<CharacterModel?>(CharacterSelector(),
        context: context);

    if (char != null) {
      final chat = await ChatController.of
          .createChatFromCharacter(char, _currentDirectory.path);
      _openChat(chat.file.path);
      _loadFiles();
    }
  }

  Future<void> _createGroupChat(BuildContext context) async {
    final chat = await customNavigate<ChatModel>(
        NewChatPage(_currentDirectory.path),
        context: context);
    if (chat != null) {
      _openChat(chat.file.path);
      _loadFiles();
    }
  }

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建文件夹'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: '文件夹名称'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  final newDirPath =
                      path.join(_currentDirectory.path, controller.text);
                  try {
                    await Directory(newDirPath).create();
                    _loadFiles();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('创建文件夹失败: $e')),
                    );
                  }
                  Navigator.of(context).pop();
                }
              },
              child: const Text('创建'),
            ),
          ],
        );
      },
    );
  }

  void _copyFiles() {
    _clipboard.clear();
    _clipboard.addAll(_selectedFiles);
    _clipboardAction = FileAction.copy;
    setState(() {
      _isMultiSelectMode = false;
      _selectedFiles.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制')),
    );
  }

  void _cutFiles() {
    _clipboard.clear();
    _clipboard.addAll(_selectedFiles);
    _clipboardAction = FileAction.cut;
    setState(() {
      _isMultiSelectMode = false;
      _selectedFiles.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已剪切')),
    );
  }

  Future<void> _pasteFiles() async {
    if (_clipboard.isEmpty) return;

    ConflictAction allConflictAction = ConflictAction.ask;

    for (final entity in _clipboard) {
      String newPath =
          path.join(_currentDirectory.path, path.basename(entity.path));
      ConflictAction currentAction = allConflictAction;

      // 1. 冲突检测
      if (await File(newPath).exists() || await Directory(newPath).exists()) {
        if (currentAction == ConflictAction.ask) {
          final result = await _showConflictDialog(path.basename(entity.path));

          // 如果用户取消对话框，则终止整个粘贴操作
          if (result == null) break;

          final userChoice = result.keys.first;
          final applyToAll = result.values.first;

          if (applyToAll) {
            allConflictAction = userChoice;
          }
          currentAction = userChoice;
        }
      }

      // 2. 根据决策执行操作
      try {
        switch (currentAction) {
          case ConflictAction.skip:
            continue; // 跳过当前文件

          case ConflictAction.keepBoth:
            // 如果是冲突后选择保留，则获取唯一名称，否则使用原名
            if (await FileSystemEntity.type(newPath) !=
                FileSystemEntityType.notFound) {
              newPath = await _getUniqueName(newPath);
            }
            break; // 继续执行默认的粘贴逻辑

          case ConflictAction.replace:
            // 如果目标存在，先删除
            if (await File(newPath).exists()) {
              await File(newPath).delete();
            } else if (await Directory(newPath).exists()) {
              await Directory(newPath).delete(recursive: true);
            }
            break; // 继续执行默认的粘贴逻辑

          case ConflictAction.ask:
            // 默认情况，没有冲突，直接粘贴
            break;
        }

        // 3. 执行文件操作
        if (entity is File) {
          if (_clipboardAction == FileAction.cut) {
            await entity.rename(newPath);
          } else {
            await entity.copy(newPath);
          }
        } else if (entity is Directory) {
          if (_clipboardAction == FileAction.cut) {
            await entity.rename(newPath);
          } else {
            // 健壮的递归文件夹复制
            final newDir = Directory(newPath);
            await newDir.create();
            await for (final subEntity in entity.list(recursive: true)) {
              final relativePath =
                  path.relative(subEntity.path, from: entity.path);
              final newSubPath = path.join(newDir.path, relativePath);
              if (subEntity is File) {
                // 确保目标子目录存在
                await Directory(path.dirname(newSubPath))
                    .create(recursive: true);
                await subEntity.copy(newSubPath);
              } else if (subEntity is Directory) {
                await Directory(newSubPath).create(recursive: true);
              }
            }
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('粘贴失败: ${path.basename(entity.path)} - $e')),
        );
      }
    }

    // 4. 操作完成后，根据类型清空剪贴板并刷新列表s
    setState(() {
      _clipboard.clear();
    });

    _loadFiles();
  }

  void _deleteFiles() {
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
              for (final entity in _selectedFiles) {
                try {
                  await entity.delete(recursive: true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('删除失败: $e')),
                  );
                }
              }
              setState(() {
                _isMultiSelectMode = false;
                _selectedFiles.clear();
              });
              _loadFiles();
              Navigator.of(context).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _renameFile() {
    if (_selectedFiles.length != 1) return;
    final entity = _selectedFiles.first;
    final controller =
        TextEditingController(text: path.basenameWithoutExtension(entity.path));
    final ext = path.extension(entity.path);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '新名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) return;

              final newPath = path.join(_currentDirectory.path, '$newName$ext');

              // 1. 如果新路径和原路径相同，直接关闭对话框即可（无变化）
              if (newPath == entity.path) {
                Navigator.of(context).pop();
                return;
              }
              // 2. 检测冲突：目标文件/目录是否已存在
              final targetExists = await File(newPath).exists() ||
                  await Directory(newPath).exists();
              if (targetExists) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('名称已存在!')),
                );
                return; // 终止重命名
              }
              try {
                await entity.rename(newPath);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('重命名失败: $e')),
                );
              }

              setState(() {
                _isMultiSelectMode = false;
                _selectedFiles.clear();
              });
              _loadFiles();
              if (!mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  /// 为给定的路径生成一个不冲突的唯一路径
  /// 例如 "file.txt" -> "file (1).txt"
  Future<String> _getUniqueName(String originalPath) async {
    String newPath = originalPath;
    int count = 1;
    final type = await FileSystemEntity.type(originalPath);

    // 如果文件不存在，直接返回原路径
    if (type == FileSystemEntityType.notFound) {
      return newPath;
    }

    final dir = path.dirname(originalPath);
    final extension = path.extension(originalPath);
    final basename = path.basenameWithoutExtension(originalPath);

    while (true) {
      if (extension.isNotEmpty) {
        newPath = path.join(dir, '$basename ($count)$extension');
      } else {
        newPath = path.join(dir, '$basename ($count)');
      }

      if (!await File(newPath).exists() && !await Directory(newPath).exists()) {
        break;
      }
      count++;
    }
    return newPath;
  }

  /// 显示一个对话框，让用户决定如何处理文件/文件夹名称冲突
  Future<Map<ConflictAction, bool>?> _showConflictDialog(String name) async {
    final applyToAll = ValueNotifier<bool>(false);
    final result = await showDialog<ConflictAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('名称冲突'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('目标文件夹中已存在一个名为 "$name" 的项目。'),
              const SizedBox(height: 20),
              ValueListenableBuilder<bool>(
                valueListenable: applyToAll,
                builder: (context, value, child) {
                  return CheckboxListTile(
                    title: const Text('对全部冲突应用此操作'),
                    value: value,
                    onChanged: (newValue) {
                      if (newValue != null) {
                        applyToAll.value = newValue;
                      }
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('跳过'),
              onPressed: () => Navigator.of(context).pop(ConflictAction.skip),
            ),
            TextButton(
              child: const Text('保留两者'),
              onPressed: () =>
                  Navigator.of(context).pop(ConflictAction.keepBoth),
            ),
            TextButton(
              child: const Text('替换'),
              onPressed: () =>
                  Navigator.of(context).pop(ConflictAction.replace),
            ),
          ],
        );
      },
    );

    if (result == null) return null; // 用户可能通过其他方式关闭了对话框

    return {result: applyToAll.value};
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatController chatController = Get.find<ChatController>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: FutureBuilder<Directory>(
          future: SettingController.of
              .getVaultPath()
              .then((path) => Directory('$path/chats')),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.hasData) {
                return FileManagerWidget(
                  directory: snapshot.data!,
                );
              }
            }
            return const Center(child: CircularProgressIndicator());
          },
        ));
  }
}
