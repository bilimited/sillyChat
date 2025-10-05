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

  static Widget avatar(String? fileName, int radius,
      {double borderRadius = 2}) {
    return Container(
      height: radius * 2,
      width: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300, width: borderRadius),
        color: Colors.grey.shade100,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius.toDouble()),
        child: fileName != null
            ? AvatarImage(fileName: fileName!)
            : Icon(
                Icons.add_photo_alternate,
                size: radius - 20,
                color: Colors.grey.shade600,
              ),
      ),
    );
  }

  const AvatarImage({
    Key? key,
    required this.fileName,
    this.width,
    this.height,
  }) : super(key: key);

  /// 异步获取图片文件的完整路径。
  String getPath(String filename) {
    return '${SettingController.of.getImagePathSync()}/${p.basename(filename)}';
  }

  static Widget round(String path, double radius) {
    return ClipRRect(
        borderRadius: BorderRadiusGeometry.circular(114514),
        child:
            AvatarImage(fileName: path, width: radius * 2, height: radius * 2));
  }

  @override
  Widget build(BuildContext context) {
    final file = File(getPath(fileName));
    return Image.file(
      file,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.account_circle,
          color: Theme.of(context).colorScheme.secondary,
          size: width,
        );
      },
    );
  }
}
