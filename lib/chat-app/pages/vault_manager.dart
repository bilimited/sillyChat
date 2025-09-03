import 'package:flutter/material.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../providers/setting_controller.dart';
import 'package:path/path.dart' as p;

class VaultManagerPage extends StatefulWidget {
  const VaultManagerPage({super.key});

  @override
  State<VaultManagerPage> createState() => _VaultManagerPageState();
}

class _VaultManagerPageState extends State<VaultManagerPage> {
  final SettingController settingController = Get.find<SettingController>();
  List<String> vaultFolders = [];

  @override
  void initState() {
    super.initState();
    _loadVaultFolders();
  }

  Future<void> migrateFiles({
    required String sourcePath,
    required String destinationPath,
  }) async {
    try {
      final sourceDir = Directory(sourcePath);
      final destinationDir = Directory(destinationPath);

      if (!await sourceDir.exists()) {
        throw Exception("源路径不存在: $sourcePath");
      }

      // 1. 如果目标路径存在，则清空
      if (await destinationDir.exists()) {
        await for (final entity in destinationDir.list()) {
          if (entity is File) {
            await entity.delete();
          } else if (entity is Directory) {
            await entity.delete(recursive: true);
          }
        }
      } else {
        // 如果目标路径不存在，则创建
        await destinationDir.create(recursive: true);
      }

      // 2. 获取所有源文件以计算总数
      final allFiles = await sourceDir
          .list(recursive: true)
          .where((entity) => entity is File)
          .toList();
      final totalFiles = allFiles.length;
      if (totalFiles == 0) {
        return;
      }

      // 3. 逐个复制文件并更新进度
      await for (final entity in sourceDir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = p.relative(entity.path, from: sourcePath);
          final newPath = p.join(destinationPath, relativePath);

          // 确保目标文件的目录存在
          final newFile = File(newPath);
          await newFile.parent.create(recursive: true);

          await entity.copy(newPath);
        } else if (entity is Directory) {
          // 如果是空目录，也需要创建
          final relativePath = p.relative(entity.path, from: sourcePath);
          final newDirPath = p.join(destinationPath, relativePath);
          final newDir = Directory(newDirPath);
          if (!await newDir.exists()) {
            await newDir.create(recursive: true);
          }
        }
      }

      await _loadVaultFolders();
      // SettingController.of.setCurrentVaultName('');
      SillyChatApp.restart();

      SillyChatApp.snackbar(context, '迁移已完成!');
    } catch (e) {
      SillyChatApp.snackbar(context, "文件迁移失败: $e");
      rethrow;
    }
  }

  Future<void> _loadVaultFolders() async {
    final directory = await getApplicationDocumentsDirectory();
    final baseDir = '${directory.path}/SillyChat';
    final dir = Directory(baseDir);

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final List<String> folders = [];
    await for (var entity in dir.list()) {
      if (entity is Directory) {
        final folderName = entity.path.split(Platform.pathSeparator).last;
        if (!folderName.startsWith('.') && folderName != 'chats') {
          folders.add(folderName);
        }
      }
    }

    setState(() {
      vaultFolders = folders;
    });
  }

  void _showConfirmationDialog(String vaultName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('切换仓库'),
          content: Text('确定要切换到仓库 "$vaultName" 吗？应用将会重启。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                settingController.setCurrentVaultName(vaultName);
                Get.back();
                Get.back();
                SillyChatApp.restart();
              },
              child: Text('确认'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createNewVault(String vaultName, bool copyCurrentVault) async {
    final directory = await getApplicationDocumentsDirectory();
    final baseDir = '${directory.path}/SillyChat';
    final newVaultPath = '$baseDir/$vaultName';
    final newVaultDir = Directory(newVaultPath);

    if (await newVaultDir.exists()) {
      Get.snackbar('错误', '仓库已存在');
      return;
    }

    await newVaultDir.create();

    if (copyCurrentVault) {
      final currentVaultPath = '$baseDir/${SettingController.currectValutName}';
      final currentVaultDir = Directory(currentVaultPath);

      if (await currentVaultDir.exists()) {
        await for (var entity in currentVaultDir.list()) {
          if (entity is File) {
            final fileName = entity.path.split('\\').last.split('/').last;
            if (fileName.startsWith('chat_options') ||
                !fileName.startsWith('chat')) {
              final newPath = '${newVaultDir.path}/$fileName';
              // 这里发生了错误
              await entity.copy(newPath);
            }
          }
        }
      }
    }

    await _loadVaultFolders();
    Get.snackbar('成功', '仓库创建成功');
  }

  void _showCreateVaultDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('创建新仓库'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.create_new_folder),
                title: Text('创建空白仓库'),
                onTap: () {
                  Navigator.pop(context);
                  _showNameInputDialog(false);
                },
              ),
              ListTile(
                leading: Icon(Icons.content_copy),
                title: Text('复制当前仓库'),
                onTap: () {
                  Navigator.pop(context);
                  _showNameInputDialog(true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNameInputDialog(bool copyCurrentVault) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('输入仓库名称'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '请输入仓库名称',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.pop(context);
                  _createNewVault(controller.text, copyCurrentVault);
                }
              },
              child: Text('确认'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteVault(String vaultName) async {
    final directory = await getApplicationDocumentsDirectory();
    final vaultPath = '${directory.path}/SillyChat/$vaultName';
    final vaultDir = Directory(vaultPath);

    if (await vaultDir.exists()) {
      await vaultDir.delete(recursive: true);
      await _loadVaultFolders();
      Get.snackbar('成功', '仓库已删除');
    }
  }

  Future<void> _renameVault(String oldName, String newName) async {
    final directory = await getApplicationDocumentsDirectory();
    final baseDir = '${directory.path}/SillyChat';
    final oldPath = '$baseDir/$oldName';
    final newPath = '$baseDir/$newName';

    if (await Directory(newPath).exists()) {
      Get.snackbar('错误', '目标名称已存在');
      return;
    }

    await Directory(oldPath).rename(newPath);
    if (SettingController.currectValutName == oldName) {
      settingController.setCurrentVaultName(newName);
    }
    await _loadVaultFolders();
    Get.snackbar('成功', '仓库已重命名');
  }

  void _showDeleteConfirmDialog(String vaultName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('删除仓库'),
          content: Text('确定要删除仓库 "$vaultName" 吗？此操作不可恢复。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteVault(vaultName);
              },
              child: Text('确认删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(String oldName) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('重命名仓库'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '请输入新名称',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  Navigator.pop(context);
                  _renameVault(oldName, controller.text);
                }
              },
              child: Text('确认'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('仓库管理(当前:${SettingController.currectValutName})'),
        actions: [
          IconButton(
              onPressed: () async {
                if (await SettingController.of
                    .isExternalStorageDirectoryExists()) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text('迁移应用数据'),
                        content: Text('该操作将会把应用数据从内部储存迁移到外部储存。'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('取消'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              migrateFiles(
                                  sourcePath: await SettingController.of
                                      .getOldVaultPath(),
                                  destinationPath: await SettingController.of
                                      .getVaultPath());
                            },
                            child: Text('确认迁移',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      );
                    },
                  );
                } else {
                  SillyChatApp.snackbar(context, '不需要迁移');
                }
              },
              icon: Icon(Icons.folder_copy))
        ],
      ),
      body: ListView.builder(
        itemCount: vaultFolders.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return ListTile(
              leading: Icon(Icons.folder_open),
              title: Text('根目录'),
              onTap: () => _showConfirmationDialog(''),
            );
          }
          final folderName = vaultFolders[index - 1];
          return ListTile(
            leading: Icon(Icons.folder),
            title: Text(folderName),
            onTap: () => _showConfirmationDialog(folderName),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () => _showRenameDialog(folderName),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteConfirmDialog(folderName),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateVaultDialog,
        child: Icon(Icons.add),
      ),
    );
  }
}
