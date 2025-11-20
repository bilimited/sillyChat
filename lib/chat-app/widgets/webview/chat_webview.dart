import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/session_controller.dart';
import 'package:flutter_example/chat-app/providers/web_session_controller.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:get/state_manager.dart';

class ChatWebview extends StatefulWidget {
  const ChatWebview({
    super.key,
    required this.session,
  });
  final ChatSessionController session;

  @override
  State<ChatWebview> createState() => _ChatWebviewState();
}

class _ChatWebviewState extends State<ChatWebview> {
  late InAppWebViewController _webViewController;

  ChatSessionController get session => widget.session;

  late final webSessionController = WebSessionController(
      webViewController: _webViewController, chatSessionController: session);

  String get _htmlContent {
    return r"""
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>聊天</title>
    <!-- Vue 3 CDN -->
    <script src="https://unpkg.com/vue@3/dist/vue.global.js"></script>
    <!-- Marked (Markdown Renderer) CDN -->
    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            margin: 0;
            background-color: #f0f2f5;
            color: #333;
        }

        #app {
            padding: 20px;
            display: flex;
            flex-direction: column;
        }

        .message {
            display: flex;
            align-items: flex-start;
            margin-bottom: 20px;
            max-width: 80%;
            animation: fadeIn 0.3s ease-in-out;
        }

        .message .avatar {
            width: 40px;
            height: 40px;
            border-radius: 50%;
            background-color: #ccc;
            display: flex;
            align-items: center;
            justify-content: center;
            font-weight: bold;
            color: white;
            flex-shrink: 0;
            font-size: 1.2em;
        }

        .message .content {
            background-color: #ffffff;
            padding: 12px 18px;
            border-radius: 18px;
            box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05);
            word-wrap: break-word;
            overflow-wrap: break-word;
        }
        
        /* Rendered Markdown styles */
        .content pre {
            background-color: #2d2d2d;
            color: #f8f8f2;
            padding: 1em;
            border-radius: 8px;
            overflow-x: auto;
        }
        .content code {
            font-family: "Fira Code", "Courier New", monospace;
        }
        .content p:first-child { margin-top: 0; }
        .content p:last-child { margin-bottom: 0; }


        /* User message styles */
        .message.user {
            align-self: flex-end;
            flex-direction: row-reverse;
        }

        .message.user .avatar {
            margin-left: 12px;
            background-color: #007bff;
        }

        .message.user .content {
            background-color: #e0f0ff;
        }

        /* Assistant message styles */
        .message.assistant {
            align-self: flex-start;
        }

        .message.assistant .avatar {
            margin-right: 12px;
            background-color: #6c757d;
        }
        
        /* Streaming message indicator */
        .streaming-cursor::after {
            content: '▋';
            animation: blink 1s step-end infinite;
            display: inline-block;
            margin-left: 2px;
            vertical-align: baseline;
        }

        @keyframes blink {
            from, to { opacity: 1; }
            50% { opacity: 0; }
        }

        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(10px); }
            to { opacity: 1; transform: translateY(0); }
        }
    </style>
</head>
<body>

<div id="app">
    <div v-for="message in allMessages" :key="message.id" class="message" :class="message.role">
        <div class="avatar">
            {{ message.role === 'user' ? 'U' : 'A' }}
        </div>
        <div class="content" v-html="renderMarkdown(message.content)"></div>
    </div>
</div>

<script>
    const { createApp, ref, computed, onMounted, nextTick } = Vue;

    createApp({
        setup() {
            // Reactive state for chat and generation status
            const chat = ref({ messages: [] });
            const state = ref({ LLMBuffer: '', isGenerating: false });

            // Computed property to merge historical messages with the currently streaming message
            const allMessages = computed(() => {
                const historicalMessages = chat.value.messages ? [...chat.value.messages] : [];
                
                if (state.value.isGenerating && state.value.LLMBuffer) {
                    historicalMessages.push({
                        id: 'streaming-message',
                        content: state.value.LLMBuffer,
                        role: 'assistant'
                    });
                }
                
                return historicalMessages;
            });

            // Function to render markdown content safely
            const renderMarkdown = (content) => {
                if (!content) return '';
                // Add blinking cursor to the last streaming message
                const isStreaming = state.value.isGenerating && content === state.value.LLMBuffer;
                const rendered = marked.parse(content, { gfm: true, breaks: true });
                return isStreaming ? rendered.replace(/<\/p>$/, '<span class="streaming-cursor"></span></p>') : rendered;
            };

            // Function to scroll to the bottom of the page
            const scrollToBottom = () => {
                nextTick(() => {
                    window.scrollTo({ top: document.body.scrollHeight, behavior: 'smooth' });
                });
            };

            // Set up global callback functions when the component is mounted
            onMounted(() => {
                window.onChatChange = (newChat) => {
                    chat.value = newChat;
                    scrollToBottom();
                };

                window.onStateChange = (newState) => {
                    state.value = newState;
                    scrollToBottom();
                };
            });

            return {
                allMessages,
                renderMarkdown
            };
        }
    }).mount('#app');
</script>

</body>
</html>```
""";
  }

  @override
  Widget build(BuildContext context) {
    return InAppWebView(
      initialData: InAppWebViewInitialData(data: _htmlContent),
      onWebViewCreated: (controller) {
        _webViewController = controller;
        webSessionController.onWebViewCreated(controller);
      },
      onConsoleMessage: (controller, consoleMessage) {
        print(consoleMessage);
      },
    );
  }

  @override
  void dispose() {
    session.closeWebController();
    super.dispose();
  }
}
