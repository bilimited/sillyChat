import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_example/chat-app/models/character_model.dart';
import 'package:flutter_example/chat-app/pages/character/character_selector.dart';
import 'package:flutter_example/chat-app/pages/chat/chat_detail_page.dart';
import 'package:flutter_example/chat-app/pages/chat/new_group_chat.dart';
import 'package:flutter_example/chat-app/providers/chat_session_controller.dart';
import 'package:flutter_example/chat-app/providers/setting_controller.dart';
import 'package:flutter_example/chat-app/utils/customNav.dart';
import 'package:flutter_example/chat-app/widgets/chat/file_manager.dart';
import 'package:get/get.dart';
import '../../providers/chat_controller.dart';

class ChatPage extends StatefulWidget {
  final void Function(String chatPath)? onSelectChat;

  const ChatPage({Key? key, this.onSelectChat}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatController chatController = Get.find<ChatController>();
  final TextEditingController _searchController = TextEditingController();
  final RxString _searchText = ''.obs;

  bool isQuerying = false;
  bool _isSortingMode = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _searchText.value = _searchController.text;
      setState(() {
        isQuerying = _searchText.value.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> onCreateChat() async {
    final char = await customNavigate<CharacterModel?>(CharacterSelector(),
        context: context);

    if (char != null) {
      String path = await SettingController.of.getChatPath();
      final chat = await chatController.createChatFromCharacter(char, path);
      if (widget.onSelectChat != null) {
        widget.onSelectChat!(chat.file.path);
      } else {
        customNavigate(
            ChatDetailPage(
              sessionController: ChatSessionController(chat.file.path),
            ),
            context: context);
      }
    }
  }

  dynamic onTapFile(File file) {
    if (widget.onSelectChat != null) {
      widget.onSelectChat!(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Container(
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索聊天',
                hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                prefixIcon: Icon(
                  Icons.search,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 20,
                ),
                prefixIconConstraints: const BoxConstraints(
                  minHeight: 32,
                  minWidth: 32,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                suffixIcon: _searchText.value.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant),
                        onPressed: () {
                          _searchController.clear();
                          _searchText.value = '';
                        },
                      )
                    : null,
              ),
              style: TextStyle(color: theme.colorScheme.onSurface),
              cursorColor: theme.colorScheme.primary,
            ),
          ),
          actions: [
            PopupMenuButton<int>(
              icon: Icon(Icons.add, color: theme.colorScheme.onSurface),
              // TODO:重构新建聊天并添加到ChatController中
              tooltip: '新增聊天',
              onSelected: (value) async {
                if (value == 0) {
                  onCreateChat();
                } else if (value == 1) {
                  customNavigate(NewChatPage(), context: context);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 0,
                  child: Row(
                    children: [
                      const Icon(Icons.chat, size: 20),
                      const SizedBox(width: 8),
                      const Text('创建新聊天'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      const Icon(Icons.group, size: 20),
                      const SizedBox(width: 8),
                      const Text('创建新群聊'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
          ],
          backgroundColor:
              theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
          elevation: theme.appBarTheme.elevation ?? 0,
        ),
        body: FutureBuilder<Directory>(
          future: SettingController.of
              .getVaultPath()
              .then((path) => Directory('$path/chats')),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (snapshot.hasData) {
                return FileManagerWidget(
                    directory: snapshot.data!,
                    fileExtensions: const ['.json'], // 只显示这几种类型的文件
                    onFileTap: onTapFile);
              }
            }
            return const Center(child: CircularProgressIndicator());
          },
        ));
  }
}
