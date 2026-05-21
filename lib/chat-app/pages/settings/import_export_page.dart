import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/main.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

class ImportExportPage extends StatelessWidget {
  const ImportExportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('导入导出'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionCard(
            context,
            icon: Icons.file_upload_outlined,
            title: '导出数据',
            subtitle: '将当前仓库的所有数据打包为 ZIP 压缩包并导出到本地',
            onPressed: () => _exportData(context),
          ),
          const SizedBox(height: 24),
          _buildSectionCard(
            context,
            icon: Icons.file_download_outlined,
            title: '导入数据',
            subtitle: '从 ZIP 备份文件中恢复数据。导入将覆盖当前仓库中的所有数据。',
            onPressed: () => _importData(context),
            warning: true,
          ),
        ],
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    final vaultPath = await SettingController.of.getVaultPath();
    final vaultDir = Directory(vaultPath);
    if (!await vaultDir.exists()) {
      Get.snackbar('错误', '仓库目录不存在');
      return;
    }

    // Step 1: Compress vault into temp ZIP
    final vaultName = p.basename(vaultPath);
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final zipFileName = '${vaultName}_$dateStr.zip';
    final tempDir = await Directory.systemTemp.createTemp('sillychat_export');
    final tempZipPath = p.join(tempDir.path, zipFileName);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
      ),
    );

    try {
      final encoder = ZipFileEncoder();
      encoder.create(tempZipPath);
      final files = vaultDir.list(recursive: true, followLinks: false);
      await for (var entity in files) {
        if (entity is File) {
          final relativePath = p.relative(entity.path, from: vaultPath);
          await encoder.addFile(entity, relativePath);
        }
      }
      encoder.close();
      Get.back();
    } catch (e) {
      Get.back();
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
      Get.snackbar('导出失败', '$e');
      return;
    }

    // Step 2: Let user choose save location
    final selectedDir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择保存位置',
    );

    if (selectedDir == null) {
      await tempDir.delete(recursive: true);
      return;
    }

    // Step 3: Copy to chosen directory
    try {
      final destFile = File(p.join(selectedDir, zipFileName));
      await File(tempZipPath).copy(destFile.path);
      await tempDir.delete(recursive: true);

      final fileSize = await destFile.length();
      Get.snackbar('导出成功', '已保存至 ${destFile.path} (${_getSizeString(fileSize)})');
    } catch (e) {
      try {
        await tempDir.delete(recursive: true);
      } catch (_) {}
      Get.snackbar('导出失败', '$e');
    }
  }

  Future<void> _importData(BuildContext context) async {
    // Step 1: Pick ZIP file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
      dialogTitle: '选择备份文件',
    );

    if (result == null || result.files.single.path == null) return;

    final zipPath = result.files.single.path!;
    final zipFile = File(zipPath);

    Archive archive;
    int fileSize;
    try {
      fileSize = await zipFile.length();
      final inputStream = InputFileStream(zipPath);
      archive = ZipDecoder().decodeBuffer(inputStream);
    } catch (e) {
      Get.snackbar('导入失败', '无法读取 ZIP 文件: $e');
      return;
    }

    if (!archive.files.any((f) => f.name == 'settings.json')) {
      Get.snackbar('无效的备份文件', 'ZIP 文件中未找到 settings.json，可能不是有效的仓库备份');
      return;
    }

    // Step 2: Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认导入'),
        content: Text('文件大小: ${_getSizeString(fileSize)}\n\n导入将覆盖当前仓库中的所有数据，是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Step 3: Extract
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
      ),
    );

    try {
      final vaultPath = await SettingController.of.getVaultPath();
      await extractArchiveToDisk(archive, vaultPath);
      Get.back();
      SillyChatApp.restart();
      Get.snackbar('导入完成', '数据已导入，正在重新加载');
    } catch (e) {
      Get.back();
      Get.snackbar('导入失败', '$e');
    }
  }

  String _getSizeString(int byteSize) {
    if (byteSize < 1024) {
      return '$byteSize B';
    } else if (byteSize < 1024 * 1024) {
      return '${(byteSize / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(byteSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
    bool warning = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final warningColor = Colors.orange.shade600;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: warning ? warningColor : colorScheme.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPressed,
                icon: Icon(icon, size: 20),
                label: Text(title),
                style: warning
                    ? FilledButton.styleFrom(
                        backgroundColor: warningColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      )
                    : const ButtonStyle(
                        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 12)),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
