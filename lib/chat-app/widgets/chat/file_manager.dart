import 'dart:io';

import 'package:flutter/material.dart';
import 'package:animated_tree_view/animated_tree_view.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// 自定义文件和文件夹的UI构建器
typedef FileTileBuilder = Widget Function(
    BuildContext context, FileSystemEntity entity);

// 文件管理器组件
class FileManagerWidget extends StatefulWidget {
  final Directory directory;
  final List<String>? fileExtensions;
  final Function(File) onFileTap;
  final FileTileBuilder? customFileTileBuilder;

  const FileManagerWidget({
    super.key,
    required this.directory,
    this.fileExtensions,
    required this.onFileTap,
    this.customFileTileBuilder,
  });

  @override
  State<FileManagerWidget> createState() => _FileManagerWidgetState();
}

class _FileManagerWidgetState extends State<FileManagerWidget> {
  late final TreeNode<FileSystemEntity> _root;
  FileSystemEntity? _copiedEntity;

  late TreeViewController controller;

  @override
  void initState() {
    super.initState();
    _root = _buildFileTree(widget.directory);
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
  Future<void> _pasteEntity(
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
      _refreshTree(); // 刷新以显示粘贴的文件
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已粘贴到 ${p.basename(destinationDir.path)}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('粘贴失败: $e')),
      );
    }
  }

  // 显示操作菜单
  void _showContextMenu(BuildContext context, TapDownDetails details,
      TreeNode<FileSystemEntity> node) {
    final entity = node.data!;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        details.globalPosition & const Size(40, 40), // tap position
        Offset.zero & overlay.size, // overlay size
      ),
      items: [
        PopupMenuItem(
          child: const Text('删除'),
          onTap: () => _deleteEntity(node, context),
        ),
        PopupMenuItem(
          child: const Text('复制'),
          onTap: () => _copyEntity(entity, context),
        ),
        if (entity is Directory && _copiedEntity != null)
          PopupMenuItem(
            child: const Text('粘贴'),
            onTap: () => _pasteEntity(entity, context),
          ),
        PopupMenuItem(
          child: const Text('创建文件夹'),
          onTap: () => _copyEntity(entity, context),
        ),
      ],
    );
  }

  // 默认的文件/文件夹列表项样式
  Widget _defaultFileTileBuilder(
      BuildContext context, FileSystemEntity entity) {
    return ListTile(
      leading: entity is Directory
          ? const Icon(Icons.folder)
          : const Icon(Icons.description),
      title: Text(p.basename(entity.path)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TreeView.simple(
      onTreeReady: (controller) {
        this.controller = controller;
      },
      tree: _root,
      showRootNode: false, // 不显示根节点
      expansionIndicatorBuilder: (context, node) {
        if (node.isLeaf || (node.data is File)) {
          return NoExpansionIndicator(tree: _root); //const SizedBox.shrink();
        }
        return ChevronIndicator.rightDown(
          alignment: Alignment.centerRight,
          tree: node,
          color: Colors.grey[700],
        );
      },
      indentation: const Indentation(style: IndentStyle.squareJoint),
      builder: (context, node) {
        final entity = node.data!;
        final tile = widget.customFileTileBuilder != null
            ? widget.customFileTileBuilder!(context, entity)
            : _defaultFileTileBuilder(context, entity);

        return GestureDetector(
          onTap: () {
            print('tap');
            if (entity is File) {
              widget.onFileTap(entity);
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
                    TapDownDetails(globalPosition: details.globalPosition),
                    node);
              },
              child: tile,
            );
          }),
        );
      },
    );
  }
}

class Test extends StatelessWidget {
  const Test({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'File Manager Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Future<Directory> _appDocumentsDirectory;

  @override
  void initState() {
    super.initState();
    _appDocumentsDirectory = _getDirectory();
    _createDummyFiles();
  }

  Future<Directory> _getDirectory() async {
    // 这里以应用文档目录为例，你也可以选择其他目录
    return await getApplicationDocumentsDirectory();
  }

  // 创建一些虚拟文件和文件夹用于演示
  Future<void> _createDummyFiles() async {
    final dir = await _getDirectory();
    final subDir = Directory('${dir.path}/MyFolder');
    if (!await subDir.exists()) {
      await subDir.create();
    }
    await File('${dir.path}/file1.txt').writeAsString('hello');
    await File('${dir.path}/image.png').writeAsString('');
    await File('${subDir.path}/file2.log').writeAsString('log data');
    await File('${subDir.path}/document.pdf').writeAsString('pdf content');
    final nestedDir = Directory('${subDir.path}/Nested');
    if (!await nestedDir.exists()) {
      await nestedDir.create();
    }
    await File('${nestedDir.path}/deep_file.txt').writeAsString('deep');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Manager'),
      ),
      body: FutureBuilder<Directory>(
        future: _appDocumentsDirectory,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.hasData) {
              return FileManagerWidget(
                directory: snapshot.data!,
                fileExtensions: const ['.txt', '.pdf', '.png'], // 只显示这几种类型的文件
                onFileTap: (file) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Tapped on: ${file.path}')),
                  );
                },
              );
            }
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
