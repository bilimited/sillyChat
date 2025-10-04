import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/models/settings/chat_displaysetting_model.dart';
import 'package:flutter_example/chat-app/pages/character/edit_character_page.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/utils/entitys/ChatAIState.dart';
import 'package:flutter_example/chat-app/utils/image_utils.dart';
import 'package:flutter_example/chat-app/utils/markdown/latex_block_syntax.dart';
import 'package:flutter_example/chat-app/utils/markdown/latex_element_builder.dart';
import 'package:flutter_example/chat-app/utils/markdown/latex_inline_syntax.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_example/chat-app/widgets/chat/think_widget.dart';
import 'package:flutter_example/main.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown/flutter_markdown.dart';
// import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final TextScaler textScaler;

  // 在构造函数中接收 context
  QuotedTextBuilder(this.textScaler);

  @override
  Widget? visitElementAfterWithContext(BuildContext context, md.Element element,
      TextStyle? preferredStyle, TextStyle? parentStyle) {
    if (element.tag == 'quotedText') {
      // 在这里使用 context 来获取主题颜色
      final colors = Theme.of(context).colorScheme;
      return RichText(
        textScaler: textScaler,
        text: TextSpan(
          text: '"${element.textContent}"',
          style: TextStyle(
            color: colors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return null;
  }
}

class LatexSyntax extends md.InlineSyntax {
  LatexSyntax() : super(r'"([^"]*)"');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final text = md.Element.text('latex', match.group(1)!);
    parser.addNode(text);
    return true;
  }
}

class HtmlTagSyntax extends md.InlineSyntax {
  HtmlTagSyntax() : super(r'<([a-zA-Z0-9]+)\s*([^>]*)>(.*?)<\/\1>');

  // 正则表达式用于解析属性
  final _attributeRegex = RegExp(r'([a-zA-Z0-9_-]+)\s*=\s*('
      r'"([^"]*)"|' // 带双引号的属性值
      r"'([^']*)'|" // 带单引号的属性值
      r'([^>\s]+)' // 不带引号的属性值
      r')');

  /// 规范化颜色代码
  /// 将 #rgb, #rrggbb, #rrggbbaa 格式统一转换为 #rrggbbaaff
  String _normalizeColor(String color) {
    if (color.startsWith('#')) {
      String hex = color.substring(1);
      if (hex.length == 3) {
        // #rgb -> #rrggbb
        hex = hex.split('').map((c) => c + c).join('');
      }
      if (hex.length == 6) {
        // #rrggbb -> #rrggbbaa (默认alpha为ff)
        hex = '${hex}ff';
      }
      if (hex.length == 8) {
        return '${hex.toLowerCase()}';
      }
    }
    return color;
  }

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tagName = match.group(1)!;
    final attributesString = match.group(2) ?? '';
    final content = match.group(3) ?? '';

    final attributes = <String, String>{};
    for (final attrMatch in _attributeRegex.allMatches(attributesString)) {
      final key = attrMatch.group(1)!.toLowerCase();
      // group(3), group(4), group(5) 分别对应双引号、单引号和无引号的值
      String value =
          attrMatch.group(3) ?? attrMatch.group(4) ?? attrMatch.group(5) ?? '';

      if (key == 'color') {
        value = _normalizeColor(value);
      }
      attributes[key] = value;
    }

    final element = md.Element(tagName, [md.Text(content)]);
    element.attributes.addAll(attributes);
    parser.addNode(element);

    return true;
  }
}

class FontColorBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(BuildContext context, md.Element element,
      TextStyle? preferredStyle, TextStyle? parentStyle) {
    if (element.tag == 'font') {
      final color = element.attributes['color'];
      return RichText(
        text: TextSpan(
          text: element.textContent,
          style: parentStyle?.copyWith(color: Color(int.parse('0x$color'))),
        ),
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

  final ChatAIState? state;

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
      this.index = 0,
      this.state})
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
          : widget.chat.user.id == message.senderId;
  CharacterModel get character =>
      _characterController.getCharacterById(message.senderId);

  ChatDisplaySettingModel get displaySetting =>
      Get.find<VaultSettingController>().displaySettingModel.value;
  double get avatarRadius => displaySetting.AvatarSize;

  final bool isDesktop = SillyChatApp.isDesktop();

  @override
  void initState() {
    super.initState();
  }

  Widget _buildMessageAvatar() {
    Widget _buildAvatar() {
      switch (displaySetting.avatarStyle) {
        case AvatarStyle.circle:
          return CircleAvatar(
            backgroundImage: ImageUtils.getProvider(character.avatar),
            radius: avatarRadius,
          );
        case AvatarStyle.rounded:
          return ClipRRect(
              borderRadius:
                  BorderRadius.circular(displaySetting.AvatarBorderRadius),
              child: AvatarImage(
                fileName: character.avatar,
                width: avatarRadius * 2,
                height: avatarRadius * 2,
              ));
        case AvatarStyle.hidden:
          return SizedBox.shrink();
        default:
          return CircleAvatar(
            backgroundImage: Image.file(File(character.avatar)).image,
            radius: avatarRadius,
          );
      }
    }

    return GestureDetector(
      onTap: () {
        customNavigate(
            EditCharacterPage(
              characterId: character.id,
            ),
            context: context);
      },
      child: _buildAvatar(),
    );
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

  void _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      // Handle the case where the URL cannot be launched
      // For example, show a Snackbar or an AlertDialog
      print('Could not launch $url');
    }
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
                  widget.state?.GenerateState ?? '加载中',
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
                onTapLink: (text, href, title) {
                  _launchURL(href ?? '');
                },
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
                builders: isMe
                    ? {}
                    : {
                        'quotedText': QuotedTextBuilder(
                            TextScaler.linear(displaySetting.ContentFontScale)),
                        'font': FontColorBuilder(),
                        // 'latex': LatexElementBuilder(
                        //   // textStyle: const TextStyle(color: Colors.blue),
                        //   textScaleFactor: 1.2,
                        // ),
                      },
                extensionSet: md.ExtensionSet([
                  const md.FencedCodeBlockSyntax(),
                  const md.TableSyntax(),
                  const md.UnorderedListWithCheckboxSyntax(),
                  const md.OrderedListWithCheckboxSyntax(),
                  const md.FootnoteDefSyntax(),
                  LatexBlockSyntax()
                ], [
                  QuotedTextSyntax(),
                  HtmlTagSyntax(),
                  LatexInlineSyntax()
                ]),
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
        widget.lastMessage!.senderId == message.senderId;

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
          //behavior: HitTestBehavior.translucent,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
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
