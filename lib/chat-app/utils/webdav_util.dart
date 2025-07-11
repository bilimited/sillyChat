import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:get/get.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

class WebDavUtil {
  late webdav.Client client;
  final SettingController _settingController = Get.find();

  String get backupFolder {
    if (SettingController.currectValutName == '') {
      return '/SillyChat';
    }

    return '/SillyChat/${SettingController.currectValutName}';
  }

  // 初始化WebDAV客户端
  Future<void> init() async {
    client = webdav.newClient(
      SettingController.webdav_url,
      user: SettingController.webdav_username,
      password: SettingController.webdav_password,
      debug: true,
    );
  }

  // 上传所有本地数据到WebDAV
  Future<void> backupAllData(BuildContext context,
      {void Function(int, int)? onProgress,
      void Function(int)? onSuccess,
      void Function(Object)? onFail}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primaryContainer,
          ),
        );
      },
    );
    try {
      final directory = await _settingController.getVaultPath();
      await client.mkdir(backupFolder);

      // 获取所有需要备份的文件
      final filesToBackup = [
        'characters.json',
        'prompts.json',
        'settings.json',
        'chat_options.json',
        'character_avatars.zip'
        'lorebooks.json',
      ];

      // 添加所有聊天数据文件
      int fileId = 1;
      while (await File('${directory}/chats_$fileId.json').exists()) {
        filesToBackup.add('chats_$fileId.json');
        fileId++;
      }

      // 上传每个文件
      for (String fileName in filesToBackup) {
        final localFile = File('${directory}/$fileName');
        print('$fileName');

        if (await localFile.exists()) {
          await client.writeFromFile(
            '${directory}/$fileName',
            '$backupFolder/$fileName',
          );
        }
      }
      if (onSuccess != null) {
        onSuccess(filesToBackup.length);
      }
    } catch (e) {
      if (onFail != null) {
        onFail(e);
      } else {
        rethrow;
      }
    }
  }

  // 从WebDAV下载所有数据
  Future<List<webdav.File>> downloadAllProps() async {
    try {
      await client.mkdir(backupFolder);
      // 获取备份目录中的所有文件
      return await client.readDir(backupFolder);
    } catch (e) {
      print('下载数据失败: $e');
      rethrow;
    }
  }

  // 将下载的数据恢复到本地。暂时懒得改了
  Future<void> downloadAllData(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
          );
        },
      );
      final directory = await Get.find<SettingController>().getVaultPath();
      final files = await downloadAllProps();

      for (var file in files) {
        if (file.isDir == false) {
          final localPath = '${directory}/${file.name}';
          await client.read2File(
            file.path!,
            localPath,
            onProgress: (count, total) {
              print('Downloading ${file.name}: $count/$total');
            },
          );
        }
      }
      Get.back();
      Get.snackbar("下载成功", "下载了${files.length}个文件");
    } catch (e) {
      Get.back();
      Get.snackbar('恢复数据失败', '$e');
      rethrow;
    }
  }
}
