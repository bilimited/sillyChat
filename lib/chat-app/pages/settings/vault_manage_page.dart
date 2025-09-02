import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class VaultManagementPage extends StatelessWidget {
  VaultManagementPage({super.key});

  final SettingController settingController = Get.put(SettingController());

  // 在新仓库中需要检查的文件列表
  final List<String> requiredFiles = ['settings.json'];

  Future<void> _exportVaultAsZip(BuildContext context) async {
    try {
      // 1. 获取当前仓库的路径
      final sourceDir = Directory(await settingController.getVaultPath());
      final vaultName = p.basename(sourceDir.path);

      // 2. 获取系统的下载文件夹路径
      // getDownloadsDirectory() 在 Android, iOS, Linux, macOS, Windows 上都可用。
      final Directory? downloadsDir = await getDownloadsDirectory();

      // 检查是否成功获取下载文件夹
      if (downloadsDir == null) {
        // 在某些极少数情况或特定平台配置下可能无法获取
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法找到下载文件夹。')),
        );
        print('错误：无法获取下载文件夹。');
        return;
      }

      // 3. 构建最终的输出文件路径
      final String outputFile = p.join(downloadsDir.path, '$vaultName.zip');

      // 4. 创建一个 ZIP 编码器并指定输出路径
      final encoder = ZipFileEncoder();
      encoder.create(outputFile);

      // 5. 递归地将源目录中的所有文件和文件夹添加到压缩包中
      // 使用 listSync(recursive: true) 来遍历所有子文件和目录
      final List<FileSystemEntity> files = sourceDir.listSync(recursive: true);
      for (var file in files) {
        if (file is File) {
          // 获取文件相对于仓库根目录的路径，以保持压缩包内的目录结构
          final relativePath = p.relative(file.path, from: sourceDir.path);
          await encoder.addFile(file, relativePath);
        }
      }

      // 6. 关闭编码器以完成文件写入
      encoder.close();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('仓库已成功导出到下载文件夹: $outputFile')),
      );
    } catch (e) {
      print('导出仓库失败: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  // 添加新仓库的方法
  void _addVault(BuildContext context) async {
    // 打开文件选择器以选择一个文件夹
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      final directory = Directory(selectedDirectory);
      //final vaultName = p.(selectedDirectory);

      // 检查仓库是否已存在
      if (settingController.vaultPaths.contains(selectedDirectory)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('该仓库已存在。')),
        );
        return;
      }

      // 检查文件夹是否为空
      if (await directory.list().isEmpty) {
        // 执行初始化函数
        // await _initializeNewVault(directory);
        settingController.vaultPaths.add(selectedDirectory);
        settingController.saveGlobalSettings();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('空仓库已初始化并添加。')),
        );
      } else {
        // 检查所需文件是否存在
        List<String> missingFiles = [];
        for (String fileName in requiredFiles) {
          final file = File(p.join(selectedDirectory, fileName));
          if (!await file.exists()) {
            missingFiles.add(fileName);
          }
        }

        if (missingFiles.isNotEmpty) {
          // 如果文件丢失，则显示警告
          bool? continueAnyway = await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Text('警告'),
                content: Text('所选文件夹中已存在文件，要继续吗？'),
                actions: <Widget>[
                  TextButton(
                    child: Text('取消'),
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                  ),
                  TextButton(
                    child: Text('继续'),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                  ),
                ],
              );
            },
          );

          if (continueAnyway != null && continueAnyway) {
            settingController.vaultPaths.add(selectedDirectory);
            settingController.saveGlobalSettings();
          }
        } else {
          // 如果所有文件都存在，则添加仓库
          settingController.vaultPaths.add(selectedDirectory);
          settingController.saveGlobalSettings();
        }
      }
    }
  }

  // 为新的空仓库执行的初始化函数
  Future<void> _initializeNewVault(Directory directory) async {
    // 在此创建所需的默认文件和文件夹
    for (String fileName in requiredFiles) {
      final file = File(p.join(directory.path, fileName));
      await file.create();
    }
    // 创建一个 'chats' 文件夹
    final chatDir = Directory(p.join(directory.path, 'chats'));
    if (!await chatDir.exists()) {
      await chatDir.create();
    }
  }

  void _showConfirmationDialog(BuildContext context, String vaultPath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('切换仓库'),
          content: Text('确定要切换到仓库 "${p.basename(vaultPath)}" 吗？应用将会重启。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                settingController.setCurrentVaultName(vaultPath);
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

  void _showDeleteConfirmationDialog(
      BuildContext context, int index, String vaultName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('删除仓库'),
          content: Text('确定要删除仓库 "$vaultName" 吗？此操作无法撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () {
                settingController.vaultPaths.removeAt(index);
                settingController.saveGlobalSettings();
                Navigator.pop(context);
              },
              child: Text('删除',
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
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
        title: Text('仓库管理'),
        actions: [
          IconButton(
            icon: Icon(Icons.archive_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('导出中~')),
              );
              _exportVaultAsZip(context);
            },
            tooltip: '导出当前仓库',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 当前仓库信息卡片
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前仓库',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 8),
                    Text(
                      SettingController.currectValutPath.isNotEmpty
                          ? p.basename(SettingController.currectValutPath.value)
                          : '根目录',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(height: 4),
                    Text(
                      SettingController.currectValutPath.isNotEmpty
                          ? SettingController.currectValutPath.value
                          : '默认应用数据目录',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16), // 卡片间的间距

            // 仓库列表标题

            // 仓库列表
            Expanded(
              child: Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Obx(
                  () => ListView.builder(
                    itemCount: settingController.vaultPaths.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // "根目录" 选项
                        return ListTile(
                          title: Text('根目录'),
                          onTap: () {
                            _showConfirmationDialog(context, '');
                          },
                        );
                      }
                      final vaultIndex = index - 1;
                      final vaultPath =
                          settingController.vaultPaths[vaultIndex];
                      final vaultName = p.basename(vaultPath);
                      return ListTile(
                        title: Text(vaultName),
                        subtitle: Text(
                          vaultPath,
                          style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline),
                        ),
                        onTap: () {
                          _showConfirmationDialog(context, vaultPath);
                        },
                        trailing: IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error),
                          onPressed: () {
                            _showDeleteConfirmationDialog(
                                context, vaultIndex, vaultName);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      // 添加仓库按钮
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          icon: Icon(Icons.add_box_outlined),
          label: Text('添加仓库'),
          onPressed: () => _addVault(context),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16),
            textStyle: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
