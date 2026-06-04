import 'package:flutter_example/chat-app/models/memory_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';

class MemoryUtils {
  static void tryAddMemoryToCharacter(int charId, String summary) {
    final char = CharacterController.of.getCharacterById(charId);
    if (char.memory == null) {
      char.memory = MemoryModel();
    }
    addMemory(char.memory!, summary);
    CharacterController.of.updateCharacter(char);
  }

  static void addMemory(MemoryModel memory, String summary) {
    final entry = MemoryEntryModel(
      id: DateTime.now().microsecondsSinceEpoch,
      content: summary,
      isActive: true,
    );

    memory.entries.add(entry);
  }
}
