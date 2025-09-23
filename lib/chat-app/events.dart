abstract class AppEvent {}

class FileDeletedEvent extends AppEvent {
  final String filePath;

  FileDeletedEvent(this.filePath);
}
