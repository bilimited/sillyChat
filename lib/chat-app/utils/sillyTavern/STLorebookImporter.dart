import 'package:flutter_example/chat-app/models/lorebook_item_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';

int? parseMotherFuckerToInt(dynamic motherFucker) {
  if (motherFucker == null) return null;
  if (motherFucker is int) return motherFucker;
  if (motherFucker is double || motherFucker is num)
    return motherFucker.toInt();
  if (motherFucker is String) {
    return int.tryParse(motherFucker) ?? double.tryParse(motherFucker)?.toInt();
  }
  return null;
}

abstract class STLorebookImporter {
  static String getPositionByString(String depthName) {
    switch (depthName) {
      case 'before char':
      case 'after char':
        return depthName.replaceAll(' ', '_');
      default:
        return depthName;
    }
  }

  static LorebookModel? fromJson(Map<String, dynamic> json) {
    try {
      LorebookModel lorebook = LorebookModel(
          id: DateTime.now().microsecondsSinceEpoch,
          name: json['name'],
          items: [],
          scanDepth: 4,
          maxToken: 99999);

      List<dynamic> entries = json['entries'];

      entries.sort((a, b) {
        int aIndex = (a['extensions']?['insertion_order'] ?? 0) as int;
        int bIndex = (b['extensions']?['insertion_order'] ?? 0) as int;
        return bIndex.compareTo(aIndex);
      });

      int index = 0;
      entries.forEach((entry) {
        Map<String, dynamic>? extensions = entry['extensions'];

        ActivationType type = ActivationType.manual;
        if (entry['constant'] == true) {
          type = ActivationType.always;
        } else {
          type = ActivationType.keywords;
        }

        dynamic position = extensions?['position'] ?? entry['position'];
        String lorePosition = '';
        if (position is String) {
          lorePosition = getPositionByString(position);
        } else if (position is int) {
          lorePosition = [
                'before_char',
                'after_char',
                '@Duser',
                '@Duser', // 這兩種對於沒人用的“作者注釋之前/之後”
                '@D',
                'before_em',
                'after_em'
              ][position] ??
              'before char';
          if (position == 4) {
            lorePosition +=
                ['system', 'user', 'assistant'][(extensions?['role'] ?? 1)];
          }
        }

        LorebookItemModel item = LorebookItemModel(
          id: index,
          name: entry['comment'],
          content: entry['content'],
          priority: parseMotherFuckerToInt(entry['insertion_order']) ?? 100,
          isActive: entry['enabled'],
          activationDepth: parseMotherFuckerToInt(entry['scanDepth']) ?? 0,
          position: lorePosition,
          positionId: (position == 3 || position == 2)
              ? 4
              : (parseMotherFuckerToInt(extensions?['depth']) ?? 1),
          keywords: (entry['keys'] as List<dynamic>).join(','),
          activationType: type,
        );
        lorebook.items.add(item);

        index++;
      });

      return lorebook;
    } catch (e) {
      throw e;
    }
  }
}
