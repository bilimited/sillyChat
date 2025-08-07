import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 一个用于动态加载和管理字体文件的工具类。
class FontManager {
  // 当前活跃的字体族名称，用于在Text widget中应用
  static String? _currentFontFamily;

  /// 获取当前正在使用的字体族名称。
  static String? get currentFontFamily => _currentFontFamily;

  static Future<void> initCustomFont(String fontName, String path) async {
    final targetFile = File(path);
    if (!await targetFile.exists()) {
      return;
    }

    final fontLoader = FontLoader(fontName);
    final fontData = targetFile.readAsBytes();
    fontLoader.addFont(fontData.then((bytes) => ByteData.view(bytes.buffer)));
    await fontLoader.load();
  }

  /// 加载本地字体文件并应用到应用中。
  ///
  /// [onFontLoaded]: 当字体成功加载时调用的回调函数。它会接收到字体族名称和字体文件路径。
  /// [manualFontName]: 如果提供，将使用此名称作为字体族名称；否则，将提示用户输入或自动生成。
  ///
  /// 返回 `true` 如果字体加载成功，否则返回 `false`。
  static Future<bool> loadFont({
    required BuildContext context,
    required Function(String fontFamily, String fontPath) onFontLoaded,
    String? manualFontName,
  }) async {
    // 1. 请求存储权限 (仅限Android)
    // if (Theme.of(context).platform == TargetPlatform.android) {
    //   final status = await Permission.storage.request();
    //   if (!status.isGranted) {
    //     _showSnackBar(context, '需要存储权限才能选择字体文件。');
    //     return false;
    //   }
    // }

    // 2. 选择字体文件
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ttf', 'otf'], // 支持的字体文件类型
    );

    if (result == null || result.files.single.path == null) {
      _showSnackBar(context, '未选择字体文件。');
      return false;
    }

    final String selectedFilePath = result.files.single.path!;
    final String fileName = selectedFilePath.split(Platform.pathSeparator).last;

    String fontName;
    if (manualFontName != null && manualFontName.isNotEmpty) {
      fontName = manualFontName;
    } else {
      // 提示用户输入字体名或自动生成
      fontName = await _getFontNameFromUser(context, fileName) ??
          fileName.replaceAll('.', '_');
      if (fontName.isEmpty) {
        _showSnackBar(context, '字体名称不能为空。');
        return false;
      }
    }

    // 3. 将字体文件复制到应用沙盒（如果是Windows平台，则直接获取字体文件路径）
    try {
      if (Platform.isWindows) {
        // Windows平台直接使用选择的文件路径

        final File targetFile = File(selectedFilePath);
        final fontLoader = FontLoader(fontName);
        final fontData = targetFile.readAsBytes();
        fontLoader
            .addFont(fontData.then((bytes) => ByteData.view(bytes.buffer)));
        await fontLoader.load();

        _currentFontFamily = fontName;
        onFontLoaded(_currentFontFamily!, selectedFilePath);
        _showSnackBar(context, '字体 "${_currentFontFamily}" 加载成功！');
        return true;
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final String targetPath =
            '${directory.path}${Platform.pathSeparator}$fileName';
        final File sourceFile = File(selectedFilePath);
        final File targetFile = await sourceFile.copy(targetPath);

        // 4. 加载字体
        final fontLoader = FontLoader(fontName);
        final fontData = targetFile.readAsBytes();
        fontLoader
            .addFont(fontData.then((bytes) => ByteData.view(bytes.buffer)));
        await fontLoader.load();

        // 5. 更新当前字体族名称
        _currentFontFamily = fontName;

        // 6. 持久化字体信息 (通过回调函数)
        onFontLoaded(_currentFontFamily!, targetPath);
        _showSnackBar(context, '字体 "${_currentFontFamily}" 加载成功！');
        return true;
      }
    } catch (e) {
      print('加载字体失败: $e');
      _showSnackBar(context, '加载字体失败: ${e.toString()}');
      return false;
    }
  }

  /// 内部方法：弹出对话框让用户输入字体名称。
  static Future<String?> _getFontNameFromUser(
      BuildContext context, String defaultName) async {
    String? inputFontName;
    await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('输入字体名称'),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(
              hintText: '默认为文件名: ${defaultName.replaceAll('.', '_')}',
            ),
            onChanged: (value) {
              inputFontName = value;
            },
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('取消'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('自动生成'),
              onPressed: () {
                inputFontName = defaultName.replaceAll('.', '_'); // 自动生成名称
                Navigator.of(dialogContext).pop(inputFontName);
              },
            ),
            TextButton(
              child: const Text('确定'),
              onPressed: () {
                Navigator.of(dialogContext).pop(inputFontName);
              },
            ),
          ],
        );
      },
    );
    return inputFontName;
  }

  /// 内部方法：显示一个SnackBar提示。
  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
