import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_page.dart';
import 'package:flutter_example/chat-app/pages/chat_options/edit_chat_option.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/FileUtils.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/main.dart';
import 'package:get/get.dart';

import 'package:path/path.dart' as p;

class OtherSettingsPage extends StatelessWidget {
  const OtherSettingsPage({super.key});

  Future<int> clearUnusedImage() async {
    int delete_count = 0;
    final Set<String> all_reses = Set();
    try {
      /**
       * 收集聊天中的图片
       */
      final dir = await SettingController.of.getChatDirectory();
      final path = dir.path;

      if (!await dir.exists()) {
        debugPrint('clearUnusedImage: directory does not exist: $path');
        return -1;
      }

      final List<File> files = [];

      await for (final entity
          in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          files.add(entity);
        }
      }
      for (final f in files) {
        if (Fileutils.isChatFile(f.path)) {
          final chat = await ChatModel.fromFile(f);
          final chat_reses = chat.messages.expand((msg) => msg.resPath);

          all_reses.addAll(chat_reses);
        }
      }

      /**
       * 收集头像和背景图片
       */
      for (final c in CharacterController.of.characters) {
        all_reses.add(c.avatar);
        if (c.backgroundImage != null) {
          all_reses.add(c.backgroundImage!);
        }
      }

      Directory imgDir = Directory(await SettingController.of.getImagePath());
      final all_filenames = all_reses
          .where((r) => r != null && r.isNotEmpty)
          .map((r) => p.basename(r))
          // .map((s) => s.toLowerCase())
          .toSet();

      if (!await imgDir.exists()) {
        debugPrint(
            'clearUnusedImage: image directory does not exist: ${imgDir.path}');
        return -1;
      }

      /**
       * 开始删除图片（不包括画廊内容）
       */
      await for (final entity
          in imgDir.list(recursive: false, followLinks: false)) {
        if (entity is File) {
          final fname = p.basename(entity.path); //.toLowerCase();
          if (!all_filenames.contains(fname)) {
            try {
              delete_count++;
              await entity.delete();
              debugPrint('Deleted unused image: ${entity.path}');
            } catch (e) {
              debugPrint('Failed to delete ${entity.path}: $e');
            }
          }
        }
      }
      return delete_count;
    } catch (e, st) {
      debugPrint('clearUnusedImage error: $e\n$st');
      return -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 通过GetX查找已初始化的VaultSettingController实例
    final VaultSettingController controller =
        Get.find<VaultSettingController>();
    // 获取响应式的自动标题设置模型
    final settings = controller.miscSetting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('其他设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          ListTile(
            title: const Text('清除未使用图片'),
            subtitle: const Text('清除冗余图片。会扫描所有聊天文件。可能很慢。'),
            trailing: Icon(Icons.arrow_right),
            onTap: () async {
              SillyChatApp.snackbar(context, "正在扫描...");
              int c = await clearUnusedImage();
              if (c == -1) {
                SillyChatApp.snackbarErr(context, "清理失败!");
              } else {
                SillyChatApp.snackbar(context, "清理成功，删除了${c}个文件");
              }
            },
          ),
          const Divider(height: 32),
        ],
      ),
    );
  }

  /// 辅助方法，用于构建数字输入的设置项UI。
  Widget _buildNumberSection({
    required BuildContext context,
    required String title,
    required String description,
    required int initialValue,
    required ValueChanged<int> onChanged,
    required VoidCallback onSave,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        TextFormField(
          initialValue: initialValue.toString(),
          keyboardType: TextInputType.number,
          // 只允许输入数字
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) {
            // 将字符串转换为整数，如果解析失败则默认为0
            onChanged(int.tryParse(value) ?? 0);
          },
          onTapOutside: (event) {
            FocusScope.of(context).unfocus();
            onSave();
          },
          onFieldSubmitted: (value) {
            onSave();
          },
          decoration: const InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          ),
        ),
      ],
    );
  }
}
