import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/main.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as p;

/// 图片工具类
class ImageUtils {
  static ImageProvider getProvider(String pathOrFilename) {
    final filename = _convertPath(pathOrFilename);
    return Image.file(
            File('${SettingController.of.getImagePathSync()}/$filename'))
        .image;
  }

  /// 选择图片并进行裁剪
  ///
  /// [context] 上下文
  /// [isCrop] 是否需要裁剪，默认为 true
  /// [aspectRatio] 裁剪比例，默认为 1.0
  /// [isCircleUi] 是否为圆形裁剪，默认为 false
  /// 返回处理后的图片路径，如果用户取消选择则返回 null
  static Future<String?> selectAndCropImage(
    BuildContext context, {
    bool isCrop = true,
    double aspectRatio = 1.0,
    bool isCircleUi = false,
    String? fileName,
  }) async {
    // 1. 使用 image_picker 选择图片
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      return null; // 用户取消选择
    }

    final imageBytes = await pickedFile.readAsBytes();
    Uint8List? resultImageData;

    if (isCrop && context.mounted) {
      // 2. 如果需要裁剪，则跳转到裁剪页面
      final croppedData = await customNavigate<Uint8List>(
          _ImageCropPage(
            imageData: imageBytes,
            aspectRatio: aspectRatio,
            isCircleUi: isCircleUi,
          ),
          context: context);
      if (croppedData == null) {
        return null; // 用户在裁剪页面取消
      }
      resultImageData = croppedData;
    } else {
      // 不需要裁剪，直接使用原图数据
      resultImageData = imageBytes;
    }

    // 3. 将最终的图片数据保存到特定目录
    return await _saveImage(resultImageData, fileName);
  }

  /// 选择图片并进行内存压缩
  ///
  /// [targetSizeInBytes] 压缩后的目标大小（字节），默认为 1MB
  /// [fileName] 保存图片时使用的文件名
  /// 返回处理后的图片路径，如果用户取消选择则返回 null
  static Future<String?> selectAndCompressImage({
    int targetSizeInBytes = 1048576, // 默认为 1MB
    String? fileName,
  }) async {
    // 1. 使用 image_picker 选择图片
    final pickedFile = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 100); // 获取最高质量原图
    if (pickedFile == null) {
      return null; // 用户取消选择
    }

    Uint8List imageBytes = await pickedFile.readAsBytes();

    try {
      // 2. 检查图片大小，如果超过目标大小则在内存中进行压缩
      if (imageBytes.lengthInBytes > targetSizeInBytes) {
        int quality = 95; // 初始压缩质量

        // 当文件大小超过目标时，循环压缩
        while (imageBytes.lengthInBytes > targetSizeInBytes && quality > 10) {
          // 使用 compressWithList 直接压缩字节数据
          final Uint8List compressedBytes =
              await FlutterImageCompress.compressWithList(
            imageBytes,
            quality: quality,
          );

          imageBytes = compressedBytes; // 更新为压缩后的字节

          // 降低质量以便下次循环
          quality -= 5;
        }
      }

      // 3. 将最终的图片数据保存到特定目录
      return await _saveImage(imageBytes, fileName);
    } catch (e) {
      // UnimplementedError 很有可能在这里被捕获
      if (e is UnimplementedError) {
        Get.snackbar('无法压缩图片', '压缩功能在当前平台不受支持。将使用原图。');
        // 在不支持的平台上，直接保存原图
        return await _saveImage(imageBytes, fileName);
      }
      // 处理其他选择或压缩过程中的错误
      print('处理图片时出错: $e');
      return null;
    }
  }

  /// 将图片数据保存到应用文档目录
  static Future<String> _saveImage(Uint8List imageData, String? name) async {
    // 1. 获取应用文档目录
    final imageParentDir = Directory(await SettingController.of.getImagePath());

    // 2. 如果目标文件夹不存在，则创建
    if (!await imageParentDir.exists()) {
      await imageParentDir.create();
    }

    // 3. 生成一个唯一的文件名

    final fileName = name != null ? '${name}.png' : '${const Uuid().v4()}.png';
    final filePath = '${imageParentDir.path}/$fileName';
    final imageFile = File(filePath);

    // 4. 将图片数据写入文件
    await imageFile.writeAsBytes(imageData);

    debugPrint('图片已保存至: $filePath');
    return filePath;
  }

  static String _convertPath(String pathOrName) {
    return p.basename(pathOrName);
  }

  static Future<void> deleteImage(String filename) async {
    filename = _convertPath(filename);
    final file = File('${await SettingController.of.getImagePath()}/$filename');
    if (file.existsSync()) {
      file.delete();
    }
  }
}

///
/// 内部使用的图片裁剪页面 (私有)
///
class _ImageCropPage extends StatefulWidget {
  final Uint8List imageData;
  final double aspectRatio;
  final bool isCircleUi;

  const _ImageCropPage({
    required this.imageData,
    this.aspectRatio = 1.0,
    this.isCircleUi = false,
  });

  @override
  _ImageCropPageState createState() => _ImageCropPageState();
}

class _ImageCropPageState extends State<_ImageCropPage> {
  final _cropController = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('裁剪图片'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              setState(() {
                _isCropping = true;
              });
              if (widget.isCircleUi) {
                _cropController.cropCircle();
              } else {
                _cropController.crop();
              }
            },
          )
        ],
      ),
      body: Stack(
        children: [
          Crop(
            controller: _cropController,
            image: widget.imageData,
            aspectRatio: widget.aspectRatio,
            withCircleUi: widget.isCircleUi,
            onCropped: (result) {
              setState(() {
                _isCropping = false;
              });

              switch (result) {
                case CropSuccess(croppedImage: final croppedImage):
                  // 裁剪成功，返回裁剪后的数据
                  Navigator.pop(context, croppedImage);
                  break;
                case CropFailure(cause: final cause):
                  // 裁剪失败，可以给用户提示
                  debugPrint('图片裁剪失败: $cause');
                  SillyChatApp.snackbarErr(context, '图片裁剪失败: $cause');
                  break;
              }
            },
          ),
          if (_isCropping)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
