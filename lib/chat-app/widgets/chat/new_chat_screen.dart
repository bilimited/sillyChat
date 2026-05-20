import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/providers/chat_option_controller.dart';
import 'package:flutter_example/chat-app/widgets/common/avatar_image.dart';

class NewChatScreen extends StatelessWidget {
  final ChatModel chat;
  final VoidCallback? onAvatarTap;

  const NewChatScreen({
    Key? key,
    required this.chat,
    this.onAvatarTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TweenAnimationBuilder<Offset>(
      tween: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCirc,
      builder: (context, offset, child) {
        final opacity = (1 - (offset.dy / 0.2)).clamp(0.0, 1.0);
        return FractionalTranslation(
          translation: offset,
          child: Opacity(opacity: opacity, child: child),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: 128, left: 30, right: 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (chat.bindCharacter != null) ...[
              InkWell(
                child: AvatarImage.round(chat.bindCharacter!.avatar, 44),
                onTap: onAvatarTap,
              ),
              SizedBox(
                height: 16,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    chat.bindCharacter!.roleName,
                    style: TextStyle(fontSize: 16),
                  ),
                  Container(
                    margin: EdgeInsets.only(left: 6),
                    padding: EdgeInsets.symmetric(vertical: 3, horizontal: 5),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      chat.bindCharacter!.bindOption?.name ??
                          ChatOptionController.of().defaultOption.name,
                      style: TextStyle(
                          fontSize: 12,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  )
                ],
              ),
            ] else if (chat.bindStory != null) ...[
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: '点击右下角'),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Icon(
                          Icons.group_outlined,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                    const TextSpan(text: '让AI角色发送一条消息\n'),
                    const TextSpan(text: '或者直接输入消息并发送'),
                  ],
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.outline,
                ),
              )
            ] else
              Text("如果你看到这个,一定是出了什么bug。")
          ],
        ),
      ),
    );
  }
}
