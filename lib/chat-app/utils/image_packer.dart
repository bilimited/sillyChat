import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class ImagePacker {
  static const String _outputDir = '.unpacked_images';
  // 使用固定的加密密钥（32字符，256位）
  static const String _encryptionKey = 'xK8#mP2\$vL5*nQ9@wX4&jY7!zC3^hN6%';
  static final _encrypter = encrypt.Encrypter(
      encrypt.AES(encrypt.Key.fromUtf8(_encryptionKey)));
  static final _iv = encrypt.IV.fromLength(16);

  /// 获取应用程序专用的存储目录
  static Future<String> _getStorageDir() async {
    return (await getApplicationDocumentsDirectory()).path;
  }

  /// 加密数据
  // ignore: unused_element
  static Uint8List _encryptData(List<int> data) {
    final encrypted = _encrypter.encryptBytes(data, iv: _iv);
    return encrypted.bytes;
  }

  /// 解密数据
  // ignore: unused_element
  static Uint8List _decryptData(List<int> data) {
    final encrypted = encrypt.Encrypted(Uint8List.fromList(data));
    return Uint8List.fromList(_encrypter.decryptBytes(encrypted, iv: _iv));
  }

  /// 打包图片文件
  /// [imageMap] 图片ID和路径的映射关系
  /// [outputPath] 输出zip文件的路径
  /// 返回是否打包成功
  static Future<bool> packImages(
      Map<String, String> imageMap, String outputPath) async {
    try {
      final archive = Archive();
      
      for (var entry in imageMap.entries) {
        final file = File(entry.value);
        if (!await file.exists()) continue;
        
        final bytes = await file.readAsBytes();
        final extension = path.extension(entry.value);
        final archiveFile = ArchiveFile(
          '${entry.key}$extension',
          bytes.length,
          bytes,
        );
        archive.addFile(archiveFile);
      }

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) return false;
      
      // 加密并保存文件
      final encryptedData = zipData; //_encryptData(zipData);
      await File(outputPath).writeAsBytes(encryptedData);
      return true;
    } catch (e) {
      print('打包失败: $e');
      return false;
    }
  }

  /// 解包图片文件
  /// [zipPath] zip文件路径
  /// [baseDir] 解压基础目录，默认为当前目录
  /// 返回图片ID和解压后路径的映射关系
  static Future<Map<String, String>> unpackImages(
      String zipPath, {String? baseDir}) async {
    try {
      // 读取并解密文件
      //final encryptedBytes = await File(zipPath).readAsBytes();
      final decryptedBytes = await File(zipPath).readAsBytes();//_decryptData(encryptedBytes);
      final archive = ZipDecoder().decodeBytes(decryptedBytes);
      
      // 获取跨平台存储目录
      final basePath = baseDir ?? await _getStorageDir();
      final outputDir = path.join(basePath, _outputDir);
      await Directory(outputDir).create(recursive: true);

      final Map<String, String> resultMap = {};

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final filePath = path.join(outputDir, filename);
          await File(filePath).writeAsBytes(data);
          
          final id = path.basenameWithoutExtension(filename);
          resultMap[id] = filePath;
        }
      }

      return resultMap;
    } catch (e) {
      print('解包失败: $e');
      return {};
    }
  }
}


