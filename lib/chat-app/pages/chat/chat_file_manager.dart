import 'dart:io';

import 'package:flutter/material.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/pages/chat/new_group_chat.dart';
import 'package:flutter_example/chat-app/pages/vault_manager.dart';
import 'package:flutter_example/chat-app/providers/chat_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

// 自定义文件和文件夹的UI构建器
typedef FileTileBuilder = Widget Function(
    BuildContext context, FileSystemEntity entity);

// 文件管理器组件
class FileManagerWidget extends StatefulWidget {
  final Directory directory;
  final List<String> fileExtensions = const ['.chat'];
  // final Function(File) onFileTap;

  const FileManagerWidget({
    super.key,
    required this.directory,
    // required this.onFileTap,
  });

  @override
  State<FileManagerWidget> createState() => _FileManagerWidgetState();
}

class _FileManagerWidgetState extends State<FileManagerWidget> {
  late final TreeNode<FileSystemEntity> _root;
  late TreeNode<FileSystemEntity> _selectedNode;

  FileSystemEntity? _copiedEntity;

  late TreeViewController controller;

  @override
  void initState() {
    super.initState();
    _root = _buildFileTree(widget.directory);
    _selectedNode = _root;
  }

  // 递归构建文件树
  TreeNode<FileSystemEntity> _buildFileTree(Directory dir) {
    final parentNode = TreeNode<FileSystemEntity>(data: dir);
    try {
      final items = dir.listSync().toList();

      items.sort((a, b) {
        if (a is Directory && b is File) return -1;
        if (a is File && b is Directory) return 1;
        return p.basename(a.path).compareTo(p.basename(b.path));
      });

      for (final entity in items) {
        if (entity is Directory) {
          parentNode.add(_buildFileTree(entity));
        } else if (entity is File) {
          if (widget.fileExtensions == null ||
              widget.fileExtensions!.isEmpty ||
              widget.fileExtensions!
                  .any((ext) => p.extension(entity.path) == ext)) {
            parentNode.add(TreeNode<FileSystemEntity>(data: entity));
          }
        }
      }
    } catch (e) {
      // Handle potential access errors
      print("Error listing directory ${dir.path}: $e");
    }
    return parentNode;
  }

  Widget _buildFileTile(BuildContext context, FileSystemEntity entity) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: entity == _selectedNode?.data
                    ? colors.outlineVariant
                    : Colors.transparent, // 边框颜色
                width: 2.0, // 边框宽度
              ),
              borderRadius: BorderRadius.circular(10.0), // 圆角半径
            ),
            //color:  colors.surfaceContainer : null,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(p.basenameWithoutExtension(entity.path)),
            ),
          ),
        ),
      ],
    );
  }

  // 刷新整个文件树
  void _refreshTree() {
    setState(() {
      _root.clear();
      final newRoot = _buildFileTree(widget.directory);
      for (var child in newRoot.children.values) {
        _root.add(child);
      }
      _root.data = newRoot.data;
    });
  }

  void _addNode(TreeNode<FileSystemEntity> node, FileSystemEntity data) {
    setState(() {
      if (node.data is File) {
        if (node.parent != null) {
          node.parent!.add(TreeNode<FileSystemEntity>(data: data));
        } else {
          print('parent is null.');
        }
      } else if (node.data is Directory) {
        node.add(TreeNode<FileSystemEntity>(data: data));
      } else {
        print('unknown node.');
      }
    });
  }

  // 删除文件或文件夹
  Future<void> _deleteEntity(
      TreeNode<FileSystemEntity> node, BuildContext context) async {
    final entity = node.data!;
    try {
      if (entity is File) {
        await entity.delete();
      } else if (entity is Directory) {
        await entity.delete(recursive: true);
      }
      node.parent!.remove(node);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${p.basename(entity.path)} 已被删除')),
      );
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e')),
      );
    }
  }

  // 复制文件或文件夹
  void _copyEntity(FileSystemEntity entity, BuildContext context) {
    setState(() {
      _copiedEntity = entity;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${p.basename(entity.path)} 已复制')),
    );
  }

  // 粘贴文件或文件夹
  Future<void> _pasteEntity(TreeNode<FileSystemEntity> node,
      Directory destinationDir, BuildContext context) async {
    if (_copiedEntity == null) return;

    final newPath =
        p.join(destinationDir.path, p.basename(_copiedEntity!.path));

    try {
      if (await FileSystemEntity.isDirectory(newPath) ||
          await FileSystemEntity.isFile(newPath)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目标已存在同名文件或文件夹')),
        );
        return;
      }

      if (_copiedEntity is File) {
        await (_copiedEntity as File).copy(newPath);
      } else if (_copiedEntity is Directory) {
        final newDir = Directory(newPath);
        await newDir.create();
        for (final entity
            in (_copiedEntity as Directory).listSync(recursive: true)) {
          final relativePath =
              p.relative(entity.path, from: _copiedEntity!.path);
          final newEntityPath = p.join(newDir.path, relativePath);
          if (entity is File) {
            await File(newEntityPath).parent.create(recursive: true);
            await entity.copy(newEntityPath);
          } else if (entity is Directory) {
            await Directory(newEntityPath).create(recursive: true);
          }
        }
      }
      //_refreshTree(); // 刷新以显示粘贴的文件
      _addNode(node, File(newPath));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已粘贴到 ${p.basename(destinationDir.path)}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('粘贴失败: $e')),
      );
    }
  }

  Future<void> _createFolder(TreeNode<FileSystemEntity> node,
      FileSystemEntity entity, BuildContext context) {
    final dir = (entity is Directory) ? entity : entity.parent;
    final newFolderPath = p.join(dir.path, 'NewFolder');
    int counter = 1;
    String uniqueFolderPath = newFolderPath;

    while (Directory(uniqueFolderPath).existsSync()) {
      uniqueFolderPath = '$newFolderPath($counter)';
      counter++;
    }

    return Directory(uniqueFolderPath).create().then((_) {
      _addNode(node, Directory(uniqueFolderPath));
    }).catchError((e) {
      Get.snackbar('创建文件夹失败', '$e');
    });
  }

  Future<void> _createChat(TreeNode<FileSystemEntity> node,
      FileSystemEntity entity, BuildContext context) async {
    final dir = (entity is Directory) ? entity : entity.parent;
    final char = await customNavigate<CharacterModel?>(CharacterSelector(),
        context: context);

    if (char != null) {
      final chat =
          await ChatController.of.createChatFromCharacter(char, dir.path);
      _openChat(chat.file.path);
      _addNode(node, chat.file);
    }
  }

  Future<void> _createGroupChat(TreeNode<FileSystemEntity> node,
      FileSystemEntity entity, BuildContext context) async {
    final dir = (entity is Directory) ? entity : entity.parent;
    final chat = await customNavigate<ChatModel>(NewChatPage(dir.path),
        context: context);
    if (chat != null) {
      _openChat(chat.file.path);
      _addNode(node, chat.file);
    }
  }

  Future<void> _renameFile(TreeNode<FileSystemEntity> node,
      FileSystemEntity entity, BuildContext context) async {
    final dir = (entity is Directory) ? entity : entity.parent;
    final baseName = p.basenameWithoutExtension(entity.path);
    final extension = p.extension(entity.path);

    final newName = await showDialog<String>(
      context: context,
      builder: (context) {
        String tempName = baseName;
        return AlertDialog(
          title: const Text('重命名'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(labelText: '新名称'),
            controller: TextEditingController(text: baseName),
            onChanged: (value) {
              tempName = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(tempName),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty && newName != baseName) {
      final trimmedNewName = newName.trim();
      if (trimmedNewName.isEmpty) {
        Get.snackbar('重命名失败', '名称不能为空');
        return;
      }

      final newPath = entity is Directory
          ? p.join(dir.path, trimmedNewName)
          : p.join(dir.path, '$trimmedNewName$extension');
      if (await FileSystemEntity.isDirectory(newPath) ||
          await FileSystemEntity.isFile(newPath)) {
        Get.snackbar('重命名失败', '目标已存在同名文件或文件夹');

        return;
      }

      try {
// 先获取规范化的路径
        final normalizedPath = p.normalize(entity.path);
        final normalizedNewPath = p.normalize(newPath);

        // 使用规范化后的路径创建一个新的实体对象，然后执行重命名
        final normalizedEntity =
            entity is File ? File(normalizedPath) : Directory(normalizedPath);

        // TODO: Win 命名失败 WTF??
        // TODO: 试试Android失败不失败
        await normalizedEntity.rename(normalizedNewPath);

        setState(() {
          // 更新节点数据时也使用规范化后的路径
          node.data = entity is File
              ? File(normalizedNewPath)
              : Directory(normalizedNewPath);
        });
      } catch (e, s) {
        Get.snackbar('重命名失败', '$e');
        print(s);
        print(e);
      }
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

  // 显示操作菜单
  void _showContextMenu(BuildContext context, TapDownDetails details,
      TreeNode<FileSystemEntity> node) {
    final entity = node.data!;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              SizedBox(
                height: 48,
                child: Center(
                  child: Text(
                    p.basename(entity.path),
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('删除'),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteEntity(node, context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('复制'),
                onTap: () {
                  Navigator.of(context).pop();
                  _copyEntity(entity, context);
                },
              ),
              if (entity is Directory && _copiedEntity != null)
                ListTile(
                  leading: const Icon(Icons.content_paste),
                  title: const Text('粘贴'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pasteEntity(node, entity, context);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('重命名'),
                onTap: () {
                  Navigator.of(context).pop();
                  _renameFile(node, entity, context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.create_new_folder),
                title: const Text('创建文件夹'),
                onTap: () {
                  Navigator.of(context).pop();
                  _createFolder(node, entity, context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: TreeView.simple(
            onTreeReady: (controller) {
              this.controller = controller;
            },
            tree: _root,
            showRootNode: false, // 不显示根节点
            expansionIndicatorBuilder: (context, node) {
              if (node.isLeaf || (node.data is File)) {
                return NoExpansionIndicator(
                    tree: _root); //const SizedBox.shrink();
              }
              return ChevronIndicator.rightDown(
                alignment: Alignment.centerRight,
                tree: node,
                color: Colors.grey[700],
              );
            },
            indentation: Indentation(
              style: IndentStyle.scopingLine,
              color: Theme.of(context).colorScheme.outline,
            ),
            builder: (context, node) {
              final entity = node.data!;
              final tile = _buildFileTile(context, entity);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedNode = node;
                  });

                  if (entity is File) {
                    _openChat(entity.path);
                    // widget.onFileTap(entity);
                  } else {
                    if (node.isExpanded) {
                      controller.collapseNode(node);
                    } else {
                      controller.expandNode(node);
                    }

                    //node.isExpanded = !node.isExpanded;
                    // node.toggleExpansion();
                  }
                },
                onLongPress: () {
                  // 我们需要 TapDownDetails，所以使用 GestureDetector.onTapDown 配合 LongPress
                },
                onTapDown: (details) {
                  // 这里可以触发长按菜单，但在 onTapDown 中直接 showMenu 体验不佳
                  // 我们用一个透明的 onLongPressStart 触发
                },
                child: Builder(builder: (context) {
                  return GestureDetector(
                    onLongPressStart: (details) {
                      _showContextMenu(
                          context,
                          TapDownDetails(
                              globalPosition: details.globalPosition),
                          node);
                    },
                    child: tile,
                  );
                }),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                  onPressed: () {
                    _createChat(_selectedNode,
                        _selectedNode.data ?? widget.directory, context);
                  },
                  icon: Icon(Icons.chat)),
              SizedBox(
                width: 8,
              ),
              IconButton(
                  onPressed: () {
                    _createGroupChat(_selectedNode,
                        _selectedNode.data ?? widget.directory, context);
                  },
                  icon: Icon(Icons.group)),
              SizedBox(
                width: 8,
              ),
              IconButton(
                  onPressed: () {
                    _createFolder(_selectedNode,
                        _selectedNode.data ?? widget.directory, context);
                  },
                  icon: Icon(Icons.create_new_folder)),
            ],
          ),
        )
      ],
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
        appBar: SillyChatApp.isDesktop()
            ? AppBar(
                title: GestureDetector(
                  onTap: () {
                    customNavigate(VaultManagerPage(), context: context);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_outlined),
                      SizedBox(
                        width: 8,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            SettingController.currectValutName,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '文件列表',
                            style: TextStyle(
                                fontSize: 12, color: theme.colorScheme.outline),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              )
            : null,
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
