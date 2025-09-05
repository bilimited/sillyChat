import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:path/path.dart' as p;

/// 一个用于显示头像图片的组件，支持异步加载和占位符。
/// 头像的形状和边框由其父组件提供。
class AvatarImage extends StatelessWidget {
  /// 图片的文件名（不包含路径和扩展名）。
  final String fileName;

  final double? width;
  final double? height;

  const AvatarImage({
    Key? key,
    required this.fileName,
    this.width,
    this.height,
  }) : super(key: key);

  /// 异步获取图片文件的完整路径。
  Future<String> getPath(String filename) async {
    return '${await SettingController.of.getImagePath()}/${p.basename(filename)}';
  }

  @override
  Widget build(BuildContext context) {
    // 使用 FutureBuilder 来处理异步获取文件路径。
    return FutureBuilder<String>(
      future: getPath(fileName),
      builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
        // 当异步操作完成且成功获取到文件路径时，显示图片。
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          final file = File(snapshot.data!);
          // 检查文件是否存在以避免错误。
          if (file.existsSync()) {
            return Image.file(
              file,
              width: width,
              height: height,
              fit: BoxFit.cover,
            );
          }
        }

        // 当异步操作未完成、发生错误或文件不存在时，显示一个占位符图标。
        // 这解决了加载中和加载失败两种情况。
        return const Icon(
          Icons.account_circle,
          size: 40.0,
          color: Colors.grey,
        );
      },
    );
  }
}
