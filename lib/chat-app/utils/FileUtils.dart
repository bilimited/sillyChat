import 'package:path/path.dart' as p;

class Fileutils {
  static bool isChatFile(String path) {
    return p.extension(path) == '.chat';
  }

  static bool comparePath(String path1, String path2) {
    return path1.replaceAll('/', '\\') == path2.replaceAll('/', '\\');
  }
}
