
class Relation {
  final int targetId;
  String? type;
  String? brief;

  Relation({required this.targetId});
}

enum MessageStyle {
  common,
  narration,

}

class CharacterModel {
  final int id;

  // JSONIgnore。仅供丢失角色（旁白和分割线）使用。现已无用
  MessageStyle messageStyle = MessageStyle.common;

  String name;
  String roleName; // 唯一名称
  String avatar;
  String gender = '女';
  int age = 18;
  String? description;
  String? backgroundImage;
  String? brief; // 简略个人信息
  String archive = ""; // 替代原来的个人信息

  String category;
  Map<int, Relation> relations = {};


  CharacterModel({
    required this.id,
    required this.name,
    required this.roleName,
    required this.avatar,
    this.description,
    required this.category,
    this.messageStyle = MessageStyle.common,
    this.brief,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nickname': roleName,
      'avatar': avatar,
      'gender': gender.toString().split('.').last,
      'age': age,
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
    };
  }

  factory CharacterModel.fromJson(Map<String, dynamic> json) {
    var char = CharacterModel(
      id: json['id'],
      name: json['name'],
      roleName: json['nickname'] ?? json['name'],
      avatar: json['avatar'],
      description: json['description'],
      category: json['category'],
      brief: json['brief'],
    );

    char.archive = json['archive'] ?? ''; // 添加archive字段的解析
    char.gender = json['gender'] ?? '女';
    char.age = json['age'] ?? 18;
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

    return char;
  }

  CharacterModel copy() {
    var newChar = CharacterModel(
      id: DateTime.now().millisecondsSinceEpoch, // 使用时间戳作为新ID
      name: name,
      roleName: roleName,
      avatar: avatar,
      description: description,
      category: category,
      brief: brief,
      messageStyle: messageStyle,
    );

    newChar.archive = archive; // 添加archive字段的复制

    newChar.gender = gender;
    newChar.age = age;
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
