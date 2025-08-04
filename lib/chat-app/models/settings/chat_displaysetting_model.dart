import 'package:flutter/material.dart';

enum AvatarStyle { circle, rounded, hidden }
enum MessageBubbleStyle { bubble, compact }

class ChatDisplaySettingModel {
  AvatarStyle avatarStyle = AvatarStyle.circle;
  MessageBubbleStyle messageBubbleStyle = MessageBubbleStyle.bubble;

  Color themeColor = Colors.blue;
  String schemeName = "sakura";

  double ContentFontScale = 1;
  double AvatarSize = 25;
  double AvatarBorderRadius = 8;
  double MessageBubbleBorderRadius = 16;

  String? GlobalFont = "";

  /// 若不为空则说明使用了1自定义字体
  String? CustomFontPath = ""; // TODO:自定义字体的路径；启动时自动加载字体+
  String? ContentFont = "";

  bool displayUserName = true;
  bool displayAssistantName = true;
  bool displayMessageDate = false;
  bool displayMessageIndex = false;
  bool tryParseInlineHtml = true;

  bool get displayAvatar => avatarStyle != AvatarStyle.hidden;

  ChatDisplaySettingModel({
    this.avatarStyle = AvatarStyle.circle,
    this.messageBubbleStyle = MessageBubbleStyle.bubble,
    this.ContentFontScale = 1,
    this.GlobalFont = "",
    this.ContentFont = "",
    this.displayUserName = true,
    this.displayAssistantName = true,
    this.displayMessageDate = false,
    this.displayMessageIndex = false,
    this.tryParseInlineHtml = true,
    this.AvatarSize = 25,
    this.themeColor = Colors.blue,
    this.schemeName = "sakura",
    this.AvatarBorderRadius = 8,
    this.MessageBubbleBorderRadius = 16,
  });

  // JSON序列化
  Map<String, dynamic> toJson() {
    return {
      'avatarStyle': avatarStyle.index,
      'messageBubbleStyle': messageBubbleStyle.index,
      'ContentFontSize': ContentFontScale,
      'GlobalFont': GlobalFont,
      'CustomFontPath': CustomFontPath,
      'ContentFont': ContentFont,
      'displayUserName': displayUserName,
      'displayAssistantName': displayAssistantName,
      'displayMessageDate': displayMessageDate,
      'displayMessageIndex': displayMessageIndex,
      'AvatarSize': AvatarSize,
      'themeColor': themeColor.value,
      'AvatarBorderRadius': AvatarBorderRadius,
      'MessageBubbleBorderRadius': MessageBubbleBorderRadius,
      'schemeName': schemeName,
      'tryParseInlineHtml': tryParseInlineHtml, 
    };
  }

  // JSON反序列化
  ChatDisplaySettingModel.fromJson(Map<String, dynamic> json) {
    avatarStyle = AvatarStyle.values[json['avatarStyle'] ?? 0];
    messageBubbleStyle = MessageBubbleStyle.values[json['messageBubbleStyle'] ?? 0];
    ContentFontScale = (json['ContentFontSize'] ?? 1).toDouble();
    GlobalFont = json['GlobalFont'];
    CustomFontPath = json['CustomFontPath'] ?? "";
    ContentFont = json['ContentFont'];
    displayUserName = json['displayUserName'] ?? true;
    displayAssistantName = json['displayAssistantName'] ?? true;
    displayMessageDate = json['displayMessageDate'] ?? false;
    displayMessageIndex = json['displayMessageIndex'] ?? false;
    AvatarSize = (json['AvatarSize'] ?? 25).toDouble();
    themeColor = Color(json['themeColor'] ?? Colors.blue.value);
    AvatarBorderRadius = (json['AvatarBorderRadius'] ?? 8).toDouble();
    MessageBubbleBorderRadius = (json['MessageBubbleBorderRadius'] ?? 16).toDouble();
    schemeName = json['schemeName'] ?? "sakura";
    tryParseInlineHtml = json['tryParseInlineHtml'] ?? true;
  }
}
