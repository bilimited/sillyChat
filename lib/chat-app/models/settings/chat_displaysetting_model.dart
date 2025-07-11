enum AvatarStyle { circle, rounded, rect, hidden }
enum MessageBubbleStyle { bubble, compact, article }

class ChatDisplaySettingModel {
  AvatarStyle avatarStyle = AvatarStyle.circle;

  double UserNameFontSize = 0;//TODO
  double ContentFontSize = 0;

  String? GlobalFont = "";
  String? ContentFont = "";

  bool displayUserName = true;
  bool displayMessageDate = false;
  bool displayMessageIndex = false;
}
 