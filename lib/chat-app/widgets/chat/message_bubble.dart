import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/models/settings/chat_displaysetting_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/widgets/chat/think_widget.dart';
import 'package:flutter_example/main.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';

class QuotedTextSyntax extends md.InlineSyntax {
  QuotedTextSyntax() : super(r'"([^"]*)"');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = md.Element.text('quotedText', match.group(1)!);
    parser.addNode(text);
    return true;
  }
}

class QuotedTextBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  final TextScaler textScaler;

  // 在构造函数中接收 context
  QuotedTextBuilder(this.context,this.textScaler);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    if (element.tag == 'quotedText') {
      // 在这里使用 context 来获取主题颜色
      final colors = Theme.of(context).colorScheme;

      return Text(
        '"${element.textContent}"',
        style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold),textScaler: textScaler,
      );
    }
    return null;
  }
}

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final ChatModel chat;
  final MessageModel? lastMessage;
  final int index;
  final bool isSelected;
  final bool isNarration;
  final void Function() onTap;
  final void Function() onLongPress;
  final void Function() onUpdateChat;
  final Widget Function(bool isSelected, MessageModel message)
      buildBottomButtons;

  final bool avatarHero;

  const MessageBubble(
      {Key? key,
      required this.chat,
      required this.message,
      required this.isSelected,
      required this.onTap,
      required this.onLongPress,
      required this.buildBottomButtons,
      required this.onUpdateChat,
      required this.isNarration,
      this.lastMessage,
      this.avatarHero = false,
      this.index = 0})
      : super(key: key);

  @override
  _MessageBubbleState createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  final _characterController = Get.find<CharacterController>();

  ColorScheme get colors => Theme.of(context).colorScheme;
  MessageModel get message => widget.message;
  bool get isMe =>
      displaySetting.messageBubbleStyle == MessageBubbleStyle.compact
          ? false
          : widget.chat.user.id == message.sender;
  CharacterModel get character =>
      _characterController.getCharacterById(message.sender);

  ChatDisplaySettingModel get displaySetting =>
      Get.find<VaultSettingController>().displaySettingModel.value;
  double get avatarRadius => displaySetting.AvatarSize;

  final bool isDesktop = SillyChatApp.isDesktop();

  @override
  void initState() {
    super.initState();
  }

  Widget _buildMessageAvatar() {
    switch (displaySetting.avatarStyle) {
      case AvatarStyle.circle:
        return CircleAvatar(
          backgroundImage: Image.file(File(character.avatar)).image,
          radius: avatarRadius,
        );
      case AvatarStyle.rounded:
        return ClipRRect(
          borderRadius:
              BorderRadius.circular(displaySetting.AvatarBorderRadius),
          child: Image.file(
            File(character.avatar),
            width: avatarRadius * 2,
            height: avatarRadius * 2,
            fit: BoxFit.cover,
          ),
        );
      case AvatarStyle.hidden:
        return SizedBox.shrink();
      default:
        return CircleAvatar(
          backgroundImage: Image.file(File(character.avatar)).image,
          radius: avatarRadius,
        );
    }
  }

  Widget _buildMessageUserName() {
    bool isNarration = widget.isNarration;
    int index = widget.index;

    bool shouldDisplayRoleName =
        (displaySetting.displayAssistantName && !isMe) ||
            (displaySetting.displayUserName && isMe);

    final widgets = [
      if (!isNarration && shouldDisplayRoleName) ...[
        Text(
          character.roleName,
          textScaler: TextScaler.linear(displaySetting.ContentFontScale),
        ),
        const SizedBox(width: 8)
      ],
      if (displaySetting.displayMessageIndex)
        Text(
          '#${widget.chat.messages.length - index}',
          style: TextStyle(color: Colors.grey, fontSize: 12),
          textScaler: TextScaler.linear(displaySetting.ContentFontScale),
        ),
      if (displaySetting.displayMessageDate)
        Text(
          ' ${message.time.toIso8601String()} ',
          style: TextStyle(color: Colors.grey, fontSize: 12),
          textScaler: TextScaler.linear(displaySetting.ContentFontScale),
        ),
      // BookMark icon (blue)
      if (message.bookmark != null)
        const Icon(Icons.bookmark, color: Colors.blue, size: 16),
      // Pin icon (orange)
      if (message.isPinned)
        const Icon(Icons.push_pin, color: Colors.orange, size: 16),
      if (message.isHidden)
        const Icon(Icons.visibility_off, color: Colors.blueGrey, size: 16),
    ];

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: isMe ? widgets.reversed.toList() : widgets,
        ),
        if (widgets.isNotEmpty)
          SizedBox(
            height: 4,
          ),
      ],
    );
  }

  void _showPhotoView(String imagePath) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(0),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            child: PhotoView(
              imageProvider: FileImage(File(imagePath)),
              backgroundDecoration: BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageImage() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: message.resPath.length == 1
          ? Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(message.resPath.first),
                    fit: BoxFit.contain,
                    height: 250, // 限制图片高度
                  ),
                ),
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => _showPhotoView(message.resPath.first),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        message.resPath.removeAt(0);
                        widget.onUpdateChat();
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: message.resPath.asMap().entries.map((entry) {
                final idx = entry.key;
                final path = entry.value;
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(path),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _showPhotoView(path),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            message.resPath.removeAt(idx);
                            widget.onUpdateChat();
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
    );
  }

  Widget _buildMessageContent(String content) {
    final textColor =
        displaySetting.messageBubbleStyle == MessageBubbleStyle.bubble
            ? (isMe ? colors.onPrimary : colors.onSurfaceVariant)
            : colors.onSurfaceVariant;
    return content.isEmpty
        // 消息为空显示转圈圈
        ? Container(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.chat.aiState.GenerateState,
                  style: TextStyle(color: colors.outline),
                )
              ],
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.resPath.isNotEmpty) _buildMessageImage(),
              MarkdownBody(
                data: content,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: textColor,
                  ),
                  em: TextStyle(
                    color: isMe ? textColor : colors.outline,
                  ),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border.all(width: 1, color: colors.outlineVariant),
                  ),
                  textScaler:
                      TextScaler.linear(displaySetting.ContentFontScale),
                ),
                builders: {
                  'quotedText': QuotedTextBuilder(context,TextScaler.linear(displaySetting.ContentFontScale)),
                },
                extensionSet: md.ExtensionSet(
                    [const md.FencedCodeBlockSyntax()], [QuotedTextSyntax()]),
                softLineBreak: true,
                shrinkWrap: true,
                inlineSyntaxes: [],
              ),
            ],
          );
  }

  Widget _buildMessageBubbleBody(String content) {
    final colors = Theme.of(context).colorScheme;

    final isLoading = message.id == -9999;

    // 气泡外的动画效果、加载条
    return AnimatedSize(
      alignment: Alignment.topLeft,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Stack(
        children: [
          displaySetting.messageBubbleStyle == MessageBubbleStyle.bubble
              ? Container(
                  decoration: BoxDecoration(
                    color: isMe
                        ? colors.primary
                        : isDesktop
                            ? colors.surface
                            : colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(
                        displaySetting.MessageBubbleBorderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: _buildMessageContent(content))
              : displaySetting.messageBubbleStyle == MessageBubbleStyle.compact
                  ? Column(
                      children: [
                        _buildMessageContent(content),
                        SizedBox(
                          height: 16,
                        )
                      ],
                    )
                  : _buildMessageContent(content),
          if (isLoading)
            Positioned(
              left: 0,
              right: 0,
              top: 0, // 假设一个ProgressIndicator的高度
              child: const LinearProgressIndicator(
                backgroundColor: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNarration() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 40),
      child: Center(
          child: Column(
        children: [
          SizedBox(
            height: 16,
          ),
          if (message.resPath.isNotEmpty) _buildMessageImage(),
          _buildMessageUserName(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: MarkdownBody(
                data: message.content,
                softLineBreak: true,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: colors.outline),
                  textScaler:
                      TextScaler.linear(displaySetting.ContentFontScale),
                  horizontalRuleDecoration: BoxDecoration(
                    border: Border.all(width: 1, color: colors.outlineVariant),
                  ),
                  // selectable: true,
                )),
          ),
          SizedBox(
            height: 16,
          ),
          widget.buildBottomButtons(widget.isSelected, message)
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    String thinkContent = '';
    String afterThink = '';
    bool isThinking = false;

    final isHideName = widget.lastMessage != null &&
        widget.lastMessage!.sender == message.sender;

    final regexs = widget.chat.vaildRegexs;

    // 内置正则：渲染<think>
    if (message.content.contains('<think>')) {
      int startIndex = message.content.indexOf('<think>') + 7;
      int endIndex = message.content.indexOf('</think>');

      if (endIndex == -1) {
        // Only has opening <think>
        thinkContent = message.content.substring(startIndex);
        afterThink = '';
        isThinking = true;
      } else {
        // Has both <think> and </think>
        thinkContent = message.content.substring(startIndex, endIndex);
        afterThink = message.content.substring(endIndex + 8);
      }
    } else {
      afterThink = message.content;
    }

    for (final regex in regexs
        .where((reg) => reg.onRender)
        .where((reg) => reg.isAvailable(widget.chat, message))) {
      afterThink = regex.process(afterThink);
    }

    return Obx(() => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          // onLongPress: () => _showMessageOptions(message),
          child: widget.isNarration
              ? _buildNarration()
              : Padding(
                  padding: isHideName
                      ? const EdgeInsets.symmetric(horizontal: 16, vertical: 3)
                      : const EdgeInsets.only(
                          left: 16, right: 16, top: 10, bottom: 4),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe && !isHideName) ...[
                            _buildMessageAvatar(),
                            const SizedBox(width: 10),
                          ],

                          // 用于让连续消息对齐
                          if (!isMe && isHideName)
                            SizedBox(
                              width: avatarRadius * 2 + 10,
                            ),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                if (!isHideName) _buildMessageUserName(),

                                if (thinkContent.isNotEmpty)
                                  //思考过程块
                                  ThinkWidget(
                                      isThinking: isThinking,
                                      thinkContent: thinkContent),
                                // 主消息气泡
                                _buildMessageBubbleBody(afterThink),
                                SizedBox(height: 8.0),
                                widget.buildBottomButtons(
                                    widget.isSelected, message),
                              ],
                            ),
                          ),

                          if (isMe && !isHideName) ...[
                            const SizedBox(width: 10),
                            _buildMessageAvatar(),
                          ],
                          if (isMe && isHideName)
                            SizedBox(
                              width: avatarRadius * 2 + 10,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
        ));
  }
}
