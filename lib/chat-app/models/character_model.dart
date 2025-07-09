
class Relation {
  final int targetId;
  String? type;
  String? brief;

  Relation({required this.targetId});

  Relation copy() {
    return Relation(
      targetId: targetId,
    )..type = type
     ..brief = brief;
  }
}

enum MessageStyle {
  common,
  narration,

}

class CharacterModel {
  final int id;
  MessageStyle messageStyle = MessageStyle.common;

  String remark;       // 备注
  String roleName;        // 唯一名称
  String avatar;
  String? description;
  String? backgroundImage;
  String? brief; // 简略个人信息
  String archive = ""; // 替代原来的个人信息

  String category;
  Map<int, Relation> relations = {};

  List<CharacterModel>? backups;

  CharacterModel({
    required this.id,
    required this.remark,
    required this.roleName,
    required this.avatar,
    this.description,
    required this.category,
    this.messageStyle = MessageStyle.common,
    this.brief,
    this.backups,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': remark,
      'nickname': roleName,
      'avatar': avatar,
      // 'gender': gender.toString().split('.').last,
      // 'age': age,
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
      'messageStyle': messageStyle.toString().split('.').last, // 序列化messageStyle
      'backups': backups!=null ? backups!.map((e) => e.toJson()).toList() : null, // 添加isBackup字段
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
    );

    char.archive = json['archive'] ?? ''; // 添加archive字段的解析
    // char.gender = json['gender'] ?? '女';
    // char.age = json['age'] ?? 18;
    // 版本迁移
    if (json['gender'] != null && json['age'] != null) {
      String genderAge = '性别：${json['gender']}，年龄：${json['age']}\n';
      char.archive = genderAge + (char.archive ?? '');
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

    return char;
  }

  CharacterModel copy() {
    var newChar = CharacterModel(
      id: DateTime.now().millisecondsSinceEpoch, // 使用时间戳作为新ID
      remark: remark,
      roleName: roleName,
      avatar: avatar,
      description: description,
      category: category,
      brief: brief,
      messageStyle: messageStyle,
      backups: backups?.map((e) => e.copy()).toList(),
    );

    newChar.archive = archive; // 添加archive字段的复制

    // newChar.gender = gender;
    // newChar.age = age;
    newChar.backgroundImage = backgroundImage;
    newChar.roleName = roleName;
    newChar.messageStyle = messageStyle;

    // 深拷贝关系
    relations.forEach((key, value) {
      newChar.relations[key] = Relation(targetId: value.targetId)
        ..type = value.type
        ..brief = value.brief;
    });

    return newChar;
  }
}
