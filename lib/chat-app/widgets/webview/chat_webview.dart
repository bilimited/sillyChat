import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/session_controller.dart';
import 'package:flutter_example/chat-app/providers/web_session_controller.dart';
import 'package:flutter_example/chat-app/widgets/AvatarImage.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:get/state_manager.dart';
import 'package:mime/mime.dart'; // 推荐引入 mime 包来动态获取 content-type

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
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Chat Interface with Console</title>
    <style>
        /* --- 基础设置 --- */
        * { box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
        body {
            margin: 0; padding: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            height: 100vh;
            display: flex; flex-direction: column;
            overflow: hidden;
        }

        /* --- 聊天容器 --- */
        #chat-container {
            flex: 1;
            overflow-y: auto;
            padding: 20px 12px;
            display: flex;
            flex-direction: column;
            gap: 20px;
            scroll-behavior: smooth;
        }
        #chat-container::-webkit-scrollbar { width: 0; height: 0; }

        /* --- 消息行布局 --- */
        .msg-row {
            display: flex;
            align-items: flex-start;
            gap: 10px;
            width: 100%;
        }
        .msg-row.user { flex-direction: row-reverse; }

        /* --- 头像样式 --- */
        .avatar-container {
            flex-shrink: 0;
            display: flex;
            flex-direction: column;
            align-items: center;
        }
        .avatar {
            width: 40px; height: 40px;
            border-radius: 50%;
            object-fit: cover;
            background-color: #e0e0e0;
            border: 1px solid rgba(0,0,0,0.05);
        }

        /* --- 消息内容区域 --- */
        .content-container {
            display: flex;
            flex-direction: column;
            max-width: 75%;
        }

        .nickname {
            font-size: 12px;
            color: #888;
            margin-bottom: 4px;
        }
        .msg-row.user .nickname { text-align: right; }
        .msg-row.assistant .nickname { text-align: left; }

        .bubble {
            padding: 10px 14px;
            border-radius: 12px;
            font-size: 15px;
            line-height: 1.5;
            word-break: break-word;
            white-space: pre-wrap; 
            position: relative;
            box-shadow: 0 1px 2px rgba(0,0,0,0.05);
        }
        
        .bubble img { max-width: 100%; height: auto; border-radius: 4px; display: block; margin: 5px 0; }
        .bubble p { margin: 0 0 5px 0; }
        .bubble pre { background: #f4f4f4; padding: 8px; border-radius: 4px; overflow-x: auto; }
        .bubble code { font-family: monospace; background: rgba(0,0,0,0.05); padding: 2px 4px; border-radius: 3px; }

        .msg-row.assistant .bubble {
            background-color: #ffffff;
            color: #333;
            border-top-left-radius: 2px;
        }
        .msg-row.user .bubble {
            background-color: #95ec69;
            color: #000;
            border-top-right-radius: 2px;
        }

        .cursor {
            display: inline-block; width: 2px; height: 15px;
            background-color: #333; vertical-align: middle;
            margin-left: 2px; animation: blink 1s infinite;
        }
        @keyframes blink { 50% { opacity: 0; } }

        .avatar-placeholder {
            display: flex; justify-content: center; align-items: center;
            font-size: 12px; color: #fff; background-color: #ccc;
        }

        /* --- 🆕 调试控制台样式 --- */
        .debug-trigger {
            position: fixed;
            bottom: 80px;
            right: 20px;
            width: 40px; height: 40px;
            background: rgba(0,0,0,0.6);
            color: #fff;
            border-radius: 50%;
            display: flex; justify-content: center; align-items: center;
            font-size: 20px;
            cursor: pointer;
            z-index: 999;
            box-shadow: 0 2px 8px rgba(0,0,0,0.2);
        }
        .debug-console {
            position: fixed;
            bottom: 0; left: 0; width: 100%; height: 40vh;
            background: rgba(30, 30, 30, 0.95);
            color: #00ff00;
            z-index: 1000;
            display: flex; flex-direction: column;
            font-family: monospace;
            font-size: 12px;
            border-top: 1px solid #444;
            transition: transform 0.3s ease;
        }
        .debug-header {
            padding: 8px 12px;
            background: #333;
            display: flex; justify-content: space-between; align-items: center;
            border-bottom: 1px solid #555;
        }
        .debug-body {
            flex: 1;
            overflow-y: auto;
            padding: 10px;
        }
        .log-item {
            margin-bottom: 4px;
            word-break: break-all;
            border-bottom: 1px solid rgba(255,255,255,0.1);
            padding-bottom: 2px;
        }
        .log-time { color: #888; margin-right: 8px; }
        .btn-mini {
            background: #555; color: #fff; border: none;
            padding: 2px 8px; border-radius: 4px; cursor: pointer; font-size: 10px;
        }

        [v-cloak] { display: none; }
    </style>
    <!-- 引入 Vue 3 -->
    <script src="https://unpkg.com/vue@3/dist/vue.global.js"></script>
</head>
<body>

    <div id="app" v-cloak>
        
        <!-- 聊天主区域 -->
        <div id="chat-container" ref="chatRef" @scroll="handleScroll">
            <!-- 历史消息 -->
            <div v-for="(msg, index) in messages" :key="index" class="msg-row" :class="msg.role">
                <div class="avatar-container">
                    <img v-if="getAvatarUrl(msg.role)" :src="getAvatarUrl(msg.role)" class="avatar" @error="handleImgError">
                    <div v-else class="avatar avatar-placeholder">
                        {{ getName(msg.role)[0] || (msg.role === 'user' ? 'U' : 'A') }}
                    </div>
                </div>
                <div class="content-container">
                    <div class="nickname">{{ getName(msg.role) }}</div>
                    <div class="bubble" v-html="msg.content"></div>
                </div>
            </div>

            <!-- 缓冲层 -->
            <div v-if="isStreaming" class="msg-row assistant">
                <div class="avatar-container">
                    <img v-if="assistant.avatar" :src="processAvatarUrl(assistant.avatar)" class="avatar" @error="handleImgError">
                    <div v-else class="avatar avatar-placeholder">{{ assistant.name[0] || 'A' }}</div>
                </div>
                <div class="content-container">
                    <div class="nickname">{{ assistant.name }}</div>
                    <div class="bubble"><span v-html="streamingBuffer"></span><span class="cursor"></span></div>
                </div>
            </div>
        </div>

        <!-- 🆕 调试控制台 UI -->
        <div class="debug-trigger" @click="toggleConsole">🐞</div>
        
        <div class="debug-console" v-if="showConsole">
            <div class="debug-header">
                <span>Console ({{ debugLogs.length }})</span>
                <div>
                    <button class="btn-mini" @click="clearLogs">清空</button>
                    <button class="btn-mini" @click="toggleConsole" style="margin-left:8px">关闭</button>
                </div>
            </div>
            <div class="debug-body" ref="consoleBodyRef">
                <div v-for="(log, idx) in debugLogs" :key="idx" class="log-item">
                    <span class="log-time">[{{ log.time }}]</span>
                    <span class="log-msg">{{ log.msg }}</span>
                </div>
            </div>
        </div>

    </div>

    <script>
        const { createApp, ref, reactive, nextTick, onMounted } = Vue;

        createApp({
            setup() {
                // --- 原有状态 ---
                const chatRef = ref(null);
                const chatId = ref(null);
                const autoScroll = ref(true);
                const assistant = reactive({ name: 'Assistant', avatar: '' });
                const user = reactive({ name: '我', avatar: '' });
                const messages = ref([]);
                const isStreaming = ref(false);
                const streamingBuffer = ref('');

                // --- 🆕 调试相关状态 ---
                const showConsole = ref(false);
                const debugLogs = ref([]);
                const consoleBodyRef = ref(null);

                // --- 工具方法 ---
                const processAvatarUrl = (path) => {
                    if (!path) return '';
                    if (path.startsWith('http')) return path;
                    let rawPath = path;
                    if (rawPath[0] !== '/') { rawPath = '/' + rawPath; }
                    return `imgs:///${rawPath}`;
                };
                const getAvatarUrl = (role) => role === 'user' ? processAvatarUrl(user.avatar) : processAvatarUrl(assistant.avatar);
                const getName = (role) => role === 'user' ? user.name : assistant.name;
                const handleImgError = (e) => { e.target.style.display = 'none'; };

                // --- 滚动逻辑 ---
                const handleScroll = () => {
                    const el = chatRef.value;
                    if (!el) return;
                    autoScroll.value = (el.scrollHeight - el.scrollTop - el.clientHeight) < 50;
                };

                const scrollToBottom = () => {
                    if (autoScroll.value && chatRef.value) {
                        nextTick(() => chatRef.value.scrollTop = chatRef.value.scrollHeight);
                    }
                };

                // --- 🆕 调试方法 ---
                const toggleConsole = () => {
                    showConsole.value = !showConsole.value;
                    // 打开时自动滚动到底部
                    if (showConsole.value) {
                        nextTick(() => scrollConsoleToBottom());
                    }
                };

                const addDebugLog = (msg) => {
                    const now = new Date();
                    const timeStr = `${now.getHours().toString().padStart(2,'0')}:${now.getMinutes().toString().padStart(2,'0')}:${now.getSeconds().toString().padStart(2,'0')}`;
                    
                    // 处理对象类型的打印
                    const finalMsg = typeof msg === 'object' ? JSON.stringify(msg) : String(msg);
                    
                    debugLogs.value.push({ time: timeStr, msg: finalMsg });

                    // 保持日志在最近 200 条
                    if (debugLogs.value.length > 200) {
                        debugLogs.value.shift();
                    }

                    if (showConsole.value) {
                        nextTick(() => scrollConsoleToBottom());
                    }
                };

                const clearLogs = () => {
                    debugLogs.value = [];
                };

                const scrollConsoleToBottom = () => {
                    if (consoleBodyRef.value) {
                        consoleBodyRef.value.scrollTop = consoleBodyRef.value.scrollHeight;
                    }
                };

                // --- 核心业务逻辑 ---
                const updateChat = (newChat) => {
                    if (!newChat) return;
                    // 🆕 记录日志
                    addDebugLog('Receive Chat Update');
                    
                    const chatData = typeof newChat === 'string' ? JSON.parse(newChat) : newChat;
                    assistant.name = chatData.name || 'Assistant';
                    assistant.avatar = chatData.avatar || '';

                    if (chatId.value !== chatData.id) {
                        addDebugLog(`Chat ID Changed: ${chatData.id}`);
                        messages.value = [];
                        chatId.value = chatData.id;
                        streamingBuffer.value = '';
                        isStreaming.value = false;
                        autoScroll.value = true;
                    }

                    const newMessages = chatData.messages || [];
                    if (newMessages.length > messages.value.length) {
                        const startIdx = messages.value.length;
                        for (let i = startIdx; i < newMessages.length; i++) {
                            messages.value.push(newMessages[i]);
                        }
                    } else if (newMessages.length < messages.value.length) {
                        messages.value = newMessages;
                    } else {
                        if (newMessages.length > 0) {
                            const lastIdx = newMessages.length - 1;
                            if (messages.value[lastIdx].content !== newMessages[lastIdx].content) {
                                messages.value[lastIdx].content = newMessages[lastIdx].content;
                            }
                        }
                    }
                    scrollToBottom();
                };

                const updateState = (newState) => {
                    if (!newState) return;
                    const sData = typeof newState === 'string' ? JSON.parse(newState) : newState;

                    if (sData.isGenerating && sData.LLMBuffer) {
                        if (!isStreaming.value) addDebugLog('Start Streaming...');
                        isStreaming.value = true;
                        streamingBuffer.value = sData.LLMBuffer;
                        scrollToBottom();
                    } else {
                        if (isStreaming.value) addDebugLog('Stop Streaming');
                        isStreaming.value = false;
                        streamingBuffer.value = '';
                    }
                };

                onMounted(() => {
                    // 暴露给全局 window
                    window.onChatChange = updateChat;
                    window.onStateChange = updateState;
                    // 🆕 暴露添加日志的方法给外部
                    window.addDebugLog = addDebugLog;

                    addDebugLog('Vue App Mounted. Waiting for Flutter...');

                    window.addEventListener("flutterInAppWebViewPlatformReady", function(event) {
                        addDebugLog('Flutter Bridge Ready');
                        if (window.flutter_inappwebview) {
                            window.flutter_inappwebview.callHandler('fetchChat');
                            window.flutter_inappwebview.callHandler('fetchAllCharacters').then((result)=>{
                              addDebugLog(result)
                            });
                        }
                    });
                });

                return {
                    // 聊天相关
                    chatRef, messages, assistant, user, isStreaming, streamingBuffer,
                    handleScroll, processAvatarUrl, getAvatarUrl, getName, handleImgError,
                    // 调试相关
                    showConsole, debugLogs, consoleBodyRef, toggleConsole, clearLogs
                };
            }
        }).mount('#app');
    </script>
</body>
</html>
""";
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: InAppWebView(
        initialData: InAppWebViewInitialData(data: _htmlContent),
        initialSettings: InAppWebViewSettings(resourceCustomSchemes: ['imgs']),
        onLoadResourceWithCustomScheme: (controller, request) async {
          if (request.url.scheme == 'imgs') {
            // 解析路径，移除 scheme 部分，得到实际文件路径
            // 注意：根据你的 HTML 写法，这里可能需要处理 /// 或者 //
            String filePath = AvatarImage.getPath(request.url.path);

            // 如果是 Android 绝对路径，可能需要适当调整 path
            // 例如: request.url.toString() 可能会把 /// 变成 /

            File file = File(filePath);

            if (await file.exists()) {
              var bytes = await file.readAsBytes();
              var mimeType = lookupMimeType(filePath) ?? 'image/png';

              // 3. 返回文件数据给 WebView
              return CustomSchemeResponse(
                data: bytes,
                contentType: mimeType,
              );
            } else {
              print("无法获取${filePath}");
            }
          }
          return null; // 如果文件不存在或出错，返回 null
        },
        onWebViewCreated: (controller) {
          _webViewController = controller;
          webSessionController.onWebViewCreated(controller);
        },
        onConsoleMessage: (controller, consoleMessage) {
          print(consoleMessage);
        },
      ),
    );
  }

  @override
  void dispose() {
    session.closeWebController();
    super.dispose();
  }
}
