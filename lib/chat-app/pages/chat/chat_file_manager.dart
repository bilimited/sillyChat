import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/pages/chat/new_group_chat.dart';
import 'package:flutter_example/chat-app/pages/vault_manager.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

/// 文件列表项的操作类型
enum FileAction { copy, cut }

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

  /// 加载当前目录下的文件和文件夹
  Future<void> _loadFiles() async {
    final List<FileSystemEntity> files = [];
    try {
      final List<FileSystemEntity> allFiles =
          await _currentDirectory.list().toList();
      allFiles.sort((a, b) {
        if (a is Directory && b is File) {
          return -1;
        }
        if (a is File && b is Directory) {
          return 1;
        }
        return a.path.toLowerCase().compareTo(b.path.toLowerCase());
      });

      for (var entity in allFiles) {
        if (entity is Directory) {
          files.add(entity);
        } else if (entity is File) {
          if (widget.fileExtensions
              .any((ext) => entity.path.toLowerCase().endsWith(ext))) {
            files.add(entity);
          }
        }
      }
    } catch (e) {
      // 处理权限错误等
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法访问目录: $e')),
      );
    }
    setState(() {
      _files = files;
    });
  }

  /// 预留的创建文件方法
  Future<void> _createFile(String fileName) async {
    final filePath = path.join(_currentDirectory.path, fileName);
    try {
      final newFile = File(filePath);
      await newFile.create();
      _loadFiles();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建文件失败: $e')),
      );
    }
  }

  /// 默认的文件列表项显示样式
  Widget _defaultItemBuilder(BuildContext context, FileSystemEntity entity,
      bool isSelected, VoidCallback onTap) {
    final isDirectory = entity is Directory;
    final theme = Theme.of(context);
    final iconColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;

    return ListTile(
      leading: Icon(
        isDirectory ? Icons.folder : Icons.insert_drive_file,
        color: iconColor,
      ),
      title: Text(
        path.basename(entity.path),
        style: TextStyle(color: textColor),
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
          : null,
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
      displayPath = path.basename(_currentDirectory.path);
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

    if (_selectedFiles.length == 1) {
      actions.add(IconButton(
        icon: const Icon(Icons.drive_file_rename_outline),
        onPressed: _renameFile,
      ));
    }

    return actions;
  }

  Widget _buildFileList() {
    if (_files.isEmpty) {
      return const Center(child: Text('文件夹为空'));
    }
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final entity = _files[index];
        final isSelected = _selectedFiles.contains(entity);
        return _defaultItemBuilder(context, entity, isSelected, () {
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

  void _showCreateFileDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('新建文件'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
                hintText: '文件名（例如: myFile${widget.fileExtensions.first}）'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  _createFile(controller.text);
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

    for (final entity in _clipboard) {
      final newPath =
          path.join(_currentDirectory.path, path.basename(entity.path));
      try {
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
            // 文件夹的复制需要递归进行
            final newDir = Directory(newPath);
            await newDir.create();
            await for (final subEntity in entity.list(recursive: true)) {
              final relativePath =
                  path.relative(subEntity.path, from: entity.path);
              final newSubPath = path.join(newDir.path, relativePath);
              if (subEntity is File) {
                await File(newSubPath).create(recursive: true);
                await subEntity.copy(newSubPath);
              } else if (subEntity is Directory) {
                await Directory(newSubPath).create(recursive: true);
              }
            }
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('粘贴失败: $e')),
        );
      }
    }

    setState(() {
      if (_clipboardAction == FileAction.cut) {
        _clipboard.clear();
      }
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
    final controller = TextEditingController(text: path.basename(entity.path));

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
              if (controller.text.isNotEmpty) {
                final newPath =
                    path.join(_currentDirectory.path, controller.text);
                try {
                  await entity.rename(newPath);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('重命名失败: $e')),
                  );
                }
                setState(() {
                  _isMultiSelectMode = false;
                  _selectedFiles.clear();
                });
                _loadFiles();
                Navigator.of(context).pop();
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
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
