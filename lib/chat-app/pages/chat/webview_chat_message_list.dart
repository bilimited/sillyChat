import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_message_list_view.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/providers/web_session_controller.dart';
import 'package:flutter_example/chat-app/widgets/webview/chat_webview.dart';
import 'package:get/get.dart';

/// WebView-based message list implementation.
///
/// Renders messages using a Vue 3 frontend embedded via [ChatWebview]
/// (flutter_inappwebview). Communicates with the JS layer through the
/// BridgeAPI defined in `lib/webview/src/api/api.js`.
///
/// Data-only message actions (send, retry, edit, delete, interrupt,
/// switch alternative) are handled by [WebSessionController] directly.
/// UI-context actions (clipboard, navigation, image picker, dialogs) are
/// forwarded to ChatPage via callbacks.
class WebviewChatMessageListView extends ChatMessageListView {
  const WebviewChatMessageListView({
    super.key,
    required super.sessionController,
    required super.scrollController,
    required super.onReadingStateChanged,
    required super.onCopyToClipboard,
    required super.onPasteMessages, 
    required super.onPickImageForMessage,
    required super.onCreateBranch,
    required super.onOptimizeMessage,
    required super.onMoreActions,
  });

  @override
  State<WebviewChatMessageListView> createState() =>
      _WebviewChatMessageListState();
}

class _WebviewChatMessageListState extends State<WebviewChatMessageListView> {
  WebSessionController? _webSessionController;
  Worker? _themeWorker;

  late final VaultSettingController _settingController = Get.find();

  ChatSessionController get sessionController => widget.sessionController;
  ChatModel get chat => sessionController.chat;

  @override
  void initState() {
    super.initState();

    // Wire up scroll control — delegates to WebView JS evaluation
    widget.scrollController.scrollToBottom = () {
      sessionController.scrollToBottom();
    };
    widget.scrollController.jumpToBottom = () {
      sessionController.scrollToBottom();
    };
    widget.scrollController.scrollToMessage = (int messageId) {
      sessionController.scrollToMessage(messageId);
    };

    // Watch Flutter theme changes and push to WebView
    _themeWorker = ever(SettingController.of.isDarkMode, (bool isDark) {
      _webSessionController?.onThemeChange(isDark ? 'dark' : 'light');
    });
  }

  @override
  void dispose() {
    _themeWorker?.dispose();
    super.dispose();
  }

  // ─── WebSession created callback ────────────────────────────────────

  void _onWebSessionCreated(WebSessionController controller) {
    _webSessionController = controller;

    // Push initial theme
    final isDark = SettingController.of.isDarkMode.value;
    controller.onThemeChange(isDark ? 'dark' : 'light');

    // Push display settings
    controller.onDisplaySettingsChange(
        _settingController.displaySettingModel.value.toJson());
  }

  // ─── emitMessage handler ────────────────────────────────────────────

  /// Handles emitMessage actions from the WebView.
  ///
  /// Data-only actions (sendMessage, retry, editMessage, deleteMessage,
  /// interrupt, switchAlternative, deleteAlternatives) are already handled
  /// by [WebSessionController] internally and won't reach this handler.
  ///
  /// UI-context actions are forwarded to ChatPage via the callbacks provided
  /// in the constructor.
  void _onMessageEmit(dynamic args) {
    if (args is! Map) return;
    final action = args['action'] as String?;
    final data = args['data'] as Map<String, dynamic>?;

    switch (action) {
      case 'copyMessage':
        final text = data?['text'] as String? ?? '';
        widget.onCopyToClipboard?.call(text);
        break;

      case 'pasteMessages':
        final timeStr = data?['time'] as String?;
        final position = data?['position'] as String?;
        if (timeStr != null && position != null) {
          widget.onPasteMessages?.call(timeStr, position);
        }
        break;

      case 'addImageToMessage':
        final timeStr = data?['time'] as String?;
        if (timeStr != null) {
          widget.onPickImageForMessage?.call(timeStr);
        }
        break;

      case 'createBranch':
        final timeStr = data?['time'] as String?;
        if (timeStr != null) {
          final targetTime = DateTime.parse(timeStr);
          final msg =
              chat.messages.firstWhereOrNull((m) => m.time == targetTime);
          if (msg != null) widget.onCreateBranch?.call(msg);
        }
        break;

      case 'optimizeMessage':
        final timeStr = data?['time'] as String?;
        if (timeStr != null) {
          final targetTime = DateTime.parse(timeStr);
          final msg =
              chat.messages.firstWhereOrNull((m) => m.time == targetTime);
          if (msg != null) widget.onOptimizeMessage?.call(msg);
        }
        break;

      case 'messageMore':
        final timeStr = data?['time'] as String?;
        if (timeStr != null) {
          final targetTime = DateTime.parse(timeStr);
          final msg =
              chat.messages.firstWhereOrNull((m) => m.time == targetTime);
          if (msg != null) widget.onMoreActions?.call(msg);
        }
        break;

      case 'scrollStateChanged':
        final nearBottom = data?['isNearBottom'] as bool? ?? true;
        widget.onReadingStateChanged(!nearBottom);
        break;

      default:
        print('[WebviewChatMessageList] Unhandled emitMessage action: $action');
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ChatWebview(
      session: sessionController,
      onMessageEmit: _onMessageEmit,
      onWebSessionCreated: _onWebSessionCreated,
    );
  }
}
