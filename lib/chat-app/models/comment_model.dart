import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';

class CommentModel {
  int id;
  int authorId;
  String content;
  DateTime time;
  // int likes = 0;

  // 楼中楼中楼的replyId，仍然是主楼的Id，（为了防止删除评论后引用断裂的问题）
  int? replyToId;
  String? replyToName;
  // List<CommentModel> replies = [];
  List<int> likes = [];

  CharacterModel author(CharacterController character_controller){
    return character_controller.getCharacterById(authorId);
  }

  CommentModel({
    required this.id,
    required this.authorId,
    required this.content,
    required this.time,
    this.replyToId,
    this.replyToName,
  });

  bool isLiked(CharacterModel character){
    return likes.contains(character.id);
  }

  CommentModel.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        authorId = json['authorId'],
        content = json['content'],
        time = DateTime.parse(json['time']),
        likes = json['likes'].cast<int>() ?? 0,
        replyToId = json['replyToId'],
        replyToName = json['replyToName'];
        // replies = (json['replies'] as List<dynamic>?)
        //         ?.map((e) => CommentModel.fromJson(e))
        //         .toList() ??
        //     [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'authorId': authorId,
        'content': content,
        'time': time.toIso8601String(),
        'likes': likes,
        'replyToId': replyToId,
        'replyToName': replyToName,
        // 'replies': replies.map((e) => e.toJson()).toList(),
      };
}
