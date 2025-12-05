import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/constants.dart';

enum AvatarStyle { circle, rounded, hidden }

enum MessageBubbleStyle { bubble, compact }

class ChatDisplaySettingModel {
  AvatarStyle avatarStyle = AvatarStyle.circle;
  MessageBubbleStyle messageBubbleStyle = MessageBubbleStyle.bubble;

  Color themeColor = Colors.blue;
  String schemeName = Constants.DEFAULT_THEME_NAME;

  double ContentFontScale = 1;
  double AvatarSize = 25;
  double AvatarBorderRadius = 8;
  double MessageBubbleBorderRadius = 16;

  double BackgroundImageOpacity = 1.0;
  double BackgroundImageBlur = 1.0;

  String? GlobalFont = "";

  /// 若不为空则说明使用了自定义字体
  String? CustomFontPath = "";
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
    this.schemeName = Constants.DEFAULT_THEME_NAME,
    this.AvatarBorderRadius = 8,
    this.MessageBubbleBorderRadius = 16,
    this.BackgroundImageBlur = 1.0,
    this.BackgroundImageOpacity = 1.0,
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
      'BackgroundImageOpacity': BackgroundImageOpacity,
      'BackgroundImageBlur': BackgroundImageBlur,
    };
  }

  // JSON反序列化
  ChatDisplaySettingModel.fromJson(Map<String, dynamic> json) {
    avatarStyle = AvatarStyle.values[json['avatarStyle'] ?? 0];
    messageBubbleStyle =
        MessageBubbleStyle.values[json['messageBubbleStyle'] ?? 0];
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
    MessageBubbleBorderRadius =
        (json['MessageBubbleBorderRadius'] ?? 16).toDouble();
    schemeName = json['schemeName'] ?? Constants.DEFAULT_THEME_NAME;
    tryParseInlineHtml = json['tryParseInlineHtml'] ?? true;
    BackgroundImageOpacity = (json['BackgroundImageOpacity'] ?? 1.0).toDouble();
    BackgroundImageBlur = (json['BackgroundImageBlur'] ?? 1.0).toDouble();
  }
}
