import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';

class MemoryUtils {
  static void tryAddMemoryToCharacter(int charId, String summary) {
    final char = CharacterController.of.getCharacterById(charId);
    final mem = char.memoryBook;
    if (mem != null) {
      addMemory(mem, summary);
    }
  }

  static void addMemory(LorebookModel lorebook, String summary) {
    LorebookItemModel item = LorebookItemModel(
            id: DateTime.now().microsecondsSinceEpoch,
            name: "记忆-${DateTime.now().toString()}",
            content: summary)
        .copyWith(
      activationType: ActivationType.always,
      position: "memory",
    );

    lorebook.items.add(item);

    LoreBookController.of.updateLorebook(lorebook);
  }
}
