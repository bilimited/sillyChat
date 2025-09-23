abstract class AppEvent {}

class FileDeletedEvent extends AppEvent {
  final String filePath;
  // 可以添加更多信息，如文件类型、大小等
  // final FileType fileType;

  FileDeletedEvent(this.filePath);
}
