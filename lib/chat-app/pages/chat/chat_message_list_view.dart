import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';

/// Scroll controller that decouples ChatPage from the message list's scroll
/// implementation (Flutter ScrollController vs WebView evaluateJavascript).
///
/// ChatPage creates and holds an instance, passes it to the active message list
/// widget, which fills in the concrete scroll methods. ChatPage can then call
/// [scrollToBottom], [jumpToBottom], and [scrollToMessage] without knowing
/// which implementation is active.
class MessageListScrollController {
  VoidCallback? scrollToBottom;
  VoidCallback? jumpToBottom;
  void Function(int messageId)? scrollToMessage;

  void dispose() {
    scrollToBottom = null;
    jumpToBottom = null;
    scrollToMessage = null;
  }
}

/// Abstract base widget for a chat message list view.
///
/// Two concrete implementations exist:
/// - [FlutterChatMessageListView] — native Flutter ListView + MessageBubble
/// - WebviewChatMessageListView — WebView-based rendering via Vue 3
///
/// Common parameters shared by both implementations are defined here.
abstract class ChatMessageListView extends StatefulWidget {
  final ChatSessionController sessionController;

  /// Scroll controller that the implementation fills in. ChatPage reads from
  /// it to trigger scroll actions.
  final MessageListScrollController scrollController;

  /// Called when the user scrolls away from / back to the bottom.
  /// `true` means the user is reading history (not at bottom).
  final void Function(bool isReading) onReadingStateChanged;

  // -- WebView callbacks (null for Flutter implementation) --
  //
  // These are actions that originate from the WebView message list and
  // require Flutter UI context (Clipboard, Navigator, ImagePicker, dialogs).
  // The Flutter implementation handles these internally via its own BuildContext.

  final void Function(String text)? onCopyToClipboard;
  final void Function(String timeStr, String position)? onPasteMessages;
  final void Function(String timeStr)? onPickImageForMessage;
  final void Function(MessageModel message)? onCreateBranch;
  final void Function(MessageModel message)? onOptimizeMessage;
  final void Function(MessageModel message)? onMoreActions;

  const ChatMessageListView({
    super.key,
    required this.sessionController,
    required this.scrollController,
    required this.onReadingStateChanged,
    this.onCopyToClipboard,
    this.onPasteMessages,
    this.onPickImageForMessage,
    this.onCreateBranch,
    this.onOptimizeMessage,
    this.onMoreActions,
  });
}
