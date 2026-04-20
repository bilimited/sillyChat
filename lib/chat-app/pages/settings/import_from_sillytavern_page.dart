import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STCharacterImporter.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STConfigImporter.dart';
import 'package:flutter_example/chat-app/utils/sillyTavern/STLorebookImporter.dart';
import 'package:flutter_example/chat-app/widgets/filePickerWindow.dart';
import 'package:get/get.dart';

class ImportFromSillytavernPage extends StatelessWidget {
  const ImportFromSillytavernPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('从 SillyTavern 导入'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 顶部提示说明
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Text(
              '请选择你想要从 SillyTavern 导入的数据类型。支持读取特定的 JSON 或 PNG 文件。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // 导入角色卡
          _buildImportCard(
            context,
            icon: Icons.badge_outlined,
            title: '导入角色卡',
            subtitle: '支持 .png (角色卡图片)',
            onTap: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['png'],
                dialogTitle: '选择角色卡PNG文件',
              );
              if (result == null || result.files.single.path == null) return;

              final file = File(result.files.single.path!);
              try {
                String decoded = await STCharacterImporter.readPNGExts(file);
                final char = await STCharacterImporter.fromJson(
                    json.decode(decoded), file.path, file.path);
                if (char != null) {
                  CharacterController.of.addCharacter(char);
                  Get.snackbar('导入成功', '角色卡已导入');
                } else {
                  Get.snackbar('导入失败', '未知错误');
                }
              } catch (e) {
                Get.snackbar('导入失败', '$e');
              }
            },
          ),

          const SizedBox(height: 16),

          // 导入预设
          _buildImportCard(
            context,
            icon: Icons.tune_outlined,
            title: '导入预设',
            subtitle: '导入角色设置、提示词预设等 JSON',
            onTap: () {
              FileImporter(
                  introduction: '导入SillyTavern预设。',
                  paramList: [],
                  allowedExtensions: ['json'],
                  onImport: (fileName, content, params, path) {
                    STConfigImporter.fromJson(json.decode(content), fileName);
                  }).pickAndProcessFile(context);
            },
          ),

          const SizedBox(height: 16),

          // 导入世界书
          _buildImportCard(
            context,
            icon: Icons.menu_book_outlined,
            title: '导入世界书',
            subtitle: '导入世界设定集 (Lorebooks) JSON',
            onTap: () {
              FileImporter(
                introduction:
                    '请注意:本应用仍在测试阶段，未兼容SillyTavern的部分功能。导入后，默认将被分类为“世界”类型。',
                paramList: [],
                allowedExtensions: ['json'],
                onImport: (fileName, content, params, path) {
                  final loreBook = STLorebookImporter.fromJson(
                      json.decode(content),
                      fileName: fileName);
                  if (loreBook != null) {
                    // 导入时可以默认设置类型，或者根据内容判断
                    //loreBook.type = _selectedType.value;
                    LoreBookController.of.addLorebook(loreBook);
                  }
                },
              ).pickAndProcessFile(context);
            },
          ),

          const SizedBox(height: 40),

          // 底部帮助提示（可选）
          // Center(
          //   child: TextButton.icon(
          //     onPressed: () {},
          //     icon: const Icon(Icons.help_outline, size: 18),
          //     label: const Text('如何导出 SillyTavern 数据？'),
          //     style: TextButton.styleFrom(
          //       foregroundColor: colorScheme.secondary,
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  /// 构建通用的导入卡片按钮
  Widget _buildImportCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      color: colorScheme.surfaceContainerLow, // 使用主题内的容器背景色
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: colorScheme.onPrimaryContainer,
            size: 28,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(subtitle),
        ),
        trailing: Icon(Icons.chevron_right, color: colorScheme.outline),
        onTap: onTap,
      ),
    );
  }
}
