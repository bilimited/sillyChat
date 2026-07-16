import 'dart:io';

import 'package:figma_squircle/figma_squircle.dart';
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
import 'package:flutter_example/chat-app/widgets/common/sticky_overlay_container.dart';
import 'package:flutter_markdown_plus_latex/flutter_markdown_plus_latex.dart';

import 'package:flutter_example/chat-app/widgets/common/avatar_image.dart';
import 'package:flutter_example/chat-app/widgets/chat/content_segment.dart';
import 'package:flutter_example/chat-app/widgets/chat/markdown_extensions.dart';
import 'package:flutter_example/chat-app/widgets/chat/summary_message_bubble.dart';
import 'package:flutter_example/chat-app/widgets/chat/think_widget.dart';
import 'package:flutter_example/chat-app/widgets/chat/tool_call_result_widget.dart';
import 'package:flutter_example/main.dart';

import 'package:markdown/markdown.dart' as md;
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart'; // import 'package:flutter_markdown_latex/flutter_markdown_latex.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageBubble extends StatefulWidget {
  final MessageModel message;
  final ChatModel chat;
  final MessageModel? lastMessage;
  final int index;
  final bool isSelected;
  //final MessageStyle style;
  final void Function() onTap;
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
      required this.buildBottomButtons,
      required this.onUpdateChat,
      //required this.style,
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

  bool get isLoading => message.id == -9999;
  MessageStyle get style => message.style;

  DateTime? _pointerDownTime;
  Offset? _pointerDownPosition;

  @override
  void initState() {
    super.initState();
  }

  /// 解析消息内容为片段列表：文本、<think>思考块、<ToolCallResult>工具调用块
  ///
  /// 支持多个思考块和工具调用块穿插在文本中。
  /// 会检测末尾未闭合的 <think> 标签（流式输出中）。
  List<ContentSegment> _parseContentSegments(String content) {
    final segments = <ContentSegment>[];

    // 组合正则：同时匹配完整的 <think> 和 <ToolCallResult> 标签
    // group(1): think 内容；group(2): id；group(3): name；group(4): args；group(5): result
    final tagRegex = RegExp(
      r'<think>(.*?)</think>|'
      r'''<ToolCallResult\s+id="([^"]*)"\s+name="([^"]*)"\s+args='([^']*)'>(.*?)</ToolCallResult>''',
      dotAll: true,
    );

    int lastEnd = 0;
    for (final match in tagRegex.allMatches(content)) {
      // 标签之前的文本
      if (match.start > lastEnd) {
        final text = content.substring(lastEnd, match.start);
        if (text.isNotEmpty) {
          segments.add(
              ContentSegment(type: ContentSegmentType.text, content: text));
        }
      }

      if (match.group(1) != null) {
        // 完整的 <think> 块
        segments.add(ContentSegment(
          type: ContentSegmentType.think,
          content: match.group(1) ?? '',
        ));
      } else {
        // 完整的 <ToolCallResult> 块
        segments.add(ContentSegment(
          type: ContentSegmentType.toolCallResult,
          content: match.group(5) ?? '',
          attributes: {
            'id': match.group(2) ?? '',
            'name': match.group(3) ?? '',
            'args': match.group(4) ?? '',
          },
        ));
      }

      lastEnd = match.end;
    }

    // 处理最后一个标签之后的剩余内容
    if (lastEnd < content.length) {
      final remaining = content.substring(lastEnd);

      // 检查是否有未闭合的 <think> 标签（流式输出中）
      final unclosedThink =
          RegExp(r'<think>(.*)', dotAll: true).firstMatch(remaining);
      if (unclosedThink != null) {
        if (unclosedThink.start > 0) {
          segments.add(ContentSegment(
              type: ContentSegmentType.text,
              content: remaining.substring(0, unclosedThink.start)));
        }
        segments.add(ContentSegment(
          type: ContentSegmentType.think,
          content: unclosedThink.group(1) ?? '',
          isThinking: true,
        ));
      } else {
        if (remaining.isNotEmpty) {
          segments.add(ContentSegment(
              type: ContentSegmentType.text, content: remaining));
        }
      }
    }

    return segments;
  }

  Widget _buildMessageAvatar() {
    Widget _buildAvatar() {
      switch (displaySetting.avatarStyle) {
        case AvatarStyle.circle:
          return AvatarImage.round(character.avatar, avatarRadius);
        case AvatarStyle.rounded:
          return ClipSmoothRect(
              // 这里可以精确控制平滑度 (Smoothing)
              // iOS 图标的 smoothing 大约是 0.6
              radius: SmoothBorderRadius(
                cornerRadius: displaySetting.AvatarBorderRadius, // 圆角大小
                cornerSmoothing: 1, // 0.0 是普通圆角，1.0 是最平滑的超椭圆
              ),
              // borderRadius:
              //     BorderRadius.circular(displaySetting.AvatarBorderRadius),
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
        if (character.isDefaultAssistant) {
          return;
        }
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
    bool isNarration = widget.message.style == MessageStyle.narration;
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
      // if (message.bookmark != null)
      //   const Icon(Icons.bookmark, color: Colors.blue, size: 16),
      // // Pin icon (orange)
      // if (message.isPinned)
      //   const Icon(Icons.push_pin, color: Colors.orange, size: 16),
      // if (message.isHidden)
      //   const Icon(Icons.visibility_off, color: Colors.blueGrey, size: 16),
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
        : SelectionArea(
            child: MarkdownBody(
              data: content,
              onTapLink: (text, href, title) {
                _launchURL(href ?? '');
              },
              //selectable: true,
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
                textScaler: TextScaler.linear(displaySetting.ContentFontScale),
                blockquoteDecoration: BoxDecoration(
                  color: isMe
                      ? colors.primary.withOpacity(0.06)
                      : colors.surfaceVariant.withOpacity(0.04),
                  border: Border(
                    left: BorderSide(
                      color: isMe
                          ? colors.primary
                          : colors.primary.withOpacity(0.8),
                      width: 4,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                blockquote: TextStyle(
                  color: isMe ? colors.onPrimary : colors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
              builders: isMe
                  ? {}
                  : {
                      'quotedText': QuotedTextBuilder(
                          TextScaler.linear(displaySetting.ContentFontScale)),
                      'font': FontColorBuilder(),
                      'pre': CodeBlockBuilder(
                          TextScaler.linear(displaySetting.ContentFontScale)),
                      'latex': LatexElementBuilder(
                        textStyle: const TextStyle(
                          // color: Colors.blue,
                          fontWeight: FontWeight.w100,
                        ),
                        textScaleFactor: displaySetting.ContentFontScale,
                      ),
                    },
              extensionSet: md.ExtensionSet([
                const md.FencedCodeBlockSyntax(),
                const md.TableSyntax(),
                const md.UnorderedListWithCheckboxSyntax(),
                const md.OrderedListWithCheckboxSyntax(),
                const md.FootnoteDefSyntax(),
                //const md.HtmlBlockSyntax(),
                LatexBlockSyntax()
              ], [
                QuotedTextSyntax(),
                //HtmlTagSyntax(),
                LatexInlineSyntax()
              ]),
              softLineBreak: true,
              shrinkWrap: true,
              inlineSyntaxes: [],
            ),
          );
  }

  /// 构建消息片段容器 — 渲染所有内容片段（文本气泡、思考块、工具调用结果）
  Widget _buildSegmentsContainer(List<ContentSegment> segments) {
    return StickyOverlayContainer(
      overlay: widget.buildBottomButtons(widget.isSelected, message),
      alignment: isMe ? Alignment.bottomRight : Alignment.bottomLeft,
      margin: EdgeInsets.zero,
      child: SizedBox(
        width: double.infinity,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCirc,
          padding: widget.isSelected
              ? const EdgeInsetsGeometry.only(bottom: 24)
              : EdgeInsetsGeometry.zero,
          child: Stack(
            children: [
              Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // 图片附件（只在第一处渲染一次）
                    if (message.resPath.isNotEmpty) _buildMessageImage(),
                    // 渲染各个内容片段
                    ...segments.map((seg) => _buildSegmentWidget(seg)),
                    // 空消息且加载中时显示占位
                    if (segments.isEmpty && isLoading)
                      Container(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.state?.GenerateState ?? '加载中',
                              style: TextStyle(color: colors.outline),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (isLoading)
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 根据片段类型构建对应的 Widget
  Widget _buildSegmentWidget(ContentSegment seg) {
    switch (seg.type) {
      case ContentSegmentType.text:
        return _buildBubbleSwitcher(seg.content, colors);
      case ContentSegmentType.think:
        return ThinkWidget(
          isThinking: seg.isThinking,
          thinkContent: seg.content,
        );
      case ContentSegmentType.toolCallResult:
        return ToolCallResultWidget(
          id: seg.attributes?['id'] ?? '',
          name: seg.attributes?['name'] ?? '',
          args: seg.attributes?['args'] ?? '',
          result: seg.content,
        );
    }
  }

// 提取气泡样式判断，保持代码整洁
  Widget _buildBubbleSwitcher(String content, ColorScheme colors) {
    if (displaySetting.messageBubbleStyle == MessageBubbleStyle.bubble) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          decoration: BoxDecoration(
            color: isMe ? colors.primary : colors.surfaceContainer,
            borderRadius:
                BorderRadius.circular(displaySetting.MessageBubbleBorderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: _buildMessageContent(content),
        ),
      );
    } else if (displaySetting.messageBubbleStyle ==
        MessageBubbleStyle.compact) {
      return Column(
        mainAxisSize: MainAxisSize.min, // 确保 Column 不纵向铺满
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          _buildMessageContent(content),
          SizedBox(height: 16),
        ],
      );
    } else {
      return _buildMessageContent(content);
    }
  }

  /// 从消息内容中提取纯文本 — 跳过 <think> 和 <ToolCallResult> 块
  String _extractPlainText(String content) {
    final tagRegex = RegExp(
      r'<think>(.*?)</think>|'
      r'''<ToolCallResult\s+id="([^"]*)"\s+name="([^"]*)"\s+args='([^']*)'>(.*?)</ToolCallResult>''',
      dotAll: true,
    );

    final buffer = StringBuffer();
    int lastEnd = 0;
    for (final match in tagRegex.allMatches(content)) {
      if (match.start > lastEnd) {
        buffer.write(content.substring(lastEnd, match.start));
      }
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      final remaining = content.substring(lastEnd);
      // 去掉未闭合的 <think> 标签
      final cleaned =
          remaining.replaceFirst(RegExp(r'<think>.*', dotAll: true), '');
      buffer.write(cleaned);
    }

    return buffer.toString();
  }

  /// 模拟气泡 — 模拟微信等聊天应用的显示模式
  /// 消息内容按分隔符拆分为多个独立气泡，思考块/工具调用块隐藏
  Widget _buildSimulate(List<dynamic> regexs) {
    // 1. 提取纯文本（跳过 think / toolCallResult 块）
    var text = _extractPlainText(message.content);

    // 2. 应用正则规则
    for (final regex in regexs
        .where((reg) => reg.onRender)
        .where((reg) => reg.isAvailable(widget.chat, message))) {
      text = regex.process(text);
    }

    // 3. 按分隔符拆分
    final parts = text
        .split(displaySetting.simulateSplitDelimiter)
        .where((p) => p.trim().isNotEmpty)
        .toList();

    // 4. 判断是否正在生成
    final isGenerating = isLoading || (widget.state?.isGenerating == true);

    // 5. 空内容且生成中：显示"对方正在输入"
    if (parts.isEmpty && isGenerating) {
      return _buildBubbleSwitcher('', colors);
    }

    // 6. 空内容且不在生成中：显示空容器
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (message.resPath.isNotEmpty) _buildMessageImage(),
        ...List.generate(parts.length, (i) {
          final isLast = i == parts.length - 1;
          if (isLast && isGenerating) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildBubbleSwitcher(parts[i], colors),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Text(
                    '对方正在输入',
                    style: TextStyle(
                      color: colors.outline,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            );
          }
          return _buildBubbleSwitcher(parts[i], colors);
        }),
      ],
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
            height: 8,
          ),
          widget.buildBottomButtons(widget.isSelected, message)
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHideName = widget.lastMessage != null &&
        widget.lastMessage!.senderId == message.senderId;

    final regexs = widget.chat.vaildRegexs;

    // 解析消息内容为片段：文本、<think>思考块、<ToolCallResult>工具调用块
    final rawSegments = _parseContentSegments(message.content);

    // 仅对文本片段应用正则规则（思考块和工具调用块的内容不受正则影响）
    final segments = rawSegments.map((seg) {
      if (seg.type != ContentSegmentType.text) return seg;
      var text = seg.content;
      for (final regex in regexs
          .where((reg) => reg.onRender)
          .where((reg) => reg.isAvailable(widget.chat, message))) {
        text = regex.process(text);
      }
      return ContentSegment(type: ContentSegmentType.text, content: text);
    }).toList();

    return Obx(() {
      var gestureDetector = Listener(
        // onTap: widget.onTap,
        // onLongPress: widget.onLongPress,
        onPointerDown: (event) {
          _pointerDownTime = DateTime.now();
          _pointerDownPosition = event.position;
        },
        onPointerUp: (event) {
          if (_pointerDownTime != null && _pointerDownPosition != null) {
            final duration = DateTime.now().difference(_pointerDownTime!);
            final distance = (event.position - _pointerDownPosition!).distance;

            // 判定条件：按下到抬起小于 200ms，且移动距离小于 10 像素
            if (duration < const Duration(milliseconds: 200) &&
                distance < 10.0) {
              widget.onTap();
            }
          }
        },
        child: style == MessageStyle.narration
            ? _buildNarration()
            : style == MessageStyle.summary
                ? SummaryMessageBubble(
                    context: context,
                    isLoading: isLoading,
                    message: message,
                    displaySetting: displaySetting,
                    widget: widget)
                : style == MessageStyle.simulate
                    ? Padding(
                        padding: isHideName
                            ? const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 3)
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
                                      _buildSimulate(regexs),
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
                      )
                    : Padding(
                        padding: isHideName
                            ? const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 3)
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

                                      // 渲染消息片段：思考块、工具调用结果、文本气泡
                                      _buildSegmentsContainer(segments),
                                      // SizedBox(height: 8.0),
                                      // widget.buildBottomButtons(
                                      //     widget.isSelected, message),
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
      );
      if (message.isHidden) {
        return Opacity(
          opacity: 0.5,
          child: gestureDetector,
        );
      }

      if (message.isPinned) {
        return Stack(
          children: [
            // 橙色高亮背景和左侧亮橙色竖线
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.18),
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 4,
                      // margin: EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            gestureDetector,
          ],
        );
      }

      return gestureDetector;
    });
  }
}
