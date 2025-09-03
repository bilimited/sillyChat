import 'package:flutter_example/chat-app/models/chat_option_model.dart';
import 'package:flutter_example/chat-app/models/lorebook_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/providers/lorebook_controller.dart';
import 'package:flutter_example/chat-app/utils/PackageValue.dart';
import 'package:get/get.dart';

class Relation {
  final int targetId;
  String? type;
  String? brief;

  Relation({required this.targetId});

  Relation copy() {
    return Relation(
      targetId: targetId,
    )
      ..type = type
      ..brief = brief;
  }

  CharacterModel get target {
    CharacterController controller = Get.find();
    return controller.getCharacterById(targetId);
  }
}

enum MessageStyle {
  common,
  narration,
}

class CharacterModel {
  final int id;
  MessageStyle messageStyle = MessageStyle.common;

  String remark; // 备注
  String roleName; // 唯一名称
  String avatar;
  String? description;
  String? backgroundImage;
  String? brief; // 简略个人信息
  String archive = ""; // 替代原来的个人信息

  String? firstMessage;
  List<String> moreFirstMessage = [];

  String category;
  Map<int, Relation> relations = {};

  List<CharacterModel>? backups;

  List<int> lorebookIds = []; // 关联的世界书ID列表
  List<LorebookModel> get loreBooks {
    LoreBookController controller = Get.find();
    return lorebookIds
        .map((id) => controller.getLorebookById(id))
        .nonNulls
        .toList();
  }

  int? bindOptionId; // 角色绑定的预设，会覆盖聊天的预设

  ChatOptionModel? get bindOption => bindOptionId == null
      ? null
      : ChatOptionController.of().getChatOptionById(bindOptionId!);

  CharacterModel(
      {required this.id,
      required this.remark,
      required this.roleName,
      required this.avatar,
      this.description,
      required this.category,
      this.messageStyle = MessageStyle.common,
      this.brief,
      this.backups,
      lorebookIds,
      this.firstMessage}) {
    if (lorebookIds != null) {
      this.lorebookIds = lorebookIds;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': remark,
      'nickname': roleName,
      'avatar': avatar,
      'description': description,
      'backgroundImage': backgroundImage,
      'category': category,
      'brief': brief,
      'archive': archive, // 添加archive字段
      'relations': relations.map((key, value) => MapEntry(key.toString(), {
            'targetId': value.targetId,
            'type': value.type,
            'brief': value.brief,
          })),
      'messageStyle':
          messageStyle.toString().split('.').last, // 序列化messageStyle
      'backups': backups != null
          ? backups!.map((e) => e.toJson()).toList()
          : null, // 添加isBackup字段
      'lorebookIds': lorebookIds, // 添加lorebookIds字段
      'firstMessage': firstMessage, // 添加firstMessage字段
      'moreFirstMessage': moreFirstMessage, // 添加moreFirstMessage字段
      'bindOption': bindOptionId, // 添加bindOption字段
    };
  }

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    var char = CharacterModel(
      id: json['id'],
      remark: json['name'],
      roleName: json['nickname'] ?? json['name'],
      avatar: json['avatar'],
      description: json['description'],
      category: json['category'],
      brief: json['brief'],
      lorebookIds: (json['lorebookIds'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      firstMessage: json['firstMessage'],
    );

    char.moreFirstMessage = (json['moreFirstMessage'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        [];

    char.archive = json['archive'] ?? ''; // 添加archive字段的解析
    // 版本迁移
    if (json['gender'] != null && json['age'] != null) {
      String genderAge = '性别：${json['gender']}，年龄：${json['age']}\n';
      char.archive = genderAge + (char.archive);
      char.brief = genderAge + (char.brief ?? '');
    }
    char.backgroundImage = json['backgroundImage'];

    if (json['relations'] != null) {
      (json['relations'] as Map<String, dynamic>).forEach((key, value) {
        var relation = Relation(targetId: value['targetId']);
        relation.type = value['type'] ?? '朋友';
        relation.brief = value['brief'];
        char.relations[int.parse(key)] = relation;
      });
    }

    char.messageStyle = MessageStyle.values.firstWhere(
      (e) => e.toString() == 'MessageStyle.${json['messageStyle']}',
      orElse: () => MessageStyle.common,
    );

    char.backups = (json['backups'] as List<dynamic>?)
        ?.map((e) => CharacterModel.fromJson(e as Map<String, dynamic>))
        .toList();

    char.bindOptionId = json['bindOption'];

    return char;
  }

  CharacterModel copyWith({
    int? id,
    String? remark,
    String? roleName,
    String? avatar,
    String? description,
    String? backgroundImage,
    String? brief,
    String? archive,
    String? firstMessage,
    List<String>? moreFirstMessage,
    String? category,
    Map<int, Relation>? relations,
    List<CharacterModel>? backups,
    List<int>? lorebookIds,
    MessageStyle? messageStyle,
    PackageValue<int?>? bindOption,
  }) {
    var newChar = CharacterModel(
      id: id ?? DateTime.now().millisecondsSinceEpoch,
      remark: remark ?? this.remark,
      roleName: roleName ?? this.roleName,
      avatar: avatar ?? this.avatar,
      description: description ?? this.description,
      category: category ?? this.category,
      brief: brief ?? this.brief,
      messageStyle: messageStyle ?? this.messageStyle,
      backups: backups ?? this.backups?.map((e) => e.copyWith()).toList(),
      lorebookIds: lorebookIds != null
          ? List<int>.from(lorebookIds)
          : List<int>.from(this.lorebookIds),
      firstMessage: firstMessage ?? this.firstMessage,
    );

    newChar.moreFirstMessage = moreFirstMessage != null
        ? List<String>.from(moreFirstMessage)
        : List<String>.from(this.moreFirstMessage);

    newChar.archive = archive ?? this.archive;
    newChar.backgroundImage = backgroundImage ?? this.backgroundImage;

    // 深拷贝关系
    if (relations != null) {
      newChar.relations =
          relations.map((key, value) => MapEntry(key, value.copy()));
    } else {
      newChar.relations =
          this.relations.map((key, value) => MapEntry(key, value.copy()));
    }

    if (bindOption != null) {
      newChar.bindOptionId = bindOption.value;
    } else {
      newChar.bindOptionId = this.bindOptionId;
    }

    return newChar;
  }
}
