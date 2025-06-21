import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageHelper {
  static Future<String> saveImageToLocal(File imageFile, String folder) async {
    final appDir = await getApplicationDocumentsDirectory();
    final storageDir = Directory('${appDir.path}/character_images/$folder');
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }

    final fileName = '${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
    final savedImage = await imageFile.copy('${storageDir.path}/$fileName');
    return savedImage.path;
  }
}
