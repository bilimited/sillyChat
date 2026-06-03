import 'dart:async';
import 'dart:convert';

import 'package:flutter_example/chat-app/models/chat_model.dart';
import 'package:flutter_example/chat-app/models/message_model.dart';
import 'package:flutter_example/chat-app/providers/character_controller.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/vault_setting_controller.dart';
import 'package:flutter_example/chat-app/utils/entitys/ChatAIState.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

class WebSessionController {
  InAppWebViewController webViewController;
  ChatSessionController chatSessionController;
  final Function(dynamic args) onMessageEmit;

  // ---- Handshake state ----
  bool _isJsReady = false;
  bool _hasSentInitialPush = false;
  final List<void Function()> _pendingPushes = [];
  Timer? _readyTimeout;
  static const Duration _readyTimeoutDuration = Duration(seconds: 5);

  // ---- Theme state ----
  String _currentThemeMode = 'light';

  WebSessionController(
      {required this.webViewController,
      required this.chatSessionController,
      required this.onMessageEmit});

  void onWebViewCreated(InAppWebViewController controller) {
    chatSessionController.bindWebController(this);

    // ---- JS -> Dart handlers ----

    // Manual resync: JS can request full chat data at any time
    controller.addJavaScriptHandler(
        handlerName: 'fetchChat',
        callback: (args) {
          onChatChange(chatSessionController.chat);
        });

    controller.addJavaScriptHandler(
        handlerName: 'fetchAllCharacters',
        callback: (args) {
          final charList = CharacterController.of.characters
              .map((c) => c.toJson(smallJson: true))
              .toList();
          return charList;
        });

    // emitMessage: user interactions from WebView
    controller.addJavaScriptHandler(
        handlerName: 'emitMessage',
        callback: (args) {
          if (args.isEmpty) return;
          final raw = args[0];

          final Map<String, dynamic> decoded;
          if (raw is String) {
            decoded = json.decode(raw);
          } else if (raw is Map) {
            decoded = Map<String, dynamic>.from(raw);
          } else {
            print('[emitMessage] Unexpected args type: ${raw.runtimeType}');
            return;
          }

          final action = decoded['action'] as String?;
          final data = decoded['data'] as Map<String, dynamic>?;

          switch (action) {
            case 'sendMessage':
              final text = data?['text'] as String? ?? '';
              final selectedPath = (data?['selectedPath'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  <String>[];
              chatSessionController.onSendMessage(text, selectedPath);
              break;

            case 'retry':
              final index = data?['index'] as int? ?? 1;
              chatSessionController.onRetry(index: index);
              break;

            case 'editMessage':
              final timeStr = data?['time'] as String?;
              final newContent = data?['newContent'] as String?;
              if (timeStr != null && newContent != null) {
                final time = DateTime.parse(timeStr);
                final msg = chatSessionController.chat.messages
                    .firstWhereOrNull((m) => m.time == time);
                if (msg != null) {
                  chatSessionController.updateMessage(
                    time,
                    msg.copyWith(content: newContent),
                  );
                }
              }
              break;

            case 'deleteMessage':
              final timeStr = data?['time'] as String?;
              if (timeStr != null) {
                chatSessionController.removeMessage(DateTime.parse(timeStr));
              }
              break;

            case 'interrupt':
              chatSessionController.interrupt();
              break;

            // ---- New message action cases ----

            case 'switchAlternative':
              final timeStr = data?['time'] as String?;
              final direction = data?['direction'] as String?;
              if (timeStr != null && direction != null) {
                _handleSwitchAlternative(timeStr, direction);
              }
              break;

            case 'deleteAlternatives':
              final timeStr = data?['time'] as String?;
              if (timeStr != null) {
                _handleDeleteAlternatives(timeStr);
              }
              break;

            default:
              // Forward to widget-level callback for custom handling
              // (copyMessage, pasteMessages, addImageToMessage, createBranch,
              //  optimizeMessage, messageMore, scrollStateChanged, etc.)
              onMessageEmit(decoded);
          }
        });

    // Connection handshake: JS calls this when Vue app is mounted
    controller.addJavaScriptHandler(
        handlerName: 'notifyReady',
        callback: (args) {
          if (!_isJsReady) {
            _isJsReady = true;
            _readyTimeout?.cancel();
            _pushInitialData();
            _flushPendingPushes();
          }
        });

    // Safety timeout: if JS never calls notifyReady, push anyway
    _readyTimeout = Timer(_readyTimeoutDuration, () {
      if (!_isJsReady) {
        print('[WebSession] JS ready timeout — pushing anyway');
        _isJsReady = true;
        _pushInitialData();
        _flushPendingPushes();
      }
    });
  }

  /// Push full chat + full AI state + theme + display settings
  /// as the initial data payload.
  void _pushInitialData() {
    onChatChange(chatSessionController.chat);
    onStateChange(chatSessionController.aiState, includeBuffer: true);

    // Push current theme mode
    _doPushTheme(_currentThemeMode);

    // Push display settings if available
    try {
      final displaySettings =
          VaultSettingController.of().displaySettingModel.value;
      onDisplaySettingsChange(displaySettings.toJson());
    } catch (_) {
      // VaultSettingController not available yet — settings will be
      // pushed later when chat_page wires up
    }

    _hasSentInitialPush = true;
  }

  /// Flush any pushes queued before JS was ready.
  void _flushPendingPushes() {
    for (final push in _pendingPushes) {
      push();
    }
    _pendingPushes.clear();
  }

  // ======================================================================
  // Dart -> JS push methods
  // ======================================================================

  /// Push AI state change to WebView.
  /// [includeBuffer] — when false, LLMBuffer is omitted (for streaming
  /// metadata-only pushes); when true, full state including buffer is sent.
  void onStateChange(ChatAIState newState, {bool includeBuffer = true}) {
    if (!_isJsReady) {
      _pendingPushes
          .add(() => onStateChange(newState, includeBuffer: includeBuffer));
      return;
    }
    print("ChatAIStateChange (buffer=${includeBuffer})");
    webViewController.evaluateJavascript(
        source:
            "window.onStateChange(${json.encode(newState.toJson(includeBuffer: includeBuffer))})");
  }

  /// Push full chat data to WebView.
  void onChatChange(ChatModel newChat) {
    if (!_isJsReady) {
      _pendingPushes.add(() => onChatChange(newChat));
      return;
    }
    print("window.onChatChange(${json.encode(newChat.toJson())})");
    webViewController.evaluateJavascript(
        source: "window.onChatChange(${json.encode(newChat.toJson())})");
  }

  // ---- Incremental message sync (P1) ----

  /// Push a single new message to WebView.
  void onMessageAdded(MessageModel msg, int index) {
    if (!_isJsReady || !_hasSentInitialPush) return;
    webViewController.evaluateJavascript(
        source:
            "window.onMessageAdded(${json.encode(msg.toJson())}, $index)");
  }

  /// Push an updated message to WebView.
  void onMessageUpdated(MessageModel msg) {
    if (!_isJsReady || !_hasSentInitialPush) return;
    webViewController.evaluateJavascript(
        source: "window.onMessageUpdated(${json.encode(msg.toJson())})");
  }

  /// Push a deleted message to WebView.
  void onMessageRemoved(MessageModel msg) {
    if (!_isJsReady || !_hasSentInitialPush) return;
    webViewController.evaluateJavascript(
        source: "window.onMessageRemoved(${json.encode(msg.toJson())})");
  }

  // ---- Token delta streaming (P1) ----

  /// Push a single token/chunk during AI streaming.
  void onTokenAppend(String token) {
    if (!_isJsReady) return;
    webViewController.evaluateJavascript(
        source: "window.onTokenAppend(${json.encode(token)})");
  }

  // ---- Theme & display settings ----

  /// Push theme mode change to WebView.
  /// [mode] — "light" or "dark". WebView uses its own CSS theme system.
  void onThemeChange(String mode) {
    _currentThemeMode = mode;
    if (!_isJsReady) {
      _pendingPushes.add(() => _doPushTheme(mode));
      return;
    }
    _doPushTheme(mode);
  }

  void _doPushTheme(String mode) {
    webViewController.evaluateJavascript(
        source: "window.onThemeChange(${json.encode({'mode': mode})})");
  }

  /// Push display settings to WebView.
  void onDisplaySettingsChange(Map<String, dynamic> settings) {
    if (!_isJsReady) {
      _pendingPushes.add(() => onDisplaySettingsChange(settings));
      return;
    }
    webViewController.evaluateJavascript(
        source:
            "window.onDisplaySettingsChange(${json.encode(settings)})");
  }

  // ---- Scroll control ----

  /// Tell WebView to scroll to the bottom of the message list.
  void scrollToBottom() {
    if (!_isJsReady) return;
    webViewController.evaluateJavascript(
        source: "window.scrollToBottom()");
  }

  /// Tell WebView to scroll to a specific message by id.
  void scrollToMessage(int messageId) {
    if (!_isJsReady) return;
    webViewController.evaluateJavascript(
        source: "window.scrollToMessage(${json.encode(messageId)})");
  }

  // ======================================================================
  // Internal message action handlers
  // (Actions that don't need Flutter UI context)
  // ======================================================================

  void _handleSwitchAlternative(String timeStr, String direction) {
    final time = DateTime.parse(timeStr);
    final msg = chatSessionController.chat.messages
        .firstWhereOrNull((m) => m.time == time);
    if (msg == null || msg.alternativeContent.length <= 1) return;

    final nullIndex = msg.alternativeContent.indexWhere((e) => e == null);
    if (nullIndex == -1) return;

    final len = msg.alternativeContent.length;
    final targetIndex = direction == 'right'
        ? (nullIndex + 1) % len
        : (nullIndex - 1 + len) % len;

    final oldContent = msg.content;
    msg.content = msg.alternativeContent[targetIndex] ?? '';
    msg.alternativeContent[nullIndex] = oldContent;
    msg.alternativeContent[targetIndex] = null;

    chatSessionController.updateMessage(msg.time, msg);
  }

  void _handleDeleteAlternatives(String timeStr) {
    final time = DateTime.parse(timeStr);
    final msg = chatSessionController.chat.messages
        .firstWhereOrNull((m) => m.time == time);
    if (msg == null) return;

    msg.alternativeContent.clear();
    msg.alternativeContent.add(null);
    chatSessionController.updateMessage(msg.time, msg);
  }

  // ---- Cleanup ----

  void dispose() {
    _readyTimeout?.cancel();
    _readyTimeout = null;
    _pendingPushes.clear();
    _isJsReady = false;
    _hasSentInitialPush = false;
  }
}
