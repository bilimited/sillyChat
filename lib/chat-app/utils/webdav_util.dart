import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:get/get.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';
import 'package:intl/intl.dart';

class WebDavUtil {
  late webdav.Client client;

  String get backupFolder {
    return '/SillyChatFiles';
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
      final vaultPath = SettingController.currectValutPath.value;
      final vaultDir = Directory(vaultPath);

      if (!await vaultDir.exists()) {
        throw Exception("本地仓库目录不存在: $vaultPath");
      }

      final zipFileName = '${p.basename(vaultPath)}.zip';
      final tempDir = await Directory.systemTemp.createTemp('sillychat_backup');
      final zipFile = File(p.join(tempDir.path, zipFileName));

      // 创建压缩包
      var encoder = ZipFileEncoder();
      encoder.create(zipFile.path);

      final files = vaultDir.list(recursive: true, followLinks: false);
      await for (var entity in files) {
        if (entity is File) {
          final relativePath = p.relative(entity.path, from: vaultPath);
          await encoder.addFile(entity, relativePath);
        }
        //移除了错误的 else if (entity is Directory) 分支
      }
      encoder.close();

      await client.mkdir(backupFolder);
      await client.writeFromFile(zipFile.path, '$backupFolder/$zipFileName',
          onProgress: (c, t) {
        // 你可以在这里实现上传进度
        print('Uploading... $c/$t');
      });

      // 清理临时文件
      await tempDir.delete(recursive: true);

      Get.back(); // 关闭加载对话框
      if (onSuccess != null) {
        onSuccess(1);
      }
    } catch (e) {
      Get.back(); // 关闭加载对话框
      if (onFail != null) {
        onFail(e);
      } else {
        rethrow;
      }
    }
  }

  // 从WebDAV下载所有数据并恢复
  Future<void> downloadAllData(BuildContext context) async {
    try {
      final remoteFileName =
          '${p.basename(SettingController.currectValutPath.value)}.zip';
      final files = await client.readDir(backupFolder);
      final remoteFile = files.firstWhere(
        (file) => file.name == remoteFileName,
        orElse: () => throw Exception("远程备份文件不存在"),
      );

      final fileSize = remoteFile.size ?? 0;
      final modificationDate = remoteFile.mTime ?? DateTime.now();
      final formattedDate =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(modificationDate);
      final formattedSize = (fileSize / (1024 * 1024)).toStringAsFixed(2);

      // 弹出确认对话框
      Get.defaultDialog(
        title: "发现远程备份",
        middleText:
            "文件大小: $formattedSize MB\n修改日期: $formattedDate\n\n是否使用此备份覆盖本地文件？",
        textConfirm: "确认",
        textCancel: "取消",
        onConfirm: () async {
          Get.back(); // 关闭确认对话框
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

          final tempDir = await Directory.systemTemp.createTemp();
          final localZipPath = p.join(tempDir.path, remoteFileName);

          await client.read2File(
            remoteFile.path!,
            localZipPath,
          );

          // 解压并覆盖
          final inputStream = InputFileStream(localZipPath);
          final archive = ZipDecoder().decodeBuffer(inputStream);
          extractArchiveToDisk(
              archive, SettingController.currectValutPath.value);

          await tempDir.delete(recursive: true);

          Get.back(); // 关闭加载对话框
          Get.snackbar("恢复成功", "数据已从远程备份恢复。");
        },
      );
    } catch (e) {
      Get.snackbar('错误', '$e');
      //rethrow;
    }
  }
}
