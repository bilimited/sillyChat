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

  Future<void> _loadVaultFolders() async {
    final directory = await SettingController.of.getRootPath();
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
          title: Text('切换项目'),
          content: Text('确定要切换到项目 "$vaultName" 吗？应用将会重启。'),
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
    final directory = await SettingController.of.getRootPath();
    final baseDir = '${directory.path}/SillyChat';
    final newVaultPath = '$baseDir/$vaultName';
    final newVaultDir = Directory(newVaultPath);

    if (await newVaultDir.exists()) {
      Get.snackbar('错误', '项目已存在');
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
  }

  void _showCreateVaultDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('创建新项目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.create_new_folder),
                title: Text('创建空白项目'),
                onTap: () {
                  Navigator.pop(context);
                  _showNameInputDialog(false);
                },
              ),
              ListTile(
                leading: Icon(Icons.content_copy),
                title: Text('复制当前项目'),
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
          title: Text('输入项目名称'),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: '请输入项目名称',
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
    final directory = await SettingController.of.getRootPath();
    final vaultPath = '${directory.path}/SillyChat/$vaultName';
    final vaultDir = Directory(vaultPath);

    if (await vaultDir.exists()) {
      await vaultDir.delete(recursive: true);
      await _loadVaultFolders();
      Get.snackbar('成功', '项目已删除');
    }
  }

  Future<void> _renameVault(String oldName, String newName) async {
    final directory = await SettingController.of.getRootPath();
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
    Get.snackbar('成功', '项目已重命名');
  }

  void _showDeleteConfirmDialog(String vaultName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('删除项目'),
          content: Text('确定要删除项目 "$vaultName" 吗？此操作不可恢复。'),
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
          title: Text('重命名项目'),
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
        title: Text('项目管理'),
        actions: [],
      ),
      body: ListView.builder(
        itemCount: vaultFolders.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text('这个页面还没有经过充分测试，所以有点危险，请谨慎使用。',
                  style: TextStyle(fontSize: 13)),
            );
          } else if (index == 1) {
            return ListTile(
              leading: Icon(Icons.folder_open),
              title: Text('根目录'),
              onTap: () => _showConfirmationDialog(''),
            );
          }
          final folderName = vaultFolders[index - 2];
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
