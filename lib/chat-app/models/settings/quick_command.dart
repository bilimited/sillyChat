
// 快捷消息的发送者
enum QuickCommandRole {
  narration,
  user,
  assistant,
}

class QuickCommand {

  final int id;
  final String name;
  final String description;

  // 指令的文字内容
  final String command;
  final QuickCommandRole role;

  // 发送快捷指令时是否将指令内容加入消息列表
  final bool addCommandToMessageList;

  // 发送快捷指令时绑定的聊天预设（null使用当前聊天的预设）
  final int? bindOption;

  QuickCommand({
    required this.id,
    required this.name,
    required this.description,
    required this.command,
    this.role = QuickCommandRole.user,
    this.addCommandToMessageList = true,
    this.bindOption,
  });

  // JSON序列化
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'command': command,
      'role': role.index,
      'addCommandToMessageList': addCommandToMessageList,
      'bindOption': bindOption,
    };
  }

  // 从JSON反序列化
  factory QuickCommand.fromJson(Map<String, dynamic> json) {
    return QuickCommand(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      command: json['command'] ?? '',
      role: QuickCommandRole.values[json['role'] ?? 0],
      addCommandToMessageList: json['addCommandToMessageList'] ?? true,
      bindOption: json['bindOption'],
    );
  }

  // 创建一个新的QuickCommand实例，使用现有的属性
  QuickCommand copyWith({
    int? id,
    String? name,
    String? description,
    String? command,
    QuickCommandRole? role,
    bool? addCommandToMessageList,
    int? bindOption,
  }) {
    return QuickCommand(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      command: command ?? this.command,
      role: role ?? this.role,
      addCommandToMessageList: addCommandToMessageList ?? this.addCommandToMessageList,
      bindOption: bindOption ?? this.bindOption,
    );
  }
}