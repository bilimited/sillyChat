import 'package:flutter_example/chat-app/constants.dart';
import 'package:path/path.dart' as p;

class Fileutils {
  static bool isChatFile(String path) {
    return p.extension(path) == Constants.CHAT_FILE_EXT;
  }

  static bool isFolderSettingFile(String path){
    return p.basename(path) == Constants.FOLDER_SETTING_FILE_NAME;
  }

  static bool comparePath(String path1, String path2) {
    return path1.replaceAll('/', '\\') == path2.replaceAll('/', '\\');
  }
}
