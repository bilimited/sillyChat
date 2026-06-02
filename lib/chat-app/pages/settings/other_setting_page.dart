import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/utils/FileUtils.dart';
import 'package:flutter_example/main.dart';
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

}
